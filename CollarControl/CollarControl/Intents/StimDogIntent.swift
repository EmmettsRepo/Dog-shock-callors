import AppIntents

/// Siri Shortcut: "Send stimulation to [dog]"
struct StimDogIntent: AppIntent {
    static let title: LocalizedStringResource = "Stimulate Dog's Collar"
    static let description: IntentDescription = "Sends a stimulation command to a dog's collar at a specified level."
    static let openAppWhenRun = true

    @Parameter(title: "Dog Name")
    var dogName: String

    @Parameter(title: "Level (1-100)", default: 10)
    var level: Int

    @Parameter(title: "Duration (tenths of second)", default: 5)
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
        let clampedLevel = min(max(level, 1), 100)
        ble.sendStimulation(collarID: dog.collarID, level: clampedLevel, duration: duration)
        return .result(dialog: "Sending level \(clampedLevel) stimulation to \(dog.name)'s collar.")
    }
}
