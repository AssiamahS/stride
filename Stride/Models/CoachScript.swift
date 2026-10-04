import Foundation

/// One thing the coach can say. `id` doubles as the clip filename (Coach/clips/<id>.m4a)
/// so a cloned-voice recording can replace the synthesized line.
struct CoachLine: Codable, Hashable, Identifiable {
    let id: String
    let text: String
}

/// The whole script, loaded from Coach/cues.json. Pools are keyed by moment.
struct CoachScript: Codable {
    var start: [CoachLine]
    var warmup: [CoachLine]
    var runStart: [CoachLine]
    var walkStart: [CoachLine]
    var cooldown: [CoachLine]
    var runHalfway: [CoachLine]
    var runLast30: [CoachLine]
    var motivation: [CoachLine]
    var lastMinute: [CoachLine]
    var finish: [CoachLine]
    var paused: [CoachLine]
    var resumed: [CoachLine]

    var allLines: [CoachLine] {
        start + warmup + runStart + walkStart + cooldown + runHalfway + runLast30 + motivation + lastMinute + finish + paused + resumed
    }

    static let empty = CoachScript(start: [], warmup: [], runStart: [], walkStart: [], cooldown: [], runHalfway: [],
                                   runLast30: [], motivation: [], lastMinute: [], finish: [], paused: [], resumed: [])

    static func load() -> CoachScript {
        guard let url = Bundle.main.url(forResource: "cues", withExtension: "json", subdirectory: "Coach")
                ?? Bundle.main.url(forResource: "cues", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let script = try? JSONDecoder().decode(CoachScript.self, from: data) else {
            return .empty
        }
        return script
    }
}

/// Picks lines from a pool without repeating within a session.
final class LinePicker {
    private var used: Set<String> = []

    func pick(from pool: [CoachLine]) -> CoachLine? {
        guard !pool.isEmpty else { return nil }
        let fresh = pool.filter { !used.contains($0.id) }
        let chosen = (fresh.isEmpty ? pool : fresh).randomElement()!
        if fresh.isEmpty { used.removeAll() }
        used.insert(chosen.id)
        return chosen
    }

    func reset() { used.removeAll() }
}
