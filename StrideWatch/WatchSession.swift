import Foundation
import HealthKit
import Observation

/// The HealthKit workout session behind a run. Keeps the watch app alive, streams heart rate and
/// active calories from the sensors to the phone, and saves the run to Health (with the phone's
/// GPS distance) when the phone says the run is over.
@Observable
@MainActor
final class WatchSession: NSObject {
    static let shared = WatchSession()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var workoutID: String?

    private(set) var isActive = false
    private(set) var heartRate: Double = 0
    private(set) var calories: Double = 0

    private override init() { super.init() }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType(),
                                        HKQuantityType(.activeEnergyBurned),
                                        HKQuantityType(.distanceWalkingRunning)]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        store.requestAuthorization(toShare: share, read: read) { _, _ in }
    }

    /// Follow the phone: open a session when a run goes live, close it when the run ends.
    func sync(with s: RunSnapshot) {
        switch s.phase {
        case .running, .paused:
            if session == nil { start(workoutID: s.workoutID, indoor: s.indoor) }
            else if s.phase == .paused { session?.pause() } else { session?.resume() }
        case .finished:
            finish(meters: s.meters)
        case .cancelled:
            discard()
        }
    }

    private func start(workoutID: String, indoor: Bool) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = indoor ? .indoor : .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            // The phone measures distance (GPS / pedometer); don't let the watch double-count it.
            source.disableCollection(for: HKQuantityType(.distanceWalkingRunning))
            builder.dataSource = source
            session.delegate = self
            builder.delegate = self
            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            self.session = session
            self.builder = builder
            self.workoutID = workoutID
            heartRate = 0
            calories = 0
            isActive = true
            WatchBridge.shared.sendMetrics(heartRate: 0, calories: 0, sessionActive: true)
        } catch {
            isActive = false
        }
    }

    private func finish(meters: Double) {
        guard let session, let builder else { return }
        let end = Date()
        let start = builder.startDate ?? end
        session.end()
        let done: () -> Void = {
            builder.endCollection(withEnd: end) { _, _ in
                builder.finishWorkout { _, _ in }
            }
        }
        if meters > 0 {
            let qty = HKQuantity(unit: .meter(), doubleValue: meters)
            let sample = HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning), quantity: qty, start: start, end: end)
            builder.add([sample]) { _, _ in done() }
        } else {
            done()
        }
        reset()
    }

    private func discard() {
        guard let session, let builder else { return }
        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in builder.discardWorkout() }
        reset()
    }

    private func reset() {
        session = nil
        builder = nil
        workoutID = nil
        isActive = false
        WatchBridge.shared.sendMetrics(heartRate: heartRate, calories: calories, sessionActive: false)
    }
}

extension WatchSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.reset() }
    }
}

extension WatchSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var hr: Double?
        var kcal: Double?
        for type in collectedTypes {
            guard let q = type as? HKQuantityType, let stats = workoutBuilder.statistics(for: q) else { continue }
            switch q {
            case HKQuantityType(.heartRate):
                hr = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            case HKQuantityType(.activeEnergyBurned):
                kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
            default: break
            }
        }
        Task { @MainActor in
            if let hr { self.heartRate = hr }
            if let kcal { self.calories = kcal }
            WatchBridge.shared.sendMetrics(heartRate: self.heartRate, calories: self.calories, sessionActive: true)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
