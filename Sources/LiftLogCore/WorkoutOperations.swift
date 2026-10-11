import Foundation

public enum WorkoutOperations {
    public static func completeSet(workout: inout Workout, exerciseID: String, setID: UUID, weight: Double, reps: Int, rir: Int, now: Date) throws {
        guard let i = workout.exercises.firstIndex(where: { $0.id == exerciseID }), let j = workout.exercises[i].sets.firstIndex(where: { $0.id == setID }) else { throw LogError.invalid("Set no longer exists.") }
        var s = workout.exercises[i].sets[j]
        s.weight = weight; s.reps = reps; s.rir = rir
        guard s.valid else { throw LogError.invalid("Enter 0–1000 kg, 1–100 reps and RIR 0–10.") }
        s.completedAt = s.completedAt ?? now
        workout.exercises[i].sets[j] = s
        workout.exercises[i].skipped = false
        if workout.status == .active { workout.restEnd = now.addingTimeInterval(Double(workout.exercises[i].prescription.exercise.restSeconds)) }
    }
    public static func undoSet(workout: inout Workout, exerciseID: String, setID: UUID) {
        guard let i = workout.exercises.firstIndex(where: { $0.id == exerciseID }), let j = workout.exercises[i].sets.firstIndex(where: { $0.id == setID }) else { return }
        workout.exercises[i].sets[j].completedAt = nil
        workout.restEnd = nil
        if workout.status == .completed { workout.status = .partial }
    }
    public static func finish(workout: inout Workout, partial: Bool, now: Date) throws {
        guard workout.status == .active else { throw LogError.invalid("Workout already finished.") }
        let complete = workout.exercises.allSatisfy(\.fullyRecorded) && workout.neck.allSatisfy(\.completed)
        guard partial || complete else { throw LogError.invalid("Some sets or neck holds are unfinished. Finish as partial to preserve exactly what you recorded.") }
        workout.status = partial ? .partial : .completed
        workout.completedAt = now; workout.restEnd = nil
    }
    public static func restRemaining(_ end: Date?, now: Date) -> Int { max(0, Int(ceil((end ?? now).timeIntervalSince(now)))) }
}
