import Foundation
import SwiftUI

/// A dog profile with an assigned collar channel.
struct Dog: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var collarID: Int
    var defaultStimLevel: Int
    var colorName: String

    init(id: UUID = UUID(), name: String, collarID: Int, defaultStimLevel: Int = 10, colorName: String = "blue") {
        self.id = id
        self.name = name
        self.collarID = collarID
        self.defaultStimLevel = defaultStimLevel
        self.colorName = colorName
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
