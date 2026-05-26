import Foundation

public enum Endpoint: Sendable {
    case me
    case listTorrents(bypassCache: Bool)
    case torrentInfo(id: String)
    case addMagnet(magnet: String, name: String?, cacheOnly: Bool)
    case addTorrentFile(data: Data, filename: String, name: String?, cacheOnly: Bool)
    case checkCached(hashes: [String])
    case requestDownloadURL(torrentID: String, fileID: String)
    case controlTorrent(id: String, op: ControlOp)
    case editTorrent(id: String, name: String?, tags: [String]?)

    case listWebDownloads(bypassCache: Bool)
    case addWebDownload(link: String, name: String?)
    case requestWebDownloadURL(webID: String, fileID: String)
    case controlWebDownload(id: String, op: ControlOp)
    case editWebDownload(id: String, name: String?)
    case listHosters
    case subscriptions
    case stats
    case meSettings
    case editSettings(values: [String: SettingValue])

    /// Whitelisted scalar shape for `/user/settings/editsettings` payloads.
    /// Mirrors the JSON shape we'll send for each editable field; arrays/dicts
    /// are deliberately excluded — the generic form skips those keys.
    public enum SettingValue: Sendable, Equatable {
        case bool(Bool)
        case string(String)
        case number(Double)
        case null

        public var boolValue: Bool? {
            if case .bool(let v) = self { return v }
            return nil
        }

        public var stringValue: String? {
            if case .string(let v) = self { return v }
            return nil
        }

        public var numberStringValue: String? {
            if case .number(let v) = self {
                if v.rounded() == v, abs(v) < 1e15 { return String(Int64(v)) }
                return String(v)
            }
            return nil
        }
    }

    public enum ControlOp: String, Sendable {
        case pause, resume, reannounce, delete
    }

    public var method: String {
        switch self {
        case .me, .listTorrents, .torrentInfo, .checkCached, .requestDownloadURL,
             .listWebDownloads, .requestWebDownloadURL, .listHosters,
             .subscriptions, .stats, .meSettings: "GET"
        case .addMagnet, .addTorrentFile, .controlTorrent,
             .addWebDownload, .controlWebDownload: "POST"
        case .editTorrent, .editWebDownload, .editSettings: "PUT"
        }
    }

    public var path: String {
        switch self {
        case .me: "/user/me"
        case .listTorrents: "/torrents/mylist"
        case .torrentInfo: "/torrents/torrentinfo"
        case .checkCached: "/torrents/checkcached"
        case .addMagnet, .addTorrentFile: "/torrents/createtorrent"
        case .requestDownloadURL: "/torrents/requestdl"
        case .controlTorrent: "/torrents/controltorrent"
        case .editTorrent: "/torrents/edittorrent"
        case .listWebDownloads: "/webdl/mylist"
        case .addWebDownload: "/webdl/createwebdownload"
        case .requestWebDownloadURL: "/webdl/requestdl"
        case .controlWebDownload: "/webdl/controlwebdownload"
        case .editWebDownload: "/webdl/editwebdownload"
        case .listHosters: "/webdl/hosters"
        case .subscriptions: "/user/subscriptions"
        case .stats: "/user/stats"
        case .meSettings: "/user/me"
        case .editSettings: "/user/settings/editsettings"
        }
    }

    public var multipartFields: [String: String]? {
        switch self {
        case .addMagnet(let magnet, let name, let cacheOnly):
            var fields: [String: String] = ["magnet": magnet]
            if let name, !name.isEmpty { fields["name"] = name }
            if cacheOnly { fields["as_queued"] = "false" }
            // TorBox docs: `seed` and `allow_zip` are also accepted; we leave them
            // as server defaults. `cache_only` ("only complete if cached") maps
            // to creating the torrent with `as_queued=false` per CLI behavior.
            return fields
        case .addWebDownload(let link, let name):
            var fields: [String: String] = ["link": link]
            if let name, !name.isEmpty { fields["name"] = name }
            return fields
        default:
            return nil
        }
    }

    /// Raw multipart payload for `.torrent` file uploads. The first tuple is the
    /// file field; the rest are text fields. We keep this separate from
    /// `multipartFields` so encoding can stream the binary blob without
    /// base64-ing it.
    public var multipartFilePart: (fieldName: String, filename: String, data: Data)? {
        switch self {
        case .addTorrentFile(let data, let filename, _, _):
            return ("file", filename, data)
        default:
            return nil
        }
    }

    public var multipartTextFields: [String: String]? {
        switch self {
        case .addTorrentFile(_, _, let name, let cacheOnly):
            var fields: [String: String] = [:]
            if let name, !name.isEmpty { fields["name"] = name }
            if cacheOnly { fields["as_queued"] = "false" }
            return fields.isEmpty ? nil : fields
        default:
            return nil
        }
    }

    public var jsonBody: [String: Any]? {
        switch self {
        case .controlTorrent(let id, let op):
            return ["torrent_id": Int(id) ?? id, "operation": op.rawValue]
        case .editTorrent(let id, let name, let tags):
            var body: [String: Any] = ["torrent_id": Int(id) ?? id]
            if let name { body["name"] = name }
            if let tags { body["tags"] = tags }
            return body
        case .controlWebDownload(let id, let op):
            return ["webdl_id": Int(id) ?? id, "operation": op.rawValue]
        case .editWebDownload(let id, let name):
            var body: [String: Any] = ["webdl_id": Int(id) ?? id]
            if let name { body["name"] = name }
            return body
        case .editSettings(let values):
            var body: [String: Any] = [:]
            for (key, value) in values {
                switch value {
                case .bool(let v): body[key] = v
                case .string(let v): body[key] = v
                case .number(let v): body[key] = v
                case .null: body[key] = NSNull()
                }
            }
            return body
        default:
            return nil
        }
    }

    public var queryItems: [URLQueryItem] {
        switch self {
        case .listTorrents(let bypass):
            return bypass ? [URLQueryItem(name: "bypass_cache", value: "true")] : []
        case .torrentInfo(let id):
            return [URLQueryItem(name: "id", value: id)]
        case .checkCached(let hashes):
            return [
                URLQueryItem(name: "hash", value: hashes.joined(separator: ",")),
                URLQueryItem(name: "format", value: "object"),
                URLQueryItem(name: "list_files", value: "false"),
            ]
        case .requestDownloadURL(let tid, let fid):
            return [
                URLQueryItem(name: "torrent_id", value: tid),
                URLQueryItem(name: "file_id", value: fid),
            ]
        case .listWebDownloads(let bypass):
            return bypass ? [URLQueryItem(name: "bypass_cache", value: "true")] : []
        case .requestWebDownloadURL(let wid, let fid):
            return [
                URLQueryItem(name: "web_id", value: wid),
                URLQueryItem(name: "file_id", value: fid),
            ]
        case .stats:
            return [
                URLQueryItem(name: "general", value: "true"),
                URLQueryItem(name: "bandwidth", value: "false"),
            ]
        case .meSettings:
            return [URLQueryItem(name: "settings", value: "true")]
        default:
            return []
        }
    }
}
