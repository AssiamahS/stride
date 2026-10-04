import Foundation
import Observation
import UIKit

/// Drives one guided run: walks through the segments on a wall clock (survives backgrounding),
/// fires coach cues at the right moments, and tracks distance.
@Observable
@MainActor
final class RunEngine {
    enum State { case idle, running, paused, finished }

    let workout: Workout
    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var segmentIndex = 0
    private(set) var startedAt: Date?
    private(set) var finishedAt: Date?

    let location = LocationTracker()
    private let voice = CoachVoice.shared
    private let script = CoachScript.load()
    private let picker = LinePicker()

    private var segmentStarts: [TimeInterval] = []
    private var accumulated: TimeInterval = 0      // elapsed before the current running stretch
    private var resumedAt: Date?
    private var timer: Timer?
    private var firedCues: Set<String> = []
    private var nextMotivationAt: TimeInterval = 0

    /// Seconds between unscheduled motivational drops (user setting: chatty / normal / quiet).
    var motivationInterval: TimeInterval {
        let v = UserDefaults.standard.object(forKey: "coach.chattiness") as? Double ?? 180
        return max(60, v)
    }

    init(workout: Workout) {
        self.workout = workout
        var t: TimeInterval = 0
        for s in workout.segments { segmentStarts.append(t); t += TimeInterval(s.seconds) }
    }

    // MARK: Derived

    var currentSegment: Segment { workout.segments[min(segmentIndex, workout.segments.count - 1)] }
    var segmentElapsed: TimeInterval { elapsed - segmentStarts[min(segmentIndex, segmentStarts.count - 1)] }
    var segmentRemaining: TimeInterval { max(0, TimeInterval(currentSegment.seconds) - segmentElapsed) }
    var totalRemaining: TimeInterval { max(0, TimeInterval(workout.totalSeconds) - elapsed) }
    var progress: Double { min(1, elapsed / Double(workout.totalSeconds)) }
    var segmentProgress: Double { min(1, segmentElapsed / Double(currentSegment.seconds)) }
    var nextSegment: Segment? { segmentIndex + 1 < workout.segments.count ? workout.segments[segmentIndex + 1] : nil }
    var meters: Double { location.meters }

    /// Seconds per kilometre, nil until there's enough distance to be meaningful.
    var pacePerKm: TimeInterval? {
        guard meters > 100, elapsed > 0 else { return nil }
        return elapsed / (meters / 1000)
    }

    // MARK: Control

    func start() {
        guard state == .idle else { return }
        state = .running
        startedAt = Date()
        resumedAt = startedAt
        nextMotivationAt = motivationInterval
        location.start()
        UIApplication.shared.isIdleTimerDisabled = true
        if let l = picker.pick(from: script.start) { voice.say(l) }
        voice.say("Today: \(workout.coachSummary). \(Workout.spoken(workout.totalSeconds)) total.")
        announceSegment(0)
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        accumulated = elapsed
        resumedAt = nil
        state = .paused
        timer?.invalidate()
        location.pause()
        if let l = picker.pick(from: script.paused) { voice.say(l) }
    }

    func resume() {
        guard state == .paused else { return }
        resumedAt = Date()
        state = .running
        location.resume()
        if let l = picker.pick(from: script.resumed) { voice.say(l) }
        startTimer()
    }

    func togglePause() { state == .running ? pause() : resume() }

    /// End early or at the finish line. Returns the record to store.
    func finish() -> CompletedRun {
        timer?.invalidate()
        updateElapsed()
        state = .finished
        finishedAt = Date()
        location.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        voice.stop()
        if let l = picker.pick(from: script.finish) { voice.say(l) }
        let summary = distanceSentence()
        if !summary.isEmpty { voice.say(summary) }
        let run = CompletedRun(workoutID: workout.id, date: startedAt ?? Date(), seconds: Int(elapsed), meters: meters)
        Task { await WorkoutSaver.save(start: run.date, end: finishedAt ?? Date(), meters: meters) }
        return run
    }

    func cancel() {
        timer?.invalidate()
        location.stop()
        voice.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        state = .finished
    }

    // MARK: Clock

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateElapsed() {
        guard state == .running, let r = resumedAt else { return }
        elapsed = accumulated + Date().timeIntervalSince(r)
    }

