import Foundation
import MinchKit

public enum Fixtures {
    public static func transfer(
        id: String = "tb_fixture_1",
        name: String = "Big.Buck.Bunny.4K",
        status: TransferStatus = .downloading,
        progress: Double = 0.42
    ) -> Transfer {
        Transfer(
            id: TransferID(id),
            infoHash: "5e8a1f3c",
            name: name,
            kind: .torrent,
            addedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sizeBytes: 1_500_000_000,
            status: status,
            progress: progress,
            downloadSpeed: 12_500_000,
            uploadSpeed: 0,
            eta: 120,
            files: [
                file(id: "f_1", name: "BigBuckBunny.mkv")
            ]
        )
    }

    public static func file(
        id: String = "f_fixture_1",
        name: String = "movie.mkv"
    ) -> TransferFile {
        TransferFile(
            id: FileID(id),
            name: name,
            pathInTransfer: name,
            sizeBytes: 1_500_000_000,
            mime: "video/x-matroska"
        )
    }

    public static let activeLibrary: [Transfer] = [
        transfer(id: "tb_a", name: "Sintel.2160p.HDR", status: .downloading, progress: 0.62),
        transfer(id: "tb_b", name: "Tears.of.Steel.1080p", status: .seeding, progress: 1.0),
        transfer(id: "tb_c", name: "Big.Buck.Bunny.4K", status: .queued, progress: 0.0),
    ]
}
