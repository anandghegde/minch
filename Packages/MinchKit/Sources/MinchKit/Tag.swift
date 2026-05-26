import Foundation

public struct Tag: Hashable, Sendable, Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let colorHex: String
    public let sortOrder: Int

    public init(name: String, colorHex: String, sortOrder: Int = 0) {
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
}
