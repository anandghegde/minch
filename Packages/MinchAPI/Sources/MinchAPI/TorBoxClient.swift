import Foundation
import OSLog
import MinchKit

public protocol APIKeyProvider: Sendable {
    func currentKey() async -> String?
}

public struct StaticAPIKeyProvider: APIKeyProvider {
    private let key: String?
    public init(_ key: String?) { self.key = key }
    public func currentKey() async -> String? { key }
}

public struct SecretStoreAPIKeyProvider: APIKeyProvider {
    private let store: any SecretStore
    private let key: String
    public init(store: any SecretStore, key: String = SecretKey.torboxAPIKey) {
        self.store = store
        self.key = key
    }
    public func currentKey() async -> String? {
        try? await store.read(key)
    }
}

public struct UserAccount: Sendable, Codable, Equatable {
    public let email: String?
    public let plan: Int?
    public let isSubscribed: Bool?

    public init(email: String?, plan: Int?, isSubscribed: Bool?) {
        self.email = email
        self.plan = plan
        self.isSubscribed = isSubscribed
    }

    public var planName: String {
        switch plan {
        case 0: "Free"
        case 1: "Essential"
        case 2: "Pro"
        case 3: "Standard"
        default: "Member"
        }
    }
}

struct Envelope<T: Decodable>: Decodable {
    let success: Bool
    let detail: String?
    let error: String?
    let data: T?
}

struct CreateTorrentResult: Decodable, Sendable {
    let torrentID: Int?
    let hash: String?
    let queuedID: Int?
}

