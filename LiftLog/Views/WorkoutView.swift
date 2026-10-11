import SwiftUI

struct SetSelection: Identifiable { let id: UUID; let exerciseID: String }
@MainActor struct WorkoutView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected = 0
    @State private var selection: SetSelection?
    @State private var finishPrompt = false
    @State private var skipPrompt = false
    @State private var skipReason = ""
    @State private var rirHelp = false
    @State private var equipmentEditor: Exercise?
    let workoutID: UUID
    private var workout: Workout? { store.data.workouts.first { $0.id == workoutID } }
    var body: some View {
        if let w = workout {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Current exercise", selection: $selected) {
                        ForEach(Array(w.exercises.enumerated()), id: \.element.id) { i, log in Text("\(i + 1). \(log.prescription.exercise.name)").tag(i) }
                        if !w.neck.isEmpty { Text("Neck routine").tag(w.exercises.count) }
                    }.pickerStyle(.menu).frame(minHeight: 48)
                    if selected < w.exercises.count {
                        exerciseCard(w.exercises[selected], workout: w)
                    } else { NeckView(workoutID: w.id) }
                    if selected < w.exercises.count - (w.neck.isEmpty ? 1 : 0) {
                        Button("Next exercise", systemImage: "arrow.down") { selected += 1 }.buttonStyle(.bordered).frame(minHeight: 48)
                    }
                    if w.status == .active {
                        Button("Finish workout") { finishPrompt = true }.buttonStyle(PrimaryButton()).accessibilityIdentifier("finishWorkout")
                        Text("You can close this screen and resume. Saved sets stay on this device.").font(.footnote).foregroundStyle(.secondary)
                    } else { Text("Editing actuals only. The original prescription stays unchanged.").font(.footnote) }
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(w.templateName).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { if w.status == .active { RestBar(workoutID: w.id) } }
            .toolbar { if w.status == .active { ToolbarItem(placement: .topBarTrailing) { Button("Save & close") { dismiss() } } } }
            .sheet(item: $selection) { selection in
                NavigationStack { SetEditor(workoutID: w.id, exerciseID: selection.exerciseID, setID: selection.id) }.presentationDetents([.large])
            }
            .sheet(item: $equipmentEditor) { exercise in NavigationStack { ExerciseSettingsView(templateID: w.templateID, exerciseID: exercise.id) } }
            .alert("Finish this session?", isPresented: $finishPrompt) {
                Button("Complete workout") { if store.finish(w.id, partial: false) { dismiss() } }
                Button("Save as partial") { if store.finish(w.id, partial: true) { dismiss() } }
                Button("Keep logging", role: .cancel) {}
            } message: { Text("Complete requires every working set and neck hold. Partial preserves only the work you actually recorded.") }
            .alert("Skip exercise", isPresented: $skipPrompt) {
                TextField("Reason (optional)", text: $skipReason)
                Button("Skip") { store.editExercise(w.id, w.exercises[selected].id) { $0.skipped = true; $0.skipReason = skipReason }; skipReason = "" }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Recorded sets remain saved. This exercise will not earn an increase.") }
            .alert("What is RIR?", isPresented: $rirHelp) { Button("Got it", role: .cancel) {} } message: { Text("Reps in reserve means how many more clean repetitions you could do. 2 RIR means two clean reps left. Count controlled reps, not forced or painful reps.") }
        }
    }
    @ViewBuilder private func exerciseCard(_ log: ExerciseLog, workout w: Workout) -> some View {
        let e = log.prescription.exercise, p = log.prescription
        Card {
            Text(e.name).font(.title2.bold())
            Text("\(p.sets) × \(e.minReps)–\(e.maxReps) · target \(p.targetRIR) RIR").font(.headline)
            Text(e.unit.rawValue + (e.unilateral ? " · reps per side; use weaker side" : "")).font(.subheadline).foregroundStyle(.secondary)
            Text(e.cue).font(.callout)
            Button("RIR explained", systemImage: "questionmark.circle") { rirHelp = true }.frame(minHeight: 44)
            Divider()
            Text("THIS SESSION’S TARGET").font(.caption.bold())
            Text(p.load.map { "\(Input.number($0)) \(e.unit.rawValue) · \(p.repTarget) total reps" } ?? "Choose a comfortable starting weight").font(.headline)
            Text(p.reason).font(.callout)
            if let previous = Progression.baseline(exercise: e, templateID: w.templateID, data: historyBefore(w)) {
                Divider(); Text("PREVIOUS ACTUALS · \(previous.prescription.exercise.equipment)").font(.caption.bold())
                Text(previous.workingSets.map { "\(Input.number($0.weight ?? 0)) kg × \($0.reps ?? 0) @ \($0.rir ?? 0) RIR" }.joined(separator: "\n")).font(.callout.monospacedDigit())
            } else { Text("No previous completed normal exposure on this setup.").font(.footnote).foregroundStyle(.secondary) }
            Button("Equipment step & future targets") { equipmentEditor = e }.frame(minHeight: 44)
        }
        Card {
            Text("Working sets").font(.headline)
            if log.skipped {
                Label("Skipped: \(log.skipReason.isEmpty ? "no reason added" : log.skipReason)", systemImage: "forward.end")
                Button("Unskip exercise") { store.editExercise(w.id, log.id) { $0.skipped = false } }.frame(minHeight: 44)
            }
            ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                Button {
                    selection = SetSelection(id: set.id, exerciseID: log.id)
                } label: {
                    HStack(alignment: .top) {
                        Image(systemName: set.completedAt == nil ? "circle" : "checkmark.circle.fill").font(.title2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(set.warmup ? "Warm-up" : "Set \(index + 1)").font(.headline)
                            if let date = set.completedAt {
                                Text("\(Input.number(set.weight!)) kg × \(set.reps!) · RIR \(set.rir!)")
                                Text("Saved \(date.formatted(date: .omitted, time: .shortened)) · tap to edit or undo").font(.caption)
                            } else { Text("Not completed · tap to record").font(.subheadline) }
                        }
                        Spacer(minLength: 0)
                    }.foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }.buttonStyle(.plain).accessibilityIdentifier("set-\(index)")
                Divider()
            }
            Button("Add warm-up set", systemImage: "plus") {
                store.editExercise(w.id, log.id) { $0.sets.append(LoggedSet(warmup: true)) }
            }.frame(minHeight: 44)
        }
        Card {
            Text("Were your recorded sets clean?").font(.headline)
            HStack {
                Button(log.cleanForm == true ? "✓ Clean form" : "Clean form") { store.editExercise(w.id, log.id) { $0.cleanForm = true } }.buttonStyle(.bordered).frame(minHeight: 48)
                Button(log.cleanForm == false ? "✓ Needs work" : "Needs work") { store.editExercise(w.id, log.id) { $0.cleanForm = false } }.buttonStyle(.bordered).frame(minHeight: 48)
            }
            Toggle("Pain during this exercise", isOn: Binding(get: { log.pain }, set: { v in store.editExercise(w.id, log.id) { $0.pain = v } }))
            if log.pain { Text("Stop painful work. No load increase will be recommended.").font(.callout) }
            if log.cleanForm == nil { Text("Form not yet confirmed. No increase without confirmation.").font(.footnote) }
            if log.fullyRecorded { Text(Progression.evaluate(log, light: w.light).reason).font(.callout) }
            if !log.skipped { Button("Skip exercise", role: .destructive) { skipPrompt = true }.frame(minHeight: 44) }
        }
    }
    private func historyBefore(_ w: Workout) -> AppData {
        var data = store.data; data.workouts.removeAll { $0.id == w.id || ($0.completedAt ?? .distantFuture) > w.startedAt }; return data
    }
}

