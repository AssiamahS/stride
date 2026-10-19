#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Lock screen + Dynamic Island state for a guided run. Compiled into the app and the widget extension.
struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var segmentLabel: String
        var isRunSegment: Bool
        var segmentStart: Date
        var segmentEnd: Date
        var runEnd: Date
        var paused: Bool
        /// Remaining seconds in the segment, frozen while paused.
        var segmentRemaining: TimeInterval
        var segmentIndex: Int
        var segmentCount: Int
        var meters: Double
        var heartRate: Double
        var useMiles: Bool
    }
}
#endif
