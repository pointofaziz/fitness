import Foundation

public enum ProgressAction: String, Codable, Sendable { case chooseLoad, hold, increase, reviewMixedLoads, light }
public struct Recommendation: Equatable, Sendable {
    public var action: ProgressAction
    public var nextLoad: Double?
    public var nextRepTarget: Int // total across prescribed working sets
    public var reason: String
}
public enum Progression {
    public static func evaluate(_ log: ExerciseLog, light: Bool = false, partial: Bool = false) -> Recommendation {
        let p = log.prescription, e = p.exercise
        let recorded = log.workingSets
        let load = recorded.first(where: { $0.completedAt != nil && $0.valid })?.weight ?? p.normalLoad
        let reps = recorded.compactMap(\.reps).reduce(0, +)
        func result(_ action: ProgressAction, _ next: Double?, _ target: Int, _ why: String) -> Recommendation {
            Recommendation(action: action, nextLoad: next, nextRepTarget: target, reason: why)
        }
        if light { return result(.light, p.normalLoad, p.sets * e.minReps, "Light session: keep the normal load separate. No increase is earned.") }
        if log.skipped || partial || !log.fullyRecorded {
            return result(.hold, p.normalLoad, p.sets * e.minReps, "Incomplete or skipped work does not establish a new baseline. Complete valid working sets before progressing.")
        }
        guard let load else { return result(.chooseLoad, nil, p.sets * e.minReps, "Choose a comfortable starting weight.") }
        if Set(recorded.compactMap(\.weight)).count != 1 {
            return result(.reviewMixedLoads, nil, max(reps, p.sets * e.minReps), "Review mixed loads. Set a manual next target; no single weight earned an increase.")
        }
        guard !log.pain, log.cleanForm == true else {
            return result(.hold, load, max(p.sets * e.minReps, min(reps, p.sets * e.maxReps)), log.pain ? "Pain flagged: no increase. Stop painful work and review before the next session." : "Clean form was not confirmed. Hold the load and prioritize controlled reps.")
        }
        guard recorded.allSatisfy({ $0.reps! >= e.minReps && $0.rir! >= p.targetRIR }) else {
            return result(.hold, load, max(p.sets * e.minReps, min(reps, p.sets * e.maxReps)), "Reps or clean reps left were below target. Hold the load; one hard session does not prescribe a deload.")
        }
        if recorded.allSatisfy({ $0.reps! >= e.maxReps }) {
            guard let step = e.increment, step.isFinite, step > 0, load + step <= 1000 else {
                return result(.hold, load, p.sets * e.maxReps, "Top reps earned. Choose the smallest available equipment step before increasing.")
            }
            return result(.increase, load + step, p.sets * e.minReps, "All \(p.sets) sets reached \(e.maxReps) reps with at least \(p.targetRIR) reps left and clean form: try \(Input.number(load + step)) \(e.unit.rawValue) next time.")
        }
        return result(.hold, load, min(reps + 1, p.sets * e.maxReps), "Keep \(Input.number(load)) \(e.unit.rawValue). Aim for one extra total clean rep across the working sets.")
    }
    public static func baseline(exercise: Exercise, templateID: String, data: AppData) -> ExerciseLog? {
        data.workouts.filter { $0.templateID == templateID && $0.status == .completed && !$0.light && $0.completedAt != nil }
            .sorted { $0.completedAt! > $1.completedAt! }
            .compactMap { $0.exercises.first { log in
                log.id == exercise.id && log.fullyRecorded && log.prescription.exercise.equipment == exercise.equipment && log.prescription.exercise.unit == exercise.unit
            } }.first
    }
    public static func recommend(exercise: Exercise, templateID: String, sets: Int, data: AppData) -> Recommendation {
        guard var previous = baseline(exercise: exercise, templateID: templateID, data: data) else {
            return Recommendation(action: exercise.initialLoad == nil ? .chooseLoad : .hold, nextLoad: exercise.initialLoad, nextRepTarget: sets * exercise.minReps, reason: exercise.initialLoad == nil ? "Choose a comfortable starting weight." : "Provisional starting weight, not previously lifted in this app. Adjust to comfortable form and effort.")
        }
        if Set(previous.workingSets.compactMap(\.weight)).count > 1 {
            return Recommendation(action: .reviewMixedLoads, nextLoad: nil, nextRepTarget: sets * exercise.minReps, reason: "Review mixed loads. Choose a manual target for this exposure.")
        }
        if previous.prescription.sets != sets || previous.prescription.exercise.minReps != exercise.minReps || previous.prescription.exercise.maxReps != exercise.maxReps {
            return Recommendation(action: .hold, nextLoad: previous.workingSets.first?.weight, nextRepTarget: sets * exercise.minReps, reason: "The set count or rep range changed. Keep the last normal load and establish the new prescription; extra sets are not assumed achieved.")
        }
        // Equipment increments are current choices; historical targets stay unchanged.
        previous.prescription.exercise.increment = exercise.increment
        return evaluate(previous)
    }
    public static func stalled(exerciseID: String, templateID: String, data: AppData) -> Bool {
        let exposures = data.workouts.filter { $0.templateID == templateID && $0.status == .completed && !$0.light && $0.completedAt != nil }
            .sorted { $0.completedAt! > $1.completedAt! }
            .compactMap { $0.exercises.first { $0.id == exerciseID && $0.fullyRecorded } }
        guard exposures.count >= 3 else { return false }
        let recent = Array(exposures.prefix(3)).reversed(), logs = Array(recent)
        let first = logs[0]
        guard logs.allSatisfy({ log in
            let a = first.prescription, b = log.prescription
            return a.sets == b.sets && a.exercise.minReps == b.exercise.minReps && a.exercise.maxReps == b.exercise.maxReps && a.exercise.equipment == b.exercise.equipment && a.exercise.unit == b.exercise.unit && Set(log.workingSets.compactMap(\.weight)).count == 1 && log.cleanForm == true && !log.pain
        }) else { return false }
        func averageRIR(_ log: ExerciseLog) -> Double { Double(log.workingSets.compactMap(\.rir).reduce(0,+)) / Double(log.prescription.sets) }
        guard logs.allSatisfy({ abs(averageRIR($0) - averageRIR(first)) <= 1 }) else { return false }
        for i in 1..<logs.count {
            let older = logs[i-1], newer = logs[i]
            let oldWeight = older.workingSets[0].weight!, newWeight = newer.workingSets[0].weight!
            if newWeight > oldWeight || (newWeight == oldWeight && newer.workingSets.compactMap(\.reps).reduce(0,+) > older.workingSets.compactMap(\.reps).reduce(0,+)) { return false }
        }
        return true
    }
}

