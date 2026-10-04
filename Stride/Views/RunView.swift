import SwiftUI

/// The live guided run. Big numbers, one glance, two buttons.
struct RunView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var engine: RunEngine
    @State private var summary: CompletedRun?
    @State private var confirmEnd = false

    init(workout: Workout) {
        _engine = State(initialValue: RunEngine(workout: workout))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if let run = summary {
                SummaryView(run: run) { dismiss() }
            } else {
                runBody
            }
        }
        .onAppear {
            engine.onFinishLine = { endRun() }
            engine.start()
        }
    }

    private func endRun() {
        guard summary == nil else { return }
        let run = engine.finish()
        ProgressStore.shared.record(run)
        summary = run
    }

    private var runBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(engine.workout.title).font(.headline)
                Spacer()
                Text(Fmt.clock(engine.totalRemaining) + " left")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding()

            SegmentBar(segments: engine.workout.segments, highlight: engine.segmentIndex)
                .frame(height: 8)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 6) {
                Text(engine.currentSegment.kind.label.uppercased())
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(engine.currentSegment.kind.isRunning ? Color.accentColor : .secondary)
                Text(Fmt.clock(engine.segmentRemaining))
                    .font(.system(size: 96, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                if let next = engine.nextSegment {
                    Text("Next: \(next.kind.label.lowercased()) \(Workout.spoken(next.seconds))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Last block").foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 0) {
                StatColumn("DISTANCE", Fmt.distance(engine.meters))
                StatColumn("PACE", Fmt.pace(engine.pacePerKm))
                StatColumn("TIME", Fmt.clock(engine.elapsed))
            }
            .padding(.horizontal)

            if engine.location.authorization == .denied || engine.location.authorization == .restricted {
                Text("Location is off, so distance won't be tracked. Time-based coaching still works.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button {
                    confirmEnd = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())

                Button {
                    engine.togglePause()
                } label: {
                    Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                        .font(.largeTitle)
                        .frame(width: 96, height: 96)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
            }
            .padding(.vertical, 28)
        }
        .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End and save", role: .destructive) { endRun() }
            Button("Discard") {
                engine.cancel()
                dismiss()
            }
            Button("Keep going", role: .cancel) {}
        }
    }

}

struct StatColumn: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.semibold).monospacedDigit())
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SummaryView: View {
    let run: CompletedRun
    let done: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            Text("Run complete").font(.largeTitle.bold())
            Text(run.workout?.title ?? "Guided run").foregroundStyle(.secondary)
            HStack(spacing: 0) {
                StatColumn("TIME", Fmt.clock(TimeInterval(run.seconds)))
                StatColumn("DISTANCE", Fmt.distance(run.meters))
                StatColumn("PACE", Fmt.pace(run.meters > 100 ? Double(run.seconds) / (run.meters / 1000) : nil))
            }
            .padding(.vertical)
            Text("Saved to Health as a running workout.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button(action: done) {
                Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
