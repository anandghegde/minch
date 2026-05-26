import Foundation
import SwiftData
import MinchKit

@Model
public final class StoredTransfer {
    public var id: String
    public var infoHash: String?
    public var name: String
    public var kindRaw: String
    public var addedAt: Date
    public var sizeBytes: Int64
    public var statusRaw: String
    public var progress: Double
    public var downloadSpeed: Int64
    public var uploadSpeed: Int64
    public var eta: TimeInterval?
    public var trackers: [String]
    public var availability: Double?
    public var errorMessage: String?
    public var isFavorite: Bool
    public var isHidden: Bool
    public var lastSyncedAt: Date
    public var tagNames: [String] = []
    public var seeds: Int?
    public var peers: Int?

    @Relationship(deleteRule: .cascade, inverse: \StoredTransferFile.transfer)
    public var files: [StoredTransferFile] = []

    public init(from transfer: Transfer) {
        self.id = transfer.id.rawValue
        self.infoHash = transfer.infoHash
        self.name = transfer.name
        self.kindRaw = transfer.kind.rawValue
        self.addedAt = transfer.addedAt
        self.sizeBytes = transfer.sizeBytes
        self.statusRaw = transfer.status.rawValue
        self.progress = transfer.progress
        self.downloadSpeed = transfer.downloadSpeed
        self.uploadSpeed = transfer.uploadSpeed
        self.eta = transfer.eta
        self.trackers = transfer.trackers
        self.availability = transfer.availability
        self.errorMessage = transfer.error
        self.isFavorite = transfer.isFavorite
        self.isHidden = transfer.isHidden
        self.lastSyncedAt = transfer.lastSyncedAt
        self.tagNames = transfer.tagNames
        self.seeds = transfer.seeds
        self.peers = transfer.peers
        self.files = transfer.files.map(StoredTransferFile.init(from:))
    }

    public func snapshot() -> Transfer {
        Transfer(
            id: TransferID(id),
            infoHash: infoHash,
            name: name,
            kind: TransferKind(rawValue: kindRaw) ?? .torrent,
            addedAt: addedAt,
            sizeBytes: sizeBytes,
            status: TransferStatus(rawValue: statusRaw) ?? .queued,
            progress: progress,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            eta: eta,
            trackers: trackers,
            availability: availability,
            error: errorMessage,
            files: files.map { $0.snapshot() },
            tagNames: tagNames,
            isFavorite: isFavorite,
            isHidden: isHidden,
            lastSyncedAt: lastSyncedAt,
            seeds: seeds,
            peers: peers
        )
    }
}

@Model
public final class StoredTransferFile {
    @Attribute(.unique) public var id: String
    public var name: String
    public var pathInTransfer: String
    public var sizeBytes: Int64
    public var mime: String?
    public var isDownloaded: Bool
    public var localPath: String?
    public var playedAt: Date?
    public var playbackPositionSec: Double?

    public var transfer: StoredTransfer?

    public init(from file: TransferFile) {
        self.id = file.id.rawValue
        self.name = file.name
        self.pathInTransfer = file.pathInTransfer
        self.sizeBytes = file.sizeBytes
        self.mime = file.mime
        self.isDownloaded = file.isDownloaded
        self.localPath = file.localURL?.path
        self.playedAt = file.playedAt
        self.playbackPositionSec = file.playbackPositionSec
    }

    public func snapshot() -> TransferFile {
        TransferFile(
            id: FileID(id),
            name: name,
            pathInTransfer: pathInTransfer,
            sizeBytes: sizeBytes,
            mime: mime,
            isDownloaded: isDownloaded,
            localURL: localPath.map { URL(fileURLWithPath: $0) },
            playedAt: playedAt,
            playbackPositionSec: playbackPositionSec
        )
    }
}
