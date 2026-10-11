import XCTest
#if canImport(LiftLogCore)
@testable import LiftLogCore
#else
@testable import LiftLog
#endif

final class CoreTests: XCTestCase {
    let now = Schedule.date("2026-10-26")!
    func workout(day: String = "2026-10-26", template: String = "upper-a", light: Bool = false, data: AppData = AppData()) throws -> Workout {
        let entry = Schedule.entries(through: day, data: data).first { $0.originalDate == day && $0.templateID == template }!
        return try WorkoutFactory.start(entry: entry, data: data, now: Schedule.date(day)!, light: light)
    }
    func qualified() throws -> ExerciseLog {
        var log = try workout().exercises[0]
        log.prescription.exercise.increment = 2
        log.sets = (0..<3).map { _ in LoggedSet(weight: 30, reps: 10, rir: 2, completedAt: now) }
        log.cleanForm = true
        return log
    }
    func testExactProgrammeAndCalendar() {
        let data = AppData(), entries = Schedule.entries(through: "2026-12-31", data: AppData())
        XCTAssertEqual(entries.count, 47); XCTAssertEqual(entries.first?.date, "2026-10-12"); XCTAssertEqual(entries.last?.date, "2026-12-31")
        XCTAssertEqual(Set(entries.map(\.id)).count, 47)
        XCTAssertEqual(data.templates.map { $0.exercises.count }, [8,7,9,7])
        XCTAssertEqual(data.templates.map { $0.exercises.map(\.sets) }, [[3,3,3,2,2,3,3,3],[3,3,2,2,2,3,3],[3,3,3,2,2,3,3,3,3],[3,3,2,2,2,3,3]])
        for e in entries { XCTAssertEqual(Schedule.calendar().component(.weekday, from: Schedule.date(e.date)!), data.templates.first { $0.id == e.templateID }!.weekday) }
    }
    func testCalendarContinuesAndMissedNotCompleted() {
        let data = AppData()
        XCTAssertGreaterThan(Schedule.entries(through: "2027-02-01", data: data).count, 47)
        XCTAssertEqual(Schedule.next(data: data, now: Schedule.date("2027-01-01")!)?.date, "2027-01-02")
        XCTAssertEqual(data.workouts.count, 0)
    }
    func testQualifyingIncline() throws {
        let r = Progression.evaluate(try qualified())
        XCTAssertEqual(r.action, .increase); XCTAssertEqual(r.nextLoad, 32); XCTAssertEqual(r.nextRepTarget, 18)
    }
    func testDisqualifiers() throws {
        for mode in 0..<8 {
            var log = try qualified()
            switch mode {
            case 0: log.sets[0].rir = 0
            case 1: log.sets[0].rir = nil
            case 2: log.cleanForm = false
            case 3: log.cleanForm = nil
            case 4: log.pain = true
            case 5: log.sets[1].weight = 28
            case 6: log.sets[2].completedAt = nil
            default: log.skipped = true
            }
            XCTAssertNotEqual(Progression.evaluate(log).action, .increase, "mode \(mode)")
        }
    }
    func testMixedLoadsRequireManualTarget() throws {
        var log = try qualified(); log.sets[1].weight = 28
        XCTAssertEqual(Progression.evaluate(log).action, .reviewMixedLoads); XCTAssertNil(Progression.evaluate(log).nextLoad)
    }
    func testExtraRepAndPoorSessionHold() throws {
        var log = try qualified(); log.sets[0].reps = 8
        XCTAssertEqual(Progression.evaluate(log).nextRepTarget, 29)
        log.sets[0].reps = 4
        XCTAssertEqual(Progression.evaluate(log).action, .hold); XCTAssertEqual(Progression.evaluate(log).nextLoad, 30)
    }
    func testEquipmentStepRequiredAndPerHand() throws {
        var log = try qualified(); log.prescription.exercise.increment = nil
        XCTAssertEqual(Progression.evaluate(log).action, .hold)
        log.prescription.exercise.increment = 1
        XCTAssertEqual(Progression.evaluate(log).nextLoad, 31)
    }
    func testIntroAndNeck() throws {
        let intro = try workout(day: "2026-10-12"), full = try workout()
        XCTAssertTrue(intro.exercises.allSatisfy { $0.prescription.sets == 2 && $0.prescription.targetRIR == 3 })
        XCTAssertEqual(intro.neck.count, 4); XCTAssertEqual(full.neck.count, 8)
        XCTAssertEqual(full.exercises[0].prescription.sets, 3)
    }
    func testIntroDoesNotEarnThirdSet() throws {
        var data = AppData(), w = try workout(day: "2026-10-12")
        var log = w.exercises[0]; log.sets = (0..<2).map { _ in LoggedSet(weight: 30, reps: 10, rir: 3, completedAt: now) }; log.cleanForm = true
        w.exercises[0] = log; w.status = .completed; w.completedAt = now; data.workouts = [w]
        let r = Progression.recommend(exercise: data.templates[0].exercises[0], templateID: "upper-a", sets: 3, data: data)
        XCTAssertEqual(r.action, .hold); XCTAssertEqual(r.nextLoad, 30); XCTAssertEqual(r.nextRepTarget, 18)
    }
    func testLightDoesNotIncreaseOrReplaceNormalBaseline() throws {
        var data = AppData(); data.templates[0].exercises[0].increment = 2
        let light = try workout(light: true, data: data)
        XCTAssertEqual(light.exercises[0].prescription.sets, 2); XCTAssertEqual(light.exercises[0].prescription.targetRIR, 4)
        XCTAssertEqual(light.exercises[0].prescription.normalLoad, 30); XCTAssertEqual(light.exercises[0].prescription.load, 28)
        XCTAssertEqual(Progression.evaluate(try qualified(), light: true).action, .light)
        var w = light; w.status = .completed; w.completedAt = now; w.exercises[0] = try qualified(); data.workouts = [w]
        XCTAssertNil(Progression.baseline(exercise: data.templates[0].exercises[0], templateID: "upper-a", data: data))
    }
    func testZeroLoadAndDecimalValidation() throws {
        XCTAssertEqual(Input.decimal(" 2,5 "), 2.5); XCTAssertEqual(Input.decimal("2.5"), 2.5)
        for invalid in ["", "-1", "nan", "inf", "a", "1,2.3"] { XCTAssertNil(Input.decimal(invalid)) }
        XCTAssertTrue(LoggedSet(weight: 0, reps: 12, rir: 2).valid)
        XCTAssertFalse(LoggedSet(weight: 1001, reps: 12, rir: 2).valid)
        XCTAssertFalse(LoggedSet(weight: 1, reps: 101, rir: 2).valid)
        XCTAssertNil(Programme.templates[3].exercises[0].initialLoad)
        XCTAssertEqual(Programme.templates[3].exercises.last?.initialLoad, 0)
    }
    func testRescheduleStableIDAndNoDuplication() throws {
        var data = AppData(); let entry = Schedule.entries(through: "2026-12-31", data: data)[0]
        try Schedule.move(entry, to: "2026-10-14", data: &data)
        let all = Schedule.entries(through: "2026-12-31", data: data)
        XCTAssertEqual(all.count, 47); XCTAssertEqual(all.first { $0.id == entry.id }?.date, "2026-10-14")
        let w = try WorkoutFactory.start(entry: all.first { $0.id == entry.id }!, data: data, now: now, light: false); data.workouts.append(w)
        XCTAssertThrowsError(try WorkoutFactory.start(entry: entry, data: data, now: now, light: false))
    }
    func testWholeSessionRoundTripAndSnapshot() throws {
        var data = AppData(), w = try workout(day: "2026-10-12")
        let original = w.exercises[0].prescription
        for log in w.exercises {
            for set in log.sets { try WorkoutOperations.completeSet(workout: &w, exerciseID: log.id, setID: set.id, weight: log.prescription.load ?? 10, reps: log.prescription.exercise.minReps, rir: 3, now: w.startedAt) }
        }
        for i in w.neck.indices { w.neck[i].seconds = 12; w.neck[i].completed = true }
        try WorkoutOperations.finish(workout: &w, partial: false, now: now)
        data.workouts.append(w)
        let restored = try Backup.decode(Backup.encode(data, now: now))
        XCTAssertEqual(restored, data); XCTAssertEqual(w.completedSetCount, 16)
        data.templates[0].exercises[0].sets = 4
        XCTAssertEqual(data.workouts[0].exercises[0].prescription, original)
        try WorkoutOperations.completeSet(workout: &data.workouts[0], exerciseID: w.exercises[0].id, setID: w.exercises[0].sets[0].id, weight: 28, reps: 7, rir: 2, now: now)
        XCTAssertEqual(data.workouts[0].exercises[0].prescription, original)
    }
    func testActiveWorkoutPersistsAndUnconfirmedRepsStayNil() throws {
        var data = AppData(), w = try workout()
        XCTAssertNil(w.exercises[0].sets[0].reps); XCTAssertNil(w.exercises[0].sets[0].rir)
        try WorkoutOperations.completeSet(workout: &w, exerciseID: w.exercises[0].id, setID: w.exercises[0].sets[0].id, weight: 30, reps: 8, rir: 2, now: now)
        data.workouts = [w]; let loaded = try Backup.decode(Backup.encode(data))
        XCTAssertEqual(loaded.workouts[0].status, .active); XCTAssertEqual(loaded.workouts[0].completedSetCount, 1)
        XCTAssertEqual(loaded.workouts[0].exercises[0].prescription, w.exercises[0].prescription)
    }
    func testUndoPartialAndWarmup() throws {
        var w = try workout(); let id = w.exercises[0].sets[0].id
        w.exercises[0].sets.append(LoggedSet(weight: 5, reps: 10, rir: 5, completedAt: now, warmup: true))
        XCTAssertFalse(w.exercises[0].fullyRecorded)
        try WorkoutOperations.completeSet(workout: &w, exerciseID: w.exercises[0].id, setID: id, weight: 30, reps: 8, rir: 2, now: now)
        WorkoutOperations.undoSet(workout: &w, exerciseID: w.exercises[0].id, setID: id)
        XCTAssertNil(w.exercises[0].sets[0].completedAt)
        XCTAssertThrowsError(try WorkoutOperations.finish(workout: &w, partial: false, now: now))
        try WorkoutOperations.finish(workout: &w, partial: true, now: now)
        XCTAssertEqual(w.status, .partial)
    }
    func testVersionOneMigrationAndInvalidImport() throws {
        let original = AppData(), encoded = try Backup.encode(original)
        var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        json["schemaVersion"] = 1
        var state = json["data"] as! [String: Any]; state.removeValue(forKey: "timeZoneID"); state.removeValue(forKey: "haptics"); state.removeValue(forKey: "notifications"); json["data"] = state
        XCTAssertEqual(try Backup.decode(JSONSerialization.data(withJSONObject: json)), original)
        json["schemaVersion"] = 999
        XCTAssertThrowsError(try Backup.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertThrowsError(try Backup.decode(Data("invalid".utf8)))
        XCTAssertEqual(original.workouts.count, 0)
    }
    func testDuplicateAndInvalidBackupsRejected() throws {
        var data = AppData(); let w = try workout(); data.workouts = [w,w]
        XCTAssertThrowsError(try Backup.encode(data))
        data.workouts = [w]; data.workouts[0].exercises[0].sets[0].weight = -1
        XCTAssertThrowsError(try Backup.encode(data))
    }
    func testBodyWeeklyAverageMissingDaysAndWeeks() {
        let entries = [BodyEntry(recordedAt: now, localDate: "2026-10-12", weight: 82), BodyEntry(recordedAt: now, localDate: "2026-10-14", weight: 84), BodyEntry(recordedAt: now, localDate: "2026-10-19", weight: 83.2), BodyEntry(recordedAt: now, localDate: "2026-11-02", weight: 84)]
        let weeks = BodyTrends.weeks(entries)
        XCTAssertEqual(weeks[0].average, 83); XCTAssertEqual(weeks[0].count, 2)
        XCTAssertEqual(weeks[1].change!, 0.2, accuracy: 0.0001); XCTAssertNil(weeks[2].change)
    }
    func testDSTMidnightAndRestTimer() {
        let c = Schedule.calendar(), before = Schedule.date("2026-10-24")!, after = Schedule.date("2026-10-26")!
        XCTAssertEqual(c.dateComponents([.day], from: before, to: after).day, 2)
        XCTAssertEqual(Schedule.week(on: "2026-10-26"), 3)
        let utc = ISO8601DateFormatter().date(from: "2026-10-25T23:30:00Z")!
        XCTAssertEqual(Schedule.day(utc), "2026-10-26")
        XCTAssertEqual(WorkoutOperations.restRemaining(now.addingTimeInterval(90), now: now.addingTimeInterval(35)), 55)
        XCTAssertEqual(WorkoutOperations.restRemaining(now, now: now.addingTimeInterval(10)), 0)
    }
    func testStallNeedsThreeComparableExposuresAndRepGainBreaksIt() throws {
        var data = AppData()
        for n in 0..<3 {
            var w = try workout(); var log = try qualified(); log.sets[0].reps = 8
            w.exercises[0] = log; w.status = .completed; w.completedAt = now.addingTimeInterval(Double(n * 86400)); data.workouts.append(w)
        }
        XCTAssertTrue(Progression.stalled(exerciseID: "ua-incline", templateID: "upper-a", data: data))
        data.workouts[2].exercises[0].sets[0].reps = 9
        XCTAssertFalse(Progression.stalled(exerciseID: "ua-incline", templateID: "upper-a", data: data))
        data.workouts[2].exercises[0].sets[0].reps = 8; data.workouts[2].exercises[0].prescription.exercise.equipment = "Another bench"
        XCTAssertFalse(Progression.stalled(exerciseID: "ua-incline", templateID: "upper-a", data: data))
    }
    func testBaselineUsesCompletionAndIgnoresPartial() throws {
        var data = AppData(), a = try workout(), b = try workout(), partial = try workout()
        a.exercises[0] = try qualified(); a.status = .completed; a.completedAt = now.addingTimeInterval(100)
        b.exercises[0] = try qualified(); b.exercises[0].sets[0].weight = 28; b.status = .completed; b.completedAt = now
        partial.exercises[0] = try qualified(); partial.status = .partial; partial.completedAt = now.addingTimeInterval(200)
        data.workouts = [partial,b,a]
        XCTAssertEqual(Progression.baseline(exercise: data.templates[0].exercises[0], templateID: "upper-a", data: data)?.sets[0].weight, 30)
        XCTAssertNil(Progression.baseline(exercise: data.templates[1].exercises[0], templateID: "lower-a", data: data))
    }
    func testCSVIncludesUnitsActualsAndEscapes() throws {
        var data = AppData(), w = try workout(); w.exercises[0] = try qualified(); w.exercises[0].prescription.exercise.equipment = "=bad,\"formula\""; data.workouts = [w]
        let csv = Backup.csv(data)
        XCTAssertTrue(csv.contains("kg per hand")); XCTAssertTrue(csv.contains("'" + "=bad,")); XCTAssertTrue(csv.contains("\"\"formula\"\""))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 5)
    }
}
