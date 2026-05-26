import Foundation

public struct TransferFile: Identifiable, Hashable, Sendable, Codable {
    public let id: FileID
    public var name: String
    public var pathInTransfer: String
    public var sizeBytes: Int64
    public var mime: String?
    public var isDownloaded: Bool
    public var localURL: URL?
    public var playedAt: Date?
    public var playbackPositionSec: Double?

    public init(
        id: FileID,
        name: String,
        pathInTransfer: String,
        sizeBytes: Int64,
        mime: String? = nil,
        isDownloaded: Bool = false,
        localURL: URL? = nil,
        playedAt: Date? = nil,
        playbackPositionSec: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.pathInTransfer = pathInTransfer
        self.sizeBytes = sizeBytes
        self.mime = mime
        self.isDownloaded = isDownloaded
        self.localURL = localURL
        self.playedAt = playedAt
        self.playbackPositionSec = playbackPositionSec
    }
}
