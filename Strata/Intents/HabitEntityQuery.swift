import AppIntents
import SwiftData

struct HabitEntityQuery: EntityQuery {
    @Dependency private var modelContainer: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        try await MainActor.run { try StoreUnavailableIntentError.check() }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>()
        let habits = (try? context.fetch(descriptor)) ?? []
        let idSet = Set(identifiers)
        let todayStr = Self.todayString()
        return habits.filter { idSet.contains($0.id) }.map { Self.toEntity($0, todayStr: todayStr) }
    }

    /// The most recent wins, for a picker in Shortcuts.
    ///
    /// It suggested habits scheduled for today, and nothing in the app has
    /// created a scheduled habit since the tower became the record of the day,
    /// so the picker was always empty.
    func suggestedEntities() async throws -> [HabitEntity] {
        try await MainActor.run { try StoreUnavailableIntentError.check() }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>()
        let habits = (try? context.fetch(descriptor)) ?? []
        let todayStr = Self.todayString()
        func latest(_ habit: Habit) -> Date {
            (habit.logs ?? []).compactMap(\.completedAt).max() ?? .distantPast
        }
        return habits
            .filter { $0.title != QuickWinService.untitled }
            .sorted { latest($0) > latest($1) }
            .prefix(20)
            .map { Self.toEntity($0, todayStr: todayStr) }
    }

    private static func toEntity(_ habit: Habit, todayStr: String) -> HabitEntity {
        let completed = (habit.logs ?? []).contains { $0.dateString == todayStr && $0.completed }
        return HabitEntity(id: habit.id, title: habit.title, category: habit.category.rawValue, isCompletedToday: completed)
    }

    private static func todayString() -> String {
        DateUtils.dateString(from: Date())
    }
}
