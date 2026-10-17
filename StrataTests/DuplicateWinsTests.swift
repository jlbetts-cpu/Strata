import Foundation
import SwiftData
import Testing
@testable import Strata

/// **One win, one row** (the launch pass's rare-bug hunt, 2026-10-16): a
/// restore during an iCloud import landed every win twice.
@MainActor
struct DuplicateWinsTests {
    @Test("twins by id merge: the kind of win keeps every log, the win keeps the twin with its photo")
    func twinsMerge() throws {
        let container = try ModelContainer(for: SharedModelContainer.schema,
                                           configurations: ModelConfiguration(schema: SharedModelContainer.schema, isStoredInMemoryOnly: true))
        let context = container.mainContext
        let habit = Habit(title: "Ran", category: .health)
        let twin = Habit(title: "Ran", category: .health)
        twin.id = habit.id
        context.insert(habit); context.insert(twin)
        let log = HabitLog(habit: habit, dateString: "2026-10-15", completed: true)
        let copy = HabitLog(habit: twin, dateString: "2026-10-15", completed: true)
        copy.id = log.id
        copy.imageFileName = "run.jpg"
        let other = HabitLog(habit: twin, dateString: "2026-10-14", completed: true)
        context.insert(log); context.insert(copy); context.insert(other)
        try context.save()
        #expect(StoreDedupe.mergeDuplicateWins(in: context) == 2)
        let habits = try context.fetch(FetchDescriptor<Habit>())
        let logs = try context.fetch(FetchDescriptor<HabitLog>())
        #expect(habits.count == 1)
        #expect(logs.count == 2)
        #expect(logs.first { $0.id == log.id }?.imageFileName == "run.jpg")
        #expect(logs.allSatisfy { $0.habit?.id == habit.id })
        // A store with no twins is left alone.
        #expect(StoreDedupe.mergeDuplicateWins(in: context) == 0)
    }
}
