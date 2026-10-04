import AVFoundation
import SwiftUI

/// Pick whose voice coaches you. Your own Apple Personal Voice is the default when it exists.
struct CoachSettingsView: View {
    @State private var voice = CoachVoice.shared
    @AppStorage("coach.chattiness") private var chattiness: Double = 180
    @AppStorage("units.miles") private var miles: Bool = Locale.current.measurementSystem == .us

    private let script = CoachScript.load()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coach voice").font(.headline)
                            Text(voice.activeVoiceName).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            voice.stop()
                            if let l = script.runStart.randomElement() { voice.say(l) }
                        } label: {
                            Label("Test", systemImage: voice.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Your voice") {
                    switch voice.personalVoiceStatus {
                    case .authorized:
                        if voice.personalVoices.isEmpty {
                            Text("No Personal Voice on this iPhone yet. Create one in Settings › Accessibility › Personal Voice (about 15 minutes of reading), then come back.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Toggle("Coach in my own voice", isOn: $voice.preferPersonalVoice)
                            ForEach(voice.personalVoices, id: \.identifier) { v in
                                Label(v.name, systemImage: "person.wave.2").foregroundStyle(.secondary)
                            }
                        }
                    case .denied, .unsupported:
                        Text("Personal Voice access is off. Allow it in Settings › Accessibility › Personal Voice › Allow Apps to Request to Use.")
                            .font(.footnote).foregroundStyle(.secondary)
                    default:
                        Button("Use my Personal Voice") { voice.requestPersonalVoice() }
                        Text("iOS clones your voice on-device. Create it once in Settings › Accessibility › Personal Voice, then allow Stride to use it. Nothing leaves the phone.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Recorded clips") {
                    LabeledContent("Lines with your recording", value: "\(voice.clipCount) of \(script.allLines.count)")
                    Text("Drop files named like `run-01.m4a` into the app's Documents › clips folder (Files app) or build them with tools/voice/render_clips.py. Clips play instead of synthesized speech.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Rescan clips") { voice.refreshClipCount() }
                }

                Section("System voice (fallback)") {
                    Picker("Voice", selection: Binding(
                        get: { voice.systemVoiceIdentifier ?? "" },
                        set: { voice.systemVoiceIdentifier = $0.isEmpty ? nil : $0 })) {
                        Text("Default").tag("")
                        ForEach(voice.englishSystemVoices, id: \.identifier) { v in
                            Text("\(v.name) · \(v.language)\(v.quality == .premium ? " · premium" : v.quality == .enhanced ? " · enhanced" : "")").tag(v.identifier)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Speed")
                        Slider(value: $voice.rate, in: 0.35...0.65)
                    }
                }

                Section("How much the coach talks") {
                    Picker("Pep talks", selection: $chattiness) {
                        Text("Lots (every 90s)").tag(90.0)
                        Text("Normal (every 3 min)").tag(180.0)
                        Text("Less (every 5 min)").tag(300.0)
                    }
                    .pickerStyle(.segmented)
                    Text("Segment changes, halfway marks and the last 30 seconds are always announced.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Units") {
                    Toggle("Miles", isOn: $miles)
                }

                Section("Script") {
                    NavigationLink("All \(script.allLines.count) coach lines") { ScriptView(script: script) }
                }
            }
            .navigationTitle("Coach")
        }
    }
}

struct ScriptView: View {
    let script: CoachScript
    @State private var voice = CoachVoice.shared

    var body: some View {
        List {
            group("Start", script.start); group("Warm up", script.warmup); group("Run starts", script.runStart)
            group("Walk breaks", script.walkStart); group("Halfway", script.runHalfway); group("Last 30s", script.runLast30)
            group("Pep talks", script.motivation); group("Last minute", script.lastMinute); group("Cool down", script.cooldown)
            group("Finish", script.finish)
        }
        .navigationTitle("Coach script")
    }

    private func group(_ title: String, _ lines: [CoachLine]) -> some View {
        Section(title) {
            ForEach(lines) { l in
                Button { voice.stop(); voice.say(l) } label: {
                    HStack(alignment: .top) {
                        Text(l.id).font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 84, alignment: .leading)
                        Text(l.text).foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}
