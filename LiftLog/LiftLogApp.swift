import SwiftUI

@main @MainActor struct LiftLogApp: App {
    var body: some Scene { WindowGroup { BootstrapView() } }
}
@MainActor struct BootstrapView: View {
    @State private var store: AppStore?
    @State private var failure: String?
    @State private var recoveryFiles: [URL] = []
    var body: some View {
        Group {
            if let store { RootView().environmentObject(store) }
            else if let failure {
                ContentUnavailableView {
                    Label("Your log could not open", systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text(failure + " No records have been reset. Preserve the app and its Files folder.") }
                actions: {
                    Button("Retry opening", action: load).buttonStyle(.borderedProminent)
                    ForEach(recoveryFiles, id: \.self) { url in ShareLink("Share recovery backup", item: url) }
                    Text("Recovery backups, if any, are also in Files → On My iPhone → Lift Log → Recovery. Do not delete the app to troubleshoot.").font(.footnote)
                }
            } else { ProgressView("Opening your log…") }
        }.task { if store == nil { load() } }.tint(Color("AccentColor"))
    }
    private func load() {
        do {
            #if DEBUG
            let uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let testURL = documents.appendingPathComponent("UITest.store")
            if uiTesting && ProcessInfo.processInfo.arguments.contains("--reset-test-store") {
                for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: testURL.path + suffix) }
            }
            let repository = try SwiftDataRepository(url: uiTesting ? testURL : nil)
            store = try AppStore(repository: repository, clock: uiTesting ? { Schedule.date("2026-10-12")! } : Date.init)
            #else
            store = try AppStore(repository: SwiftDataRepository())
            #endif
            failure = nil
        } catch {
            failure = error.localizedDescription
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recovery")
            recoveryFiles = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        }
    }
}
@MainActor struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            NavigationStack { TrainView() }.tabItem { Label("Train", systemImage: "dumbbell.fill") }
            NavigationStack { ProgrammeView() }.tabItem { Label("Programme", systemImage: "calendar") }
            NavigationStack { ProgressViewScreen() }.tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .alert("Save needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Keep editing", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshNotification() } }
    }
}
@MainActor struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)) }
}
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity, minHeight: 50).foregroundStyle(Color(uiColor: .systemBackground)).background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
