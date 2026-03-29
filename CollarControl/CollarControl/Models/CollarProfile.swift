import CoreBluetooth
import Foundation

/// Defines how to communicate with a specific type of BLE collar.
/// Known profiles are built-in; users can also create custom profiles
/// by exploring a collar's GATT characteristics.
struct CollarProfile: Codable, Identifiable, Sendable {
    let id: String
    let name: String

    /// The service UUID that contains the command characteristic
    let commandServiceUUID: String
    /// The characteristic UUID to write commands to
    let commandCharacteristicUUID: String
    /// Whether to use write-with-response or write-without-response
    let writeWithResponse: Bool

    /// Command byte sequences for each command type.
    /// These are hex-encoded strings. If empty, the profile uses level-based encoding.
    let stimPrefix: [UInt8]
    let vibratePrefix: [UInt8]
    let tonePrefix: [UInt8]

    /// How to encode the level into the command payload
    let encodingStyle: EncodingStyle

    enum EncodingStyle: String, Codable, Sendable {
        case prefixPlusLevel   // [prefix bytes] + [level byte]
        case singleByte        // [command_byte, level_byte]
        case raw               // user-defined raw bytes only (no level)
    }

    var cbCommandServiceUUID: CBUUID {
        CBUUID(string: commandServiceUUID)
    }

    var cbCommandCharUUID: CBUUID {
        CBUUID(string: commandCharacteristicUUID)
    }

    var cbWriteType: CBCharacteristicWriteType {
        writeWithResponse ? .withResponse : .withoutResponse
    }

    /// Encode a command for this collar profile
    func encodeCommand(type: CommandType, level: UInt8) -> Data {
        let prefix: [UInt8]
        switch type {
        case .stimulation: prefix = stimPrefix
        case .vibration:   prefix = vibratePrefix
        case .tone:        prefix = tonePrefix
        }

        switch encodingStyle {
        case .prefixPlusLevel:
            return Data(prefix + [level])
        case .singleByte:
            return Data(prefix + [level])
        case .raw:
            return Data(prefix)
        }
    }

    /// Check if a discovered service matches this profile
    func matches(services: [CBService]) -> Bool {
        services.contains { $0.uuid == cbCommandServiceUUID }
    }
}

// MARK: - Built-in Profiles

extension CollarProfile {
    /// Known collar profiles. These will be matched automatically during pairing.
    static let knownProfiles: [CollarProfile] = [
        // Generic BLE training collar (common Chinese-made collars)
        // Many use a similar protocol with service FFE0 and characteristic FFE1
        CollarProfile(
            id: "generic-ffe0",
            name: "Generic BLE Collar (FFE0)",
            commandServiceUUID: "FFE0",
            commandCharacteristicUUID: "FFE1",
            writeWithResponse: false,
            stimPrefix: [0x01],
            vibratePrefix: [0x02],
            tonePrefix: [0x03],
            encodingStyle: .prefixPlusLevel
        ),

        // Alternative generic profile (some collars use FFF0/FFF1)
        CollarProfile(
            id: "generic-fff0",
            name: "Generic BLE Collar (FFF0)",
            commandServiceUUID: "FFF0",
            commandCharacteristicUUID: "FFF1",
            writeWithResponse: false,
            stimPrefix: [0x01],
            vibratePrefix: [0x02],
            tonePrefix: [0x03],
            encodingStyle: .prefixPlusLevel
        ),
    ]

    /// Create a custom profile from user-discovered characteristics
    static func custom(
        serviceUUID: String,
        characteristicUUID: String,
        writeWithResponse: Bool
    ) -> CollarProfile {
        CollarProfile(
            id: "custom-\(UUID().uuidString.prefix(8))",
            name: "Custom Profile",
            commandServiceUUID: serviceUUID,
            commandCharacteristicUUID: characteristicUUID,
            writeWithResponse: writeWithResponse,
            stimPrefix: [0x01],
            vibratePrefix: [0x02],
            tonePrefix: [0x03],
            encodingStyle: .prefixPlusLevel
        )
    }
}
