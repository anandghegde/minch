import Foundation
import Testing
import MinchKit
@testable import MinchAPI

@Suite("TorBox client", .serialized)
struct ClientTests {
    @Test func endpointPathsAreStable() {
        #expect(Endpoint.me.path == "/user/me")
        #expect(Endpoint.listTorrents(bypassCache: false).path == "/torrents/mylist")
        #expect(Endpoint.addMagnet(magnet: "x", name: nil, cacheOnly: false).method == "POST")
    }

    @Test func listTorrentsQueryItems() {
        #expect(Endpoint.listTorrents(bypassCache: true).queryItems.first?.name == "bypass_cache")
        #expect(Endpoint.listTorrents(bypassCache: false).queryItems.isEmpty)
    }

    @Test func apiErrorBuckets() {
        #expect(APIError.auth("x").bucket == "auth")
        #expect(APIError.transient(underlying: "x").bucket == "transient")
        #expect(APIError.quota("x").bucket == "quota")
    }

    @Test func meDecodesSuccessfulEnvelope() async throws {
        let json = """
        { "success": true, "detail": "ok", "data": { "email": "a@b.com", "plan": 2, "is_subscribed": true } }
        """.data(using: .utf8)!

        let client = try makeClient(stub: .json(status: 200, data: json))
        let account = try await client.me()
        #expect(account.email == "a@b.com")
        #expect(account.plan == 2)
        #expect(account.planName == "Pro")
        #expect(account.isSubscribed == true)
    }

    @Test func meMapsAuthErrorOn401() async throws {
        let client = try makeClient(stub: .json(status: 401, data: Data("unauthorized".utf8)))
        await #expect(throws: APIError.self) {
            try await client.me()
        }
    }

    @Test func meMapsFailureEnvelopeAsValidation() async throws {
        let json = """
        { "success": false, "detail": "bad key", "error": "BAD_TOKEN" }
        """.data(using: .utf8)!
        let client = try makeClient(stub: .json(status: 200, data: json))
        do {
            _ = try await client.me()
            Issue.record("expected throw")
        } catch let error as APIError {
            #expect(error.bucket == "validation")
        }
    }

    @Test func listTransfersDecodesAndMaps() async throws {
        let json = """
        {
          "success": true,
          "data": [
            {
              "id": 42,
              "hash": "deadbeef",
              "name": "Sintel.4K",
              "size": 1500000000,
              "progress": 0.65,
              "download_speed": 1048576,
              "upload_speed": 0,
              "eta": 1200,
              "download_state": "downloading",
              "availability": 1.5,
              "files": [
                { "id": 1, "name": "sintel.mkv", "short_name": "sintel.mkv", "size": 1500000000, "mimetype": "video/x-matroska" }
              ]
            },
            {
              "id": 43,
              "hash": "feedface",
              "name": "Big.Buck.Bunny",
              "size": 800000000,
              "progress": 1.0,
              "download_state": "completed",
              "files": []
            }
          ]
        }
        """.data(using: .utf8)!

        let client = try makeClient(stub: .json(status: 200, data: json))
        let transfers = try await client.listTransfers()
        #expect(transfers.count == 2)

        let first = transfers[0]
        #expect(first.id.rawValue == "42")
        #expect(first.name == "Sintel.4K")
        #expect(first.status == .downloading)
        #expect(first.progress == 0.65)
        #expect(first.downloadSpeed == 1_048_576)
        #expect(first.eta == 1200)
        #expect(first.files.count == 1)
        #expect(first.files.first?.id.rawValue == "42:1")
        #expect(first.files.first?.mime == "video/x-matroska")

        #expect(transfers[1].status == .done)
        #expect(transfers[1].progress == 1.0)
    }

    @Test func statusMappingCoversAllBuckets() {
        #expect(TorBoxTransferDTO.mapStatus("downloading") == .downloading)
        #expect(TorBoxTransferDTO.mapStatus("uploading") == .seeding)
        #expect(TorBoxTransferDTO.mapStatus("completed") == .done)
        #expect(TorBoxTransferDTO.mapStatus("paused") == .paused)
        #expect(TorBoxTransferDTO.mapStatus("error") == .error)
        #expect(TorBoxTransferDTO.mapStatus("missingFiles") == .error)
        #expect(TorBoxTransferDTO.mapStatus(nil) == .queued)
        #expect(TorBoxTransferDTO.mapStatus("metaDL") == .downloading)
    }

    @Test func secretStoreProviderReadsLatestKey() async {
        let store = InMemorySecretStore(seed: [SecretKey.torboxAPIKey: "sk_1"])
        let provider = SecretStoreAPIKeyProvider(store: store)
        #expect(await provider.currentKey() == "sk_1")
        try? await store.write("sk_2", for: SecretKey.torboxAPIKey)
        #expect(await provider.currentKey() == "sk_2")
    }

    @Test func requestDownloadURLDecodesString() async throws {
        let json = """
        { "success": true, "detail": "ok", "data": "https://example.com/stream.mp4" }
        """.data(using: .utf8)!

        let client = try makeClient(stub: .json(status: 200, data: json))
        let url = try await client.requestDownloadURL(transferID: "42", fileID: "42:1")
        #expect(url.absoluteString == "https://example.com/stream.mp4")
    }

    @Test func requestWebDownloadURLDecodesString() async throws {
        let json = """
        { "success": true, "detail": "ok", "data": "https://example.com/stream.mp4" }
        """.data(using: .utf8)!

        let client = try makeClient(stub: .json(status: 200, data: json))
        let url = try await client.requestDownloadURL(transferID: "webdl:42", fileID: "webdl:42:1")
        #expect(url.absoluteString == "https://example.com/stream.mp4")
    }

    @Test func requestStreamURLDecodesHLS() async throws {
        let json = """
        { "success": true, "detail": "ok", "data": { "hls_url": "https://example.com/playlist.m3u8" } }
        """.data(using: .utf8)!

        let client = try makeClient(stub: .json(status: 200, data: json))
        let url = try await client.requestStreamURL(transferID: "42", fileID: "42:1")
        #expect(url.absoluteString == "https://example.com/playlist.m3u8")
    }

    private func makeClient(stub: StubResponse) throws -> TorBoxClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.next = stub
        let session = URLSession(configuration: config)
        return TorBoxClient(
            baseURL: URL(string: "https://stub.local/v1/api")!,
            session: session,
            keyProvider: StaticAPIKeyProvider("sk_test")
        )
    }
}

struct StubResponse: Sendable {
    let status: Int
    let body: Data
    static func json(status: Int, data: Data) -> StubResponse { .init(status: status, body: data) }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var next: StubResponse?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.next else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
