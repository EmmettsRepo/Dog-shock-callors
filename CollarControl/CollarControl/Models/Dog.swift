import Foundation
import SwiftUI

/// A dog profile with a paired BLE collar.
struct Dog: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// The CBPeripheral.identifier UUID of the paired collar. Nil if not yet paired.
    var peripheralUUID: UUID?
    /// The collar profile ID used to encode commands for this collar.
    var collarProfileID: String?
    var defaultStimLevel: Int
    var colorName: String

    init(id: UUID = UUID(), name: String, peripheralUUID: UUID? = nil, collarProfileID: String? = nil, defaultStimLevel: Int = 10, colorName: String = "blue") {
        self.id = id
        self.name = name
        self.peripheralUUID = peripheralUUID
        self.collarProfileID = collarProfileID
        self.defaultStimLevel = defaultStimLevel
        self.colorName = colorName
    }

    var isPaired: Bool {
        peripheralUUID != nil && collarProfileID != nil
    }

    var color: Color {
        switch colorName {
        case "red":    return .red
        case "green":  return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink":   return .pink
        default:       return .blue
        }
    }

    static let availableColors = ["blue", "red", "green", "orange", "purple", "yellow", "pink"]
}
