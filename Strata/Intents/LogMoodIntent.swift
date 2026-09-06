import AppIntents
import SwiftUI
import SwiftData

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var description = IntentDescription("Log your mood in Strata.")
    static var openAppWhenRun = false

    @Parameter(title: "Mood (1-5)")
    var mood: Int

    @Parameter(title: "Motivation (1-5)", default: 3)
    var motivation: Int

    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView & ProvidesDialog {
        let context = ModelContext(modelContainer)
        let todayStr = DateUtils.dateString(from: Date())

        let clampedMood = min(max(mood, 1), 5)
        let clampedMotivation = min(max(motivation, 1), 5)

        // Upsert: update existing or create new
        let descriptor = FetchDescriptor<MoodLog>(predicate: #Predicate { $0.dateString == todayStr })
        if let existing = try context.fetch(descriptor).first {
            existing.mood = clampedMood
            existing.motivation = clampedMotivation
        } else {
            let log = MoodLog(dateString: todayStr, mood: clampedMood, motivation: clampedMotivation)
            context.insert(log)
        }
        try context.save()

        return .result(dialog: "Mood logged: \(clampedMood)/5") {
            MoodLogSnippet(mood: clampedMood, motivation: clampedMotivation)
        }
    }
}
