import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// Watch side of the bridge. Receives run snapshots from the phone, sends back commands and
/// heart rate. The phone is the brain; this never runs a plan on its own.
@Observable
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private(set) var home: WatchHome?
    private(set) var snapshot: RunSnapshot?
    private(set) var isReachable = false
    /// Set when a start was requested and no snapshot has arrived yet.
    private(set) var starting = false

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    // MARK: Watch → phone

    func send(_ cmd: WatchCommand, workoutID: String? = nil) {
        guard WCSession.isSupported() else { return }
        var msg: [String: Any] = [SyncKey.command: cmd.rawValue]
        if let workoutID { msg[SyncKey.workoutID] = workoutID }
        if cmd == .start { starting = true }
        // sendMessage from the watch launches the iPhone app in the background if it isn't running.
        WCSession.default.sendMessage(msg, replyHandler: nil) { [weak self] _ in
            Task { @MainActor in self?.starting = false }
        }
    }

    func sendMetrics(heartRate: Double, calories: Double, sessionActive: Bool) {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([SyncKey.heartRate: heartRate,
                                       SyncKey.calories: calories,
                                       SyncKey.sessionActive: sessionActive],
                                      replyHandler: nil, errorHandler: nil)
    }

    // MARK: Phone → watch

    private func handle(_ dict: [String: Any]) {
        if let data = dict[SyncKey.home] as? Data, let h = try? SyncCoder.decoder.decode(WatchHome.self, from: data) {
            home = h
        }
        if let data = dict[SyncKey.snapshot] as? Data, let s = try? SyncCoder.decoder.decode(RunSnapshot.self, from: data) {
            apply(s)
        }
    }

    private func apply(_ s: RunSnapshot) {
        starting = false
        if let h = s.haptic {
            switch h {
            case "start": WKInterfaceDevice.current().play(.start)
            case "stop": WKInterfaceDevice.current().play(.stop)
            case "success": WKInterfaceDevice.current().play(.success)
            default: WKInterfaceDevice.current().play(.click)
            }
        }
        snapshot = s.isLive ? s : nil
        WatchSession.shared.sync(with: s)
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let ctx = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if !ctx.isEmpty { self.handle(ctx) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handle(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.handle(applicationContext) }
    }
}
