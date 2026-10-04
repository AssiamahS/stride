import Foundation

/// One block of a guided run. Durations are seconds.
struct Segment: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case warmup, run, walk, cooldown

        var label: String {
            switch self {
            case .warmup: return "Warm up"
            case .run: return "Run"
            case .walk: return "Walk"
            case .cooldown: return "Cool down"
            }
        }

        var isRunning: Bool { self == .run }
    }

    var id = UUID()
    let kind: Kind
    let seconds: Int

    init(_ kind: Kind, seconds: Int) {
        self.kind = kind
        self.seconds = seconds
    }

    static func minutes(_ kind: Kind, _ m: Double) -> Segment {
        Segment(kind, seconds: Int(m * 60))
    }
}

/// A complete guided run: a sequence of segments plus a name the coach can say.
struct Workout: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let segments: [Segment]

    var totalSeconds: Int { segments.reduce(0) { $0 + $1.seconds } }
    var runSeconds: Int { segments.filter { $0.kind.isRunning }.reduce(0) { $0 + $1.seconds } }
    var runIntervals: Int { segments.filter { $0.kind.isRunning }.count }

    var durationText: String {
        let m = totalSeconds / 60
        return "\(m) min"
    }

    /// Short coach-facing description: "eight one-minute runs" etc.
    var coachSummary: String {
        let runs = segments.filter { $0.kind.isRunning }
        guard let first = runs.first else { return "a \(totalSeconds / 60) minute walk" }
        let same = runs.allSatisfy { $0.seconds == first.seconds }
        if runs.count == 1 {
            return "one steady \(Self.spoken(first.seconds)) run"
        }
        if same {
            return "\(runs.count) runs of \(Self.spoken(first.seconds)), with walking breaks"
        }
        return "\(runs.count) running intervals, the longest \(Self.spoken(runs.map(\.seconds).max() ?? 0))"
    }

    static func spoken(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let m = seconds / 60, s = seconds % 60
        if s == 0 { return m == 1 ? "one minute" : "\(m) minutes" }
        if s == 30 { return m == 1 ? "a minute and a half" : "\(m) and a half minutes" }
        return "\(m) minutes \(s) seconds"
    }
}

/// A multi-week progression. Week 0 exists for people who can't yet jog a full minute.
struct PlanWeek: Identifiable, Hashable {
    let week: Int
    let theme: String
    let workouts: [Workout]
    var id: Int { week }
}

struct TrainingPlan {
    let title: String
    let weeks: [PlanWeek]

    var allWorkouts: [Workout] { weeks.flatMap(\.workouts) }
}

// MARK: - Builders

private func intervals(_ pairs: [(run: Double, walk: Double)], warm: Double = 5, cool: Double = 5) -> [Segment] {
    var segs: [Segment] = [.minutes(.warmup, warm)]
    for (i, p) in pairs.enumerated() {
        segs.append(.minutes(.run, p.run))
        if i < pairs.count - 1 { segs.append(.minutes(.walk, p.walk)) }
    }
    segs.append(.minutes(.cooldown, cool))
    return segs
}

private func repeated(_ count: Int, run: Double, walk: Double, warm: Double = 5, cool: Double = 5) -> [Segment] {
    intervals(Array(repeating: (run: run, walk: walk), count: count), warm: warm, cool: cool)
}

private func steady(_ minutes: Double, warm: Double = 5, cool: Double = 5) -> [Segment] {
    [.minutes(.warmup, warm), .minutes(.run, minutes), .minutes(.cooldown, cool)]
}

private func w(_ week: Int, _ day: Int, _ title: String, _ subtitle: String, _ segs: [Segment]) -> Workout {
    Workout(id: "w\(week)d\(day)", title: title, subtitle: subtitle, segments: segs)
}

// MARK: - The plan

