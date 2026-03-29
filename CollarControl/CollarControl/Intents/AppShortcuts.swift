import AppIntents

/// Registers Siri phrases for collar control shortcuts.
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VibrateDogIntent(),
            phrases: [
                "Vibrate \(\.$dogName)'s collar in \(.applicationName)",
                "Vibrate \(\.$dogName) collar with \(.applicationName)"
            ],
            shortTitle: "Vibrate Collar",
            systemImageName: "iphone.radiowaves.left.and.right"
        )

        AppShortcut(
            intent: ToneDogIntent(),
            phrases: [
                "Beep \(\.$dogName)'s collar in \(.applicationName)",
                "Tone \(\.$dogName) collar with \(.applicationName)"
            ],
            shortTitle: "Beep Collar",
            systemImageName: "speaker.wave.2.fill"
        )

        AppShortcut(
            intent: StimDogIntent(),
            phrases: [
                "Stim \(\.$dogName)'s collar in \(.applicationName)",
                "Send stimulation to \(\.$dogName) with \(.applicationName)"
            ],
            shortTitle: "Stim Collar",
            systemImageName: "bolt.fill"
        )
    }
}
