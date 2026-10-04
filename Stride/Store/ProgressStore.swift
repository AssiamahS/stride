import Foundation
import Observation

struct CompletedRun: Codable, Identifiable, Hashable {
    var id = UUID()
    let workoutID: String
    let date: Date
    let seconds: Int
    let meters: Double

    var workout: Workout? { Plans.workout(id: workoutID) }
}

/// Everything the app remembers between launches: your starting week and every finished run.
@Observable
@MainActor
final class ProgressStore {
    static let shared = ProgressStore()

    private(set) var runs: [CompletedRun] = []
    var startingWeek: Int {
        didSet { UserDefaults.standard.set(startingWeek, forKey: "plan.startingWeek") }
    }
    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "plan.onboarded") }
    }

    private let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("runs.json")
    }()

    private init() {
        startingWeek = UserDefaults.standard.integer(forKey: "plan.startingWeek")
        hasOnboarded = UserDefaults.standard.bool(forKey: "plan.onboarded")
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([CompletedRun].self, from: data) {
            runs = decoded
        }
    }

    func record(_ run: CompletedRun) {
        runs.append(run)
        save()
    }

    func delete(_ run: CompletedRun) {
        runs.removeAll { $0.id == run.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(runs) { try? data.write(to: file, options: .atomic) }
    }

    func isDone(_ workout: Workout) -> Bool { runs.contains { $0.workoutID == workout.id } }

    /// The plan weeks that apply to this runner (from their starting week on).
    var activeWeeks: [PlanWeek] { Plans.couchTo5K.weeks.filter { $0.week >= startingWeek } }

    /// First plan workout not yet completed.
    var nextWorkout: Workout? {
        activeWeeks.flatMap(\.workouts).first { !isDone($0) }
    }

    var planProgress: Double {
        let all = activeWeeks.flatMap(\.workouts)
        guard !all.isEmpty else { return 0 }
        return Double(all.filter(isDone).count) / Double(all.count)
    }

    var totalMeters: Double { runs.reduce(0) { $0 + $1.meters } }
    var totalSeconds: Int { runs.reduce(0) { $0 + $1.seconds } }
}
