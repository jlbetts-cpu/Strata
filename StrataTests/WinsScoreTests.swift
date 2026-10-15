import Testing
import Foundation
import SwiftData
@testable import Strata

/// The score is the record weighed: Quick 1, Regular 2, Deep 3, and a deleted
/// win takes its points with it.
@Suite("Wins score")
@MainActor
struct WinsScoreTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema, isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @discardableResult
    private func win(_ size: BlockSize, completed: Bool = true, in context: ModelContext) -> Habit {
        let habit = Habit(title: "Win", category: .health, blockSize: size)
        context.insert(habit)
        context.insert(HabitLog(habit: habit, dateString: "2026-10-15", completed: completed))
        return habit
    }

    @Test("each size is worth its weight")
    func weights() {
        #expect(WinsScore.tally([.small, .medium, .hard]) == .init(score: 6, wins: 3))
        #expect(WinsScore.tally([BlockSize]()) == .init(score: 0, wins: 0))
    }

    @Test("only logged wins count")
    func onlyLogged() throws {
        let context = try context()
        win(.hard, in: context)
        win(.medium, completed: false, in: context)
        try context.save()
        #expect(WinsScore.tally(in: context) == .init(score: 3, wins: 1))
    }

    @Test("deleting a win lowers the score, and undo brings it back")
    func deleteLowers() throws {
        let context = try context()
        win(.small, in: context)
        let deep = win(.hard, in: context)
        try context.save()
        #expect(WinsScore.tally(in: context).score == 4)
        let pending = try WinDeletion.delete(deep, in: context)
        try context.save()
        #expect(WinsScore.tally(in: context) == .init(score: 1, wins: 1))
        pending.undo()
        #expect(WinsScore.tally(in: context) == .init(score: 4, wins: 2))
    }
}
