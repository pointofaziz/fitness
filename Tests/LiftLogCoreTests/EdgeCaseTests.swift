import XCTest
#if canImport(LiftLogCore)
@testable import LiftLogCore
#else
@testable import LiftLog
#endif

final class EdgeCaseTests: XCTestCase {
    func testCorrectingSavedSetDoesNotRestartRestTimer() throws {
        let data = AppData(), now = Schedule.date("2026-10-12")!
        let entry = Schedule.entries(through: "2026-10-12", data: data)[0]
        var workout = try WorkoutFactory.start(entry: entry, data: data, now: now, light: false)
        let log = workout.exercises[0]
        try WorkoutOperations.completeSet(workout: &workout, exerciseID: log.id, setID: log.sets[0].id, weight: 30, reps: 8, rir: 3, now: now)
        let rest = workout.restEnd
        try WorkoutOperations.completeSet(workout: &workout, exerciseID: log.id, setID: log.sets[0].id, weight: 30, reps: 9, rir: 3, now: now.addingTimeInterval(60))
        XCTAssertEqual(workout.restEnd, rest)
        XCTAssertEqual(workout.exercises[0].sets[0].completedAt, now)
    }
    func testSubsecondTimestampRoundTripIsExact() throws {
        var state = AppData()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000.1234567)
        let entry = Schedule.entries(through: "2026-10-12", data: state)[0]
        var workout = try WorkoutFactory.start(entry: entry, data: state, now: now, light: false)
        let log = workout.exercises[0]
        try WorkoutOperations.completeSet(workout: &workout, exerciseID: log.id, setID: log.sets[0].id, weight: 30, reps: 8, rir: 3, now: now)
        state.workouts = [workout]
        XCTAssertEqual(try Backup.decode(Backup.encode(state)), state)
    }
    func testLegacyISO8601DatesDecode() throws {
        var data = AppData(); let now = Schedule.date("2026-10-12")!
        data.body = [BodyEntry(recordedAt: now, localDate: "2026-10-12", weight: 82)]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(BackupEnvelope(data: data, exportedAt: now, schemaVersion: 1))
        XCTAssertEqual(try Backup.decode(bytes), data)
    }
    func testFarFutureSessionMovedEarlierAppearsOnlyOnce() throws {
        var data = AppData()
        let distant = Schedule.entries(through: "2027-10-11", data: data).last!
        try Schedule.move(distant, to: "2026-10-13", data: &data)
        let entries = Schedule.entries(through: "2026-10-31", data: data)
        XCTAssertEqual(entries.filter { $0.id == distant.id }.count, 1)
        XCTAssertEqual(entries.first { $0.id == distant.id }?.date, "2026-10-13")
    }
    func testManualNextTargetOverridesMixedLoadReview() throws {
        var data = AppData(); data.manualNextLoads["ua-incline"] = 28
        let rec = Progression.recommend(exercise: data.templates[0].exercises[0], templateID: "upper-a", sets: 3, data: data)
        XCTAssertEqual(rec.nextLoad, 28); XCTAssertEqual(rec.action, .hold)
        XCTAssertEqual(try Backup.decode(Backup.encode(data)).manualNextLoads, data.manualNextLoads)
    }
    func testCompletedSetValidationRejectsFractionalRepsAndBadReserve() {
        XCTAssertNil(Int("10.5")); XCTAssertNil(Int("3,5"))
        XCTAssertFalse(LoggedSet(weight: 0, reps: 0, rir: 2).valid)
        XCTAssertFalse(LoggedSet(weight: 0, reps: 10, rir: 11).valid)
    }
    func testNegativeBodyEntryAndInconsistentCompletionRejected() throws {
        var data = AppData()
        data.body = [BodyEntry(recordedAt: Date(), localDate: "2026-10-12", weight: -1)]
        XCTAssertThrowsError(try Backup.encode(data))
        data.body = []
        let entry = Schedule.entries(through: "2026-10-12", data: data)[0]
        var w = try WorkoutFactory.start(entry: entry, data: data, now: Schedule.date("2026-10-12")!, light: false)
        w.status = .completed; w.completedAt = w.startedAt
        data.workouts = [w]
        XCTAssertThrowsError(try Backup.encode(data))
    }
    func testWarmupsCannotEarnIncrease() throws {
        let data = AppData(), entry = Schedule.entries(through: "2026-10-26", data: AppData()).last!
        let w = try WorkoutFactory.start(entry: entry, data: data, now: Schedule.date("2026-10-26")!, light: false)
        var log = w.exercises[0]; log.cleanForm = true
        log.sets.append(LoggedSet(weight: 30, reps: 10, rir: 2, completedAt: Date(), warmup: true))
        XCTAssertEqual(Progression.evaluate(log).action, .hold)
    }
    func testTemplateIDsDoNotShareRowHistory() {
        let a = Programme.templates[0].exercises.first { $0.name == "Chest-supported row" }!
        let b = Programme.templates[2].exercises.first { $0.name == "Chest-supported row" }!
        XCTAssertNotEqual(a.id, b.id)
    }
}
