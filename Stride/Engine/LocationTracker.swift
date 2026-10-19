import CoreLocation
import Foundation
import Observation

/// Accumulates distance from GPS while a run is active, and watches for standing still so the
/// engine can auto-pause at a red light. Keeps running in the background thanks to the
/// `location` background mode + allowsBackgroundLocationUpdates.
@Observable
@MainActor
final class LocationTracker: NSObject {
    private(set) var meters: Double = 0
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var lastAccuracy: Double = -1
    private(set) var speed: Double = -1
    private(set) var lastFixAt: Date = .distantPast
    private(set) var lastMovedAt: Date = .distantPast

    private let manager = CLLocationManager()
    private var last: CLLocation?
    private var tracking = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    /// GPS is fresh and has reported no movement for a while. Never true without a recent fix,
    /// so losing signal under a bridge doesn't look like standing still.
    var isStationary: Bool {
        let now = Date()
        return now.timeIntervalSince(lastFixAt) < 6 && now.timeIntervalSince(lastMovedAt) > 8
    }

    var isMoving: Bool { Date().timeIntervalSince(lastMovedAt) < 2.5 }

    func requestPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() {
        meters = 0
        last = nil
        tracking = true
        lastMovedAt = Date()
        requestPermission()
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func pause() { tracking = false; last = nil }
    func resume() { tracking = true; lastMovedAt = Date() }

    func stop() {
        tracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for loc in locations {
                self.lastAccuracy = loc.horizontalAccuracy
                // throw away poor fixes and stale/cached points
                guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 30,
                      loc.timestamp.timeIntervalSinceNow > -10 else { continue }
                self.lastFixAt = loc.timestamp
                self.speed = loc.speed
                let step = self.last.map { loc.distance(from: $0) } ?? 0
                if loc.speed > 0.7 || step > 3 { self.lastMovedAt = loc.timestamp }
                guard self.tracking else { self.last = loc; continue }
                if self.last != nil, step > 1 { self.meters += step }
                self.last = loc
            }
        }
    }
}
