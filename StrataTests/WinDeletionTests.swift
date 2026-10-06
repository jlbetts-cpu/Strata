import Testing
import Foundation
import SwiftData
@testable import Strata

/// Delete, then Undo (`WinDeletion`): the win comes back whole, and the
/// photographs only go once the chance to undo has passed.
@MainActor
@Suite("Deleting a win can be undone")
struct WinDeletionTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Habit.self, HabitLog.self, Tower.self, MoodLog.self, PlanItem.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test("undo brings back the win, its log, its photo's name and its plan tick")
    func undoRestores() throws {
        let container = try container()
        let context = container.mainContext
        let line = PlanItem(text: "Run", order: 0, category: .health)
        context.insert(line)
        let win = try QuickWinService.logWin(title: "Run", category: .health, size: .medium,
                                             context: context, tower: nil)
        win.habit.planItemID = line.id
        line.completedAt = Date()
        let log = try #require((win.habit.logs ?? []).first)
        log.imageFileName = "photo-1.heic"
        let habitID = win.habit.id
        try context.save()

        let pending = try WinDeletion.delete(win.habit, in: context)
        #expect(try context.fetch(FetchDescriptor<Habit>()).isEmpty)
        #expect(line.completedAt == nil, "deleting the win puts its line back")

        pending.undo()
        let back = try context.fetch(FetchDescriptor<Habit>())
        #expect(back.count == 1)
        #expect(back.first?.id == habitID)
        #expect(back.first?.title == "Run")
        #expect(back.first?.blockSize == .medium)
        #expect(back.first?.logs?.first?.imageFileName == "photo-1.heic")
        #expect(line.completedAt != nil, "undo ticks the line again")
    }

    @Test("without undo the win stays gone")
    func staysGone() throws {
        let container = try container()
        let context = container.mainContext
        let win = try QuickWinService.logWin(title: "Read", category: .focus, size: .small,
                                             context: context, tower: nil)
        try context.save()
        let pending = try WinDeletion.delete(win.habit, in: context)
        pending.finish()
        #expect(try context.fetch(FetchDescriptor<Habit>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HabitLog>()).isEmpty)
    }
}
