import Foundation

/// Persists dog profiles to UserDefaults.
@MainActor
final class DogStore: ObservableObject {
    static let shared = DogStore()

    @Published var dogs: [Dog] {
        didSet { save() }
    }

    private let key = "saved_dogs_v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Dog].self, from: data) {
            dogs = decoded
        } else {
            dogs = []
        }
    }

    func addDog(_ dog: Dog) {
        // Prevent duplicate peripheral UUID assignments
        if let uuid = dog.peripheralUUID,
           dogs.contains(where: { $0.peripheralUUID == uuid }) {
            return
        }
        dogs.append(dog)
    }

    func updateDog(_ dog: Dog) {
        if let idx = dogs.firstIndex(where: { $0.id == dog.id }) {
            dogs[idx] = dog
        }
    }

    func deleteDog(_ dog: Dog) {
        dogs.removeAll { $0.id == dog.id }
    }

    func dog(named name: String) -> Dog? {
        dogs.first { $0.name.lowercased() == name.lowercased() }
    }

    func dog(withPeripheralUUID uuid: UUID) -> Dog? {
        dogs.first { $0.peripheralUUID == uuid }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(dogs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
