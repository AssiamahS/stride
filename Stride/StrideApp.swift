import SwiftUI

@main
struct StrideApp: App {
    init() {
        ActiveRun.shared.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @State private var store = ProgressStore.shared
    @State private var active = ActiveRun.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Today", systemImage: "figure.run") { HomeView() }
            Tab("Plan", systemImage: "calendar") { PlanView() }
            Tab("Coach", systemImage: "waveform") { CoachSettingsView() }
        }
        .tint(.accentColor)
        .sheet(isPresented: Binding(get: { !store.hasOnboarded }, set: { _ in })) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: Binding(get: { active.isPresented }, set: { if !$0 { active.close() } })) {
            RunView().interactiveDismissDisabled()
        }
        .onChange(of: scenePhase) { _, phase in
            // An intent can land before onRequest is wired; also refresh the wrist's "today" card.
            if phase == .active {
                if let pending = RunLauncher.pendingWorkoutID {
                    RunLauncher.pendingWorkoutID = nil
                    active.open(workoutID: pending, autoStart: true)
                }
                active.pushHome()
            }
        }
        .onChange(of: store.runs.count) { _, _ in active.pushHome() }
    }
}