public enum WorkoutFactory {
    public static func start(entry: ScheduleEntry, data: AppData, now: Date, light: Bool) throws -> Workout {
        guard data.workouts.allSatisfy({ $0.status != .active && $0.scheduleID != entry.id }), !entry.skipped,
              let template = data.templates.first(where: { $0.id == entry.templateID }) else { throw LogError.invalid("This session is already started, skipped, or another workout is active.") }
        let today = Schedule.day(now, zone: data.timeZoneID), week = Schedule.week(on: today, zone: data.timeZoneID)
        let logs = template.exercises.map { exercise -> ExerciseLog in
            let normalSets = week <= 2 ? 2 : exercise.sets
            let rec = Progression.recommend(exercise: exercise, templateID: template.id, sets: normalSets, data: data)
            var load = rec.nextLoad
            if light, let normal = load {
                let step = exercise.increment ?? 0.5
                load = max(0, (normal * 0.9 / step).rounded() * step)
            }
            return ExerciseLog(prescription: Prescription(exercise: exercise, sets: light ? (normalSets + 1) / 2 : normalSets, targetRIR: light ? 4 : (week <= 2 ? 3 : exercise.targetRIR), normalLoad: rec.nextLoad, load: load, repTarget: light ? ((normalSets + 1) / 2) * exercise.minReps : rec.nextRepTarget, reason: light ? "Light: roughly half the sets, about 10% less load, 4 RIR. Normal target is preserved. \(exercise.increment == nil ? "Load rounded to 0.5 kg provisionally; adjust to available equipment." : "")" : rec.reason))
        }
        let holds = template.neck ? ["Forward", "Backward", "Left", "Right"].flatMap { direction in
            (0..<(week <= 2 ? 1 : 2)).map { NeckHold(id: "\(direction)-\($0)", direction: direction) }
        } : []
        return Workout(scheduleID: entry.id, templateID: template.id, templateName: template.name, scheduledDate: entry.date, localDate: today, timeZoneID: data.timeZoneID, startedAt: now, light: light, exercises: logs, neck: holds)
    }
}
public struct WeeklyWeight: Identifiable, Equatable, Sendable {
    public var id: String
    public var average: Double
    public var count: Int
    public var change: Double?
}
public enum BodyTrends {
    public static func weeks(_ entries: [BodyEntry], zone: String = "Europe/Warsaw") -> [WeeklyWeight] {
        let c = Schedule.calendar(zone)
        var groups: [String: [Double]] = [:]
        for entry in entries {
            guard let weight = entry.weight, let date = Schedule.date(entry.localDate, zone: zone), let start = c.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            groups[Schedule.day(start, zone: zone), default: []].append(weight)
        }
        return groups.keys.sorted().map { key in
            let values = groups[key]!, avg = values.reduce(0,+) / Double(values.count)
            let prevDate = c.date(byAdding: .day, value: -7, to: Schedule.date(key, zone: zone)!)!
            let previous = groups[Schedule.day(prevDate, zone: zone)]
            return WeeklyWeight(id: key, average: avg, count: values.count, change: previous.map { avg - $0.reduce(0,+) / Double($0.count) })
        }
    }
}