    private func tick() {
        guard state == .running else { return }
        updateElapsed()

        // segment transitions (may skip several if we were suspended a long time)
        while segmentIndex + 1 < workout.segments.count, elapsed >= segmentStarts[segmentIndex + 1] {
            segmentIndex += 1
            announceSegment(segmentIndex)
        }

        if elapsed >= Double(workout.totalSeconds) {
            onFinishLine?()
            return
        }

        let seg = currentSegment
        if seg.kind.isRunning {
            let half = Double(seg.seconds) / 2
            if seg.seconds >= 120, segmentElapsed >= half { fire("half-\(segmentIndex)", from: script.runHalfway) }
            if seg.seconds >= 60, segmentRemaining <= 30 { fire("last30-\(segmentIndex)", from: script.runLast30) }
        }
        if totalRemaining <= 60 { fire("lastmin", from: script.lastMinute) }

        if elapsed >= nextMotivationAt {
            nextMotivationAt = elapsed + motivationInterval
            // never talk over a transition that's about to happen
            if segmentRemaining > 45, totalRemaining > 90, !voice.isSpeaking,
               let l = picker.pick(from: script.motivation) {
                voice.say(l)
            }
        }
    }

    /// Set by the view: what to do when the clock runs out (finish + show summary).
    var onFinishLine: (() -> Void)?

    private func fire(_ key: String, from pool: [CoachLine]) {
        guard !firedCues.contains(key) else { return }
        firedCues.insert(key)
        if let l = picker.pick(from: pool) { voice.say(l) }
    }

    private func announceSegment(_ i: Int) {
        let seg = workout.segments[i]
        if i > 0 { voice.stop() }   // a transition always wins over a half-finished pep talk
        let pool: [CoachLine]
        switch seg.kind {
        case .warmup: pool = script.warmup
        case .run: pool = script.runStart
        case .walk: pool = script.walkStart
        case .cooldown: pool = script.cooldown
        }
        if let l = picker.pick(from: pool) { voice.say(l) }
        let runsLeft = workout.segments[i...].filter { $0.kind.isRunning }.count
        switch seg.kind {
        case .run:
            let which = seg.seconds >= 60 && workout.runIntervals > 1 ? "Run \(workout.runIntervals - runsLeft + 1) of \(workout.runIntervals). " : ""
            voice.say("\(which)\(Workout.spoken(seg.seconds)).")
        case .walk:
            voice.say("Walk for \(Workout.spoken(seg.seconds)).")
        case .warmup, .cooldown:
            voice.say("\(Workout.spoken(seg.seconds)).")
        }
        if i > 0, seg.kind.isRunning, let sentence = distanceHint() { voice.say(sentence) }
    }

    private func distanceHint() -> String? {
        guard meters > 400 else { return nil }
        return distanceSentence()
    }

    private func distanceSentence() -> String {
        guard meters > 50 else { return "" }
        let km = meters / 1000
        let dist = Fmt.useMiles ? String(format: "%.1f miles", km * 0.621371) : String(format: "%.1f kilometers", km)
        var s = "\(dist) so far."
        if let p = pacePerKm {
            let perUnit = Fmt.useMiles ? p / 0.621371 : p
            let m = Int(perUnit) / 60, sec = Int(perUnit) % 60
            s += " About \(m) minutes \(sec) seconds per \(Fmt.useMiles ? "mile" : "kilometer")."
        }
        return s
    }
}

// MARK: - Formatting helpers shared by views

enum Fmt {
    /// Mirrors the "units.miles" @AppStorage toggle in Coach settings.
    static var useMiles: Bool {
        UserDefaults.standard.object(forKey: "units.miles") as? Bool ?? (Locale.current.measurementSystem == .us)
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.down)))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }

    static func distance(_ meters: Double) -> String {
        if Fmt.useMiles { return String(format: "%.2f mi", meters / 1609.344) }
        return String(format: "%.2f km", meters / 1000)
    }

    static func pace(_ secPerKm: TimeInterval?) -> String {
        guard let p = secPerKm else { return "--:--" }
        let perUnit = Fmt.useMiles ? p * 1.609344 : p
        return String(format: "%d:%02d /%@", Int(perUnit) / 60, Int(perUnit) % 60, Fmt.useMiles ? "mi" : "km")
    }
}
