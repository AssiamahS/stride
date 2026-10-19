import Foundation
import Observation

/// The one place a run lives. Views observe it; the watch, Siri and Control Center drive it.
/// A run can start with no UI on screen (the phone was woken by the watch), so the engine is
/// owned here and not by RunView.
@Observable
@MainActor
final class ActiveRun {
    static let shared = ActiveRun()

    /// The run that's on screen (ready, running, or on its summary).
    private(set) var workout: Workout?
    private(set) var engine: RunEngine?
    private(set) var summary: CompletedRun?

    var isPresented: Bool { workout != nil }

    private init() {}

    /// Indoor is remembered between runs. Siri / watch starts use the remembered choice.
    var defaultIndoor: Bool {
        get { UserDefaults.standard.bool(forKey: "run.indoor") }
        set { UserDefaults.standard.set(newValue, forKey: "run.indoor") }
    }

    /// Show the pre-run screen for a workout (or start immediately).
    func open(_ w: Workout, autoStart: Bool = false) {
        guard engine == nil else { return }   // never stack a run on a run
        workout = w
        summary = nil
        if autoStart { begin(indoor: defaultIndoor) }
    }

    /// Resolve "next" / a workout id and open it.
    func open(workoutID: String, autoStart: Bool) {
        let w: Workout?
        if workoutID == "next" {
            w = ProgressStore.shared.nextWorkout ?? Plans.guided.first
        } else {
            w = Plans.workout(id: workoutID)
        }
        if let w { open(w, autoStart: autoStart) }
    }

    func begin(indoor: Bool) {
        guard let workout, engine == nil else { return }
        defaultIndoor = indoor
        let e = RunEngine(workout: workout, indoor: indoor)
        e.onFinishLine = { [weak self] in self?.finish() }
        engine = e
        e.start()
    }

    func finish() {
        guard let engine, summary == nil else { return }
        let run = engine.finish()
        ProgressStore.shared.record(run)
        summary = run
        self.engine = nil
    }

    func discard() {
        engine?.cancel()
        engine = nil
        close()
    }

    func close() {
        workout = nil
        summary = nil
        engine = nil
    }

    // MARK: Remote control (watch, Siri, Control Center)

    func install() {
        RunLauncher.onRequest = { [weak self] id in self?.open(workoutID: id, autoStart: true) }
        if let pending = RunLauncher.pendingWorkoutID {
            RunLauncher.pendingWorkoutID = nil
            open(workoutID: pending, autoStart: true)
        }
        PhoneConnectivity.shared.onCommand = { [weak self] cmd, id in self?.handle(cmd, workoutID: id) }
        PhoneConnectivity.shared.activate()
        LiveActivityManager.shared.endStale()
        pushHome()
    }

    private func handle(_ cmd: WatchCommand, workoutID: String?) {
        switch cmd {
        case .start:
            if engine == nil { open(workoutID: workoutID ?? "next", autoStart: true) }
        case .pause: engine?.pause()
        case .resume: engine?.resume()
        case .end:
            if engine != nil { finish() }
        case .discard:
            if engine != nil { discard() }
        }
    }

    /// Tell the wrist what today's run is.
    func pushHome() {
        let next = ProgressStore.shared.nextWorkout
        PhoneConnectivity.shared.pushHome(WatchHome(nextWorkoutID: next?.id,
                                                    nextTitle: next?.title ?? "Plan complete",
                                                    nextSubtitle: next?.subtitle ?? "Pick a guided run",
                                                    useMiles: Fmt.useMiles))
    }
}
