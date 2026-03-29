import AppIntents

/// Siri Shortcut: "Vibrate [dog]'s collar"
struct VibrateDogIntent: AppIntent {
    static let title: LocalizedStringResource = "Vibrate Dog's Collar"
    static let description: IntentDescription = "Sends a vibration command to a dog's collar."
    static let openAppWhenRun = true

    @Parameter(title: "Dog Name")
    var dogName: String

    @Parameter(title: "Duration (tenths of second)", default: 10)
    var duration: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DogStore.shared
        guard let dog = store.dog(named: dogName) else {
            return .result(dialog: "I couldn't find a dog named \(dogName).")
        }
        let ble = BLEManager.shared
        guard ble.connectionState == .connected else {
            return .result(dialog: "The collar bridge is not connected.")
        }
        ble.sendVibration(collarID: dog.collarID, duration: duration)
        return .result(dialog: "Vibrating \(dog.name)'s collar.")
    }
}
