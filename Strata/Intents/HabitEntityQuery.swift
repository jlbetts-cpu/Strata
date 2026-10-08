import AppIntents
import SwiftData

struct HabitEntityQuery: EntityQuery {
    @Dependency private var modelContainer: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        try await MainActor.run { try StoreUnavailableIntentError.check() }
        let context = ModelContext(modelContainer)
        // By id in the store, not every win fetched and filtered (2026-10-08:
        // every win is its own Habit, so "every win" grows without bound).
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { identifiers.contains($0.id) })
        let habits = (try? context.fetch(descriptor)) ?? []
        let todayStr = Self.todayString()
        return habits.map { Self.toEntity($0, todayStr: todayStr) }
    }

    /// The most recent wins, for a picker in Shortcuts.
    ///
    /// It suggested habits scheduled for today, and nothing in the app has
    /// created a scheduled habit since the tower became the record of the day,
    /// so the picker was always empty.
    func suggestedEntities() async throws -> [HabitEntity] {
        try await MainActor.run { try StoreUnavailableIntentError.check() }
        let context = ModelContext(modelContainer)
        // The latest logs, newest first, rather than every win and every log
        // sorted in memory (2026-10-08). A hundred logs hold twenty titled
        // wins on any real tower.
        var descriptor = FetchDescriptor<HabitLog>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        descriptor.fetchLimit = 100
        let logs = (try? context.fetch(descriptor)) ?? []
        let todayStr = Self.todayString()
        var seen = Set<UUID>()
        return logs.compactMap(\.habit)
            .filter { $0.title != QuickWinService.untitled && seen.insert($0.id).inserted }
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
