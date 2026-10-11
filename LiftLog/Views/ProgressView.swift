import SwiftUI
import Charts

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var templateID = "upper-a"
    @State private var exerciseID = "ua-incline"
    @State private var bodyEditor = false
    private var template: SessionTemplate { store.data.templates.first { $0.id == templateID }! }
    private var exercise: Exercise { template.exercises.first { $0.id == exerciseID } ?? template.exercises[0] }
    var body: some View {
        List {
            Section("Exercise history") {
                Picker("Session template", selection: $templateID) { ForEach(store.data.templates) { Text($0.name).tag($0.id) } }
                    .onChange(of: templateID) { _, _ in exerciseID = template.exercises[0].id }
                Picker("Exercise", selection: $exerciseID) { ForEach(template.exercises) { Text($0.name).tag($0.id) } }
                let rec = Progression.recommend(exercise: exercise, templateID: templateID, sets: Schedule.week(on: Schedule.day(store.now, zone: store.data.timeZoneID)) <= 2 ? 2 : exercise.sets, data: store.data)
                Text("Next normal exposure").font(.headline)
                Text(rec.reason)
                if let load = rec.nextLoad { Text("\(Input.number(load)) \(exercise.unit.rawValue) · \(rec.nextRepTarget) total reps") }
                if Progression.stalled(exerciseID: exerciseID, templateID: templateID, data: store.data) {
                    Label("Review: three comparable completed normal exposures without rep/load improvement at similar RIR. Check recovery, setup and technique. No sets or deload are added automatically.", systemImage: "magnifyingglass").font(.callout)
                }
                let history = store.data.workouts.filter { $0.templateID == templateID && $0.exercises.contains { $0.id == exerciseID && $0.sets.contains { $0.completedAt != nil } } }.sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
                if history.isEmpty { Text("No recorded sets yet. Your first session will appear here.").foregroundStyle(.secondary) }
                ForEach(history) { w in
                    if let log = w.exercises.first(where: { $0.id == exerciseID }) {
                        NavigationLink { WorkoutSummaryView(workoutID: w.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(w.localDate) · \(w.light ? "Light" : w.status.rawValue.capitalized)").font(.headline)
                                Text(log.prescription.exercise.equipment + " · " + log.prescription.exercise.unit.rawValue).font(.caption)
                                ForEach(log.workingSets.filter { $0.completedAt != nil }) { s in Text("\(Input.number(s.weight!)) kg × \(s.reps!) · RIR \(s.rir!)") }
                            }
                        }
                    }
                }
            }
            Section("Body measurements") {
                Button("Log morning weight / weekly waist", systemImage: "plus") { bodyEditor = true }.frame(minHeight: 48)
                let weeks = BodyTrends.weeks(store.data.body, zone: store.data.timeZoneID)
                if weeks.isEmpty { Text("No measurements recorded. Missing days never count as zero.").foregroundStyle(.secondary) }
                else {
                    Chart(weeks) { week in
                        PointMark(x: .value("Week", week.id), y: .value("Average kg", week.average))
                            .accessibilityLabel("Week \(week.id), \(week.average.formatted(.number.precision(.fractionLength(2)))) kilograms from \(week.count) readings")
                    }.frame(height: 180).chartYScale(domain: .automatic(includesZero: false))
                    ForEach(weeks.reversed()) { week in
                        VStack(alignment: .leading) {
                            Text("\(week.id): \(week.average.formatted(.number.precision(.fractionLength(2)))) kg").font(.headline)
                            Text("\(week.count) readings" + (week.change.map { " · change \($0.formatted(.number.sign(strategy: .always()).precision(.fractionLength(2)))) kg" } ?? " · no adjacent-week comparison")).font(.caption)
                        }
                    }
                }
                ForEach(store.data.body.sorted { $0.localDate > $1.localDate }.prefix(12)) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.localDate).font(.caption)
                        if let weight = entry.weight { Text("Weight: \(Input.number(weight)) kg") }
                        if let waist = entry.waist { Text("Waist: \(Input.number(waist)) cm") }
                    }
                }
                Text("Initial planning range: about 0.15–0.25 kg/week. Long-term personal goal: 90 kg at 10–12% body fat, not a promised result. Waist does not calculate body fat here.").font(.footnote)
            }
            Section("All sessions") {
                ForEach(store.data.workouts.sorted { $0.startedAt > $1.startedAt }) { w in
                    NavigationLink("\(w.localDate) · \(w.templateName) · \(w.status.rawValue)") { if w.status == .active { WorkoutView(workoutID: w.id) } else { WorkoutSummaryView(workoutID: w.id) } }
                }
            }
        }.navigationTitle("Progress").sheet(isPresented: $bodyEditor) { NavigationStack { BodyEditor() } }
    }
}
struct BodyEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var date = Date()
    @State private var weight = ""
    @State private var waist = ""
    @State private var message: String?
    var body: some View {
        Form {
            DatePicker("Local measurement date", selection: $date, displayedComponents: .date).environment(\.timeZone, TimeZone(identifier: store.data.timeZoneID)!)
            TextField("Morning weight (kg)", text: $weight).keyboardType(.decimalPad).focused($focused)
            TextField("Weekly waist (cm)", text: $waist).keyboardType(.decimalPad).focused($focused)
            Text("One record per date. Saving the same date updates it; an empty field retains that day's existing measurement.").font(.footnote)
            if let message { Text(message).foregroundStyle(.red) }
            Button("Save measurement") {
                guard !weight.isEmpty || !waist.isEmpty, weight.isEmpty || (Input.decimal(weight) != nil && (20...400).contains(Input.decimal(weight)!)), waist.isEmpty || (Input.decimal(waist) != nil && (30...250).contains(Input.decimal(waist)!)) else { message = "Enter weight from 20–400 kg or waist from 30–250 cm. Use dot or comma decimals."; return }
                let key = Schedule.day(date, zone: store.data.timeZoneID)
                if store.transaction({ data in
                    if let i = data.body.firstIndex(where: { $0.localDate == key }) {
                        if !weight.isEmpty { data.body[i].weight = Input.decimal(weight) }; if !waist.isEmpty { data.body[i].waist = Input.decimal(waist) }
                    } else { data.body.append(BodyEntry(recordedAt: store.now, localDate: key, timeZoneID: data.timeZoneID, weight: Input.decimal(weight), waist: Input.decimal(waist))) }
                }) { dismiss() }
            }.frame(minHeight: 48)
        }.navigationTitle("Body log").onAppear { date = store.now }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
        }
    }
}
