import Foundation

/// Types of commands that can be sent to a collar
enum CommandType: UInt8, CaseIterable, Sendable, Codable {
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