@MainActor struct RestBar: View {
    @EnvironmentObject private var store: AppStore
    let workoutID: UUID
    var body: some View {
        if let workout = store.data.workouts.first(where: { $0.id == workoutID }) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = WorkoutOperations.restRemaining(workout.restEnd, now: context.date)
                HStack {
                    VStack(alignment: .leading) {
                        Text(remaining > 0 ? "REST" : "READY WHEN YOU ARE").font(.caption.bold())
                        Text(remaining > 0 ? String(format: "%d:%02d", remaining / 60, remaining % 60) : "Rest complete").font(.title3.monospacedDigit()).accessibilityLabel("Rest, \(remaining) seconds remaining")
                    }
                    Spacer()
                    Button("+30s") { store.editWorkout(workoutID) { $0.restEnd = max($0.restEnd ?? store.now, store.now).addingTimeInterval(30) }; store.refreshNotification() }.frame(minWidth: 48, minHeight: 48)
                    Button("End") { store.editWorkout(workoutID) { $0.restEnd = nil }; store.refreshNotification() }.frame(minWidth: 48, minHeight: 48)
                }.padding(.horizontal).padding(.vertical, 8).background(.regularMaterial)
            }
        }
    }
}

@MainActor struct SetEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    enum Field: Hashable { case weight, reps, rir }
    let workoutID: UUID
    let exerciseID: String
    let setID: UUID
    @State private var weight = ""
    @State private var reps = ""
    @State private var rir = ""
    @State private var message: String?
    @State private var loaded = false
    private var log: ExerciseLog? { store.data.workouts.first { $0.id == workoutID }?.exercises.first { $0.id == exerciseID } }
    private var set: LoggedSet? { log?.sets.first { $0.id == setID } }
    var body: some View {
        Form {
            Section {
                Text(log?.prescription.exercise.name ?? "Set").font(.headline)
                Text(log?.prescription.exercise.unit.rawValue ?? "kg")
                Text("Target: \(log?.prescription.exercise.minReps ?? 0)–\(log?.prescription.exercise.maxReps ?? 0) reps, \(log?.prescription.targetRIR ?? 0) RIR. Record what you actually did.").font(.callout)
            }
            Section("Actual performance") {
                numericField("Weight (kg)", text: $weight, field: .weight, decimal: true, step: log?.prescription.exercise.increment ?? 0.5)
                numericField("Reps", text: $reps, field: .reps, decimal: false, step: 1)
                numericField("RIR", text: $rir, field: .rir, decimal: false, step: 1)
                Text("RIR = clean reps left. Bodyweight uses 0 external kg. Dot and comma decimals both work.").font(.footnote)
            }
            if let error = store.error { Section("Save failed") { Text(error); Button("Retry saving", action: complete) } }
            if let message { Section { Text(message).foregroundStyle(.red).accessibilityIdentifier("validationMessage") } }
            if set?.completedAt != nil {
                Section {
                    Button("Undo completion", role: .destructive) {
                        if store.editWorkout(workoutID, { w in WorkoutOperations.undoSet(workout: &w, exerciseID: exerciseID, setID: setID) }) { store.refreshNotification(); dismiss() }
                    }.frame(minHeight: 48)
                }
            }
        }
        .navigationTitle(set?.warmup == true ? "Warm-up" : "Record set").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(set?.completedAt == nil ? "Complete & save set" : "Save correction", action: complete).buttonStyle(PrimaryButton()).padding().background(.regularMaterial).accessibilityIdentifier("saveSet")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = nil } }
        }
        .onAppear {
            guard !loaded, let set else { return }; loaded = true
            weight = set.weight.map(Input.number) ?? ""; reps = set.reps.map { String($0) } ?? ""; rir = set.rir.map { String($0) } ?? ""
        }
        .onChange(of: weight) { _, _ in saveDraft() }.onChange(of: reps) { _, _ in saveDraft() }.onChange(of: rir) { _, _ in saveDraft() }
    }
    @ViewBuilder private func numericField(_ label: String, text: Binding<String>, field: Field, decimal: Bool, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline)
            HStack {
                TextField(label, text: text).keyboardType(decimal ? .decimalPad : .numberPad).focused($focus, equals: field).font(.title2.monospacedDigit()).frame(minHeight: 48).accessibilityIdentifier(field == .weight ? "weightInput" : field == .reps ? "repsInput" : "rirInput")
                Button { adjust(text, by: -step) } label: { Image(systemName: "minus").frame(width: 44, height: 48) }.buttonStyle(.borderless).accessibilityLabel("Decrease \(label)")
                Button { adjust(text, by: step) } label: { Image(systemName: "plus").frame(width: 44, height: 48) }.buttonStyle(.borderless).accessibilityLabel("Increase \(label)")
            }
        }
    }
    private func adjust(_ text: Binding<String>, by step: Double) { text.wrappedValue = Input.number(max(0, (Input.decimal(text.wrappedValue) ?? 0) + step)) }
    private func saveDraft() {
        guard loaded, set?.completedAt == nil else { return }
        let w = weight.isEmpty ? nil : Input.decimal(weight), r = reps.isEmpty ? nil : Int(reps), reserve = rir.isEmpty ? nil : Int(rir)
        guard (weight.isEmpty || (w != nil && w! <= 1000)), (reps.isEmpty || (r != nil && (1...100).contains(r!))), (rir.isEmpty || (reserve != nil && (0...10).contains(reserve!))) else { return }
        store.editExercise(workoutID, exerciseID) { log in
            if let i = log.sets.firstIndex(where: { $0.id == setID }) { log.sets[i].weight = w; log.sets[i].reps = r; log.sets[i].rir = reserve }
        }
    }
    private func complete() {
        guard let w = Input.decimal(weight), let r = Int(reps), let reserve = Int(rir), LoggedSet(weight: w, reps: r, rir: reserve).valid else {
            message = "Enter 0–1000 kg, 1–100 whole reps and RIR 0–10. Reps and RIR must be explicitly recorded."; return
        }
        if store.complete(workout: workoutID, exercise: exerciseID, set: setID, weight: w, reps: r, rir: reserve) { dismiss() }
    }
}

