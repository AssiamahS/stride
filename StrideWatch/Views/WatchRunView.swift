import SwiftUI

/// Native-Workout-style vertical pager: controls | live numbers.
struct WatchRunView: View {
    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            WatchControlsView().tag(0)
            WatchMetricsView().tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

struct WatchControlsView: View {
    @State private var bridge = WatchBridge.shared
    @State private var confirmEnd = false

    var body: some View {
        let paused = bridge.snapshot?.phase == .paused
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack {
                    Button { bridge.send(paused ? .resume : .pause) } label: {
                        Image(systemName: paused ? "play.fill" : "pause.fill").font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(paused ? "Resume" : "Pause").font(.caption2)
                }
                VStack {
                    Button(role: .destructive) { confirmEnd = true } label: {
                        Image(systemName: "stop.fill").font(.title2)
                    }
                    .buttonStyle(.bordered)
                    Text("End").font(.caption2)
                }
            }
        }
        .confirmationDialog("End this run?", isPresented: $confirmEnd) {
            Button("End and save") { bridge.send(.end) }
            Button("Discard", role: .destructive) { bridge.send(.discard) }
            Button("Keep going", role: .cancel) {}
        }
    }
}

struct WatchMetricsView: View {
    @State private var bridge = WatchBridge.shared
    @State private var session = WatchSession.shared

    var body: some View {
        if let s = bridge.snapshot {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.phase == .paused ? "PAUSED" : s.segmentLabel.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(s.phase == .paused ? .orange : (s.isRunSegment ? Color.accentColor : .secondary))
                if s.phase == .paused {
                    Text(clock(s.segmentRemaining))
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                } else {
                    Text(timerInterval: Date()...Date(timeIntervalSince1970: s.segmentEnd), countsDown: true)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                }
                Text("\(s.segmentIndex + 1) of \(s.segmentCount) · \(s.title)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Divider()
                HStack {
                    Label(session.heartRate > 0 ? "\(Int(session.heartRate))" : "--", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    Text(distance(s.meters, miles: s.useMiles))
                }
                .font(.body.monospacedDigit())
                HStack {
                    Label("\(Int(session.calories))", systemImage: "flame.fill").foregroundStyle(.orange)
                    Spacer()
                    Text(clock(s.elapsed))
                }
                .font(.body.monospacedDigit())
            }
            .padding(.horizontal, 4)
        }
    }

    private func clock(_ t: Double) -> String {
        let s = max(0, Int(t.rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func distance(_ m: Double, miles: Bool) -> String {
        miles ? String(format: "%.2f mi", m / 1609.344) : String(format: "%.2f km", m / 1000)
    }
}
