import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct StrideWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RunLiveActivity()
        StartRunControl()
    }
}

// MARK: - Control Center button

struct StartRunControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.assiamah.stride.startrun") {
            ControlWidgetButton(action: StartNextRunIntent()) {
                Label("Start run", systemImage: "figure.run")
            }
        }
        .displayName("Start run")
        .description("Starts today's Stride run with the coach.")
    }
}

// MARK: - Live Activity

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            LockScreenRunView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.7))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.paused ? "Paused" : context.state.segmentLabel,
                          systemImage: context.state.isRunSegment ? "figure.run" : "figure.walk")
                        .font(.caption.bold())
                        .foregroundStyle(phaseTint(context.state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state).font(.title3.bold()).frame(maxWidth: 80)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        if !context.state.paused {
                            ProgressView(timerInterval: context.state.segmentStart...context.state.segmentEnd, countsDown: true)
                                .labelsHidden().tint(phaseTint(context.state))
                        }
                        HStack {
                            Text(context.state.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Text(distance(context.state)).font(.caption2.monospacedDigit())
                            if context.state.heartRate > 0 {
                                Label("\(Int(context.state.heartRate))", systemImage: "heart.fill")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.red)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isRunSegment ? "figure.run" : "figure.walk")
                    .foregroundStyle(phaseTint(context.state))
            } compactTrailing: {
                Countdown(state: context.state).font(.caption2.bold()).frame(maxWidth: 44).foregroundStyle(phaseTint(context.state))
            } minimal: {
                Image(systemName: context.state.isRunSegment ? "figure.run" : "figure.walk")
                    .foregroundStyle(phaseTint(context.state))
            }
        }
    }
}

private func phaseTint(_ s: RunActivityAttributes.ContentState) -> Color {
    if s.paused { return .orange }
    return s.isRunSegment ? .green : .blue
}

private func distance(_ s: RunActivityAttributes.ContentState) -> String {
    s.useMiles ? String(format: "%.2f mi", s.meters / 1609.344) : String(format: "%.2f km", s.meters / 1000)
}

/// Live countdown while running, frozen number while paused.
struct Countdown: View {
    let state: RunActivityAttributes.ContentState

    var body: some View {
        if state.paused {
            let s = max(0, Int(state.segmentRemaining))
            Text(String(format: "%d:%02d", s / 60, s % 60)).monospacedDigit()
        } else {
            Text(timerInterval: state.segmentStart...state.segmentEnd, countsDown: true).monospacedDigit()
        }
    }
}

struct LockScreenRunView: View {
    let state: RunActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(state.paused ? "Paused" : state.segmentLabel,
                      systemImage: state.isRunSegment ? "figure.run" : "figure.walk")
                    .font(.headline)
                    .foregroundStyle(phaseTint(state))
                Spacer()
                Countdown(state: state).font(.system(size: 34, weight: .bold, design: .rounded))
            }
            if !state.paused {
                ProgressView(timerInterval: state.segmentStart...state.segmentEnd, countsDown: true)
                    .labelsHidden().tint(phaseTint(state))
            }
            HStack {
                Text("\(state.title) · \(state.segmentIndex + 1)/\(state.segmentCount)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(distance(state)).font(.caption.monospacedDigit())
                if state.heartRate > 0 {
                    Label("\(Int(state.heartRate))", systemImage: "heart.fill")
                        .font(.caption.monospacedDigit()).foregroundStyle(.red)
                }
            }
        }
    }
}
