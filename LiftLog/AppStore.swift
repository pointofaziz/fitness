import SwiftUI
import UserNotifications

@MainActor final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var error: String?
    @Published var notice: String?
    let repository: any LogRepository
    let clock: () -> Date
    init(repository: any LogRepository, clock: @escaping () -> Date = Date.init) throws {
        self.repository = repository; self.clock = clock; data = try repository.load()
    }
    var now: Date { clock() }
    var active: Workout? { data.workouts.first { $0.status == .active } }
    @discardableResult func transaction(_ operation: (inout AppData) throws -> Void) -> Bool {
        do {
            var next = data; try operation(&next); try repository.save(next); data = next
            return true
        } catch { self.error = "Not saved. \(error.localizedDescription) Your last saved records remain intact. Retry the edit or export a backup from Settings."; return false }
    }
    @discardableResult func editWorkout(_ id: UUID, _ change: (inout Workout) throws -> Void) -> Bool {
        transaction { state in
            guard let i = state.workouts.firstIndex(where: { $0.id == id }) else { throw LogError.invalid("Workout not found.") }
            try change(&state.workouts[i])
        }
    }
    @discardableResult func editExercise(_ workout: UUID, _ exercise: String, _ change: (inout ExerciseLog) throws -> Void) -> Bool {
        editWorkout(workout) { w in
            guard let i = w.exercises.firstIndex(where: { $0.id == exercise }) else { throw LogError.invalid("Exercise not found.") }
            try change(&w.exercises[i])
            if w.status == .completed && !w.exercises.allSatisfy(\.fullyRecorded) { w.status = .partial }
        }
    }
    func start(_ entry: ScheduleEntry, light: Bool) {
        transaction { state in state.workouts.append(try WorkoutFactory.start(entry: entry, data: state, now: now, light: light)) }
    }
    func complete(workout: UUID, exercise: String, set: UUID, weight: Double, reps: Int, rir: Int) -> Bool {
        let saved = editWorkout(workout) { w in try WorkoutOperations.completeSet(workout: &w, exerciseID: exercise, setID: set, weight: weight, reps: reps, rir: rir, now: now) }
        if saved { haptic(); refreshNotification() }
        return saved
    }
    func haptic() { if data.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    func finish(_ id: UUID, partial: Bool) -> Bool {
        let success = editWorkout(id) { w in try WorkoutOperations.finish(workout: &w, partial: partial, now: now) }
        if success { refreshNotification() }; return success
    }
    func skip(_ entry: ScheduleEntry) {
        transaction { state in
            guard !state.workouts.contains(where: { $0.scheduleID == entry.id }) else { throw LogError.invalid("Started sessions cannot be skipped in the calendar.") }
            var skipped = entry; skipped.skipped.toggle()
            state.scheduleChanges.removeAll { $0.id == entry.id }; state.scheduleChanges.append(skipped)
        }
    }
    func refreshNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rest"])
        guard data.notifications, let end = active?.restEnd, end > now else { return }
        let content = UNMutableNotificationContent(); content.title = "Rest complete"; content.body = "Ready for your next clean set?"; content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSince(now)), repeats: false)
        center.add(UNNotificationRequest(identifier: "rest", content: content, trigger: trigger)) { error in
            if let error { Task { @MainActor in self.notice = "Timer continues in the app. Notification could not be scheduled: \(error.localizedDescription)" } }
        }
    }
    func enableNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            transaction { $0.notifications = granted }
            notice = granted ? "Rest notifications enabled. Focus and silent settings may suppress alerts." : "Notifications are not allowed. Training and the in-app timer still work. You can change permission in iPhone Settings."
            refreshNotification()
        } catch { notice = "Notifications unavailable. The in-app timer still works." }
    }
    func backupURL() throws -> URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("LiftLog-before-replace-\(UUID().uuidString).json")
        try Backup.encode(data).write(to: url, options: .atomic)
        return url
    }
    @discardableResult func replace(with replacement: AppData) -> Bool {
        do {
            try Backup.validate(replacement)
            let recovery = try backupURL()
            guard transaction({ $0 = replacement }) else { return false }
            notice = "Restored without merging or duplicating records. Previous data is recoverable in Files → On My iPhone → Lift Log → Recovery (\(recovery.lastPathComponent))."
            refreshNotification(); return true
        } catch { self.error = "Restore cancelled: \(error.localizedDescription). Existing data was kept."; return false }
    }
}
