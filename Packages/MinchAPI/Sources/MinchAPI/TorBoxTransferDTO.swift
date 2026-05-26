import Foundation
import MinchKit

struct TorBoxTransferDTO: Decodable, Sendable {
    let id: Int
    let hash: String?
    let name: String?
    let size: Int64?
    let progress: Double?
    let downloadSpeed: Int64?
    let uploadSpeed: Int64?
    let eta: Int?
    let downloadState: String?
    let availability: Double?
    let seeds: Int?
    let peers: Int?
    let files: [TorBoxFileDTO]?
}

struct TorBoxFileDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let shortName: String?
    let size: Int64?
    let mimetype: String?
}

extension TorBoxTransferDTO {
    func toDomain() -> Transfer {
        Transfer(
            id: TransferID(String(id)),
            infoHash: hash,
            name: name ?? "Untitled",
            kind: .torrent,
            addedAt: .now,
            sizeBytes: size ?? 0,
            status: Self.mapStatus(downloadState),
            progress: progress ?? 0,
            downloadSpeed: downloadSpeed ?? 0,
            uploadSpeed: uploadSpeed ?? 0,
            eta: eta.map(TimeInterval.init),
            trackers: [],
            availability: availability,
            error: nil,
            files: (files ?? []).map { $0.toDomain(transferID: String(id)) },
            tagNames: [],
            isFavorite: false,
            isHidden: false,
            lastSyncedAt: .now,
            seeds: seeds,
            peers: peers
        )
    }

    static func mapStatus(_ raw: String?) -> TransferStatus {
        switch raw?.lowercased() {
        case "downloading", "metadl", "downloadingmetadata": .downloading
        case "uploading", "seeding": .seeding
        case "completed", "cached", "downloaded", "finished": .done
        case "paused": .paused
        case "error", "failed", "missingfiles": .error
        default: .queued
        }
    }
}

extension TorBoxFileDTO {
    func toDomain(transferID: String) -> TransferFile {
        TransferFile(
            id: FileID("\(transferID):\(id)"),
            name: name ?? shortName ?? "file_\(id)",
            pathInTransfer: shortName ?? name ?? "file_\(id)",
            sizeBytes: size ?? 0,
            mime: mimetype,
            isDownloaded: false,
            localURL: nil,
            playedAt: nil,
            playbackPositionSec: nil
        )
    }
}
