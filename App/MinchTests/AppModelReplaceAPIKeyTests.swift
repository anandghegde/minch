import Foundation
import Testing
import MinchAPI
import MinchKit
import MinchDownloads
@testable import Minch

@Suite("AppModel.replaceAPIKey")
@MainActor
struct AppModelReplaceAPIKeyTests {
    /// In-memory secret store so tests don't touch Keychain.
    final class StubSecretStore: SecretStore, @unchecked Sendable {
        var stored: [String: String] = [:]
        var writeCount = 0
        func read(_ key: String) async throws -> String? { stored[key] }
        func write(_ value: String, for key: String) async throws {
            stored[key] = value
            writeCount += 1
        }
        func delete(_ key: String) async throws { stored.removeValue(forKey: key) }
    }

    @Test
    func rejectsEmptyKey() async {
        let store = StubSecretStore()
        store.stored[SecretKey.torboxAPIKey] = "old-key"
        let model = AppModel(
            secretStore: store,
            clientFactory: { _ in TorBoxClient(keyProvider: StaticAPIKeyProvider("x")) }
        )
        await #expect(throws: Error.self) {
            try await model.replaceAPIKey("   ")
        }
        // Old key is preserved.
        #expect(store.stored[SecretKey.torboxAPIKey] == "old-key")
    }

    @Test
    func failedValidationKeepsOldKey() async {
        let store = StubSecretStore()
        store.stored[SecretKey.torboxAPIKey] = "old-key"
        // clientFactory returns a client whose `me()` will fail (bogus URL).
        let model = AppModel(
            secretStore: store,
            clientFactory: { _ in
                TorBoxClient(
                    baseURL: URL(string: "http://127.0.0.1:1/never")!,
                    session: URLSession(configuration: .ephemeral),
                    keyProvider: StaticAPIKeyProvider("bad")
                )
            }
        )
        await #expect(throws: Error.self) {
            try await model.replaceAPIKey("new-but-broken")
        }
        #expect(store.stored[SecretKey.torboxAPIKey] == "old-key")
        #expect(store.writeCount == 0)
    }

    @Test
    func downloadFolderDefaultsToDefaultDestinationRoot() async {
        let store = StubSecretStore()
        UserDefaults.standard.removeObject(forKey: "customDownloadFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "customDownloadFolderPath")

        let model = AppModel(secretStore: store)
        #expect(model.customDownloadFolderURL.path == DownloadManager.defaultDestinationRoot().path)
    }

    @Test
    func downloadFolderUpdatesAndPersists() async {
        let store = StubSecretStore()
        UserDefaults.standard.removeObject(forKey: "customDownloadFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "customDownloadFolderPath")

        let model = AppModel(secretStore: store)
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        model.updateDownloadFolder(tempDir)

        #expect(model.customDownloadFolderURL.path == tempDir.path)
        #expect(UserDefaults.standard.string(forKey: "customDownloadFolderPath") == tempDir.path)

        // Check load on new instance
        let model2 = AppModel(secretStore: store)
        #expect(model2.customDownloadFolderURL.path == tempDir.path)

        UserDefaults.standard.removeObject(forKey: "customDownloadFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "customDownloadFolderPath")
    }

    @Test
    func ingestDroppedProvidersParsesMagnetString() async {
        let store = StubSecretStore()
        let model = AppModel(secretStore: store)

        let magnetText = "magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678"
        let provider = NSItemProvider(object: magnetText as NSString)

        let handled = await model.ingestDroppedProviders([provider])

        #expect(handled == true)
        #expect(model.pendingMagnet == magnetText)
    }

    @Test
    func ingestDroppedProvidersParsesMagnetURL() async {
        let store = StubSecretStore()
        let model = AppModel(secretStore: store)

        let magnetURL = URL(string: "magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678")!
        let provider = NSItemProvider(object: magnetURL as NSURL)

        let handled = await model.ingestDroppedProviders([provider])

        #expect(handled == true)
        #expect(model.pendingMagnet == magnetURL.absoluteString)
    }
}