@MainActor struct NeckView: View {
    @EnvironmentObject private var store: AppStore
    let workoutID: UUID
    var body: some View {
        if let w = store.data.workouts.first(where: { $0.id == workoutID }) {
            Card {
                Text("Neck · hand-resisted holds").font(.title2.bold())
                Text(Programme.neckSafety)
                Text(w.neck.count == 4 ? "One 10–15-second hold per direction." : "Two holds per direction. Build comfortable holds toward 20 seconds before modestly increasing manual resistance.").font(.callout)
                ForEach(w.neck) { hold in
                    VStack(alignment: .leading) {
                        Text(hold.direction).font(.headline)
                        Stepper("\(hold.seconds ?? 10) seconds\(hold.seconds == nil ? " · suggested" : "")", value: Binding(get: { hold.seconds ?? 10 }, set: { v in update(hold.id) { $0.seconds = v } }), in: 1...60).frame(minHeight: 48)
                        Button(hold.completed ? "✓ Saved · undo hold" : "Save hold") { update(hold.id) { $0.seconds = $0.seconds ?? 10; $0.completed.toggle() } }.buttonStyle(.bordered).frame(minHeight: 48)
                    }
                }
                TextField("Comfort notes (optional)", text: Binding(get: { w.neckNotes }, set: { v in store.editWorkout(w.id) { $0.neckNotes = v } }), axis: .vertical).textFieldStyle(.roundedBorder)
            }
        }
    }
    private func update(_ id: String, change: (inout NeckHold) -> Void) {
        store.editWorkout(workoutID) { w in
            if let i = w.neck.firstIndex(where: { $0.id == id }) { change(&w.neck[i]) }
            if w.status == .completed && !w.neck.allSatisfy(\.completed) { w.status = .partial }
        }
    }
}
