import AVFoundation
import Foundation
import Observation

/// Speaks coach lines. Order of preference for every line:
/// 1. A pre-rendered clip at Coach/clips/<id>.m4a (bundle) or Documents/clips/<id>.m4a (your cloned voice).
/// 2. On-device synthesis with your Apple Personal Voice, if you've authorized it.
/// 3. On-device synthesis with the selected system voice.
/// Audio ducks whatever is playing (music, podcast) and un-ducks when the line ends.
@Observable
@MainActor
final class CoachVoice: NSObject {
    static let shared = CoachVoice()

    enum VoiceSource: String, CaseIterable, Identifiable {
        case personal, system
        var id: String { rawValue }
    }

    var personalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined
    var preferPersonalVoice: Bool {
        didSet { UserDefaults.standard.set(preferPersonalVoice, forKey: "coach.preferPersonal") }
    }
    var systemVoiceIdentifier: String? {
        didSet { UserDefaults.standard.set(systemVoiceIdentifier, forKey: "coach.systemVoice") }
    }
    var rate: Float {
        didSet { UserDefaults.standard.set(rate, forKey: "coach.rate") }
    }
    private(set) var isSpeaking = false
    private(set) var clipCount = 0

    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var queue: [(id: String?, text: String)] = []

    private override init() {
        let d = UserDefaults.standard
        preferPersonalVoice = d.object(forKey: "coach.preferPersonal") as? Bool ?? true
        systemVoiceIdentifier = d.string(forKey: "coach.systemVoice")
        rate = d.object(forKey: "coach.rate") as? Float ?? 0.5
        super.init()
        synth.delegate = self
        personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        refreshClipCount()
    }

    // MARK: Voices

    var personalVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    var englishSystemVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isPersonalVoice) }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
    }

    func requestPersonalVoice() {
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
            Task { @MainActor in self.personalVoiceStatus = status }
        }
    }

    private var activeVoice: AVSpeechSynthesisVoice? {
        if preferPersonalVoice, personalVoiceStatus == .authorized, let pv = personalVoices.first {
            return pv
        }
        if let id = systemVoiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) {
            return v
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    var activeVoiceName: String {
        if preferPersonalVoice, personalVoiceStatus == .authorized, let pv = personalVoices.first {
            return "\(pv.name) (your voice)"
        }
        return activeVoice?.name ?? "Default"
    }

    // MARK: Clips

    static var clipsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func refreshClipCount() {
        let docs = (try? FileManager.default.contentsOfDirectory(atPath: Self.clipsDirectory.path)) ?? []
        let bundled = Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: "Coach/clips") ?? []
        clipCount = Set(docs.map { ($0 as NSString).deletingPathExtension } + bundled.map { $0.deletingPathExtension().lastPathComponent }).count
    }

    private func clipURL(for id: String) -> URL? {
        for ext in ["m4a", "mp3", "wav"] {
            let local = Self.clipsDirectory.appendingPathComponent("\(id).\(ext)")
            if FileManager.default.fileExists(atPath: local.path) { return local }
            if let url = Bundle.main.url(forResource: id, withExtension: ext, subdirectory: "Coach/clips") { return url }
        }
        return nil
    }

    // MARK: Speaking

    /// Say a scripted line (clip if available) or free text (always synthesized).
    func say(_ line: CoachLine) { enqueue(id: line.id, text: line.text) }
    func say(_ text: String) { enqueue(id: nil, text: text) }

    func stop() {
        queue.removeAll()
        synth.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        finished()
    }

    private func enqueue(id: String?, text: String) {
        queue.append((id, text))
        if !isSpeaking { playNext() }
    }

    private func playNext() {
        guard !queue.isEmpty else { finished(); return }
        let item = queue.removeFirst()
        isSpeaking = true
        activateSession()
        if let id = item.id, let url = clipURL(for: id), let p = try? AVAudioPlayer(contentsOf: url) {
            player = p
            p.delegate = self
            p.play()
            return
        }
        let utt = AVSpeechUtterance(string: item.text)
        utt.voice = activeVoice
        utt.rate = rate
        utt.postUtteranceDelay = 0.15
        synth.speak(utt)
    }

    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? s.setActive(true)
    }

    private func finished() {
        isSpeaking = false
        if queue.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

extension CoachVoice: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.playNext() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }
}

extension CoachVoice: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playNext()
        }
    }
}
