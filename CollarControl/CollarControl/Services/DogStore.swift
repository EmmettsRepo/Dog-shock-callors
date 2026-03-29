import Foundation

/// Persists dog profiles to UserDefaults.
@MainActor
final class DogStore: ObservableObject {
    static let shared = DogStore()

    @Published var dogs: [Dog] {
        didSet { save() }
    }

    private let key = "saved_dogs"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Dog].self, from: data) {
            dogs = decoded
        } else {
            // Pre-populate with Jack
            dogs = [Dog(name: "Jack", collarID: 0)]
        }
    }

    func addDog(_ dog: Dog) {
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

    private func save() {
        if let data = try? JSONEncoder().encode(dogs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
