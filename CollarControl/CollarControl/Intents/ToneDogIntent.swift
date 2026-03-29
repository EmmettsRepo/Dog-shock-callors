import AppIntents

/// Siri Shortcut: "Beep [dog]'s collar"
struct ToneDogIntent: AppIntent {
    static let title: LocalizedStringResource = "Beep Dog's Collar"
    static let description: IntentDescription = "Sends a tone/beep command to a dog's collar."
    static let openAppWhenRun = true

    @Parameter(title: "Dog Name")
    var dogName: String

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
        ble.sendTone(to: uuid)
        return .result(dialog: "Beeping \(dog.name)'s collar.")
    }
}
