import SwiftUI
import CoreBluetooth

/// GATT characteristic explorer for pairing unknown BLE collars.
///
/// Shows all services and writable characteristics. User taps "Test" buttons
/// to send test payloads until the collar responds (vibrates/beeps), then
/// selects that characteristic as the command target.
struct CharacteristicExplorerView: View {
    @ObservedObject var bleManager: BLEManager
    let peripheral: DiscoveredPeripheral
    let onProfileSelected: (CollarProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var autoMatchedProfile: CollarProfile?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Discovering services...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = autoMatchedProfile {
                    // Known collar detected
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)

                        Text("Recognized Collar")
                            .font(.title2.bold())

                        Text("Detected as: \(profile.name)")
                            .foregroundStyle(.secondary)

                        Button("Use This Profile") {
                            onProfileSelected(profile)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button("Explore Manually Instead") {
                            autoMatchedProfile = nil
                        }
                        .font(.subheadline)
                    }
                    .padding()
                } else {
                    // Manual exploration
                    List {
                        Section {
                            Text("Tap \"Test\" on writable characteristics below. Hold the collar in your hand - when it vibrates or beeps, tap \"Use This\" to select that characteristic.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(bleManager.exploredServices) { discoveredService in
                            Section(header: serviceHeader(discoveredService.service)) {
                                ForEach(discoveredService.characteristics, id: \.uuid) { char in
                                    CharacteristicRow(
                                        characteristic: char,
                                        bleManager: bleManager,
                                        peripheral: peripheral.peripheral,
                                        onSelect: { selectedChar in
                                            let profile = CollarProfile.custom(
                                                serviceUUID: discoveredService.service.uuid.uuidString,
                                                characteristicUUID: selectedChar.uuid.uuidString,
                                                writeWithResponse: selectedChar.properties.contains(.write)
                                            )
                                            bleManager.saveCustomProfile(profile)
                                            onProfileSelected(profile)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(peripheral.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        bleManager.disconnectExploring()
                        dismiss()
                    }
                }
            }
            .onAppear {
                bleManager.onExplorationComplete = {
                    isLoading = false
                    // Check for auto-match
                    if let peripheral = bleManager.exploredServices.first?.service.peripheral {
                        for profile in CollarProfile.knownProfiles {
                            if profile.matches(services: peripheral.services ?? []) {
                                autoMatchedProfile = profile
                                break
                            }
                        }
                    }
                }
                // If services already discovered
                if !bleManager.exploredServices.isEmpty {
                    isLoading = false
                }
            }
        }
    }

    private func serviceHeader(_ service: CBService) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(serviceName(service))
                .font(.caption.bold())
            Text(service.uuid.uuidString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
    }

    private func serviceName(_ service: CBService) -> String {
        let uuid = service.uuid.uuidString
        // Common service names
        switch uuid {
        case "180A": return "Device Information"
        case "180F": return "Battery Service"
        case "1800": return "Generic Access"
        case "1801": return "Generic Attribute"
        case "FFE0": return "Custom Service (FFE0)"
        case "FFF0": return "Custom Service (FFF0)"
        default:     return "Service"
        }
    }
}

/// A row showing a single BLE characteristic with test/select buttons
struct CharacteristicRow: View {
    let characteristic: CBCharacteristic
    let bleManager: BLEManager
    let peripheral: CBPeripheral
    let onSelect: (CBCharacteristic) -> Void

    @State private var testSent = false

    private var isWritable: Bool {
        characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(characteristic.uuid.uuidString)
                    .font(.caption)
                    .monospaced()

                Spacer()

                Text(propertiesText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isWritable {
                HStack(spacing: 12) {
                    Button("Test Vibrate") {
                        bleManager.testWrite(
                            to: peripheral,
                            characteristic: characteristic,
                            data: Data([0x02, 0x01])
                        )
                        testSent = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Test Tone") {
                        bleManager.testWrite(
                            to: peripheral,
                            characteristic: characteristic,
                            data: Data([0x03, 0x01])
                        )
                        testSent = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    if testSent {
                        Button("Use This") {
                            onSelect(characteristic)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var propertiesText: String {
        var props: [String] = []
        if characteristic.properties.contains(.read)                { props.append("R") }
        if characteristic.properties.contains(.write)               { props.append("W") }
        if characteristic.properties.contains(.writeWithoutResponse) { props.append("WNR") }
        if characteristic.properties.contains(.notify)              { props.append("N") }
        if characteristic.properties.contains(.indicate)            { props.append("I") }
        return props.joined(separator: " ")
    }
}
