import Foundation

/// Types of commands that can be sent to a collar
enum CommandType: UInt8, CaseIterable, Sendable {
    case stimulation = 0x01
    case vibration   = 0x02
    case tone        = 0x03

    var label: String {
        switch self {
        case .stimulation: return "Stim"
        case .vibration:   return "Vibrate"
        case .tone:        return "Tone"
        }
    }

    var systemImage: String {
        switch self {
        case .stimulation: return "bolt.fill"
        case .vibration:   return "iphone.radiowaves.left.and.right"
        case .tone:        return "speaker.wave.2.fill"
        }
    }
}

/// A command packet to send to the ESP32 bridge.
///
/// Packet format (6 bytes):
/// ```
/// [0] Collar ID     (0-15)
/// [1] Command type   (0x01=stim, 0x02=vibrate, 0x03=tone)
/// [2] Level          (0-100 for stim, 0/1 for vibrate/tone)
/// [3] Duration       (tenths of second, 1-50)
/// [4-5] CRC-16       (CCITT over bytes 0-3)
/// ```
struct CollarCommand: Sendable {
    let collarID: UInt8
    let type: CommandType
    let level: UInt8
    let duration: UInt8

    /// Encode this command into a 6-byte Data packet for BLE transmission.
    func encode() -> Data {
        var bytes: [UInt8] = [
            collarID,
            type.rawValue,
            level,
            duration
        ]
        let crc = Self.crc16(bytes)
        bytes.append(UInt8(crc >> 8))
        bytes.append(UInt8(crc & 0xFF))
        return Data(bytes)
    }

    /// CRC-16/CCITT (polynomial 0x1021, init 0xFFFF)
    static func crc16(_ data: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc = crc << 1
                }
            }
        }
        return crc
    }
}
