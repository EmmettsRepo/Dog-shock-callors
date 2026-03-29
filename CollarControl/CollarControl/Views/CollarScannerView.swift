import SwiftUI
import CoreBluetooth

/// BLE scanner view shown during the pairing flow.
/// Displays nearby Bluetooth peripherals sorted by signal strength.
struct CollarScannerView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var dogStore: DogStore
    let onPaired: (UUID, CollarProfile) -> Void

    @State private var selectedPeripheral: DiscoveredPeripheral?
    @State private var showExplorer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scanning indicator
                if bleManager.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Scanning for collars...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                if bleManager.discoveredPeripherals.isEmpty && !bleManager.isScanning {
                    ContentUnavailableView {
                        Label("No Devices Found", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text("Make sure your collar is turned on and in range.")
                    } actions: {
                        Button("Scan Again") { bleManager.startScanning() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(bleManager.discoveredPeripherals) { peripheral in
                        PeripheralRow(
                            peripheral: peripheral,
                            isAssigned: isAssigned(peripheral.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isAssigned(peripheral.id) else { return }
                            selectedPeripheral = peripheral
                            bleManager.stopScanning()
                            bleManager.connectForExploration(peripheral.peripheral)
                            showExplorer = true
                        }
                    }
                }
            }
            .navigationTitle("Find Collar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !bleManager.isScanning {
                        Button("Scan") { bleManager.startScanning() }
                    } else {
                        Button("Stop") { bleManager.stopScanning() }
                    }
                }
            }
            .sheet(isPresented: $showExplorer) {
                if let peripheral = selectedPeripheral {
                    CharacteristicExplorerView(
                        bleManager: bleManager,
                        peripheral: peripheral
                    ) { profile in
                        onPaired(peripheral.id, profile)
                        showExplorer = false
                    }
                }
            }
            .onAppear { bleManager.startScanning() }
            .onDisappear {
                bleManager.stopScanning()
                bleManager.disconnectExploring()
            }
        }
    }

    private func isAssigned(_ uuid: UUID) -> Bool {
        dogStore.dogs.contains { $0.peripheralUUID == uuid }
    }
}

/// A row showing a discovered BLE peripheral
struct PeripheralRow: View {
    let peripheral: DiscoveredPeripheral
    let isAssigned: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Signal bars
            SignalBars(strength: peripheral.signalStrength)

            VStack(alignment: .leading, spacing: 2) {
                Text(peripheral.name)
                    .font(.body)
                    .foregroundStyle(isAssigned ? .secondary : .primary)
                Text(peripheral.id.uuidString.prefix(8) + "...")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()

            if isAssigned {
                Text("Paired")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.15), in: Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isAssigned ? 0.6 : 1)
    }
}

/// Visual signal strength indicator
struct SignalBars: View {
    let strength: DiscoveredPeripheral.SignalStrength

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= strength.bars ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(bar) * 4 + 4)
            }
        }
        .frame(width: 24, height: 20)
    }
}
