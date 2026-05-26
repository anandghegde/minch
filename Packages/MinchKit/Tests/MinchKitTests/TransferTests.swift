import Foundation
import Testing
@testable import MinchKit

@Suite("Transfer model")
struct TransferTests {
    @Test func newTransferDefaultsAreSane() {
        let t = Transfer(id: "tb_1", name: "Sintel.4K.mkv")
        #expect(t.status == .queued)
        #expect(t.progress == 0)
        #expect(t.kind == .torrent)
        #expect(t.files.isEmpty)
        #expect(t.isActive == true)
    }

    @Test func isActiveTracksStatus() {
        var t = Transfer(id: "tb_1", name: "x")
        t.status = .downloading
        #expect(t.isActive)
        t.status = .seeding
        #expect(t.isActive)
        t.status = .paused
        #expect(!t.isActive)
        t.status = .done
        #expect(!t.isActive)
    }

    @Test func codableRoundTrips() throws {
        let original = Transfer(
            id: "tb_1",
            infoHash: "5e8a",
            name: "Big.Buck.Bunny",
            kind: .torrent,
            sizeBytes: 12_345,
            status: .downloading,
            progress: 0.42
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transfer.self, from: encoded)
        #expect(decoded == original)
    }

    @Test func identifiersAreStringLiteralFriendly() {
        let id: TransferID = "tb_42"
        #expect(id.rawValue == "tb_42")
        let f: FileID = "tb_file_7"
        #expect(f.rawValue == "tb_file_7")
    }
}
