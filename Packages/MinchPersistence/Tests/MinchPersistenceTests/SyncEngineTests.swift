import Foundation
import SwiftData
import Testing
import MinchKit
@testable import MinchPersistence

@Suite("SyncEngine")
@MainActor
struct SyncEngineTests {
    @Test func insertsNewTransfersOnFirstRefresh() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let engine = SyncEngine(container: container) {
            [
                makeTransfer(id: "1", name: "Sintel", progress: 0.3),
                makeTransfer(id: "2", name: "Bunny", progress: 1.0, status: .done)
            ]
        }

        try await engine.refresh()

        let rows = try container.mainContext.fetch(FetchDescriptor<StoredTransfer>())
        #expect(rows.count == 2)
        let names = Set(rows.map(\.name))
        #expect(names == ["Sintel", "Bunny"])
    }

    @Test func updatesExistingRowsAndDeletesStaleOnes() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let holder = BatchHolder([
            makeTransfer(id: "1", name: "Sintel", progress: 0.3),
            makeTransfer(id: "2", name: "Bunny", progress: 0.5)
        ])
        let engine = SyncEngine(container: container) { await holder.get() }

        try await engine.refresh()
        #expect(try container.mainContext.fetch(FetchDescriptor<StoredTransfer>()).count == 2)

        await holder.set([
            makeTransfer(id: "1", name: "Sintel", progress: 0.9, status: .seeding),
            makeTransfer(id: "3", name: "Tears", progress: 0.1)
        ])
        try await engine.refresh()

        let rows = try container.mainContext.fetch(FetchDescriptor<StoredTransfer>())
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        #expect(rows.count == 2)
        #expect(byID["1"]?.progress == 0.9)
        #expect(byID["1"]?.statusRaw == TransferStatus.seeding.rawValue)
        #expect(byID["3"]?.name == "Tears")
        #expect(byID["2"] == nil)
    }

    @Test func preservesUserFlagsAcrossSync() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let seeded = StoredTransfer(from: makeTransfer(id: "1", name: "Sintel"))
        seeded.isFavorite = true
        seeded.isHidden = true
        context.insert(seeded)
        try context.save()

        let engine = SyncEngine(container: container) {
            [makeTransfer(id: "1", name: "Sintel.Renamed", progress: 0.42)]
        }
        try await engine.refresh()

        let rows = try context.fetch(FetchDescriptor<StoredTransfer>())
        #expect(rows.count == 1)
        #expect(rows[0].isFavorite == true)
        #expect(rows[0].isHidden == true)
        #expect(rows[0].name == "Sintel.Renamed")
        #expect(rows[0].progress == 0.42)
    }

    @Test func reconcilesNestedFiles() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let holder = BatchHolder([
            makeTransfer(
                id: "1",
                name: "Sintel",
                files: [
                    TransferFile(id: "1:a", name: "a.mkv", pathInTransfer: "a.mkv", sizeBytes: 100),
                    TransferFile(id: "1:b", name: "b.srt", pathInTransfer: "b.srt", sizeBytes: 5)
                ]
            )
        ])
        let engine = SyncEngine(container: container) { await holder.get() }
        try await engine.refresh()

        await holder.set([
            makeTransfer(
                id: "1",
                name: "Sintel",
                files: [
                    TransferFile(id: "1:a", name: "a.4k.mkv", pathInTransfer: "a.4k.mkv", sizeBytes: 200),
                    TransferFile(id: "1:c", name: "c.nfo", pathInTransfer: "c.nfo", sizeBytes: 1)
                ]
            )
        ])
        try await engine.refresh()

        let rows = try container.mainContext.fetch(FetchDescriptor<StoredTransfer>())
        #expect(rows.count == 1)
        let files = rows[0].files
        #expect(files.count == 2)
        let byID = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
        #expect(byID["1:a"]?.name == "a.4k.mkv")
        #expect(byID["1:a"]?.sizeBytes == 200)
        #expect(byID["1:c"]?.name == "c.nfo")
        #expect(byID["1:b"] == nil)
    }
}

private actor BatchHolder {
    private var batch: [Transfer]
    init(_ batch: [Transfer]) { self.batch = batch }
    func get() -> [Transfer] { batch }
    func set(_ batch: [Transfer]) { self.batch = batch }
}

private func makeTransfer(
    id: String,
    name: String,
    progress: Double = 0,
    status: TransferStatus = .downloading,
    files: [TransferFile] = []
) -> Transfer {
    Transfer(
        id: TransferID(id),
        name: name,
        status: status,
        progress: progress,
        files: files
    )
}
