import SwiftUI

/// Nothing running: today's run and the guided library. Running: the live pager.
struct WatchRootView: View {
    @State private var bridge = WatchBridge.shared

    var body: some View {
        if bridge.snapshot != nil {
            WatchRunView()
        } else {
            NavigationStack {
                List {
                    Section {
                        Button { bridge.send(.start, workoutID: bridge.home?.nextWorkoutID ?? "next") } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TODAY").font(.caption2.weight(.heavy)).foregroundStyle(Color.accentColor)
                                Text(bridge.home?.nextTitle ?? "Today's run").font(.headline)
                                Text(bridge.home?.nextSubtitle ?? "From your plan").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(bridge.starting)
                    }
                    Section("Guided runs") {
                        ForEach(Plans.guided) { w in
                            Button { bridge.send(.start, workoutID: w.id) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.title).font(.headline)
                                    Text(w.durationText).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .disabled(bridge.starting)
                        }
                    }
                    if bridge.starting {
                        Section { Label("Starting on iPhone…", systemImage: "iphone").font(.caption2).foregroundStyle(.secondary) }
                    } else if !bridge.isReachable {
                        Section { Label("iPhone not reachable. Keep it nearby.", systemImage: "iphone.slash").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .navigationTitle("Stride")
            }
        }
    }
}
