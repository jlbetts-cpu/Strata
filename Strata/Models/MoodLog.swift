import Foundation
import SwiftData

@Model
final class MoodLog {
    @Attribute(.unique) var id: UUID
    var dateString: String // YYYY-MM-DD format
    var mood: Int          // 1-5 (1=awful, 5=great)
    var motivation: Int    // 1-5
    var note: String?
    var imageURL: String?
    var videoURL: String?

    init(
        dateString: String,
        mood: Int,
        motivation: Int,
        note: String? = nil
    ) {
        self.id = UUID()
        self.dateString = dateString
        self.mood = min(max(mood, 1), 5)
        self.motivation = min(max(motivation, 1), 5)
        self.note = note
    }
}
