import CoreGraphics
import Foundation
import Testing
@testable import Strata

/// **The ring comes forward to take a win** (the owner, 2026-10-10: "when a
/// win is completed, animate the ring large on screen ... then zoom back to
/// its spot ... calm and minimal, not loud"). `RingMoment`, `RingTrigger`.
@MainActor
@Suite("The ring's moment", .serialized)
struct GoalRingMomentTests {
    func fresh() -> RingMoment {
        let moment = RingMoment.shared
        moment.cancel()
        moment.crestFrame = CGRect(x: 171, y: 80, width: 60, height: 60)
        return moment
    }

    /// Waits for `condition`, a little at a time, so nothing here leans on
    /// a margin of milliseconds against a clock every other suite shares
    /// (found by review).
    func until(_ seconds: Double = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    // MARK: When it plays (`RingTrigger`)

    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("a win with the tower in view plays at once")
    func playsWhenClear() {
        var trigger = RingTrigger()
        #expect(trigger.counted(old: 2, new: 3, isClear: true, now: t0) == .play(from: 2, to: 3))
        #expect(trigger.cleared(true, now: t0) == .none, "and only once")
    }

    @Test("a win saved under a sheet plays when the tower is back, if that is soon")
    func waitsForTheTower() {
        var trigger = RingTrigger()
        #expect(trigger.counted(old: 2, new: 3, isClear: false, now: t0) == .none)
        #expect(trigger.cleared(true, now: t0.addingTimeInterval(0.6)) == .play(from: 2, to: 3))
        // Left too long (another tab, another sheet): the moment has gone.
        var late = RingTrigger()
        _ = late.counted(old: 2, new: 3, isClear: false, now: t0)
        #expect(late.cleared(true, now: t0.addingTimeInterval(RingTrigger.keeps + 1)) == .none)
        #expect(late.cleared(true, now: t0.addingTimeInterval(RingTrigger.keeps + 2)) == .none)
    }

    @Test("a win taken back takes the moment with it")
    func undoCancels() {
        var trigger = RingTrigger()
        _ = trigger.counted(old: 2, new: 3, isClear: true, now: t0)
        #expect(trigger.counted(old: 3, new: 2, isClear: true, now: t0.addingTimeInterval(0.4)) == .cancel)
        // And one that was still waiting is dropped, not played later.
        var waiting = RingTrigger()
        _ = waiting.counted(old: 2, new: 3, isClear: false, now: t0)
        #expect(waiting.counted(old: 3, new: 2, isClear: false, now: t0.addingTimeInterval(0.4)) == .cancel)
        #expect(waiting.cleared(true, now: t0.addingTimeInterval(1)) == .none)
    }

    @Test("two wins under one sheet are one moment, from where the count stood")
    func severalAtOnce() {
        var trigger = RingTrigger()
        _ = trigger.counted(old: 2, new: 3, isClear: false, now: t0)
        _ = trigger.counted(old: 3, new: 4, isClear: false, now: t0.addingTimeInterval(1))
        #expect(trigger.cleared(true, now: t0.addingTimeInterval(2)) == .play(from: 2, to: 4))
    }

    @Test("something coming over the tower stops it")
    func coveredCancels() {
        var trigger = RingTrigger()
        #expect(trigger.cleared(false, now: t0) == .cancel)
        #expect(trigger.counted(old: 3, new: 3, isClear: true, now: t0) == .none)
    }

    // MARK: The trip itself (`RingMoment`)

    @Test("a count that fell, or no crest to lift, starts nothing")
    func whatStartsIt() {
        let moment = fresh()
        moment.play(from: 3, to: 2, goal: 8, reduceMotion: false)
        #expect(!moment.isPlaying, "taking a win off is not a moment")
        moment.crestFrame = .zero
        moment.play(from: 2, to: 3, goal: 8, reduceMotion: false)
        #expect(!moment.isPlaying, "with nowhere to lift from, nothing starts")
        #expect(moment.holding == nil)
    }

    @Test("the header keeps the old count, then it lifts, fills, and goes home by itself")
    func theTrip() async {
        let moment = fresh()
        moment.play(from: 2, to: 3, goal: 8, reduceMotion: false)
        #expect(moment.isPlaying && !moment.lifted, "the block falls first")
        #expect(moment.holding == 2, "the header still says what it said")
        #expect(await until { moment.lifted }, "out of its place")
        #expect(moment.grown && !moment.filled, "growing, the old count on it")
        #expect(await until { moment.filled }, "the segment this win earned is drawn")
        #expect(moment.holding == nil, "and the header may say the new count")
        #expect(await until { !moment.lifted && !moment.filled && !moment.isPlaying }, "home, with nothing to dismiss")
    }

    @Test("a second win while it plays does not start a second one")
    func oneAtATime() {
        let moment = fresh()
        moment.play(from: 2, to: 3, goal: 8, reduceMotion: false)
        moment.play(from: 3, to: 4, goal: 8, reduceMotion: false)
        #expect(moment.from == 2 && moment.to == 3)
        moment.cancel()
        #expect(!moment.lifted && !moment.isPlaying)
    }

    @Test("with Reduce Motion nothing travels: the check shows where the crest sits")
    func reduceMotion() async {
        let moment = fresh()
        moment.play(from: 0, to: 1, goal: 3, reduceMotion: true)
        #expect(await until { moment.checkInPlace })
        #expect(!moment.lifted && !moment.grown)
        #expect(await until { !moment.checkInPlace && !moment.isPlaying })
        #expect(!moment.lifted, "it never left")
    }

    @Test("cancelled, it stops where it is and does not come back")
    func cancelled() async {
        let moment = fresh()
        moment.play(from: 1, to: 2, goal: 3, reduceMotion: false)
        #expect(await until { moment.lifted })
        moment.cancel()
        #expect(!moment.lifted && !moment.grown && !moment.filled && moment.holding == nil)
        try? await Task.sleep(for: .seconds(RingMoment.whole))
        #expect(!moment.lifted && !moment.filled, "the task that was cancelled moved nothing afterwards")
    }

    /// It is an everyday moment, so it must be short, must not block a
    /// touch, and must not be the goal's celebration over again.
    @Test("short, untouchable, before the dance, and not the confetti")
    func calm() throws {
        #expect(RingMoment.whole < 3.2, "about three seconds from the press, a third of it the block's own fall")
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRingMoment.swift"))
        #expect(code.contains(".allowsHitTesting(false)"), "touches go through to the tower")
        #expect(!code.contains("Confetti") && !code.contains("HapticsEngine.success()"))
        #expect(code.contains("Image(\"MarkCheck\")"), "his drawn check, not a symbol")
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("GoalRingMomentWatch(wins: blocksToday, goal: todaysGoal, isClear: ringIsClear)"))
        #expect(main.contains("while !animCoord.isStill || RingMoment.shared.isPlaying"),
                "the goal's dance waits for the ring to go home")
        let clear = try #require(main.components(separatedBy: "private var ringIsClear: Bool").dropFirst().first)
        let body = clear.components(separatedBy: "private var blocksToday").first ?? ""
        // `crewPath.isEmpty` went with crews leaving Wins for a tab of their
        // own (2026-10-13): a crew can no longer be over the tower, and
        // `selectedTab == .tower` says the tower is what is in front.
        for covering in ["selectedTab == .tower", "inlineOpening == nil", "!isPlanning", "!returnsToPlan", "booth == nil",
                         "expandedBlockID == nil", "scenePhase == .active"] {
            #expect(body.contains(covering), "\(covering): the ring never plays over something else")
        }
    }
}
