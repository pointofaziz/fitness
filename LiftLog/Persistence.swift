import Foundation
import SwiftData

enum LogSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Record.self] }
    @Model final class Record {
        @Attribute(.unique) var key: String
        var payload: Data
        init(key: String = "lift-log", payload: Data) { self.key = key; self.payload = payload }
    }
}
enum LogSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Record.self] }
    @Model final class Record {
        @Attribute(.unique) var key: String
        var payload: Data
        var updatedAt: Date?
        init(key: String = "lift-log", payload: Data, updatedAt: Date? = nil) { self.key = key; self.payload = payload; self.updatedAt = updatedAt }
    }
}
enum LogMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LogSchemaV1.self, LogSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: LogSchemaV1.self, toVersion: LogSchemaV2.self)] }
}
@MainActor protocol LogRepository {
    func load() throws -> AppData
    func save(_ data: AppData) throws
}
@MainActor final class SwiftDataRepository: LogRepository {
    let container: ModelContainer
    let context: ModelContext
    init(url: URL? = nil, memory: Bool = false) throws {
        let schema = Schema(versionedSchema: LogSchemaV2.self)
        let config: ModelConfiguration
        if let url { config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: memory, cloudKitDatabase: .none) }
        container = try ModelContainer(for: schema, migrationPlan: LogMigration.self, configurations: [config])
        context = ModelContext(container); context.autosaveEnabled = false
    }
    func load() throws -> AppData {
        let records = try context.fetch(FetchDescriptor<LogSchemaV2.Record>())
        guard records.count <= 1 else { throw LogError.invalid("Multiple store documents found. Restore a known backup.") }
        if let record = records.first { return try Backup.decode(record.payload) }
        let fresh = AppData(); try save(fresh); return fresh
    }
    func save(_ data: AppData) throws {
        let bytes = try Backup.encode(data)
        do {
            if let existing = try context.fetch(FetchDescriptor<LogSchemaV2.Record>()).first {
                existing.payload = bytes; existing.updatedAt = Date()
            } else { context.insert(LogSchemaV2.Record(payload: bytes, updatedAt: Date())) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
