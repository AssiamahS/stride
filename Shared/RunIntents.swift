import AppIntents
import Foundation

/// Bridge from an intent to the app. The app installs `onRequest` at launch; inside the widget
/// extension nothing is installed and the intent simply opens the app, which then reads `pendingWorkoutID`.
enum RunLauncher {
    static var pendingWorkoutID: String?
    static var onRequest: ((String) -> Void)?

    static func request(_ workoutID: String) {
        pendingWorkoutID = workoutID
        onRequest?(workoutID)
    }
}

struct StartNextRunIntent: AppIntent {
    static let title: LocalizedStringResource = "Start my next run"
    static let description = IntentDescription("Starts today's run from your Road to 5K plan with the coach.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        RunLauncher.request("next")
        return .result()
    }
}

enum GuidedRunChoice: String, AppEnum {
    case first = "g-first"
    case easy15 = "g-easy15"
    case comeback = "g-comeback"
    case raceDay = "g-raceday"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Guided run")
    static let caseDisplayRepresentations: [GuidedRunChoice: DisplayRepresentation] = [
        .first: "First Run",
        .easy15: "Easy 15",
        .comeback: "Comeback Run",
        .raceDay: "5K Day",
    ]
}

struct StartGuidedRunIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a guided run"
    static let description = IntentDescription("Starts one of the stand-alone guided runs.")
    static let openAppWhenRun = true

    @Parameter(title: "Run") var run: GuidedRunChoice

    init() {}
    init(run: GuidedRunChoice) { self.run = run }

    @MainActor
    func perform() async throws -> some IntentResult {
        RunLauncher.request(run.rawValue)
        return .result()
    }
}