enum Plans {
    /// Classic 9-week walk/run progression to a continuous 30-minute run (~5K),
    /// with a Week 0 on-ramp for anyone who isn't ready for one-minute runs yet.
    static let couchTo5K = TrainingPlan(title: "Road to 5K", weeks: [
        PlanWeek(week: 0, theme: "Just move", workouts: [
            w(0, 1, "Walk it out", "20 min brisk walk", [.minutes(.warmup, 5), .minutes(.walk, 10), .minutes(.cooldown, 5)]),
            w(0, 2, "First strides", "6 × 30s jog / 2 min walk", repeated(6, run: 0.5, walk: 2)),
            w(0, 3, "Strides again", "8 × 30s jog / 90s walk", repeated(8, run: 0.5, walk: 1.5)),
        ]),
        PlanWeek(week: 1, theme: "Become a runner", workouts: [
            w(1, 1, "Week 1, run 1", "8 × 1 min run / 90s walk", repeated(8, run: 1, walk: 1.5)),
            w(1, 2, "Week 1, run 2", "8 × 1 min run / 90s walk", repeated(8, run: 1, walk: 1.5)),
            w(1, 3, "Week 1, run 3", "8 × 1 min run / 90s walk", repeated(8, run: 1, walk: 1.5)),
        ]),
        PlanWeek(week: 2, theme: "Stretch it", workouts: [
            w(2, 1, "Week 2, run 1", "6 × 90s run / 2 min walk", repeated(6, run: 1.5, walk: 2)),
            w(2, 2, "Week 2, run 2", "6 × 90s run / 2 min walk", repeated(6, run: 1.5, walk: 2)),
            w(2, 3, "Week 2, run 3", "6 × 90s run / 2 min walk", repeated(6, run: 1.5, walk: 2)),
        ]),
        PlanWeek(week: 3, theme: "Three minutes", workouts: (1...3).map {
            w(3, $0, "Week 3, run \($0)", "90s / 3 min runs, twice through",
              intervals([(1.5, 1.5), (3, 3), (1.5, 1.5), (3, 3)]))
        }),
        PlanWeek(week: 4, theme: "Five minutes", workouts: (1...3).map {
            w(4, $0, "Week 4, run \($0)", "3 / 5 / 3 / 5 min runs",
              intervals([(3, 1.5), (5, 2.5), (3, 1.5), (5, 2.5)]))
        }),
        PlanWeek(week: 5, theme: "The big step", workouts: [
            w(5, 1, "Week 5, run 1", "3 × 5 min run / 3 min walk", repeated(3, run: 5, walk: 3)),
            w(5, 2, "Week 5, run 2", "8 min / 5 walk / 8 min", intervals([(8, 5), (8, 5)])),
            w(5, 3, "Week 5, run 3", "20 minutes, no stopping", steady(20)),
        ]),
        PlanWeek(week: 6, theme: "Trust it", workouts: [
            w(6, 1, "Week 6, run 1", "5 / 8 / 5 min runs", intervals([(5, 3), (8, 3), (5, 3)])),
            w(6, 2, "Week 6, run 2", "10 min / 3 walk / 10 min", intervals([(10, 3), (10, 3)])),
            w(6, 3, "Week 6, run 3", "25 minutes steady", steady(25)),
        ]),
        PlanWeek(week: 7, theme: "Steady", workouts: (1...3).map {
            w(7, $0, "Week 7, run \($0)", "25 minutes steady", steady(25))
        }),
        PlanWeek(week: 8, theme: "Almost there", workouts: (1...3).map {
            w(8, $0, "Week 8, run \($0)", "28 minutes steady", steady(28))
        }),
        PlanWeek(week: 9, theme: "5K", workouts: (1...3).map {
            w(9, $0, "Week 9, run \($0)", "30 minutes steady", steady(30))
        }),
    ])

    /// Stand-alone guided runs, like the Nike Run Club library.
    static let guided: [Workout] = [
        Workout(id: "g-first", title: "First Run", subtitle: "10 easy minutes, talk the whole way",
                segments: [.minutes(.warmup, 2), .minutes(.run, 10), .minutes(.cooldown, 3)]),
        Workout(id: "g-easy15", title: "Easy 15", subtitle: "Conversational pace, no watch-checking",
                segments: steady(15, warm: 3, cool: 2)),
        Workout(id: "g-comeback", title: "Comeback Run", subtitle: "20 min, 2 min run / 1 min walk",
                segments: repeated(7, run: 2, walk: 1, warm: 3, cool: 2)),
        Workout(id: "g-raceday", title: "5K Day", subtitle: "Warm up, 30 min effort, cool down",
                segments: steady(30, warm: 5, cool: 5)),
    ]

    static func workout(id: String) -> Workout? {
        (couchTo5K.allWorkouts + guided).first { $0.id == id }
    }

    /// Where to start based on an honest self-check.
    static func startingWeek(for readiness: Readiness) -> Int {
        switch readiness {
        case .notYet: return 0
        case .oneMinute: return 1
        case .fiveMinutes: return 3
        case .tenMinutes: return 5
        case .twentyMinutes: return 7
        }
    }
}

enum Readiness: String, CaseIterable, Identifiable, Codable {
    case notYet, oneMinute, fiveMinutes, tenMinutes, twentyMinutes
    var id: String { rawValue }

    var question: String {
        switch self {
        case .notYet: return "Walking is where I'm at right now"
        case .oneMinute: return "I can jog for 1 minute"
        case .fiveMinutes: return "I can jog 5 minutes without stopping"
        case .tenMinutes: return "I can run 10 minutes straight"
        case .twentyMinutes: return "I can run 20 minutes straight"
        }
    }
}
