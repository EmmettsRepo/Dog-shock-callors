import SwiftUI

/// Sheet view for adding a new dog and pairing its BLE collar.
struct AddDogView: View {
    @ObservedObject var dogStore: DogStore
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var showScanner = false
    @State private var pairedPeripheralUUID: UUID?
    @State private var pairedProfile: CollarProfile?

    var body: some View {
        NavigationStack {
            Form {
                Section("Dog Info") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(Dog.availableColors, id: \.self) { color in
                            Circle()
                                .fill(Dog(name: "", colorName: color).color)
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

                Section("Collar") {
                    if let uuid = pairedPeripheralUUID, let profile = pairedProfile {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("Collar Paired")
                                    .font(.subheadline.bold())
                                Text(profile.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(uuid.uuidString.prefix(8) + "...")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospaced()
                            }
                            Spacer()
                            Button("Change") { showScanner = true }
                                .font(.caption)
                        }
                    } else {
                        Button {
                            showScanner = true
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Scan for Collar")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if pairedPeripheralUUID == nil {
                    Section {
                        Text("You can also add the dog now and pair the collar later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                        var dog = Dog(
                            name: name,
                            peripheralUUID: pairedPeripheralUUID,
                            collarProfileID: pairedProfile?.id,
                            colorName: selectedColor
                        )
                        dogStore.addDog(dog)
                        if let uuid = pairedPeripheralUUID, let profile = pairedProfile {
                            bleManager.pairCollar(peripheralUUID: uuid, profile: profile)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                CollarScannerView(bleManager: bleManager, dogStore: dogStore) { uuid, profile in
                    pairedPeripheralUUID = uuid
                    pairedProfile = profile
                    showScanner = false
                }
            }
        }
    }
}
