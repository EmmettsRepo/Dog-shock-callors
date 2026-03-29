import SwiftUI

/// Per-dog control view with stimulation slider, vibrate, and tone buttons.
struct DogControlView: View {
    let dog: Dog
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var dogStore: DogStore

    @State private var stimLevel: Double
    @State private var isStimulating = false

    init(dog: Dog, bleManager: BLEManager, dogStore: DogStore) {
        self.dog = dog
        self.bleManager = bleManager
        self.dogStore = dogStore
        self._stimLevel = State(initialValue: Double(dog.defaultStimLevel))
    }

    private var isConnected: Bool {
        bleManager.connectionState == .connected
    }

    var body: some View {
        VStack(spacing: 32) {
            // Dog avatar
            ZStack {
                Circle()
                    .fill(dog.color.gradient)
                    .frame(width: 100, height: 100)
                Text(String(dog.name.prefix(1)).uppercased())
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .padding(.top, 16)

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

            // Stim button (hold to send)
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
            .disabled(!isConnected)
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
                .disabled(!isConnected)

                Button {
                    sendTone()
                } label: {
                    Label("Tone", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!isConnected)
            }
            .padding(.horizontal, 32)

            if !isConnected {
                Text("Connect to ESP32 bridge to send commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: stimLevel) { _, newValue in
            // Save as default for this dog
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
        bleManager.sendStimulation(collarID: dog.collarID, level: Int(stimLevel))
    }

    private func sendVibrate() {
        bleManager.sendVibration(collarID: dog.collarID)
    }

    private func sendTone() {
        bleManager.sendTone(collarID: dog.collarID)
    }
}
