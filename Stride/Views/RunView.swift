import SwiftUI

/// The run screen in three states: ready (pick outdoor/treadmill, start), live (big numbers,
/// two buttons), and summary (stats + share card).
struct RunView: View {
    @State private var active = ActiveRun.shared
    @State private var watch = PhoneConnectivity.shared
    @State private var confirmEnd = false
    @State private var indoor = ActiveRun.shared.defaultIndoor

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if let run = active.summary {
                SummaryView(run: run) { active.close() }
            } else if let engine = active.engine {
                LiveRunView(engine: engine, heartRate: watch.heartRate, confirmEnd: $confirmEnd)
            } else if let w = active.workout {
                readyBody(w)
            }
        }
        .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End and save", role: .destructive) { active.finish() }
            Button("Discard") { active.discard() }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: Ready

    private func readyBody(_ w: Workout) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button { active.close() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 40, height: 40)
                }
                .buttonStyle(.bordered).clipShape(Circle())
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(w.title).font(.largeTitle.bold())
                Text(w.subtitle).foregroundStyle(.secondary)
                SegmentBar(segments: w.segments).frame(height: 10).padding(.top, 6)
                HStack {
                    Label(w.durationText, systemImage: "clock")
                    Spacer()
                    Label("\(w.runIntervals) run\(w.runIntervals == 1 ? "" : "s")", systemImage: "figure.run")
                }
                .font(.footnote).foregroundStyle(.secondary)
            }

            Picker("Where", selection: $indoor) {
                Label("Outdoor", systemImage: "location.fill").tag(false)
                Label("Treadmill", systemImage: "figure.run.treadmill").tag(true)
            }
            .pickerStyle(.segmented)

            Text(indoor ? "No GPS. Distance is estimated from your stride. Auto-pause is off."
                        : "GPS distance and pace. The clock auto-pauses when you stop at a light.")
                .font(.footnote).foregroundStyle(.secondary)

            if watch.isPaired {
                Label(watch.isReachable ? "Apple Watch connected: heart rate and wrist taps are on."
                                        : "Open Stride on your Apple Watch for heart rate.",
                      systemImage: "applewatch")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()

            Button { active.begin(indoor: indoor) } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct LiveRunView: View {
    let engine: RunEngine
    let heartRate: Double
    @Binding var confirmEnd: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(engine.workout.title).font(.headline)
                if engine.indoor {
                    Image(systemName: "figure.run.treadmill").foregroundStyle(.secondary)
                }
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
                if engine.autoPaused {
                    Text("AUTO PAUSED").font(.title3.weight(.heavy)).foregroundStyle(.orange)
                } else {
                    Text(engine.currentSegment.kind.label.uppercased())
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(engine.currentSegment.kind.isRunning ? Color.accentColor : .secondary)
                }
                Text(Fmt.clock(engine.segmentRemaining))
                    .font(.system(size: 96, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                if engine.autoPaused {
                    Text("Start moving and the clock picks back up").foregroundStyle(.secondary)
                } else if let next = engine.nextSegment {
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
                if heartRate > 0 {
                    StatColumn("BPM", "\(Int(heartRate))", tint: .red)
                }
            }
            .padding(.horizontal)

            if !engine.indoor, engine.location.authorization == .denied || engine.location.authorization == .restricted {
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
    }
}

struct StatColumn: View {
    let label: String
    let value: String
    var tint: Color = .primary
    init(_ label: String, _ value: String, tint: Color = .primary) { self.label = label; self.value = value; self.tint = tint }

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SummaryView: View {
    let run: CompletedRun
    let done: () -> Void
    @State private var card: UIImage?

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
            if run.avgHeartRate != nil || run.calories != nil {
                HStack(spacing: 0) {
                    if let hr = run.avgHeartRate { StatColumn("AVG BPM", "\(Int(hr))", tint: .red) }
                    if let kcal = run.calories { StatColumn("KCAL", "\(Int(kcal))", tint: .orange) }
                }
            }
            Text(run.indoor ? "Saved to Health as an indoor run." : "Saved to Health as a running workout.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 12) {
                if let card {
                    ShareLink(item: Image(uiImage: card), preview: SharePreview("My run", image: Image(uiImage: card))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
                Button(action: done) {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .task { card = ShareCard.render(run) }
    }
}
