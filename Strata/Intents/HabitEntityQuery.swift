import AppIntents
import SwiftData

struct HabitEntityQuery: EntityQuery {
    @Dependency private var modelContainer: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>()
        let habits = (try? context.fetch(descriptor)) ?? []
        let idSet = Set(identifiers)
        let todayStr = Self.todayString()
        return habits.filter { idSet.contains($0.id) }.map { Self.toEntity($0, todayStr: todayStr) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>()
        let habits = (try? context.fetch(descriptor)) ?? []
        let todayStr = Self.todayString()
        let today = DayCode.today()
        return habits
            .filter { !$0.isTodo && $0.frequency.contains(today) }
            .map { Self.toEntity($0, todayStr: todayStr) }
    }

    private static func toEntity(_ habit: Habit, todayStr: String) -> HabitEntity {
        let completed = habit.logs.contains { $0.dateString == todayStr && $0.completed }
        return HabitEntity(id: habit.id, title: habit.title, category: habit.category.rawValue, isCompletedToday: completed)
    }

    private static func todayString() -> String {
        DateUtils.dateString(from: Date())
    }
}
