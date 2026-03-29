import CoreBluetooth
import Foundation

/// A BLE peripheral discovered during scanning.
struct DiscoveredPeripheral: Identifiable, Sendable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral

    init(peripheral: CBPeripheral, rssi: Int) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
        self.peripheral = peripheral
    }

    /// Signal strength description
    var signalStrength: SignalStrength {
        switch rssi {
        case -50...0:    return .excellent
        case -65..<(-50): return .good
        case -80..<(-65): return .fair
        default:         return .weak
        }
    }

    enum SignalStrength: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case weak = "Weak"

        var bars: Int {
            switch self {
            case .excellent: return 4
            case .good:      return 3
            case .fair:      return 2
            case .weak:      return 1
            }
        }
    }
}
