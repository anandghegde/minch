import Foundation
import Testing
import MinchAPI
import MinchKit
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
}
