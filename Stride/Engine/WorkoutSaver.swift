import Foundation
import HealthKit

/// Writes a finished guided run to Health as a running workout. Best effort: a failure here
/// never blocks the summary screen.
enum WorkoutSaver {
    static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func requestAuthorization() async {
        guard isAvailable else { return }
        let types: Set<HKSampleType> = [HKObjectType.workoutType(),
                                        HKQuantityType(.distanceWalkingRunning)]
        try? await store.requestAuthorization(toShare: types, read: [HKObjectType.workoutType()])
    }

    static func save(start: Date, end: Date, meters: Double) async {
        guard isAvailable else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            if meters > 0 {
                let qty = HKQuantity(unit: .meter(), doubleValue: meters)
                let sample = HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning), quantity: qty, start: start, end: end)
                try await builder.addSamples([sample])
            }
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // ignore: Health not authorized or unavailable
        }
    }
}
