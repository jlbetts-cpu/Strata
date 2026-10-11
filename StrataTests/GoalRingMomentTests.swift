import CoreGraphics
import Foundation
import Testing
@testable import Strata

/// **The ring comes forward to take a win** (the owner, 2026-10-10: "when a
/// win is completed, animate the ring large on screen ... then zoom back to
/// its spot ... calm and minimal, not loud"). `RingMoment`.
@MainActor
@Suite("The ring's moment", .serialized)
struct GoalRingMomentTests {
    func fresh() -> RingMoment {
        let moment = RingMoment.shared
        moment.cancel()
        moment.crestFrame = CGRect(x: 171, y: 80, width: 60, height: 60)
        return moment
    }

    @Test("a win starts it; a count that fell, or no crest to lift, does not")
    func whatStartsIt() async throws {
        let moment = fresh()
        moment.play(from: 3, to: 2, goal: 8, reduceMotion: false)
        try await Task.sleep(for: .milliseconds(60))
        #expect(!moment.lifted, "taking a win off is not a moment")
        moment.crestFrame = .zero
        moment.play(from: 2, to: 3, goal: 8, reduceMotion: false)
        #expect(moment.to == 0 || moment.to == 2, "with nowhere to lift from, nothing is set up")
        moment.cancel()
    }

    @Test("it waits for the block, lifts, fills, and goes home by itself")
    func theTrip() async throws {
        let moment = fresh()
        moment.play(from: 2, to: 3, goal: 8, reduceMotion: false)
        #expect(!moment.lifted, "the block falls first")
        #expect(moment.from == 2 && moment.to == 3 && moment.goal == 8)
        try await Task.sleep(for: .seconds(GridConstants.ringWaitsForBlock + 0.2))
        #expect(moment.lifted && moment.grown && !moment.filled, "out of its place, growing, the old count on it")
        try await Task.sleep(for: .seconds(0.5))
        #expect(moment.filled, "the segment this win earned is drawn")
        try await Task.sleep(for: .seconds(0.5 + GridConstants.ringHold + 0.7))
        #expect(!moment.lifted && !moment.grown && !moment.filled, "home, with nothing to dismiss")
    }

    @Test("a second win while it plays does not start a second one")
    func oneAtATime() async throws {
        let moment = fresh()
        moment.play(from: 2, to: 3, goal: 8, reduceMotion: false)
        moment.play(from: 3, to: 4, goal: 8, reduceMotion: false)
        #expect(moment.from == 2 && moment.to == 3)
        moment.cancel()
        #expect(!moment.lifted)
    }

    @Test("with Reduce Motion nothing travels: the check shows where the crest sits")
    func reduceMotion() async throws {
        let moment = fresh()
        moment.play(from: 0, to: 1, goal: 3, reduceMotion: true)
        try await Task.sleep(for: .seconds(GridConstants.ringWaitsForBlock + 0.2))
        #expect(moment.checkInPlace && !moment.lifted && !moment.grown)
        try await Task.sleep(for: .seconds(GridConstants.ringHold + 0.7))
        #expect(!moment.checkInPlace)
    }

    @Test("leaving the tower stops it where it is")
    func cancelled() async throws {
        let moment = fresh()
        moment.play(from: 1, to: 2, goal: 3, reduceMotion: false)
        try await Task.sleep(for: .seconds(GridConstants.ringWaitsForBlock + 0.2))
        #expect(moment.lifted)
        moment.cancel()
        #expect(!moment.lifted && !moment.grown && !moment.filled)
        try await Task.sleep(for: .seconds(1.2))
        #expect(!moment.lifted, "and it does not come back")
    }

    /// It is an everyday moment, so it must be short, must not block a
    /// touch, and must not be the goal's celebration over again.
    @Test("short, untouchable, and not the confetti")
    func calm() throws {
        let whole = GridConstants.ringWaitsForBlock + 0.42 + 0.34 + 0.16 + GridConstants.ringHold + 0.44
        #expect(whole < 3.2, "about three seconds from the press, most of it the block's own fall")
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRingMoment.swift"))
        #expect(code.contains(".allowsHitTesting(false)"), "touches go through to the tower")
        #expect(!code.contains("Confetti") && !code.contains("HapticsEngine.success()"))
        #expect(code.contains("Image(\"MarkCheck\")"), "his drawn check, not a symbol")
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("GoalRingMomentWatch(wins: blocksToday, goal: todaysGoal, isClear: ringIsClear)"))
    }
}
