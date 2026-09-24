import Foundation

enum CategorySuggestionEngine {

    private static let keywordMap: [(HabitCategory, [String])] = [
        (.health, ["run", "exercise", "gym", "water", "walk", "stretch", "yoga", "sleep", "workout", "pushup", "plank", "swim", "bike", "jog", "hike", "health", "cardio", "lift", "squat", "abs"]),
        (.work, ["work", "meeting", "email", "report", "project", "code", "review", "standup", "deadline", "invoice", "task", "present", "ship"]),
        (.creativity, ["draw", "write", "paint", "sketch", "design", "music", "create", "art", "blog", "photo", "craft", "compose", "sing", "play", "guitar", "piano"]),
        (.focus, ["read", "study", "learn", "focus", "research", "book", "practice", "deep", "course", "lesson", "review"]),
        (.social, ["call", "friend", "family", "dinner", "lunch", "coffee", "hangout", "text", "date", "party", "visit", "chat"]),
        (.mindfulness, ["meditate", "journal", "breathe", "reflect", "gratitude", "pray", "mindful", "calm", "relax", "silence", "quiet"]),
    ]

    // No size keywords. `suggestSize` guessed a block size from words like
    // "gym" or "quick" and had no caller: the size is drawn by hand, by
    // dragging the slot out, which is the one thing about a win the person
    // says with a gesture rather than with words.

    /// Suggests a category by matching any word in the title against keywords.
    /// Uses substring matching so "running" matches "run".
    static func suggest(for title: String) -> HabitCategory? {
        let words = title.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        for word in words {
            for (category, keywords) in keywordMap {
                for keyword in keywords {
                    if word == keyword || word.hasPrefix(keyword) {
                        return category
                    }
                }
            }
        }
        return nil
    }

}
