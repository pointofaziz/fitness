import SwiftUI

@MainActor struct TrainView: View {
    @EnvironmentObject private var store: AppStore
    @State private var light = false
    @State private var showingWorkout = false
    @State private var presentedWorkoutID: UUID?
    @State private var showSummary = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("One clean set at a time.").font(.title2.bold())
                if let active = store.active {
                    Card {
                        Label("Workout in progress", systemImage: "pause.circle.fill").font(.headline)
                        Text(active.templateName).font(.largeTitle.bold())
                        Text("\(active.completedSetCount) working sets saved · started \(active.localDate)")
                        Text("Your original targets are preserved.").font(.footnote).foregroundStyle(.secondary)
                        Button("Resume workout") { presentedWorkoutID = active.id; showingWorkout = true }.buttonStyle(PrimaryButton()).accessibilityIdentifier("resumeWorkout")
                    }
                } else if let entry = Schedule.next(data: store.data, now: store.now), let template = store.data.templates.first(where: { $0.id == entry.templateID }) {
                    Card {
                        Text(entry.date == Schedule.day(store.now, zone: store.data.timeZoneID) ? "TODAY" : "NEXT · \(entry.date)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(template.name).font(.largeTitle.bold())
                        Text("\(template.focus) · about \(template.minutes) min")
                        let week = Schedule.week(on: Schedule.day(store.now, zone: store.data.timeZoneID), zone: store.data.timeZoneID)
                        if week <= 2 { Text("Intro: 2 sets per exercise, 3 clean reps left.").font(.callout) }
                        Toggle("Light session", isOn: $light)
                        if light { Text("Half the sets, rounded up; about 10% less load; 4 RIR. Your normal baseline stays intact.").font(.footnote) }
                        Button(entry.date == Schedule.day(store.now, zone: store.data.timeZoneID) ? "Start workout" : "Train today") {
                            store.start(entry, light: light); presentedWorkoutID = store.active?.id; showingWorkout = store.active != nil
                        }.buttonStyle(PrimaryButton()).accessibilityIdentifier("startWorkout")
                    }
                }
                Card {
                    Label("Before you lift", systemImage: "figure.walk").font(.headline)
                    Text(Programme.warmup).foregroundStyle(.secondary)
                }
                let week = Schedule.week(on: Schedule.day(store.now, zone: store.data.timeZoneID), zone: store.data.timeZoneID)
                if (6...8).contains(week) || (week > 8 && (week - 1) % 8 == 0) {
                    Card { Label("Recovery checkpoint", systemImage: "leaf").font(.headline); Text("Review sleep, soreness and performance. You can choose Light mode when useful; this is not a fatigue diagnosis or an automatic lighter week.") }
                }
                if let last = store.data.workouts.filter({ $0.status != .active }).sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }).first {
                    NavigationLink { WorkoutSummaryView(workoutID: last.id) } label: {
                        Card { Text("Last session").font(.caption); Text("\(last.templateName) · \(last.completedSetCount) sets").font(.headline); Text(last.status == .partial ? "Saved as partial" : "Completed").font(.footnote) }
                    }.buttonStyle(.plain)
                }
            }.padding()
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Train")
        .sheet(isPresented: $showingWorkout, onDismiss: {
            if let id = presentedWorkoutID, store.data.workouts.first(where: { $0.id == id })?.status != .active { showSummary = true }
        }) {
            if let id = presentedWorkoutID { NavigationStack { WorkoutView(workoutID: id) }.interactiveDismissDisabled(false) }
        }
        .navigationDestination(isPresented: $showSummary) { if let id = presentedWorkoutID { WorkoutSummaryView(workoutID: id) } }
    }
}

@MainActor struct WorkoutSummaryView: View {
    @EnvironmentObject private var store: AppStore
    let workoutID: UUID
    var body: some View {
        if let workout = store.data.workouts.first(where: { $0.id == workoutID }) {
            List {
                Section {
                    Text("\(workout.templateName) · \(workout.status.rawValue.capitalized)").font(.title2.bold())
                    Text("\(workout.completedSetCount) working sets actually recorded")
                    Text("\(workout.localDate) · \(workout.timeZoneID)").font(.caption)
                    if workout.light { Text("Light session — normal baseline preserved") }
                }
                ForEach(workout.exercises) { log in
                    Section(log.prescription.exercise.name) {
                        ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                            if set.completedAt != nil {
                                Text("\(set.warmup ? "Warm-up" : "Set \(index + 1)"): \(Input.number(set.weight!)) \(log.prescription.exercise.unit.rawValue) × \(set.reps!) · RIR \(set.rir!)")
                            }
                        }
                        if log.skipped { Text("Skipped\(log.skipReason.isEmpty ? "" : ": \(log.skipReason)")") }
                        Text(Progression.evaluate(log, light: workout.light, partial: workout.status == .partial).reason).font(.callout).foregroundStyle(.secondary)
                    }
                }
                if !workout.neck.isEmpty {
                    Section("Neck holds") {
                        ForEach(workout.neck.filter(\.completed)) { h in Text("\(h.direction): \(h.seconds ?? 0) sec") }
                        if !workout.neckNotes.isEmpty { Text(workout.neckNotes) }
                    }
                }
                NavigationLink("Correct recorded actuals") { WorkoutView(workoutID: workout.id) }
            }.navigationTitle("Session summary")
        }
    }
}
