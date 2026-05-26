import Foundation
import SwiftData
import MinchKit

public typealias TransferFetcher = @Sendable () async throws -> [Transfer]

public actor SyncEngine {
    private let container: ModelContainer
    private let fetcher: TransferFetcher

    public init(container: ModelContainer, fetcher: @escaping TransferFetcher) {
        self.container = container
        self.fetcher = fetcher
    }

    public func refresh() async throws {
        let transfers = try await fetcher()
        try await apply(transfers)
    }

    @MainActor
    private func apply(_ transfers: [Transfer]) throws {
        let context = container.mainContext
        let existing = try context.fetch(FetchDescriptor<StoredTransfer>())
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for transfer in transfers {
            if let row = byID.removeValue(forKey: transfer.id.rawValue) {
                row.update(from: transfer)
            } else {
                context.insert(StoredTransfer(from: transfer))
            }
        }
        for stale in byID.values {
            context.delete(stale)
        }
        try context.save()
    }
}

extension StoredTransfer {
    func update(from transfer: Transfer) {
        infoHash = transfer.infoHash
        name = transfer.name
        kindRaw = transfer.kind.rawValue
        sizeBytes = transfer.sizeBytes
        statusRaw = transfer.status.rawValue
        progress = transfer.progress
        downloadSpeed = transfer.downloadSpeed
        uploadSpeed = transfer.uploadSpeed
        eta = transfer.eta
        trackers = transfer.trackers
        availability = transfer.availability
        errorMessage = transfer.error
        seeds = transfer.seeds
        peers = transfer.peers
        lastSyncedAt = .now

        let incomingByID = Dictionary(uniqueKeysWithValues: transfer.files.map { ($0.id.rawValue, $0) })
        var existingByID = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
        for (fileID, incoming) in incomingByID {
            if let row = existingByID.removeValue(forKey: fileID) {
                row.update(from: incoming)
            } else {
                files.append(StoredTransferFile(from: incoming))
            }
        }
        for stale in existingByID.values {
            files.removeAll { $0.id == stale.id }
        }
    }
}

extension StoredTransferFile {
    func update(from file: TransferFile) {
        name = file.name
        pathInTransfer = file.pathInTransfer
        sizeBytes = file.sizeBytes
        mime = file.mime
    }
}
