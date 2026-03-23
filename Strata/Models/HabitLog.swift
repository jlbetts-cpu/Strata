import Foundation
import SwiftData

struct SubTask: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var completed: Bool = false
}

@Model
final class HabitLog {
    @Attribute(.unique) var id: UUID = UUID()
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
    var subtasks: [SubTask] = []

    var hasDrawerContent: Bool {
        (note != nil && !note!.isEmpty)
        || !caption.isEmpty
        || !subtasks.isEmpty
        || imageFileName != nil
    }

    init(
        habit: Habit,
        dateString: String,
        completed: Bool = false
    ) {
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
    }

    func markIncomplete() {
        completed = false
        completedAt = nil
    }
}
