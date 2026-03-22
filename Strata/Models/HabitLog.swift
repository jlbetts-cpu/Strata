import Foundation
import SwiftData

@Model
final class HabitLog {
    @Attribute(.unique) var id: UUID
    var habit: Habit?
    var dateString: String // YYYY-MM-DD format for easy lookup
    var completed: Bool
    var completedAt: Date?
    var note: String?
    var caption: String
    @Attribute(.externalStorage) var imageData: Data? // Retained temporarily for migration
    var imageFileName: String?
    var imageURL: String?       // Deprecated — retained for schema compatibility
    var videoURL: String?       // Deprecated — retained for schema compatibility
    var imageFlipped: Bool = false  // Deprecated — retained for schema compatibility
    var cropPositionX: Double?  // Deprecated — retained for schema compatibility
    var cropPositionY: Double?  // Deprecated — retained for schema compatibility
    var surgeMode: Bool
    var pendingXP: Int?
    var xpCollected: Bool
    var isBonusBlock: Bool
    var skipped: Bool = false

    init(
        habit: Habit,
        dateString: String,
        completed: Bool = false
    ) {
        self.id = UUID()
        self.habit = habit
        self.dateString = dateString
        self.completed = completed
        self.completedAt = completed ? Date() : nil
        self.caption = ""
        self.surgeMode = false
        self.xpCollected = false
        self.isBonusBlock = false
        self.skipped = false
    }

    func markCompleted() {
        completed = true
        completedAt = Date()

        // 5% chance for bonus block
        let isBonus = Double.random(in: 0...1) < 0.05
        isBonusBlock = isBonus
        pendingXP = isBonus ? Int.random(in: 50...100) : Int.random(in: 5...25)
    }

    func markIncomplete() {
        completed = false
        completedAt = nil
        // Preserve pendingXP so it doesn't re-roll on undo/redo
        xpCollected = false
        isBonusBlock = false
    }

    func collectXP() {
        xpCollected = true
    }
}
