import CoreBluetooth

/// BLE protocol constants shared between the iOS app and ESP32 firmware.
/// The ESP32 acts as a BLE peripheral (GATT server) and the iPhone connects as a central.
enum BLEProtocol {
    /// Service UUID for the collar control service
    static let serviceUUID = CBUUID(string: "0000CC01-0000-1000-8000-00805F9B34FB")

    /// Characteristic for sending commands (phone -> ESP32). Write without response.
    static let commandCharacteristicUUID = CBUUID(string: "0000CC02-0000-1000-8000-00805F9B34FB")

    /// Characteristic for receiving status updates (ESP32 -> phone). Notify.
    static let statusCharacteristicUUID = CBUUID(string: "0000CC03-0000-1000-8000-00805F9B34FB")

    /// Name the ESP32 advertises as
    static let peripheralName = "CollarBridge"

    /// Maximum supported collar IDs (0-15)
    static let maxCollarID: UInt8 = 15
}
