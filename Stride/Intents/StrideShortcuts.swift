import AppIntents

/// "Hey Siri, start my run in Stride." Also surfaces in Shortcuts and Spotlight.
struct StrideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartNextRunIntent(),
                    phrases: ["Start my run in \(.applicationName)",
                              "Start my next run in \(.applicationName)",
                              "Let's run with \(.applicationName)"],
                    shortTitle: "Start run",
                    systemImageName: "figure.run")
        AppShortcut(intent: StartGuidedRunIntent(),
                    phrases: ["Start \(\.$run) in \(.applicationName)",
                              "Start a \(\.$run) in \(.applicationName)"],
                    shortTitle: "Guided run",
                    systemImageName: "waveform")
    }
}
