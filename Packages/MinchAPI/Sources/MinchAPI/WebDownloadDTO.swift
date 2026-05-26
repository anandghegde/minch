import Foundation
import MinchKit

struct WebDownloadDTO: Decodable, Sendable {
    let id: Int
    let hash: String?
    let name: String?
    let size: Int64?
    let progress: Double?
    let downloadSpeed: Int64?
    let uploadSpeed: Int64?
    let eta: Int?
    let downloadState: String?
    let files: [WebDownloadFileDTO]?
}

struct WebDownloadFileDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let shortName: String?
    let size: Int64?
    let mimetype: String?
}

extension WebDownloadDTO {
    func toDomain() -> Transfer {
        let namespacedID = "webdl:\(id)"
        return Transfer(
            id: TransferID(namespacedID),
            infoHash: hash,
            name: name ?? "Untitled",
            kind: .webdl,
            addedAt: .now,
            sizeBytes: size ?? 0,
            status: TorBoxTransferDTO.mapStatus(downloadState),
            progress: progress ?? 0,
            downloadSpeed: downloadSpeed ?? 0,
            uploadSpeed: uploadSpeed ?? 0,
            eta: eta.map(TimeInterval.init),
            trackers: [],
            availability: nil,
            error: nil,
            files: (files ?? []).map { $0.toDomain(transferID: namespacedID) },
            tagNames: [],
            isFavorite: false,
            isHidden: false,
            lastSyncedAt: .now,
            seeds: nil,
            peers: nil
        )
    }
}

extension WebDownloadFileDTO {
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
