import CoreSpotlight
import SwiftData
import AppIntents

enum SpotlightIndexer {
    /// The day the whole list was last indexed.
    nonisolated static let fullDayKey = "spotlight.fullIndexDay"

    /// **Everything at most once a day, today's wins otherwise** (2026-10-08,
    /// the scale audit). Every win is its own `Habit`, so a new win changed the
    /// count and indexed EVERY win ever logged, faulting in all their logs;
    /// so did every return to the app and, twice, every launch. After a year
    /// that is thousands of records for one new block. The whole list now goes
    /// once a day (what refreshes yesterday's "done today"), and in between
    /// only the wins logged today, which is where anything changes.
    static func reindex(container: ModelContainer) {
        let today = DateUtils.dateString(from: Date())
        guard UserDefaults.standard.string(forKey: fullDayKey) != today else {
            indexToday(container: container)
            return
        }
        UserDefaults.standard.set(today, forKey: fullDayKey)
        // **`.background`, after the first two seconds** (2026-10-02, the
        // motion pass). At `.utility` it started with the first frame and ran
        // beside the person's first taps; sampled cold, it was the busiest
        // thing in the process while the first sheet opened. Search results
        // that are two seconds late cost nobody anything.
        Task.detached(priority: .background) {
            try? await Task.sleep(for: .seconds(2))
            let context = ModelContext(container)
            guard let habits = try? context.fetch(FetchDescriptor<Habit>()) else { return }
            let entities = habits.filter(Self.isSearchable).map { entity($0, today: today) }
            try? await CSSearchableIndex.default().indexAppEntities(entities)
        }
    }

    /// Only the wins logged today: after a new win, or a return to the app on
    /// a day already indexed in full.
    static func indexToday(container: ModelContainer) {
        let today = DateUtils.dateString(from: Date())
        Task.detached(priority: .background) {
            let context = ModelContext(container)
            let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.dateString == today }))) ?? []
            var seen = Set<UUID>()
            let habits = logs.compactMap(\.habit).filter { seen.insert($0.id).inserted }
            let entities = habits.filter(Self.isSearchable).map { entity($0, today: today) }
            guard !entities.isEmpty else { return }
            try? await CSSearchableIndex.default().indexAppEntities(entities)
        }
    }

    /// An untitled win is called "Win": a thousand of those in Spotlight are
    /// noise, never something anyone searches for.
    nonisolated static func isSearchable(_ habit: Habit) -> Bool {
        habit.title != QuickWinService.untitled && !habit.title.isEmpty
    }

    nonisolated private static func entity(_ habit: Habit, today: String) -> HabitEntity {
        let completed = (habit.logs ?? []).contains { $0.dateString == today && $0.completed }
        return HabitEntity(id: habit.id, title: habit.title, category: habit.category.rawValue,
                           isCompletedToday: completed)
    }

    /// Remove deleted habits from Spotlight
    static func remove(habitIDs: [UUID]) {
        Task.detached(priority: .utility) {
            let ids = habitIDs.map(\.uuidString)
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
        }
    }
}
