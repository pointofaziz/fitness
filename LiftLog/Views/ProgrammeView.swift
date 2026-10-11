import SwiftUI

@MainActor struct ProgrammeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var moving: ScheduleEntry?
    @State private var startEntry: ScheduleEntry?
    @State private var showWorkout = false
    @State private var monthOffset = 0
    private var month: Date { Schedule.calendar(store.data.timeZoneID).date(byAdding: .month, value: monthOffset, to: max(store.now, Schedule.date("2026-10-12")!))! }
    private var monthKey: String { String(Schedule.day(month, zone: store.data.timeZoneID).prefix(7)) }
    private var entries: [ScheduleEntry] {
        let end = Schedule.calendar(store.data.timeZoneID).date(byAdding: .month, value: 1, to: month)!
        return Schedule.entries(through: max("2026-12-31", Schedule.day(end, zone: store.data.timeZoneID)), data: store.data).filter { $0.date.hasPrefix(monthKey) }
    }
    var body: some View {
        List {
            Section("Your four-day split") {
                ForEach(store.data.templates) { template in
                    NavigationLink { TemplateView(templateID: template.id) } label: {
                        VStack(alignment: .leading, spacing: 4) { Text(template.name).font(.headline); Text(template.focus).foregroundStyle(.secondary) }.padding(.vertical, 4)
                    }
                }
            }
            Section {
                HStack {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 48) }.buttonStyle(.borderless).accessibilityLabel("Previous month")
                    Spacer(); Text(monthKey).font(.headline); Spacer()
                    Button { monthOffset += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 48) }.buttonStyle(.borderless).accessibilityLabel("Next month")
                }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        let recorded = store.data.workouts.first { $0.scheduleID == entry.id }
                        Text("\(entry.date) · \(store.data.templates.first { $0.id == entry.templateID }?.name ?? entry.templateID)").font(.headline)
                        if let recorded {
                            Text(recorded.status == .active ? "In progress" : recorded.status == .partial ? "Partial · \(recorded.completedSetCount) working sets" : "Completed · \(recorded.completedSetCount) working sets")
                            NavigationLink("View recorded session") { if recorded.status == .active { WorkoutView(workoutID: recorded.id) } else { WorkoutSummaryView(workoutID: recorded.id) } }
                        } else {
                            Text(entry.skipped ? "Skipped" : entry.date < Schedule.day(store.now, zone: store.data.timeZoneID) ? "Missed · not recorded" : "Planned").foregroundStyle(.secondary)
                            if entry.date != entry.originalDate { Text("Moved from \(entry.originalDate)").font(.caption) }
                            ViewThatFits(in: .horizontal) {
                                HStack { entryActions(entry) }
                                VStack(alignment: .leading) { entryActions(entry) }
                            }
                        }
                    }.padding(.vertical, 6)
                }
            } header: { Text("Calendar") } footer: { Text("47 initial sessions: 12 October–31 December 2026. The same weekly pattern continues afterward. Missed sessions stay visible; move, skip or train them explicitly.") }
        }.navigationTitle("Programme")
        .sheet(item: $moving) { entry in NavigationStack { MoveSessionView(entry: entry) } }
        .confirmationDialog("Start this session today?", isPresented: Binding(get: { startEntry != nil }, set: { if !$0 { startEntry = nil } }), titleVisibility: .visible) {
            Button("Normal session") { if let entry = startEntry { store.start(entry, light: false); showWorkout = store.active != nil }; startEntry = nil }
            Button("Light session") { if let entry = startEntry { store.start(entry, light: true); showWorkout = store.active != nil }; startEntry = nil }
        }
        .sheet(isPresented: $showWorkout) { if let active = store.active { NavigationStack { WorkoutView(workoutID: active.id) } } }
    }
    @ViewBuilder private func entryActions(_ entry: ScheduleEntry) -> some View {
        Button("Move") { moving = entry }.buttonStyle(.bordered).frame(minHeight: 44)
        Button(entry.skipped ? "Unskip" : "Skip") { store.skip(entry) }.buttonStyle(.bordered).frame(minHeight: 44)
        if !entry.skipped { Button("Train") { startEntry = entry }.buttonStyle(.bordered).frame(minHeight: 44).disabled(store.active != nil) }
    }
}
@MainActor struct MoveSessionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let entry: ScheduleEntry
    @State private var date = Date()
    var body: some View {
        Form {
            DatePicker("New session date", selection: $date, displayedComponents: .date)
                .environment(\.timeZone, TimeZone(identifier: store.data.timeZoneID)!)
            Text("Moves the existing session. Its identity and any recorded history are preserved.")
            Button("Save new date") {
                if store.transaction({ try Schedule.move(entry, to: Schedule.day(date, zone: store.data.timeZoneID), data: &$0) }) { dismiss() }
            }.frame(minHeight: 48)
        }.navigationTitle("Move session").onAppear { date = Schedule.date(entry.date, zone: store.data.timeZoneID) ?? store.now }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}
