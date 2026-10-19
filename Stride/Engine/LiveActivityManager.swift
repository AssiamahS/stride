import ActivityKit
import Foundation

/// Lock screen banner + Dynamic Island for the current run. The countdown is a date range, so the
/// system ticks it without updates; we only push on transitions, pause/resume, and slow metric refreshes.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<RunActivityAttributes>?

    private init() {}

    func update(_ state: RunActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: RunActivityAttributes(), content: content)
        }
    }

    func end(final state: RunActivityAttributes.ContentState?) {
        guard let activity else { return }
        self.activity = nil
        Task {
            if let state {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 60))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Clean up any activity left over from a previous launch (e.g. the app was killed mid-run).
    func endStale() {
        for a in Activity<RunActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
