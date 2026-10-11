import Foundation

public enum LoadUnit: String, Codable, CaseIterable, Sendable {
    case perHand = "kg per hand", total = "kg total barbell", perSide = "kg per side"
    case machine = "kg machine scale", bodyweight = "kg external (bodyweight = 0)"
}
public struct Exercise: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var sets: Int
    public var minReps: Int
    public var maxReps: Int
    public var targetRIR: Int
    public var restSeconds: Int
    public var unit: LoadUnit
    public var cue: String
    public var unilateral: Bool
    public var initialLoad: Double?
    public var increment: Double?
    public var equipment: String
}
public struct SessionTemplate: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var focus: String
    public var weekday: Int // Foundation: Sunday = 1
    public var minutes: Int
    public var exercises: [Exercise]
    public var neck: Bool
}
public struct Prescription: Codable, Equatable, Sendable {
    public var exercise: Exercise
    public var sets: Int
    public var targetRIR: Int
    public var normalLoad: Double?
    public var load: Double?
    public var repTarget: Int
    public var reason: String
}
public struct LoggedSet: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var weight: Double?
    public var reps: Int?
    public var rir: Int?
    public var completedAt: Date?
    public var warmup: Bool
    public init(weight: Double? = nil, reps: Int? = nil, rir: Int? = nil, completedAt: Date? = nil, warmup: Bool = false) {
        self.weight = weight; self.reps = reps; self.rir = rir; self.completedAt = completedAt; self.warmup = warmup
    }
    public var valid: Bool {
        guard let weight, let reps, let rir else { return false }
        return weight.isFinite && (0...1000).contains(weight) && (1...100).contains(reps) && (0...10).contains(rir)
    }
}
public struct ExerciseLog: Codable, Identifiable, Equatable, Sendable {
    public var id: String { prescription.exercise.id }
    public var prescription: Prescription
    public var sets: [LoggedSet]
    public var cleanForm: Bool?
    public var pain = false
    public var skipped = false
    public var skipReason = ""
    public var workingSets: [LoggedSet] { sets.filter { !$0.warmup } }
    public var fullyRecorded: Bool { !skipped && workingSets.count == prescription.sets && workingSets.allSatisfy { $0.completedAt != nil && $0.valid } }
    public init(prescription: Prescription) {
        self.prescription = prescription
        self.sets = (0..<prescription.sets).map { _ in LoggedSet(weight: prescription.load) }
    }
}
public struct NeckHold: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var direction: String
    public var seconds: Int?
    public var completed = false
}
public enum WorkoutStatus: String, Codable, Sendable { case active, completed, partial }
public struct Workout: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var scheduleID: String
    public var templateID: String
    public var templateName: String
    public var scheduledDate: String
    public var localDate: String
    public var timeZoneID: String
    public var startedAt: Date
    public var completedAt: Date?
    public var light: Bool
    public var status: WorkoutStatus = .active
    public var exercises: [ExerciseLog]
    public var neck: [NeckHold]
    public var neckNotes = ""
    public var restEnd: Date?
    public var completedSetCount: Int { exercises.flatMap(\.sets).filter { !$0.warmup && $0.completedAt != nil }.count }
}
public struct ScheduleEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: String // immutable original date + template
    public var templateID: String
    public var originalDate: String
    public var date: String
    public var skipped = false
}
public struct BodyEntry: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var recordedAt: Date
    public var localDate: String
    public var timeZoneID: String
    public var weight: Double?
    public var waist: Double?
    public init(recordedAt: Date, localDate: String, timeZoneID: String = "Europe/Warsaw", weight: Double? = nil, waist: Double? = nil) {
        self.recordedAt = recordedAt; self.localDate = localDate; self.timeZoneID = timeZoneID; self.weight = weight; self.waist = waist
    }
}
public struct AppData: Codable, Equatable, Sendable {
    public var templates: [SessionTemplate] = Programme.templates
    public var workouts: [Workout] = []
    public var scheduleChanges: [ScheduleEntry] = []
    public var body: [BodyEntry] = []
    public var timeZoneID = "Europe/Warsaw"
    public var haptics = true
    public var notifications = false
    public init() {}
    enum CodingKeys: String, CodingKey { case templates, workouts, scheduleChanges, body, timeZoneID, haptics, notifications }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templates = try c.decode([SessionTemplate].self, forKey: .templates)
        workouts = try c.decode([Workout].self, forKey: .workouts)
        scheduleChanges = try c.decode([ScheduleEntry].self, forKey: .scheduleChanges)
        body = try c.decode([BodyEntry].self, forKey: .body)
        timeZoneID = try c.decodeIfPresent(String.self, forKey: .timeZoneID) ?? "Europe/Warsaw"
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        notifications = try c.decodeIfPresent(Bool.self, forKey: .notifications) ?? false
    }
}
public enum Input {
    public static func decimal(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let n = Double(normalized), n.isFinite, n >= 0 else { return nil }
        return n
    }
    public static func number(_ value: Double) -> String { String(format: "%g", value) }
}
public enum LogError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let text): return text } }
}