@MainActor struct TemplateView: View {
    @EnvironmentObject private var store: AppStore
    let templateID: String
    var body: some View {
        if let t = store.data.templates.first(where: { $0.id == templateID }) {
            List {
                Section { Text(t.focus).font(.title2.bold()); Text(Programme.warmup) }
                ForEach(t.exercises) { e in
                    NavigationLink { ExerciseSettingsView(templateID: t.id, exerciseID: e.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.name).font(.headline)
                            Text("\(e.sets) × \(e.minReps)–\(e.maxReps) · \(e.targetRIR) RIR · \(e.restSeconds)s rest")
                            Text(e.unit.rawValue).font(.caption).foregroundStyle(.secondary)
                            Text(e.cue).font(.callout)
                        }.padding(.vertical, 6)
                    }
                }
                if t.neck { Section("After the upper session") { Text("Neck holds: forward, backward, left and right. Weeks 1–2: one 10–15s hold per direction; then two, building comfortably toward 20s."); Text(Programme.neckSafety) } }
                Section { Text("First two programme weeks: 2 sets and 3 RIR for every exercise. Editing settings changes future sessions only; started sessions keep their snapshot.") }
            }.navigationTitle(t.name)
        }
    }
}
@MainActor struct ExerciseSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var typing: Bool
    let templateID: String
    let exerciseID: String
    @State private var draft: Exercise?
    @State private var weight = ""
    @State private var step = ""
    @State private var manual = ""
    @State private var message: String?
    var body: some View {
        Form {
            if let e = draft {
                Section(e.name) {
                    Text("Defaults preserve the agreed programme. Adjust only when intentional. Existing workout prescriptions never change.").font(.callout)
                    Stepper("\(e.sets) working sets", value: field(\.sets), in: 1...10)
                    Stepper("Minimum reps: \(e.minReps)", value: field(\.minReps), in: 1...e.maxReps)
                    Stepper("Maximum reps: \(e.maxReps)", value: field(\.maxReps), in: e.minReps...100)
                    if ["la-squat", "lb-rdl"].contains(e.id) { Text("Normal target: 2 RIR (squat/RDL)") }
                    else { Stepper("Normal target: \(e.targetRIR) RIR", value: field(\.targetRIR), in: 1...4) }
                    Stepper("Rest: \(e.restSeconds) seconds", value: field(\.restSeconds), in: 15...600, step: 15)
                }
                Section("Equipment and load") {
                    TextField("Machine / setup name", text: field(\.equipment)).focused($typing)
                    Text("Changing the setup starts a separate baseline. Use the same machine label for comparable results.").font(.footnote)
                    Picker("Load convention", selection: field(\.unit)) { ForEach(LoadUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    TextField("Provisional starting kg (optional)", text: $weight).keyboardType(.decimalPad).focused($typing)
                    Text("Starting weight is used only when no comparable completed normal exposure exists. Mixed-load sessions require you to choose a weight when logging the next session.").font(.footnote)
                    TextField("Manual next target kg (optional)", text: $manual).keyboardType(.decimalPad).focused($typing)
                    Text("Overrides the next normal session once. Use this to resolve mixed loads; it never changes past prescriptions.").font(.footnote)
                    TextField("Smallest equipment step in kg", text: $step).keyboardType(.decimalPad).focused($typing).accessibilityIdentifier("equipmentStep")
                    Text("Dumbbells: usually 1 or 2 kg per hand. Machines: often 2.5 or 5 kg. 30 → 32 kg is 6.7%; these are equipment choices, not weekly guarantees.").font(.footnote)
                }
                if let message { Text(message).foregroundStyle(.red) }
                Button("Save future settings", action: save).frame(minHeight: 48)
            }
        }.navigationTitle("Exercise settings").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } } }
        .onAppear {
            guard draft == nil else { return }
            draft = store.data.templates.first { $0.id == templateID }?.exercises.first { $0.id == exerciseID }
            manual = store.data.manualNextLoads[exerciseID].map(Input.number) ?? ""
            weight = draft?.initialLoad.map(Input.number) ?? ""; step = draft?.increment.map(Input.number) ?? ""
        }
    }
    private func field<T>(_ key: WritableKeyPath<Exercise, T>) -> Binding<T> {
        Binding(get: { draft![keyPath: key] }, set: { draft?[keyPath: key] = $0 })
    }
    private func save() {
        guard var e = draft else { return }
        guard manual.isEmpty || (Input.decimal(manual) != nil && Input.decimal(manual)! <= 1000) else { message = "Manual target must be 0–1000 kg."; return }
        guard weight.isEmpty || (Input.decimal(weight) != nil && Input.decimal(weight)! <= 1000), step.isEmpty || (Input.decimal(step) != nil && (0.1...100).contains(Input.decimal(step)!)) else { message = "Use 0–1000 kg and a step from 0.1–100 kg. Both dot and comma decimals work."; return }
        e.initialLoad = weight.isEmpty ? nil : Input.decimal(weight); e.increment = step.isEmpty ? nil : Input.decimal(step)
        if store.transaction({ data in
            guard let i = data.templates.firstIndex(where: { $0.id == templateID }), let j = data.templates[i].exercises.firstIndex(where: { $0.id == exerciseID }) else { throw LogError.invalid("Exercise not found.") }
            data.templates[i].exercises[j] = e
            data.manualNextLoads[exerciseID] = manual.isEmpty ? nil : Input.decimal(manual)
        }) { dismiss() }
    }
}
