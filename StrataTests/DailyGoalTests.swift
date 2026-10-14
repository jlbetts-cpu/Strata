import Testing
import Foundation
@testable import Strata

/// **The day's goal, as a ring** (the owner, 2026-10-06), and the dance that
/// now comes when it is reached.
@Suite("Daily goal")
struct DailyGoalTests {
    @Test("the ring only fills: never past full, never below empty")
    func progress() {
        #expect(DailyGoal.progress(wins: 0, goal: 3) == 0)
        #expect(DailyGoal.progress(wins: 2, goal: 4) == 0.5)
        #expect(DailyGoal.progress(wins: 7, goal: 3) == 1)
    }

    @Test("reaching is crossing, not resting on it")
    func reached() {
        #expect(DailyGoal.reached(from: 2, to: 3, goal: 3))
        #expect(!DailyGoal.reached(from: 3, to: 4, goal: 3))
        #expect(!DailyGoal.reached(from: 1, to: 2, goal: 3))
    }

    @Test("you choose it, from one to twelve, starting at three")
    func range() {
        #expect(DailyGoal.standard == 3)
        #expect(DailyGoal.clamped(0) == 1 && DailyGoal.clamped(40) == 12)
    }

    @Test("the cue asks until the goal is met, and a met goal is left alone")
    func cueFollowsTheGoal() {
        let four = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!
        #expect(WinCue.line(winsToday: 4, now: four, shownOn: nil, goal: 6) == WinCue.anythingElse)
        #expect(WinCue.line(winsToday: 6, now: four, shownOn: nil, goal: 6) == nil)
        #expect(WinCue.line(winsToday: 5, now: four, shownOn: nil, goal: 6) == WinCue.oneMore)
        #expect(!WinCue.oneMore.contains("\u{2014}"))
    }

    @Test("the ring sits in the header's middle, and the Wins tower dances at the goal")
    func wired() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        // Today's goal, the one you set.
        #expect(main.contains("GoalCrest(wins: blocksToday, goal: todaysGoal,"))
        // **The dance marks its day only once it has started** (2026-10-08,
        // the owner: "i hit the goal and the tower didnt dance"). This used to
        // pin `if wins >= todaysGoal, goalDanceDay != today {`, the line that
        // marked the day BEFORE asking for the dance, which is the bug: a
        // refused dance spent the day. Now the goal reads the tower, and the
        // day is written after `triggerJubilation` says yes.
        #expect(main.contains("towerVM.placedBlocks.count >= todaysGoal else { return }"))
        let celebrate = try #require(main.components(separatedBy: "private func celebrateGoalIfDue()").dropFirst().first)
        let started = try #require(celebrate.range(of: "animCoord.triggerJubilation("))
        let marked = try #require(celebrate.range(of: "guard started else { return }\n        goalDanceDay = today"))
        #expect(started.lowerBound < marked.lowerBound, "the day is marked before the dance is asked for")
        #expect(!main.contains("wins % GridConstants.danceEvery"), "the tenth-win dance gave way to the goal")
        let ring = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRing.swift"))
        #expect(!ring.contains("Color.red") && !ring.contains(".red"), "the ring never shows a shortfall")
        // Monotone (the owner, 2026-10-06): the blocks are the only colour.
        let stroke = try #require(ring.components(separatedBy: "struct GoalRingStroke").dropFirst().first?
            .components(separatedBy: "struct CrestCaption").first)
        #expect(!stroke.contains("baseColor") && !stroke.contains("colours"))
    }
}

/// **Your day: what the middle of Wins opens** (the owner's pick).
@Suite("Your day")
struct YourDayTests {
    @Test("the week runs Monday to Sunday, today included, days to come marked")
    func week() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        let tuesday = c.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 12))!
        let days = YourDaySheet.weekDays(now: tuesday, calendar: c)
        #expect(days.count == 7)
        #expect(days.first?.key == "2026-10-05" && days.last?.key == "2026-10-11")
        #expect(days.filter(\.future).count == 5)
    }

    @Test("the crest's head and fraction both open it, as a crew's middle opens its details")
    func wired() throws {
        let ring = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRing.swift"))
        // Each gives the light tap an open gives (2026-10-11, rule 5 of
        // `docs/ten.md`); still two ways in, to one place.
        // **The face's press lets your head out when he is in it** (the
        // owner, 2026-10-13: "press, head comes out"), so the face's button
        // is `pressFace()` now, which opens Your day with the same tap
        // whenever there is no head to let out (`CrestDockTests`).
        #expect(ring.components(separatedBy: "Button { HapticsEngine.lightTap(); openDay() }").count - 1 == 1)
        #expect(ring.contains("Button { pressFace() } label: {"))
        #expect(ring.contains("HapticsEngine.lightTap()\n            openDay()"))
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("YourDaySheet(goal: $dailyGoal)"))
    }
}

/// **The goal ring, drawn in his hand** (the owner, 2026-10-13: he picked
/// "The goal ring round my head" in his doodle style).
@Suite("Goal ring: the doodle")
struct DoodleRingTests {
    private var shares: [Double] {
        (0...720).map { DoodleRing.radiusShare(at: Double($0) / 720 * 2 * .pi) }
    }

    @Test("never past its frame, and a slight variation, not a scribble")
    func subtle() throws {
        let low = try #require(shares.min()), high = try #require(shares.max())
        #expect(high <= 1.0, "a ring past its frame is clipped by the glass round it")
        #expect(low >= 0.95, "more than 5% in is a wobble, not a hand")
        #expect(high - low >= 0.015, "too even to read as drawn: that is a circle")
    }

    @Test("the line closes on itself, so the last segment meets the first")
    func closes() {
        #expect(abs(DoodleRing.radiusShare(at: 0) - DoodleRing.radiusShare(at: 2 * .pi)) < 1e-9)
    }

    @Test("his pen's weight round the crest, on the same circle as the 4pt ring was")
    func pen() throws {
        #expect(GoalCrest.line == 2.6)
        #expect(abs(GoalCrest.faceSide(crest: 60) - 40) < 0.001, "the face kept its size")
        #expect(GoalCrest.ringInset == 4)
        let ring = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRing.swift"))
        let stroke = try #require(ring.components(separatedBy: "struct GoalRingStroke").dropFirst().first?
            .components(separatedBy: "struct DoodleRing").first)
        #expect(stroke.contains("DoodleRing()") && !stroke.contains("Circle()"))
        // Still one long stroke a part, whole or empty: never a partial fill.
        #expect(stroke.contains(".stroke(i < wins ? AppColors.inkPrimary : AppColors.inkPrimary.opacity(0.08),"))
        let moment = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRingMoment.swift"))
        let sweep = try #require(moment.components(separatedBy: "private struct RingSweep").dropFirst().first?
            .components(separatedBy: "struct GoalRingMomentLayer").first)
        #expect(!sweep.contains("Circle()"), "the ring turns true on its trip")
    }
}
