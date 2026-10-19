import AVFoundation
import Foundation
import UIKit

/// Countdown beeps and transition tones, synthesized in memory so there are no audio assets to ship.
/// Plays through the coach's ducking audio session so music dips the same way it does for speech.
@MainActor
final class Tones {
    static let shared = Tones()

    private var players: [String: AVAudioPlayer] = [:]

    var enabled: Bool { UserDefaults.standard.object(forKey: "coach.tones") as? Bool ?? true }

    private init() {
        players["tick"] = Self.make([(880, 0.09)])
        players["go"] = Self.make([(1046.5, 0.12), (1318.5, 0.24)])
        players["ease"] = Self.make([(1318.5, 0.12), (880, 0.24)])
        players["done"] = Self.make([(784, 0.12), (988, 0.12), (1318.5, 0.34)])
    }

    /// One short beep (3… 2… 1…).
    func tick() { play("tick") }
    /// Rising two-tone: a run interval starts.
    func go() { play("go") }
    /// Falling two-tone: back to walking.
    func ease() { play("ease") }
    /// Three rising notes: the run is finished.
    func done() { play("done") }

    private func play(_ key: String) {
        guard enabled, let p = players[key] else { return }
        CoachVoice.shared.activateSession()
        p.currentTime = 0
        p.play()
    }

    /// Builds a 16-bit mono WAV in memory from a list of (frequency, seconds) notes.
    private static func make(_ notes: [(hz: Double, sec: Double)]) -> AVAudioPlayer? {
        let rate = 44_100.0
        var samples: [Int16] = []
        for n in notes {
            let count = Int(rate * n.sec)
            for i in 0..<count {
                let t = Double(i) / rate
                let attack = min(1, Double(i) / (rate * 0.008))
                let release = min(1, Double(count - i) / (rate * 0.03))
                let v = sin(2 * .pi * n.hz * t) * 0.55 * attack * release
                samples.append(Int16(v * 32_767))
            }
        }
        var data = Data()
        func put32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
        func put16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put32(36 + bytes); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put32(16); put16(1); put16(1)
        put32(UInt32(rate)); put32(UInt32(rate) * 2); put16(2); put16(16)
        data.append(contentsOf: Array("data".utf8)); put32(bytes)
        samples.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
        let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
        player?.prepareToPlay()
        return player
    }
}

/// Phone haptics. They only fire while the app is on screen; the wrist tap comes from the watch.
@MainActor
enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "coach.haptics") as? Bool ?? true }

    static func transition(toRun: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(toRun ? .success : .warning)
    }

    static func tick() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func finish() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
