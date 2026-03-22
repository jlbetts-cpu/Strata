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

    private static let sizeKeywords: [(BlockSize, [String])] = [
        (.small, ["quick", "water", "stretch", "breathe", "gratitude", "floss", "vitamin"]),
        (.hard, ["gym", "workout", "deep work", "session", "project", "study"]),
    ]

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

    /// Suggests a block size based on title keywords.
    /// Returns nil if no match (caller should use default .small).
    static func suggestSize(for title: String) -> BlockSize? {
        let lowered = title.lowercased()

        // Check multi-word keywords first (e.g. "deep work")
        for (size, keywords) in sizeKeywords {
            for keyword in keywords where keyword.contains(" ") {
                if lowered.contains(keyword) { return size }
            }
        }

        // Then single-word keywords with substring match
        let words = lowered
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        for word in words {
            for (size, keywords) in sizeKeywords {
                for keyword in keywords where !keyword.contains(" ") {
                    if word == keyword || word.hasPrefix(keyword) {
                        return size
                    }
                }
            }
        }
        return nil
    }
}
