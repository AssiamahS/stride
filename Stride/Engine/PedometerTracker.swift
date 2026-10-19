import CoreMotion
import Foundation
import Observation

/// Treadmill distance: the iPhone's pedometer estimates stride length from your walking/running
/// cadence. Not GPS-accurate, but far better than nothing on an indoor run.
@Observable
@MainActor
final class PedometerTracker {
    private(set) var meters: Double = 0

    private let pedometer = CMPedometer()
    private var base: Double = 0
    private var tracking = false

    static var isAvailable: Bool { CMPedometer.isDistanceAvailable() }

    func start() {
        meters = 0
        base = 0
        tracking = true
        listen()
    }

    func pause() {
        guard tracking else { return }
        tracking = false
        pedometer.stopUpdates()
        base = meters
    }

    func resume() {
        guard !tracking else { return }
        tracking = true
        listen()
    }

    func stop() {
        tracking = false
        pedometer.stopUpdates()
    }

    private func listen() {
        guard Self.isAvailable else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let d = data?.distance?.doubleValue else { return }
            Task { @MainActor in
                guard let self, self.tracking else { return }
                self.meters = self.base + d
            }
        }
    }
}
