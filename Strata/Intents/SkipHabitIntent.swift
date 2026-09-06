import AppIntents
import SwiftUI
import SwiftData

struct SkipHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Habit"
    static var description = IntentDescription("Skip a habit for today.")
    static var openAppWhenRun = false

    @Parameter(title: "Habit")
    var habit: HabitEntity

    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView & ProvidesDialog {
        let context = ModelContext(modelContainer)
        let habitID = habit.id
        let todayStr = DateUtils.dateString(from: Date())

        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habitModel = try context.fetch(descriptor).first else {
            return .result(dialog: "Couldn't find that habit.") {
                IntentErrorSnippet(message: "Habit not found")
            }
        }

        // Create or update log with skipped = true
        if let existing = habitModel.logs.first(where: { $0.dateString == todayStr }) {
            existing.skipped = true
        } else {
            let log = HabitLog(habit: habitModel, dateString: todayStr)
            log.skipped = true
            context.insert(log)
        }
        try context.save()

        return .result(dialog: "Skipped \(habitModel.title) for today.") {
            HabitSkipSnippet(title: habitModel.title, category: habitModel.category.rawValue)
        }
    }
}
