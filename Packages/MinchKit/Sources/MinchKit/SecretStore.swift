import Foundation

public protocol SecretStore: Sendable {
    func read(_ key: String) async throws -> String?
    func write(_ value: String, for key: String) async throws
    func delete(_ key: String) async throws
}

public actor InMemorySecretStore: SecretStore {
    private var storage: [String: String] = [:]
    public init(seed: [String: String] = [:]) { self.storage = seed }
    public func read(_ key: String) async throws -> String? { storage[key] }
    public func write(_ value: String, for key: String) async throws { storage[key] = value }
    public func delete(_ key: String) async throws { storage.removeValue(forKey: key) }
}

public enum SecretKey {
    public static let torboxAPIKey = "torbox.api_key"
}
