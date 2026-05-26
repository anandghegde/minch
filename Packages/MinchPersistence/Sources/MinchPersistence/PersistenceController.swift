import Foundation
import SwiftData

public enum PersistenceController {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([StoredTransfer.self, StoredTransferFile.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
