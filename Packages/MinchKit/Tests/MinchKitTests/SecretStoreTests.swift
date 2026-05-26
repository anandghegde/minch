import Testing
@testable import MinchKit

@Suite("Secret store")
struct SecretStoreTests {
    @Test func inMemoryRoundTrips() async throws {
        let store = InMemorySecretStore()
        try await store.write("sk_abc", for: SecretKey.torboxAPIKey)
        let read = try await store.read(SecretKey.torboxAPIKey)
        #expect(read == "sk_abc")

        try await store.delete(SecretKey.torboxAPIKey)
        let afterDelete = try await store.read(SecretKey.torboxAPIKey)
        #expect(afterDelete == nil)
    }

    @Test func inMemoryOverwrites() async throws {
        let store = InMemorySecretStore(seed: [SecretKey.torboxAPIKey: "old"])
        try await store.write("new", for: SecretKey.torboxAPIKey)
        #expect(try await store.read(SecretKey.torboxAPIKey) == "new")
    }
}
