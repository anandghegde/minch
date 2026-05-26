import Foundation

/// A supported file-host provider returned by `GET /webdl/hosters`. We keep the
/// shape lean — only the fields the Add bar's "Supported hosts" sheet renders.
public struct Hoster: Decodable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let domains: [String]
    public let url: String?
    public let icon: String?
    /// TorBox reports `false` for healthy hosters in this field (an "issue
    /// flag"), and `true` when the hoster is degraded.
    public let status: Bool?
    public let type: String?
    public let nsfw: Bool?

    public init(id: Int, name: String, domains: [String], url: String?, icon: String?, status: Bool?, type: String?, nsfw: Bool?) {
        self.id = id
        self.name = name
        self.domains = domains
        self.url = url
        self.icon = icon
        self.status = status
        self.type = type
        self.nsfw = nsfw
    }
}
