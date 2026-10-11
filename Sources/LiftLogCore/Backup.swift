import Foundation

public struct BackupEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var data: AppData
    public init(data: AppData, exportedAt: Date = Date(), schemaVersion: Int = 2) {
        self.schemaVersion = schemaVersion; self.exportedAt = exportedAt; self.data = data
    }
}
public enum Backup {
    public static func encode(_ data: AppData, now: Date = Date()) throws -> Data {
        try validate(data)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(BackupEnvelope(data: data, exportedAt: now))
    }
    public static func decode(_ bytes: Data) throws -> AppData {
        guard bytes.count <= 50_000_000 else { throw LogError.invalid("Backup exceeds the 50 MB limit.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer()
            if let seconds = try? value.decode(Double.self), seconds.isFinite { return Date(timeIntervalSinceReferenceDate: seconds) }
            let text = try value.decode(String.self)
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            throw LogError.invalid("Invalid backup timestamp.")
        }
        let envelope = try decoder.decode(BackupEnvelope.self, from: bytes)
        guard (1...2).contains(envelope.schemaVersion) else { throw LogError.invalid("Unsupported backup version. Existing records are unchanged.") }
        // v1 lacked timezone and preference fields. AppData's decoder supplies explicit v2 defaults.
        try validate(envelope.data)
        return envelope.data
    }
    public static func validate(_ data: AppData) throws {
        func require(_ condition: Bool, _ message: String) throws { if !condition { throw LogError.invalid(message) } }
        func unique<T: Hashable>(_ values: [T]) -> Bool { Set(values).count == values.count }
        func validWeight(_ value: Double?) -> Bool { value == nil || (value!.isFinite && (0...1000).contains(value!)) }
        let seedIDs = Set(Programme.templates.map(\.id))
        try require(Set(data.templates.map(\.id)) == seedIDs && unique(data.templates.map(\.id)), "Backup must contain the four programme templates.")
        try require(TimeZone(identifier: data.timeZoneID) != nil, "Unknown calendar time zone.")
        let exerciseIDs = Set(Programme.templates.flatMap(\.exercises).map(\.id))
        try require(data.manualNextLoads.allSatisfy { exerciseIDs.contains($0.key) && validWeight($0.value) }, "Invalid manual next target.")
        for t in data.templates {
            let seed = Programme.templates.first { $0.id == t.id }!
            try require(t.weekday == seed.weekday && Set(t.exercises.map(\.id)) == Set(seed.exercises.map(\.id)) && unique(t.exercises.map(\.id)), "Invalid programme identity or schedule.")
            for e in t.exercises { try validateExercise(e) }
        }
        try require(unique(data.workouts.map(\.id)) && unique(data.workouts.map(\.scheduleID)), "Duplicate workout or scheduled session IDs.")
        try require(data.workouts.filter { $0.status == .active }.count <= 1, "Only one workout can be active.")
        var setIDs: [UUID] = []
        for w in data.workouts {
            try require(seedIDs.contains(w.templateID) && Schedule.date(w.localDate, zone: w.timeZoneID) != nil && Schedule.date(w.scheduledDate, zone: w.timeZoneID) != nil && TimeZone(identifier: w.timeZoneID) != nil, "Invalid workout date or template.")
            try require(validScheduleID(w.scheduleID, template: w.templateID), "Invalid workout schedule identity.")
            try require((w.status == .active) == (w.completedAt == nil), "Workout completion timestamp is inconsistent.")
            if let end = w.completedAt { try require(end >= w.startedAt, "Workout ends before it starts.") }
            let seed = Programme.templates.first { $0.id == w.templateID }!
            try require(Set(w.exercises.map(\.id)) == Set(seed.exercises.map(\.id)) && unique(w.exercises.map(\.id)), "Invalid exercise identities.")
            for log in w.exercises {
                let p = log.prescription
                try validateExercise(p.exercise)
                try require((1...10).contains(p.sets) && (0...10).contains(p.targetRIR) && validWeight(p.load) && validWeight(p.normalLoad) && (1...1000).contains(p.repTarget), "Invalid prescription snapshot.")
                try require(log.workingSets.count == p.sets && log.sets.count <= 40, "Invalid working-set count.")
                for s in log.sets {
                    setIDs.append(s.id)
                    try require(validWeight(s.weight) && (s.reps == nil || (1...100).contains(s.reps!)) && (s.rir == nil || (0...10).contains(s.rir!)), "Invalid set. Use 0–1000 kg, 1–100 reps and RIR 0–10.")
                    try require(s.completedAt == nil || s.valid, "Completed set is missing valid actuals.")
                }
            }
            try require(unique(w.neck.map(\.id)) && w.neck.count <= 8, "Invalid neck holds.")
            for hold in w.neck {
                try require(["Forward", "Backward", "Left", "Right"].contains(hold.direction) && (hold.seconds == nil || (1...60).contains(hold.seconds!)) && (!hold.completed || hold.seconds != nil), "Invalid neck hold duration.")
            }
            if w.status == .completed {
                try require(w.exercises.allSatisfy(\.fullyRecorded) && w.neck.allSatisfy(\.completed), "Completed workout has unfinished work; save as partial instead.")
            }
        }
        try require(unique(setIDs), "Duplicate set IDs.")
        try require(unique(data.scheduleChanges.map(\.id)), "Duplicate schedule overrides.")
        for e in data.scheduleChanges {
            try require(seedIDs.contains(e.templateID) && e.id == "\(e.originalDate)-\(e.templateID)" && validScheduleID(e.id, template: e.templateID) && Schedule.date(e.date, zone: data.timeZoneID) != nil, "Invalid schedule override.")
            try require(!e.skipped || !data.workouts.contains(where: { $0.scheduleID == e.id }), "A started session cannot also be skipped.")
        }
        try require(unique(data.body.map(\.id)) && unique(data.body.map(\.localDate)), "Duplicate body records or days.")
        for b in data.body {
            try require(Schedule.date(b.localDate, zone: b.timeZoneID) != nil && TimeZone(identifier: b.timeZoneID) != nil && (b.weight != nil || b.waist != nil), "Invalid body entry.")
            try require(b.weight == nil || (b.weight!.isFinite && (20...400).contains(b.weight!)), "Body weight must be 20–400 kg.")
            try require(b.waist == nil || (b.waist!.isFinite && (30...250).contains(b.waist!)), "Waist must be 30–250 cm.")
        }
    }
    private static func validScheduleID(_ id: String, template: String) -> Bool {
        let date = String(id.prefix(10))
        guard id == "\(date)-\(template)", date >= "2026-10-12", let d = Schedule.date(date), let t = Programme.templates.first(where: { $0.id == template }) else { return false }
        return Schedule.calendar().component(.weekday, from: d) == t.weekday
    }
    private static func validateExercise(_ e: Exercise) throws {
        guard !e.id.isEmpty, !e.name.isEmpty, !e.equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...10).contains(e.sets), (1...100).contains(e.minReps), (e.minReps...100).contains(e.maxReps), (0...10).contains(e.targetRIR), (15...600).contains(e.restSeconds),
              e.initialLoad == nil || (e.initialLoad!.isFinite && (0...1000).contains(e.initialLoad!)),
              e.increment == nil || (e.increment!.isFinite && (0.1...100).contains(e.increment!)) else { throw LogError.invalid("Invalid exercise settings.") }
        if ["la-squat", "lb-rdl"].contains(e.id), e.targetRIR != 2 { throw LogError.invalid("Squats and RDL retain a normal target of 2 RIR.") }
    }
    public static func csv(_ data: AppData) -> String {
        func q(_ value: String) -> String {
            // Prevent spreadsheet formula execution in user-written equipment names/notes.
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.hasPrefix($0) }) ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let iso = ISO8601DateFormatter()
        var rows = [["workout_id", "template", "local_date", "time_zone", "completed_at", "status", "light", "exercise_id", "exercise", "equipment", "unit", "set", "warmup", "kg", "reps", "rir", "clean_form", "pain", "neck_seconds", "notes"].map(q).joined(separator: ",")]
        for w in data.workouts {
            for log in w.exercises {
                for (index, s) in log.sets.enumerated() where s.completedAt != nil {
                    let values: [String] = [w.id.uuidString, w.templateID, w.localDate, w.timeZoneID, iso.string(from: s.completedAt!), w.status.rawValue, String(w.light), log.id, log.prescription.exercise.name, log.prescription.exercise.equipment, log.prescription.exercise.unit.rawValue, String(index + 1), String(s.warmup), s.weight.map(Input.number) ?? "", s.reps.map { String($0) } ?? "", s.rir.map { String($0) } ?? "", log.cleanForm.map { String($0) } ?? "", String(log.pain), "", ""]
                    rows.append(values.map(q).joined(separator: ","))
                }
            }
            for h in w.neck where h.completed {
                rows.append([w.id.uuidString, w.templateID, w.localDate, w.timeZoneID, w.completedAt.map { iso.string(from: $0) } ?? "", w.status.rawValue, String(w.light), h.id, "Neck \(h.direction)", "Hand resistance", "seconds", "", "false", "", "", "", "", "", h.seconds.map { String($0) } ?? "", w.neckNotes].map(q).joined(separator: ","))
            }
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }
}
