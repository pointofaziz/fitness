import SwiftUI
import UniformTypeIdentifiers

struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var bytes: Data
    init(bytes: Data = Data()) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws { bytes = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}
@MainActor struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exporting = false
    @State private var importing = false
    @State private var document = LogDocument()
    @State private var exportType: UTType = .json
    @State private var restoreCandidate: AppData?
    @State private var resetPrompt = false
    @State private var timezone = ""
    @State private var files: [URL] = []
    @FocusState private var typing: Bool
    var body: some View {
        Form {
            Section("On this iPhone") {
                Text("Lift Log works offline from first launch. There are no accounts, servers or automatic cross-device sync. Deleting the app or losing this device can lose your records unless you keep a usable backup.")
                Text("Export JSON to Files somewhere separate from this app. CSV is for viewing training data; only the full JSON backup can restore the app.").font(.footnote)
            }
            Section("Backup and restore") {
                Button("Export full JSON backup") { export(csv: false) }.frame(minHeight: 44)
                Button("Export training CSV") { export(csv: true) }.frame(minHeight: 44)
                Button("Restore JSON from Files") { importing = true }.frame(minHeight: 44)
                Text("Restore replaces records after validation and confirmation. A recovery JSON copy is saved first in Documents/Recovery, accessible in Files under Lift Log.").font(.footnote)
                ForEach(files, id: \.self) { url in ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "square.and.arrow.up").lineLimit(2) } }
            }
            Section("Rest and feedback") {
                Toggle("Haptics", isOn: Binding(get: { store.data.haptics }, set: { value in store.transaction { $0.haptics = value } }))
                if store.data.notifications {
                    Button("Turn off rest notifications") { store.transaction { $0.notifications = false }; store.refreshNotification() }
                } else { Button("Enable rest notifications") { Task { await store.enableNotifications() } } }
                Text("The timer uses an end timestamp, including after backgrounding. iOS permission, Focus or silent mode may prevent an audible alert. Notification denial never blocks logging.").font(.footnote)
                if let notice = store.notice { Text(notice).font(.callout) }
            }
            Section("Calendar") {
                TextField("IANA time zone", text: $timezone).textInputAutocapitalization(.never).autocorrectionDisabled().focused($typing)
                Button("Save calendar time zone") {
                    guard TimeZone(identifier: timezone) != nil else { store.error = "Use a valid IANA zone such as Europe/Warsaw."; return }
                    if store.transaction({ $0.timeZoneID = timezone }) { store.notice = "Calendar zone updated. Historical local dates and timestamps are unchanged."; typing = false }
                }
                Text("Initially Europe/Warsaw. Travelling does not silently rewrite session dates. Use this setting if you want future dates calculated in a different zone.").font(.footnote)
            }
            Section("Your reference") {
                Text("Four sessions weekly: Monday Upper A, Tuesday Lower A, Thursday Upper B, Saturday Lower B.")
                Text("Nutrition reference: 3,200 kcal and approximately 200 g protein daily. Food tracking is outside this app.")
                Text("Personal goal: 90 kg at 10–12% body fat. No body-fat estimate or guaranteed six-month outcome.")
                Text("Reported working sets are context, not tested maxima. Provisional seeds: incline dumbbells 30 kg per hand, standard pulldown 75 kg, squat 100 kg. RDL starts unseeded.")
            }
            Section {
                Button("Reset all records", role: .destructive) { resetPrompt = true }.frame(minHeight: 44)
                Text("A recovery backup is required before reset. Keep a separate exported copy as well.").font(.footnote)
            }
        }.navigationTitle("Settings")
        .onAppear { timezone = store.data.timeZoneID; loadRecoveryFiles() }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } } }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportType == .json ? "LiftLog-backup" : "LiftLog-training") { result in
            switch result { case .success: store.notice = "Export saved. Keep the JSON file outside this app for recovery."; case .failure(let error): store.error = "Export failed: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let attributes = try url.resourceValues(forKeys: [.fileSizeKey])
                guard (attributes.fileSize ?? 0) <= 50_000_000 else { throw LogError.invalid("Backup exceeds 50 MB.") }
                restoreCandidate = try Backup.decode(Data(contentsOf: url))
            } catch { store.error = "Import rejected: \(error.localizedDescription). Existing data is unchanged." }
        }
        .confirmationDialog("Replace this device's records?", isPresented: Binding(get: { restoreCandidate != nil }, set: { if !$0 { restoreCandidate = nil } }), titleVisibility: .visible) {
            Button("Replace with validated backup", role: .destructive) {
                if let candidate = restoreCandidate { store.replace(with: candidate); loadRecoveryFiles() }; restoreCandidate = nil
            }
            Button("Cancel", role: .cancel) { restoreCandidate = nil }
        } message: { Text("The backup contains \(restoreCandidate?.workouts.count ?? 0) workouts. Current records will be backed up locally before replacement. Restore never merges or duplicates records.") }
        .confirmationDialog("Reset all records and settings?", isPresented: $resetPrompt, titleVisibility: .visible) {
            Button("Back up and reset", role: .destructive) { store.replace(with: AppData()); loadRecoveryFiles() }
            Button("Cancel", role: .cancel) {}
        }
    }
    private func export(csv: Bool) {
        do {
            document = LogDocument(bytes: csv ? Data(Backup.csv(store.data).utf8) : try Backup.encode(store.data))
            exportType = csv ? .commaSeparatedText : .json; exporting = true
        } catch { store.error = "Export failed: \(error.localizedDescription)" }
    }
    private func loadRecoveryFiles() {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recovery")
        files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
