import Foundation
import SwiftData
import Testing
import MinchKit
@testable import MinchPersistence

@Suite("Persistence")
@MainActor
struct PersistenceTests {
    @Test func roundTripsTransferThroughStorage() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext

        let original = Transfer(
            id: "tb_1",
            infoHash: "abc",
            name: "Sintel.4K",
            sizeBytes: 1_000_000,
            status: .downloading,
            progress: 0.5,
            files: [
                TransferFile(id: "f_1", name: "Sintel.mkv", pathInTransfer: "Sintel.mkv", sizeBytes: 1_000_000)
            ]
        )

        let stored = StoredTransfer(from: original)
        context.insert(stored)
        try context.save()

        let descriptor = FetchDescriptor<StoredTransfer>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        let snapshot = fetched[0].snapshot()
        #expect(snapshot.name == "Sintel.4K")
        #expect(snapshot.progress == 0.5)
        #expect(snapshot.files.count == 1)
        #expect(snapshot.files.first?.name == "Sintel.mkv")
    }
}
