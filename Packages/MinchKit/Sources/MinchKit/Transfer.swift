import Foundation

public enum TransferKind: String, Sendable, Codable, CaseIterable {
    case torrent
    case webdl
    case usenet
}

public enum TransferStatus: String, Sendable, Codable, CaseIterable {
    case queued
    case downloading
    case seeding
    case paused
    case error
    case done
}

public struct Transfer: Identifiable, Hashable, Sendable, Codable {
    public let id: TransferID
    public var infoHash: String?
    public var name: String
    public var kind: TransferKind
    public var addedAt: Date
    public var sizeBytes: Int64
    public var status: TransferStatus
    public var progress: Double
    public var downloadSpeed: Int64
    public var uploadSpeed: Int64
    public var eta: TimeInterval?
    public var trackers: [String]
    public var availability: Double?
    public var error: String?
    public var files: [TransferFile]
    public var tagNames: [String]
    public var isFavorite: Bool
    public var isHidden: Bool
    public var lastSyncedAt: Date
    public var seeds: Int?
    public var peers: Int?

    public init(
        id: TransferID,
        infoHash: String? = nil,
        name: String,
        kind: TransferKind = .torrent,
        addedAt: Date = .now,
        sizeBytes: Int64 = 0,
        status: TransferStatus = .queued,
        progress: Double = 0,
        downloadSpeed: Int64 = 0,
        uploadSpeed: Int64 = 0,
        eta: TimeInterval? = nil,
        trackers: [String] = [],
        availability: Double? = nil,
        error: String? = nil,
        files: [TransferFile] = [],
        tagNames: [String] = [],
        isFavorite: Bool = false,
        isHidden: Bool = false,
        lastSyncedAt: Date = .now,
        seeds: Int? = nil,
        peers: Int? = nil
    ) {
        self.id = id
        self.infoHash = infoHash
        self.name = name
        self.kind = kind
        self.addedAt = addedAt
        self.sizeBytes = sizeBytes
        self.status = status
        self.progress = progress
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.eta = eta
        self.trackers = trackers
        self.availability = availability
        self.error = error
        self.files = files
        self.tagNames = tagNames
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.lastSyncedAt = lastSyncedAt
        self.seeds = seeds
        self.peers = peers
    }
}

public extension Transfer {
    var isActive: Bool {
        switch status {
        case .queued, .downloading, .seeding: true
        case .paused, .error, .done: false
        }
    }
}
