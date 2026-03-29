import CoreBluetooth
import os

/// Connection state for an individual collar
enum CollarConnectionState: String, Sendable {
    case disconnected = "Disconnected"
    case connecting   = "Connecting..."
    case connected    = "Discovering..."
    case ready        = "Ready"
}

/// Discovered GATT service with its characteristics
struct DiscoveredService: Identifiable, Sendable {
    let id: String
    let service: CBService
    let characteristics: [CBCharacteristic]

    init(service: CBService, characteristics: [CBCharacteristic] = []) {
        self.id = service.uuid.uuidString
        self.service = service
        self.characteristics = characteristics
    }
}

/// Manages BLE connections to multiple collar peripherals simultaneously.
///
/// Each collar is a separate CBPeripheral. Commands are routed by peripheral UUID,
/// making it physically impossible to send a command to the wrong collar.
@MainActor
final class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    // MARK: - Published State

    /// Connection state per paired collar (keyed by CBPeripheral.identifier)
    @Published var collarStates: [UUID: CollarConnectionState] = [:]

    /// Peripherals discovered during scanning
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []

    /// Whether currently scanning
    @Published var isScanning = false

    /// GATT services discovered on a peripheral being explored (for pairing flow)
    @Published var exploredServices: [DiscoveredService] = []

    // MARK: - Private State

    private var centralManager: CBCentralManager!

    /// Connected peripherals, keyed by their stable identifier
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]

    /// The command characteristic for each collar
    private var commandCharacteristics: [UUID: CBCharacteristic] = [:]

    /// Collar profiles for each paired collar
    private var collarProfiles: [UUID: CollarProfile] = [:]

    /// Peripherals to auto-reconnect (deliberately paired ones)
    private var autoReconnectSet: Set<UUID> = []

    /// Reconnect attempt counts
    private var reconnectAttempts: [UUID: Int] = [:]

    /// Peripheral being explored during pairing (temporary)
    private var exploringPeripheral: CBPeripheral?

    /// Callback when exploration completes service/char discovery
    var onExplorationComplete: (() -> Void)?

    private let logger = Logger(subsystem: "com.collarcontrol", category: "BLE")

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    /// Start scanning for BLE peripherals (scans for ALL devices)
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals = []
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        logger.info("Started scanning for collars")

        // Auto-stop after timeout
        Task {
            try? await Task.sleep(for: .seconds(BLEConstants.scanTimeout))
            if isScanning { stopScanning() }
        }
    }

    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        logger.info("Stopped scanning")
    }

    // MARK: - Connection

    /// Connect to a peripheral for exploration (pairing flow)
    func connectForExploration(_ peripheral: CBPeripheral) {
        exploringPeripheral = peripheral
        exploredServices = []
        peripheral.delegate = self
        collarStates[peripheral.identifier] = .connecting
        centralManager.connect(peripheral, options: nil)
        logger.info("Connecting to \(peripheral.name ?? "unknown") for exploration")
    }

    /// Pair a collar to a dog using a discovered profile
    func pairCollar(peripheralUUID: UUID, profile: CollarProfile) {
        collarProfiles[peripheralUUID] = profile
        autoReconnectSet.insert(peripheralUUID)

        // If already connected from exploration, set up the command characteristic
        if let peripheral = connectedPeripherals[peripheralUUID] {
            setupCommandCharacteristic(for: peripheral, profile: profile)
        }

        logger.info("Paired collar \(peripheralUUID) with profile \(profile.name)")
    }

    /// Connect to a previously paired collar
    func connectPairedCollar(peripheralUUID: UUID) {
        // We need to scan to rediscover the peripheral
        guard centralManager.state == .poweredOn else { return }

        collarStates[peripheralUUID] = .connecting
        autoReconnectSet.insert(peripheralUUID)

        // Start scanning to find this peripheral
        if !isScanning {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    /// Connect all paired collars from stored dog profiles
    func connectAllPairedCollars(dogs: [Dog]) {
        for dog in dogs {
            guard let uuid = dog.peripheralUUID,
                  let profileID = dog.collarProfileID else { continue }

            // Load profile
            if collarProfiles[uuid] == nil {
                if let profile = loadProfile(id: profileID) {
                    collarProfiles[uuid] = profile
                }
            }

            autoReconnectSet.insert(uuid)
            if collarStates[uuid] != .ready {
                collarStates[uuid] = .disconnected
                connectPairedCollar(peripheralUUID: uuid)
            }
        }
    }

    /// Disconnect a specific collar
    func disconnectCollar(peripheralUUID: UUID) {
        autoReconnectSet.remove(peripheralUUID)
        if let peripheral = connectedPeripherals[peripheralUUID] {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        collarStates[peripheralUUID] = .disconnected
    }

    /// Disconnect the exploring peripheral
    func disconnectExploring() {
        if let peripheral = exploringPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            exploringPeripheral = nil
        }
    }

    // MARK: - Commands

    /// Send a command to a specific collar by its peripheral UUID.
    /// This is the core safety function - commands are routed by UUID to the exact physical device.
    func sendCommand(to peripheralUUID: UUID, type: CommandType, level: UInt8) {
        guard let peripheral = connectedPeripherals[peripheralUUID],
              let characteristic = commandCharacteristics[peripheralUUID],
              let profile = collarProfiles[peripheralUUID] else {
            logger.warning("Cannot send command: collar \(peripheralUUID) not ready")
            return
        }

        let data = profile.encodeCommand(type: type, level: level)
        peripheral.writeValue(data, for: characteristic, type: profile.cbWriteType)
        logger.info("Sent \(type.label) level=\(level) to collar \(peripheralUUID)")
    }

    /// Send stimulation to a specific collar
    func sendStimulation(to peripheralUUID: UUID, level: Int) {
        sendCommand(to: peripheralUUID, type: .stimulation, level: UInt8(min(max(level, 0), 100)))
    }

    /// Send vibration to a specific collar
    func sendVibration(to peripheralUUID: UUID) {
        sendCommand(to: peripheralUUID, type: .vibration, level: 1)
    }

    /// Send tone to a specific collar
    func sendTone(to peripheralUUID: UUID) {
        sendCommand(to: peripheralUUID, type: .tone, level: 1)
    }

    /// Test write to a specific characteristic (for pairing exploration)
    func testWrite(to peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
        logger.info("Test write to \(characteristic.uuid): \(data.map { String(format: "%02X", $0) }.joined())")
    }

    // MARK: - State Queries

    /// Check if a specific collar is ready to receive commands
    func isCollarReady(_ peripheralUUID: UUID?) -> Bool {
        guard let uuid = peripheralUUID else { return false }
        return collarStates[uuid] == .ready
    }

    /// Get connection state for a specific collar
    func connectionState(for peripheralUUID: UUID?) -> CollarConnectionState {
        guard let uuid = peripheralUUID else { return .disconnected }
        return collarStates[uuid] ?? .disconnected
    }

    // MARK: - Private Helpers

    private func setupCommandCharacteristic(for peripheral: CBPeripheral, profile: CollarProfile) {
        // Find the characteristic matching the profile
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == profile.cbCommandServiceUUID {
            if let chars = service.characteristics {
                for char in chars where char.uuid == profile.cbCommandCharUUID {
                    commandCharacteristics[peripheral.identifier] = char
                    collarStates[peripheral.identifier] = .ready
                    logger.info("Collar \(peripheral.identifier) is ready")
                    return
                }
            }
            // Need to discover characteristics for this service
            peripheral.discoverCharacteristics([profile.cbCommandCharUUID], for: service)
            return
        }
        // Service not yet discovered
        peripheral.discoverServices([profile.cbCommandServiceUUID])
    }

    private func loadProfile(id: String) -> CollarProfile? {
        // Check built-in profiles
        if let profile = CollarProfile.knownProfiles.first(where: { $0.id == id }) {
            return profile
        }
        // Check saved custom profiles
        if let data = UserDefaults.standard.data(forKey: "collar_profile_\(id)"),
           let profile = try? JSONDecoder().decode(CollarProfile.self, from: data) {
            return profile
        }
        return nil
    }

    func saveCustomProfile(_ profile: CollarProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "collar_profile_\(profile.id)")
        }
    }

    private func attemptReconnect(peripheralUUID: UUID) {
        let attempts = reconnectAttempts[peripheralUUID] ?? 0
        guard attempts < BLEConstants.maxReconnectAttempts else {
            collarStates[peripheralUUID] = .disconnected
            reconnectAttempts[peripheralUUID] = 0
            return
        }
        reconnectAttempts[peripheralUUID] = attempts + 1

        Task {
            try? await Task.sleep(for: .seconds(BLEConstants.reconnectDelay))
            connectPairedCollar(peripheralUUID: peripheralUUID)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                logger.info("Bluetooth powered on")
                // Re-connect any paired collars
                for uuid in autoReconnectSet {
                    connectPairedCollar(peripheralUUID: uuid)
                }
            case .poweredOff:
                for uuid in connectedPeripherals.keys {
                    collarStates[uuid] = .disconnected
                }
                connectedPeripherals.removeAll()
                commandCharacteristics.removeAll()
                isScanning = false
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let rssiValue = RSSI.intValue
            guard rssiValue >= BLEConstants.minimumRSSI, rssiValue != 127 else { return }

            // Check if this is a paired collar we're trying to reconnect
            if autoReconnectSet.contains(peripheral.identifier),
               collarStates[peripheral.identifier] == .connecting {
                peripheral.delegate = self
                centralManager.connect(peripheral, options: nil)
                return
            }

            // Add to discovered list for scanner UI
            if !discoveredPeripherals.contains(where: { $0.id == peripheral.identifier }) {
                let discovered = DiscoveredPeripheral(peripheral: peripheral, rssi: rssiValue)
                discoveredPeripherals.append(discovered)
                // Sort by signal strength
                discoveredPeripherals.sort { $0.rssi > $1.rssi }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            logger.info("Connected to \(peripheral.name ?? "unknown")")
            connectedPeripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            reconnectAttempts[peripheral.identifier] = 0

            if peripheral.identifier == exploringPeripheral?.identifier {
                // Exploration mode: discover ALL services
                collarStates[peripheral.identifier] = .connected
                peripheral.discoverServices(nil)
            } else if let profile = collarProfiles[peripheral.identifier] {
                // Paired collar: discover the specific service we need
                collarStates[peripheral.identifier] = .connected
                peripheral.discoverServices([profile.cbCommandServiceUUID])
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            logger.info("Disconnected from \(peripheral.name ?? "unknown")")
            let uuid = peripheral.identifier
            connectedPeripherals.removeValue(forKey: uuid)
            commandCharacteristics.removeValue(forKey: uuid)
            collarStates[uuid] = .disconnected

            if uuid == exploringPeripheral?.identifier {
                exploringPeripheral = nil
                exploredServices = []
            }

            // Auto-reconnect if this was a paired collar
            if autoReconnectSet.contains(uuid) {
                attemptReconnect(peripheralUUID: uuid)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            logger.error("Failed to connect: \(error?.localizedDescription ?? "unknown")")
            collarStates[peripheral.identifier] = .disconnected

            if autoReconnectSet.contains(peripheral.identifier) {
                attemptReconnect(peripheralUUID: peripheral.identifier)
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let services = peripheral.services else { return }

            if peripheral.identifier == exploringPeripheral?.identifier {
                // Exploration mode: discover ALL characteristics for each service
                exploredServices = services.map { DiscoveredService(service: $0) }
                for service in services {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            } else if let profile = collarProfiles[peripheral.identifier] {
                // Paired collar: find our service and discover its characteristics
                for service in services where service.uuid == profile.cbCommandServiceUUID {
                    peripheral.discoverCharacteristics([profile.cbCommandCharUUID], for: service)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard let characteristics = service.characteristics else { return }

            if peripheral.identifier == exploringPeripheral?.identifier {
                // Update explored services with discovered characteristics
                if let idx = exploredServices.firstIndex(where: { $0.service.uuid == service.uuid }) {
                    exploredServices[idx] = DiscoveredService(service: service, characteristics: characteristics)
                }
                // Check if all services have been explored
                let allExplored = exploredServices.allSatisfy { !$0.characteristics.isEmpty }
                if allExplored {
                    // Try auto-matching a known profile
                    for profile in CollarProfile.knownProfiles {
                        if profile.matches(services: peripheral.services ?? []) {
                            logger.info("Auto-matched profile: \(profile.name)")
                        }
                    }
                    onExplorationComplete?()
                }
            } else if let profile = collarProfiles[peripheral.identifier] {
                // Paired collar: find the command characteristic
                for char in characteristics where char.uuid == profile.cbCommandCharUUID {
                    commandCharacteristics[peripheral.identifier] = char
                    collarStates[peripheral.identifier] = .ready
                    logger.info("Collar \(peripheral.identifier) is ready")
                }
            }
        }
    }
}
