import CoreLocation
import Foundation
import Observation

/// Accumulates distance from GPS while a run is active. Keeps running in the background
/// thanks to the `location` background mode + allowsBackgroundLocationUpdates.
@Observable
@MainActor
final class LocationTracker: NSObject {
    private(set) var meters: Double = 0
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var lastAccuracy: Double = -1

    private let manager = CLLocationManager()
    private var last: CLLocation?
    private var tracking = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    func requestPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() {
        meters = 0
        last = nil
        tracking = true
        requestPermission()
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func pause() { tracking = false; last = nil }
    func resume() { tracking = true }

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
                guard self.tracking else { self.last = loc; continue }
                if let prev = self.last {
                    let d = loc.distance(from: prev)
                    if d > 1 { self.meters += d }
                }
                self.last = loc
            }
        }
    }
}
