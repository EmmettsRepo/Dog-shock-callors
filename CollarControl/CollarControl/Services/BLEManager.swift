import CoreBluetooth
import Combine
import os

/// Connection state for the BLE bridge
enum BridgeConnectionState: String {
    case disconnected = "Disconnected"
    case scanning     = "Scanning..."
    case connecting   = "Connecting..."
    case connected    = "Connected"
}

/// Manages the BLE connection to the ESP32 collar bridge.
@MainActor
final class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    @Published var connectionState: BridgeConnectionState = .disconnected
    @Published var lastStatusMessage: String = ""

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var shouldAutoReconnect = true

    private let logger = Logger(subsystem: "com.collarcontrol", category: "BLE")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Start scanning for the ESP32 bridge
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [BLEProtocol.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        logger.info("Started scanning for CollarBridge")
    }

    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    /// Disconnect from the bridge
    func disconnect() {
        shouldAutoReconnect = false
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    /// Send a command to a collar via the ESP32 bridge
    func sendCommand(_ command: CollarCommand) {
        guard connectionState == .connected,
              let characteristic = commandCharacteristic else {
            logger.warning("Cannot send command: not connected")
            return
        }
        let data = command.encode()
        peripheral?.writeValue(data, for: characteristic, type: .withoutResponse)
        logger.info("Sent command: collar=\(command.collarID) type=\(command.type.rawValue) level=\(command.level)")
    }

    /// Send a quick stimulation command
    func sendStimulation(collarID: Int, level: Int, duration: Int = 5) {
        let cmd = CollarCommand(
            collarID: UInt8(collarID),
            type: .stimulation,
            level: UInt8(min(max(level, 0), 100)),
            duration: UInt8(min(max(duration, 1), 50))
        )
        sendCommand(cmd)
    }

    /// Send a vibration command
    func sendVibration(collarID: Int, duration: Int = 10) {
        let cmd = CollarCommand(
            collarID: UInt8(collarID),
            type: .vibration,
            level: 1,
            duration: UInt8(min(max(duration, 1), 50))
        )
        sendCommand(cmd)
    }

    /// Send a tone command
    func sendTone(collarID: Int, duration: Int = 10) {
        let cmd = CollarCommand(
            collarID: UInt8(collarID),
            type: .tone,
            level: 1,
            duration: UInt8(min(max(duration, 1), 50))
        )
        sendCommand(cmd)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                logger.info("Bluetooth powered on")
                startScanning()
            case .poweredOff:
                connectionState = .disconnected
                logger.warning("Bluetooth powered off")
            case .unauthorized:
                connectionState = .disconnected
                logger.error("Bluetooth unauthorized")
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            logger.info("Discovered peripheral: \(peripheral.name ?? "unknown")")
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            centralManager.stopScan()
            connectionState = .connecting
            centralManager.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            logger.info("Connected to \(peripheral.name ?? "unknown")")
            connectionState = .connected
            peripheral.discoverServices([BLEProtocol.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            logger.info("Disconnected from peripheral")
            connectionState = .disconnected
            commandCharacteristic = nil
            statusCharacteristic = nil

            if shouldAutoReconnect {
                // Auto-reconnect after a short delay
                try? await Task.sleep(for: .seconds(2))
                startScanning()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            logger.error("Failed to connect: \(error?.localizedDescription ?? "unknown")")
            connectionState = .disconnected
            // Retry scanning
            try? await Task.sleep(for: .seconds(2))
            startScanning()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let service = peripheral.services?.first(where: { $0.uuid == BLEProtocol.serviceUUID }) else { return }
            peripheral.discoverCharacteristics(
                [BLEProtocol.commandCharacteristicUUID, BLEProtocol.statusCharacteristicUUID],
                for: service
            )
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard let characteristics = service.characteristics else { return }
            for characteristic in characteristics {
                switch characteristic.uuid {
                case BLEProtocol.commandCharacteristicUUID:
                    commandCharacteristic = characteristic
                    logger.info("Found command characteristic")
                case BLEProtocol.statusCharacteristicUUID:
                    statusCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    logger.info("Subscribed to status characteristic")
                default:
                    break
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard characteristic.uuid == BLEProtocol.statusCharacteristicUUID,
                  let data = characteristic.value,
                  let message = String(data: data, encoding: .utf8) else { return }
            lastStatusMessage = message
            logger.info("Status: \(message)")
        }
    }
}
