import Foundation
import Testing
@testable import Strata

/// **Confetti answers the goal, and nothing else** (2026-10-09). The owner's
/// first win of the day fired the confetti with a goal of 3: a "perfect day"
/// celebration from the old scheduled-habits model counted any day with one
/// win as perfect. This holds the fix at its root.
///
/// Self-test: put the perfect-day block back and `oneTrigger` fails (two
/// bursts, a second dance).
@Suite("Goal confetti")
struct GoalConfettiTests {
    @Test("the burst and the dance have one trigger: the goal")
    func oneTrigger() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.components(separatedBy: "confettiBursts += 1").count - 1 == 1,
                "confetti fires from more than one place")
        #expect(main.components(separatedBy: "triggerJubilation(").count - 1 == 1,
                "the tower dances from more than one place")
        #expect(!main.contains("perfectDay"))
        let celebration = try #require(main.range(of: "private func celebrateGoalIfDue()"))
        let burst = try #require(main.range(of: "confettiBursts += 1"))
        #expect(burst.lowerBound > celebration.lowerBound, "the burst is not the goal's")
        #expect(main.contains("towerVM.placedBlocks.count >= todaysGoal"))
    }
}
