import Foundation
import SwiftData

@Model
final class Tower {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var createdAt: Date
    var order: Int

    @Relationship(deleteRule: .nullify, inverse: \Habit.tower)
    var habits: [Habit] = []

    init(name: String = "Untitled Tower", emoji: String = "🏗️", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.createdAt = Date()
        self.order = order
    }
}
