import CoreSpotlight
import SwiftData
import AppIntents

enum SpotlightIndexer {
    /// Full re-index — call on app launch and after habit create/delete
    static func reindex(container: ModelContainer) {
        Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Habit>()
            guard let habits = try? context.fetch(descriptor) else { return }
            let todayStr = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }()

            let entities = habits.map { habit in
                let completed = habit.logs.contains { $0.dateString == todayStr && $0.completed }
                return HabitEntity(id: habit.id, title: habit.title, category: habit.category.rawValue, isCompletedToday: completed)
            }
            try? await CSSearchableIndex.default().indexAppEntities(entities)
        }
    }

    /// Remove deleted habits from Spotlight
    static func remove(habitIDs: [UUID]) {
        Task.detached(priority: .utility) {
            let ids = habitIDs.map(\.uuidString)
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
        }
    }
}
