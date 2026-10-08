import Testing
import Foundation
import SwiftData
@testable import Strata

/// The queries a long-time user makes on every win stay the size of a day
/// (2026-10-08, the scale audit: every win is its own Habit, so "fetch every
/// Habit" grows by about five a day for as long as someone uses the app).
///
/// Self-test: put `FetchDescriptor<Habit>()` back in `QuickWinService.logWin`'s
/// colour pick and `anUntitledWinCountsTodaysColoursOnly` fails, because last
/// week's six colours make every colour "least used" again.
@Suite("Scale queries")
struct ScaleQueryTests {
    @MainActor
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @MainActor
    @Test("an untitled win picks its colour from today's tower, not every win ever")
    func anUntitledWinCountsTodaysColoursOnly() throws {
        let context = try context()
        let lastWeek = Date().addingTimeInterval(-7 * 86_400)
        // Last week: one of every colour but health, twice over, so a count of
        // ALL wins makes health the only least-used colour.
        for _ in 0..<2 {
            for colour in HabitCategory.selectable where colour != .health {
                _ = try QuickWinService.logWin(category: colour, on: lastWeek, context: context, tower: nil)
            }
        }
        // Today: health once. Counting today, health is the one colour used,
        // so the pick is anything but health; counting everything, health has
        // 1 against the others' 2, so the pick would be health every time.
        _ = try QuickWinService.logWin(category: .health, context: context, tower: nil)
        for _ in 0..<12 {
            let (habit, _) = try QuickWinService.logWin(context: context, tower: nil)
            #expect(habit.displayCategory != .health, "counted last week's wins instead of today's")
            context.delete(habit)
        }
    }

    @MainActor
    @Test("Spotlight leaves untitled wins out")
    func untitledIsNotSearchable() {
        #expect(!SpotlightIndexer.isSearchable(Habit(title: QuickWinService.untitled, category: .unlabeled)))
        #expect(SpotlightIndexer.isSearchable(Habit(title: "Called Mum", category: .social)))
    }
}
