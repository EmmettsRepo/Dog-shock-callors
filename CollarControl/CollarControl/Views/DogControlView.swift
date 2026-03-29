import SwiftUI

/// Per-dog control view with stimulation slider, vibrate, and tone buttons.
/// Commands are sent to this specific dog's paired collar only.
struct DogControlView: View {
    let dog: Dog
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var dogStore: DogStore

    @State private var stimLevel: Double
    @State private var showScanner = false

    init(dog: Dog, bleManager: BLEManager, dogStore: DogStore) {
        self.dog = dog
        self.bleManager = bleManager
        self.dogStore = dogStore
        self._stimLevel = State(initialValue: Double(dog.defaultStimLevel))
    }

    private var isReady: Bool {
        bleManager.isCollarReady(dog.peripheralUUID)
    }

    private var collarState: CollarConnectionState {
        bleManager.connectionState(for: dog.peripheralUUID)
    }

    var body: some View {
        VStack(spacing: 32) {
            // Dog avatar with connection badge
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(dog.color.gradient)
                        .frame(width: 100, height: 100)
                    Text(String(dog.name.prefix(1)).uppercased())
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }

                if dog.isPaired {
                    CollarStatusBadge(state: collarState)
                }
            }
            .padding(.top, 16)

            if !dog.isPaired {
                // Not paired - show pairing prompt
                VStack(spacing: 16) {
                    Text("No collar paired to \(dog.name)")
                        .foregroundStyle(.secondary)
                    Button("Pair Collar") { showScanner = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                // Stimulation level
                VStack(spacing: 8) {
                    Text("Stimulation Level")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(Int(stimLevel))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(stimColor)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: stimLevel)

                    Slider(value: $stimLevel, in: 1...100, step: 1)
                        .tint(stimColor)
                        .padding(.horizontal, 32)
                }

                // Stim button
                Button {
                    sendStim()
                } label: {
                    Label("Stim", systemImage: "bolt.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!isReady)
                .padding(.horizontal, 32)

                // Vibrate and Tone buttons
                HStack(spacing: 16) {
                    Button {
                        sendVibrate()
                    } label: {
                        Label("Vibrate", systemImage: "iphone.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!isReady)

                    Button {
                        sendTone()
                    } label: {
                        Label("Tone", systemImage: "speaker.wave.2.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!isReady)
                }
                .padding(.horizontal, 32)

                if !isReady && dog.isPaired {
                    Text("Waiting for collar to connect...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if dog.isPaired {
                        Button("Reconnect Collar") {
                            if let uuid = dog.peripheralUUID {
                                bleManager.connectPairedCollar(peripheralUUID: uuid)
                            }
                        }
                    }
                    Button("Change Collar") { showScanner = true }
                    Button("Delete Dog", role: .destructive) {
                        if let uuid = dog.peripheralUUID {
                            bleManager.disconnectCollar(peripheralUUID: uuid)
                        }
                        dogStore.deleteDog(dog)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            CollarScannerView(bleManager: bleManager, dogStore: dogStore) { uuid, profile in
                var updated = dog
                updated.peripheralUUID = uuid
                updated.collarProfileID = profile.id
                dogStore.updateDog(updated)
                bleManager.pairCollar(peripheralUUID: uuid, profile: profile)
                showScanner = false
            }
        }
        .onChange(of: stimLevel) { _, newValue in
            var updated = dog
            updated.defaultStimLevel = Int(newValue)
            dogStore.updateDog(updated)
        }
    }

    private var stimColor: Color {
        if stimLevel < 30 { return .green }
        if stimLevel < 60 { return .yellow }
        if stimLevel < 80 { return .orange }
        return .red
    }

    private func sendStim() {
        guard let uuid = dog.peripheralUUID else { return }
        bleManager.sendStimulation(to: uuid, level: Int(stimLevel))
    }

    private func sendVibrate() {
        guard let uuid = dog.peripheralUUID else { return }
        bleManager.sendVibration(to: uuid)
    }

    private func sendTone() {
        guard let uuid = dog.peripheralUUID else { return }
        bleManager.sendTone(to: uuid)
    }
}
