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

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DogStore.shared
        guard let dog = store.dog(named: dogName) else {
            return .result(dialog: "I couldn't find a dog named \(dogName).")
        }
        guard let uuid = dog.peripheralUUID else {
            return .result(dialog: "\(dog.name) doesn't have a collar paired yet.")
        }
        let ble = BLEManager.shared
        guard ble.isCollarReady(uuid) else {
            return .result(dialog: "\(dog.name)'s collar is not connected.")
        }
        let clampedLevel = min(max(level, 1), 100)
        ble.sendStimulation(to: uuid, level: clampedLevel)
        return .result(dialog: "Sending level \(clampedLevel) stimulation to \(dog.name)'s collar.")
    }
}
