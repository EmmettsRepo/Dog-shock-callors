import SwiftUI

/// Sheet view for adding a new dog profile.
struct AddDogView: View {
    @ObservedObject var dogStore: DogStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var collarID = 0
    @State private var selectedColor = "blue"

    private var usedCollarIDs: Set<Int> {
        Set(dogStore.dogs.map(\.collarID))
    }

    private var nextAvailableCollarID: Int {
        for i in 0...Int(BLEProtocol.maxCollarID) {
            if !usedCollarIDs.contains(i) { return i }
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dog Info") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    Picker("Collar ID", selection: $collarID) {
                        ForEach(0...Int(BLEProtocol.maxCollarID), id: \.self) { id in
                            HStack {
                                Text("Channel \(id)")
                                if usedCollarIDs.contains(id) {
                                    Text("(in use)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(id)
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(Dog.availableColors, id: \.self) { color in
                            Circle()
                                .fill(Dog(name: "", collarID: 0, colorName: color).color)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.headline)
                                    }
                                }
                                .onTapGesture { selectedColor = color }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let dog = Dog(name: name, collarID: collarID, colorName: selectedColor)
                        dogStore.addDog(dog)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                collarID = nextAvailableCollarID
            }
        }
    }
}
