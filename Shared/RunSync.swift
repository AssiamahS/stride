import Foundation

/// Phone ⇄ watch wire format. Epoch times are Doubles on purpose: the watch is arm64_32,
/// where Int is 32-bit and Int(epoch-milliseconds) traps on device.
struct RunSnapshot: Codable, Hashable {
    enum Phase: String, Codable { case running, paused, finished, cancelled }

    var workoutID: String
    var title: String
    var phase: Phase
    var segmentLabel: String
    var isRunSegment: Bool
    var segmentIndex: Int
    var segmentCount: Int
    /// Epoch seconds when the current segment ends (valid while running).
    var segmentEnd: Double
    /// Authoritative remaining seconds in the segment (what to show while paused).
    var segmentRemaining: Double
    var runEnd: Double
    var elapsed: Double
    var meters: Double
    var indoor: Bool
    var useMiles: Bool
    /// One-shot wrist tap: "start" | "stop" | "success" | "click". Cleared after play.
    var haptic: String?

    var isLive: Bool { phase == .running || phase == .paused }
}

enum WatchCommand: String, Codable { case start, pause, resume, end, discard }

/// What the wrist shows when nothing is running. Pushed as application context (latest wins).
struct WatchHome: Codable, Hashable {
    var nextWorkoutID: String?
    var nextTitle: String
    var nextSubtitle: String
    var useMiles: Bool
}

enum SyncKey {
    static let snapshot = "snapshot"
    static let home = "home"
    static let command = "command"
    static let workoutID = "workoutID"
    static let heartRate = "hr"
    static let calories = "kcal"
    static let sessionActive = "sessionActive"
}

enum SyncCoder {
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e }()
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d }()
}
