import AppIntents
import SwiftUI
import SwiftData

struct ShowTodaysHabitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Today's Habits"
    static var description = IntentDescription("See your habits for today.")
    static var openAppWhenRun = false

    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView & ProvidesDialog {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>()
        let habits = (try? context.fetch(descriptor)) ?? []
        let today = DayCode.today()
        let todayStr = DateUtils.dateString(from: Date())

        let todaysHabits = habits.filter { !$0.isTodo && $0.frequency.contains(today) }
        let snippetData = todaysHabits.map { habit in
            let done = habit.logs.contains { $0.dateString == todayStr && $0.completed }
            return (title: habit.title, category: habit.category.rawValue, done: done)
        }

        let completedCount = snippetData.filter(\.done).count
        let totalCount = snippetData.count

        if totalCount == 0 {
            return .result(dialog: "No habits scheduled for today.") {
                IntentErrorSnippet(message: "No habits for today")
            }
        }

        let dialog: IntentDialog = if completedCount == totalCount {
            "All \(totalCount) habits done today!"
        } else {
            "\(completedCount) of \(totalCount) habits completed."
        }

        return .result(dialog: dialog) {
            TodaysHabitsSnippet(habits: snippetData)
        }
    }
}
