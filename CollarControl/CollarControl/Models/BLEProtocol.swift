import CoreBluetooth

/// BLE scanning and connection constants.
enum BLEConstants {
    /// How long to scan before stopping (seconds)
    static let scanTimeout: TimeInterval = 15

    /// Minimum RSSI to display a peripheral in scan results
    static let minimumRSSI: Int = -90

    /// Delay before auto-reconnect attempt (seconds)
    static let reconnectDelay: TimeInterval = 2

    /// Maximum auto-reconnect attempts
    static let maxReconnectAttempts = 5
}
