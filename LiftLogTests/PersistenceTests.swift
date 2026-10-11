import XCTest
import SwiftData
@testable import LiftLog

@MainActor final class PersistenceTests: XCTestCase {
    private func path() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("test.store")
    }
    func testExplicitSaveReopensWithActiveSetAndSnapshot() throws {
        let url = try path(), now = Schedule.date("2026-10-12")!
        var original: Prescription?
        do {
            let repository = try SwiftDataRepository(url: url)
            let store = try AppStore(repository: repository, clock: { now })
            let entry = Schedule.entries(through: "2026-10-12", data: store.data)[0]
            store.start(entry, light: false)
            let workout = try XCTUnwrap(store.active); original = workout.exercises[0].prescription
            XCTAssertTrue(store.complete(workout: workout.id, exercise: workout.exercises[0].id, set: workout.exercises[0].sets[0].id, weight: 30, reps: 8, rir: 3))
        }
        let reopened = try SwiftDataRepository(url: url).load()
        XCTAssertEqual(reopened.workouts[0].status, .active)
        XCTAssertEqual(reopened.workouts[0].completedSetCount, 1)
        XCTAssertEqual(reopened.workouts[0].exercises[0].prescription, original)
    }
    func testSwiftDataV1MigrationPreservesPayloadAndIDs() throws {
        let url = try path()
        var fixture = AppData()
        let day = Schedule.date("2026-10-12")!
        let entry = Schedule.entries(through: "2026-10-12", data: fixture)[0]
        fixture.workouts = [try WorkoutFactory.start(entry: entry, data: fixture, now: day, light: false)]
        do {
            let schema = Schema(versionedSchema: LogSchemaV1.self)
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container); context.autosaveEnabled = false
            context.insert(LogSchemaV1.Record(payload: try Backup.encode(fixture)))
            try context.save()
        }
        let migrated = try SwiftDataRepository(url: url).load()
        XCTAssertEqual(migrated, fixture)
    }
    func testFailedSaveDoesNotPublishOrLoseLastSavedState() throws {
        let repository = FaultRepository()
        let store = try AppStore(repository: repository)
        repository.fail = true
        XCTAssertFalse(store.transaction { $0.timeZoneID = "UTC" })
        XCTAssertEqual(store.data.timeZoneID, "Europe/Warsaw")
        XCTAssertNotNil(store.error)
        repository.fail = false
        XCTAssertTrue(store.transaction { $0.timeZoneID = "UTC" })
        XCTAssertEqual(store.data.timeZoneID, "UTC")
    }
    func testRestoreReplacesAndCreatesReadableRecoveryBackup() throws {
        let directory = try path().deletingLastPathComponent()
        let store = try AppStore(repository: FaultRepository(), recoveryDirectory: directory)
        var restored = AppData()
        restored.body = [BodyEntry(recordedAt: Date(timeIntervalSince1970: 1_800_000_000), localDate: "2026-10-12", weight: 82)]
        let original = store.data
        let backupURL = try store.backupURL()
        defer { try? FileManager.default.removeItem(at: backupURL) }
        XCTAssertEqual(try Backup.decode(Data(contentsOf: backupURL)), original)
        XCTAssertTrue(store.replace(with: restored)); XCTAssertTrue(store.replace(with: restored))
        XCTAssertEqual(store.data.body.count, 1)
        var invalid = restored; invalid.body[0].weight = -1
        XCTAssertFalse(store.replace(with: invalid)); XCTAssertEqual(store.data, restored)
    }
}
@MainActor private final class FaultRepository: LogRepository {
    var data = AppData()
    var fail = false
    func load() throws -> AppData { data }
    func save(_ data: AppData) throws {
        if fail { throw LogError.invalid("Injected disk save failure") }
        try Backup.validate(data); self.data = data
    }
}
