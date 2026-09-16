import Foundation
import SwiftData

@Model
final class Tower {
    // Five of these carried no default. See the note at the top of `Habit`:
    // CloudKit's mirroring refuses a non-optional attribute with nothing to
    // fall back on, a default is not part of the version hash, and the
    // initialiser still assigns all five, so nothing moves. Each default here
    // is the initialiser's own default value.
    var id: UUID = UUID()
    var name: String = "Untitled Tower"
    var emoji: String = "🏗️"
    var createdAt: Date = Date()
    var order: Int = 0
    /// Stamped on every save by `StoreStamp`. See `Habit.updatedAt`.
    var updatedAt: Date = Date()

    /// To-many, with an inverse, and `.nullify` rather than `.deny`. That is
    /// already what CloudKit requires of a relationship, so it does not
    /// change.
    @Relationship(deleteRule: .nullify, inverse: \Habit.tower)
    /// Optional for CloudKit's rule on relationships. See `Habit.logs`.
    var habits: [Habit]? = []

    init(name: String = "Untitled Tower", emoji: String = "🏗️", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.createdAt = Date()
        self.order = order
    }
}
