import SwiftUI

@main
struct StrideApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @State private var store = ProgressStore.shared

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
    }
}
