import SwiftUI

struct HomeView: View {
    @State private var store = ProgressStore.shared
    @State private var activeWorkout: Workout?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let next = store.nextWorkout {
                        todayCard(next)
                    } else {
                        planDoneCard
                    }

                    section("Guided runs") {
                        ForEach(Plans.guided) { w in
                            WorkoutRow(workout: w, done: store.isDone(w)) { activeWorkout = w }
                        }
                    }

                    if !store.runs.isEmpty {
                        section("History") {
                            ForEach(store.runs.sorted { $0.date > $1.date }.prefix(10)) { run in
                                HistoryRow(run: run)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Stride")
            .fullScreenCover(item: $activeWorkout) { w in
                RunView(workout: w)
            }
        }
    }

    private func todayCard(_ w: Workout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TODAY")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.accentColor)
            Text(w.title).font(.title.bold())
            Text(w.subtitle).foregroundStyle(.secondary)
            SegmentBar(segments: w.segments)
                .frame(height: 10)
            HStack {
                Label(w.durationText, systemImage: "clock")
                Spacer()
                Label("\(Int(store.planProgress * 100))% of plan", systemImage: "chart.bar")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Button { activeWorkout = w } label: {
                Label("Start guided run", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .card(padding: 20, radius: 22)
    }

    private var planDoneCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You ran 5K.").font(.title.bold())
            Text("The plan is finished. Keep the habit with the guided runs below, or reset the plan from the Plan tab.")
                .foregroundStyle(.secondary)
        }
        .card(padding: 20, radius: 22)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let done: Bool
    let start: () -> Void

    var body: some View {
        Button(action: start) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(done ? .green : Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.title).font(.headline)
                    Text(workout.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(workout.durationText).font(.footnote).foregroundStyle(.secondary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct HistoryRow: View {
    let run: CompletedRun

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(run.workout?.title ?? run.workoutID).font(.headline)
                Text(run.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.clock(TimeInterval(run.seconds))).font(.headline.monospacedDigit())
                Text(Fmt.distance(run.meters)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

/// Proportional strip showing walk/run structure at a glance.
struct SegmentBar: View {
    let segments: [Segment]
    var highlight: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let total = Double(segments.reduce(0) { $0 + $1.seconds })
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { i, s in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(s.kind))
                        .opacity(highlight == nil || highlight == i ? 1 : 0.35)
                        .frame(width: max(2, (geo.size.width - CGFloat(segments.count - 1) * 2) * CGFloat(Double(s.seconds) / total)))
                }
            }
        }
    }

    private func color(_ k: Segment.Kind) -> Color {
        switch k {
        case .run: return .accentColor
        case .walk: return .blue
        case .warmup, .cooldown: return .gray
        }
    }
}

extension View {
    /// The one card look used everywhere: soft fill, rounded corners.
    func card(padding: CGFloat = 14, radius: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: radius))
    }
}
