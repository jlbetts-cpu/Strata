import AppIntents
import SwiftUI
import SwiftData

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as completed for today.")
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

        // Check if already completed
        if habitModel.logs.contains(where: { $0.dateString == todayStr && $0.completed }) {
            return .result(dialog: "\(habitModel.title) is already done today!") {
                HabitCompletionSnippet(title: habitModel.title, category: habitModel.category.rawValue, alreadyDone: true)
            }
        }

        // Create or update log
        if let existing = habitModel.logs.first(where: { $0.dateString == todayStr }) {
            existing.completed = true
            existing.completedAt = Date()
        } else {
            let log = HabitLog(habit: habitModel, dateString: todayStr, completed: true)
            log.completedAt = Date()
            context.insert(log)
        }
        try context.save()

        return .result(dialog: "Done! \(habitModel.title) completed.") {
            HabitCompletionSnippet(title: habitModel.title, category: habitModel.category.rawValue, alreadyDone: false)
        }
    }
}
