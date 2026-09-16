import Foundation
import SwiftData

@Model
final class MoodLog {
    // Four of these carried no default. See the note at the top of `Habit`:
    // CloudKit's mirroring refuses a non-optional attribute with nothing to
    // fall back on, a default is not part of the version hash, and the
    // initialiser still assigns all four, so nothing moves.
    var id: UUID = UUID()
    var dateString: String = "" // YYYY-MM-DD format
    /// 3, the middle of the scale, because a mood with no value in it is not
    /// an awful one. The initialiser clamps and assigns, so nothing reads it.
    var mood: Int = 3          // 1-5 (1=awful, 5=great)
    var motivation: Int = 3    // 1-5
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
