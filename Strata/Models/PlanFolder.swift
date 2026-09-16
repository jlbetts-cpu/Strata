import Foundation
import SwiftUI
import SwiftData

@Model
final class PlanFolder {
    // Six of these carried no default. See the note at the top of `Habit`:
    // CloudKit's mirroring refuses a non-optional attribute with nothing to
    // fall back on, a default is not part of the version hash, and the
    // initialiser still assigns all six, so nothing moves. Each default here
    // is the initialiser's own default value.
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder.fill"
    var colorHex: String = "#8E8E93"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Habit.planFolder)
    var habits: [Habit] = []

    init(name: String, icon: String = "folder.fill", colorHex: String = "#8E8E93", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    /// Resolved SwiftUI Color from hex string
    var color: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = UInt64(hex, radix: 16) else { return .secondary }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