public actor TorBoxClient {
    public static let defaultBaseURL = URL(string: "https://api.torbox.app/v1/api")!

    private let session: URLSession
    private let baseURL: URL
    private let keyProvider: any APIKeyProvider
    private static let log = Logger(subsystem: "app.minch", category: "TorBoxClient")

    public init(
        baseURL: URL = TorBoxClient.defaultBaseURL,
        session: URLSession = .shared,
        keyProvider: any APIKeyProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keyProvider = keyProvider
    }

    public func me() async throws -> UserAccount {
        try await perform(.me, decoding: UserAccount.self)
    }

    public func listTransfers(bypassCache: Bool = false) async throws -> [Transfer] {
        let dtos = try await perform(.listTorrents(bypassCache: bypassCache), decoding: [TorBoxTransferDTO].self)
        return dtos.map { $0.toDomain() }
    }

    public func listWebDownloads(bypassCache: Bool = false) async throws -> [Transfer] {
        let dtos = try await perform(.listWebDownloads(bypassCache: bypassCache), decoding: [WebDownloadDTO].self)
        return dtos.map { $0.toDomain() }
    }

    public func addWebDownload(_ link: String, name: String? = nil) async throws {
        _ = try await perform(.addWebDownload(link: link, name: name), decoding: CreateTorrentResult.self)
    }

    /// Returns the list of file hosts TorBox supports for web downloads. Used
    /// by the Add bar to show "Supported hosts" hints.
    public func listHosters() async throws -> [Hoster] {
        try await perform(.listHosters, decoding: [Hoster].self)
    }

    public func subscriptions() async throws -> [Subscription] {
        try await perform(.subscriptions, decoding: [Subscription].self)
    }

    public func stats() async throws -> UserStats {
        try await perform(.stats, decoding: UserStats.self)
    }

    /// Reads `/user/me?settings=true` and returns the embedded `settings` map
    /// as a flat dict of scalars. Arrays and nested objects are skipped — the
    /// generic Settings form doesn't render them.
    public func loadUserSettings() async throws -> [String: Endpoint.SettingValue] {
        let value = try await perform(.meSettings, decoding: JSONValue.self)
        guard case .object(let obj) = value,
              let settingsValue = obj["settings"],
              case .object(let settings) = settingsValue
        else { return [:] }
        var result: [String: Endpoint.SettingValue] = [:]
        for (key, value) in settings {
            switch value {
            case .bool(let v): result[key] = .bool(v)
            case .string(let v): result[key] = .string(v)
            case .number(let v): result[key] = .number(v)
            case .null: result[key] = .null
            case .array, .object:
                continue
            }
        }
        return result
    }

    /// PUT /user/settings/editsettings — submit only the changed keys.
    public func updateSettings(_ values: [String: Endpoint.SettingValue]) async throws {
        try await performVoid(.editSettings(values: values))
    }

    /// webdl transfer IDs are namespaced "webdl:<n>" to avoid colliding with
    /// torrent integer IDs in the merged SyncEngine list. Strip the prefix to
    /// get the raw numeric id TorBox expects.
    private static func splitWebDL(_ transferID: String) -> String? {
        guard transferID.hasPrefix("webdl:") else { return nil }
        return String(transferID.dropFirst("webdl:".count))
    }

    public func requestDownloadURL(transferID: String, fileID: String) async throws -> URL {
        // Files are stored with composite IDs ("<transferID>:<fileID>") so that
        // SwiftData uniqueness holds across transfers. TorBox expects the raw
        // numeric file id, so strip the prefix here.
        let rawFileID = fileID.split(separator: ":").last.map(String.init) ?? fileID
        if let webID = Self.splitWebDL(transferID) {
            Self.log.debug("webdl requestdl web=\(webID, privacy: .public) file=\(rawFileID, privacy: .public)")
            let raw = try await perform(.requestWebDownloadURL(webID: webID, fileID: rawFileID), decoding: String.self)
            guard let url = URL(string: raw) else {
                throw APIError.decoding("webdl requestdl returned non-URL: \(raw)")
            }
            return url
        }
        Self.log.debug("requestdl transfer=\(transferID, privacy: .public) file=\(rawFileID, privacy: .public) (input=\(fileID, privacy: .public))")
        let raw = try await perform(.requestDownloadURL(torrentID: transferID, fileID: rawFileID), decoding: String.self)
        guard let url = URL(string: raw) else {
            throw APIError.decoding("requestdl returned non-URL: \(raw)")
        }
        return url
    }

    /// Builds a `/torrents/requestdl?redirect=true` URL that the caller can
    /// hand directly to AVPlayer or open in a browser; the server 302s to the
    /// CDN URL on first access, skipping a round-trip through this client.
    /// Returns nil if no API key is available.
    public func directDownloadURL(transferID: String, fileID: String) async -> URL? {
        let rawFileID = fileID.split(separator: ":").last.map(String.init) ?? fileID
        guard let key = await keyProvider.currentKey() else { return nil }
        if let webID = Self.splitWebDL(transferID) {
            var comps = URLComponents(
                url: baseURL.appendingPathComponent("/webdl/requestdl"),
                resolvingAgainstBaseURL: false
            )
            comps?.queryItems = [
                URLQueryItem(name: "web_id", value: webID),
                URLQueryItem(name: "file_id", value: rawFileID),
                URLQueryItem(name: "token", value: key),
                URLQueryItem(name: "redirect", value: "true"),
            ]
            return comps?.url
        }
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/torrents/requestdl"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [
            URLQueryItem(name: "torrent_id", value: transferID),
            URLQueryItem(name: "file_id", value: rawFileID),
            URLQueryItem(name: "token", value: key),
            URLQueryItem(name: "redirect", value: "true"),
        ]
        return comps?.url
    }

    public func addMagnet(_ magnet: String, name: String? = nil, cacheOnly: Bool = false) async throws {
        _ = try await perform(.addMagnet(magnet: magnet, name: name, cacheOnly: cacheOnly), decoding: CreateTorrentResult.self)
    }

    public func addTorrentFile(_ data: Data, filename: String, name: String? = nil, cacheOnly: Bool = false) async throws {
        _ = try await perform(.addTorrentFile(data: data, filename: filename, name: name, cacheOnly: cacheOnly), decoding: CreateTorrentResult.self)
    }

    /// Returns the subset of input hashes that TorBox reports as cached. Used
    /// to surface a "will be instant" preflight before adding a magnet.
    public func checkCached(hashes: [String]) async throws -> Set<String> {
        guard !hashes.isEmpty else { return [] }
        let request = try await makeRequest(.checkCached(hashes: hashes))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(status: -1, body: "non-http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Self.logHTTPFailure(http: http, request: request, body: body)
            throw mapStatus(http.statusCode, body: body, response: http)
        }
        // checkcached returns `data` as an object keyed by hash (when present
        // in cache) or `null`/`false` when not. We accept either shape.
        struct Bare: Decodable { let success: Bool?; let data: JSONValue? }
        let parsed = try? JSONDecoder.minch.decode(Bare.self, from: data)
        guard parsed?.success ?? false, let value = parsed?.data else { return [] }
        let wanted = Set(hashes.map { $0.lowercased() })
        var hits: Set<String> = []
        switch value {
        case .object(let dict):
            for key in dict.keys where wanted.contains(key.lowercased()) {
                if case .bool(false) = dict[key] { continue }
                if case .null = dict[key] { continue }
                hits.insert(key.lowercased())
            }
        default:
            break
        }
        return hits
    }

    public func controlTransfer(id: String, op: Endpoint.ControlOp) async throws {
        if let webID = Self.splitWebDL(id) {
            try await performVoid(.controlWebDownload(id: webID, op: op))
        } else {
            try await performVoid(.controlTorrent(id: id, op: op))
        }
    }

    public func editTransfer(id: String, name: String? = nil, tags: [String]? = nil) async throws {
        if let webID = Self.splitWebDL(id) {
            // TorBox webdl edit accepts name only; tags are best-effort and not
            // exposed on /webdl/editwebdownload, so we drop them here.
            try await performVoid(.editWebDownload(id: webID, name: name))
        } else {
            try await performVoid(.editTorrent(id: id, name: name, tags: tags))
        }
    }

    func performVoid(_ endpoint: Endpoint) async throws {
        let request = try await makeRequest(endpoint)
        Self.log.debug("→ \(request.httpMethod ?? "?", privacy: .public) \(request.url?.absoluteString ?? "?", privacy: .public)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(status: -1, body: "non-http response")
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            Self.logHTTPFailure(http: http, request: request, body: body)
            throw mapStatus(http.statusCode, body: body, response: http)
        }
        Self.log.debug("← HTTP \(http.statusCode, privacy: .public) \(request.url?.path ?? "?", privacy: .public) \(data.count, privacy: .public)B")
        struct Bare: Decodable { let success: Bool?; let detail: String?; let error: String? }
        if let envelope = try? JSONDecoder.minch.decode(Bare.self, from: data), envelope.success == false {
            throw APIError.validation(envelope.detail ?? envelope.error ?? "envelope reported failure")
        }
    }

    func perform<T: Decodable & Sendable>(_ endpoint: Endpoint, decoding _: T.Type) async throws -> T {
        let request = try await makeRequest(endpoint)
        Self.log.debug("→ \(request.httpMethod ?? "?", privacy: .public) \(request.url?.absoluteString ?? "?", privacy: .public)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            Self.log.error("non-http response")
            throw APIError.unknown(status: -1, body: "non-http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Self.logHTTPFailure(http: http, request: request, body: body)
            throw mapStatus(http.statusCode, body: body, response: http)
        }
        Self.log.debug("← HTTP \(http.statusCode, privacy: .public) \(request.url?.path ?? "?", privacy: .public) \(data.count, privacy: .public)B")
        let envelope: Envelope<T>
        do {
            envelope = try JSONDecoder.minch.decode(Envelope<T>.self, from: data)
        } catch {
            Self.log.error("decode failed: \(String(describing: error), privacy: .public) body=\(String(data: data, encoding: .utf8) ?? "", privacy: .public)")
            throw APIError.decoding(String(describing: error))
        }
        guard envelope.success, let value = envelope.data else {
            let msg = envelope.detail ?? envelope.error ?? "envelope reported failure"
            Self.log.error("envelope failure: \(msg, privacy: .public)")
            throw APIError.validation(msg)
        }
        return value
    }

    static func logHTTPFailure(http: HTTPURLResponse, request: URLRequest, body: String) {
        let path = request.url?.path ?? "?"
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After") ?? "—"
        let limit = http.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "—"
        let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "—"
        Self.log.error("← HTTP \(http.statusCode, privacy: .public) \(path, privacy: .public) retry-after=\(retryAfter, privacy: .public) limit=\(limit, privacy: .public) remaining=\(remaining, privacy: .public) body=\(body, privacy: .public)")
        // Also dump to stderr so it's visible when the app was launched from a
        // terminal — useful while debugging rate-limit storms.
        FileHandle.standardError.write(Data("[TorBox] HTTP \(http.statusCode) \(path) retry-after=\(retryAfter) remaining=\(remaining) body=\(body)\n".utf8))
    }

    func makeRequest(_ endpoint: Endpoint) async throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )!
        let key = await keyProvider.currentKey()
        var items = endpoint.queryItems
        if case .requestDownloadURL = endpoint, let key {
            items.append(URLQueryItem(name: "token", value: key))
        }
        if case .requestWebDownloadURL = endpoint, let key {
            items.append(URLQueryItem(name: "token", value: key))
        }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else {
            throw APIError.validation("could not construct URL for \(endpoint.path)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if let filePart = endpoint.multipartFilePart {
            let boundary = "minch-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = Self.encodeMultipartWithFile(
                file: filePart,
                fields: endpoint.multipartTextFields ?? [:],
                boundary: boundary
            )
        } else if let fields = endpoint.multipartFields {
            let boundary = "minch-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = Self.encodeMultipart(fields: fields, boundary: boundary)
        } else if let json = endpoint.jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [])
        }
        return req
    }

    static func encodeMultipart(fields: [String: String], boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("\(value)\(crlf)".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    static func encodeMultipartWithFile(
        file: (fieldName: String, filename: String, data: Data),
        fields: [String: String],
        boundary: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("\(value)\(crlf)".data(using: .utf8)!)
        }
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.filename)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: application/x-bittorrent\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(file.data)
        body.append("\(crlf)".data(using: .utf8)!)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    func mapStatus(_ code: Int, body: String, response: HTTPURLResponse? = nil) -> APIError {
        switch code {
        case 401, 403: return .auth("HTTP \(code)")
        case 402, 429:
            let retry = response?.value(forHTTPHeaderField: "Retry-After") ?? "?"
            let remaining = response?.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "?"
            return .quota("HTTP \(code) retry-after=\(retry)s remaining=\(remaining)")
        case 400, 422: return .validation(body)
        case 500...599: return .transient(underlying: "HTTP \(code)")
        default: return .unknown(status: code, body: body)
        }
    }
}

extension JSONDecoder {
    static let minch: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// Minimal heterogeneous JSON value used to decode endpoints whose response
/// shape can't be pinned to a single Codable type (e.g. checkcached returns a
/// hash-keyed object on hit and a bool/null on miss).
enum JSONValue: Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Double.self) { self = .number(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported JSON shape")
    }
}
