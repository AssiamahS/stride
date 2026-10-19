import Foundation
import Observation
import WatchConnectivity

/// iPhone side of the watch bridge. The phone is the brain (plan, GPS, coach audio); the watch is
/// the wrist display, the heart-rate sensor, and a second set of buttons.
/// - Live run state rides sendMessage (instant) AND application context (latest wins, so a watch
///   that wakes up late still catches up). Phase changes go both ways; ticks only sendMessage.
/// - Heart rate / calories come back on sendMessage.
/// - Commands (start/pause/resume/end) come back on sendMessage and wake the phone app if needed.
@Observable
@MainActor
final class PhoneConnectivity: NSObject {
    static let shared = PhoneConnectivity()

    private(set) var heartRate: Double = 0
    private(set) var calories: Double = 0
    /// The watch has a HealthKit workout session open for the current run (so it owns the Health save).
    private(set) var watchSessionActive = false
    private(set) var isPaired = false
    private(set) var isReachable = false

    var onCommand: ((WatchCommand, String?) -> Void)?

    private var pendingContext: [String: Any]?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    // MARK: Phone → watch

    func pushHome(_ home: WatchHome) {
        guard WCSession.isSupported(), let data = try? SyncCoder.encoder.encode(home) else { return }
        var ctx = WCSession.default.applicationContext
        ctx[SyncKey.home] = data
        update(context: ctx)
    }

    func send(_ snapshot: RunSnapshot, durable: Bool) {
        guard WCSession.isSupported(), let data = try? SyncCoder.encoder.encode(snapshot) else { return }
        let s = WCSession.default
        if s.isReachable {
            s.sendMessage([SyncKey.snapshot: data], replyHandler: nil, errorHandler: nil)
        }
        if durable {
            var ctx = s.applicationContext
            ctx[SyncKey.snapshot] = data
            update(context: ctx)
        }
    }

    func clearRunContext() {
        guard WCSession.isSupported() else { return }
        var ctx = WCSession.default.applicationContext
        ctx.removeValue(forKey: SyncKey.snapshot)
        update(context: ctx)
        heartRate = 0
        calories = 0
        watchSessionActive = false
    }

    private func update(context: [String: Any]) {
        let s = WCSession.default
        if s.activationState == .activated {
            try? s.updateApplicationContext(context)
        } else {
            pendingContext = context
        }
    }

    private func handle(_ message: [String: Any]) {
        if let hr = message[SyncKey.heartRate] as? Double { heartRate = hr }
        if let kcal = message[SyncKey.calories] as? Double { calories = kcal }
        if let active = message[SyncKey.sessionActive] as? Bool { watchSessionActive = active }
        if let raw = message[SyncKey.command] as? String, let cmd = WatchCommand(rawValue: raw) {
            onCommand?(cmd, message[SyncKey.workoutID] as? String)
        }
    }
}

extension PhoneConnectivity: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let paired = session.isPaired
        let reachable = session.isReachable
        Task { @MainActor in
            self.isPaired = paired
            self.isReachable = reachable
            if activationState == .activated, let ctx = self.pendingContext {
                self.pendingContext = nil
                try? session.updateApplicationContext(ctx)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handle(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in self.handle(message) }
        replyHandler(["ok": true])
    }
}
