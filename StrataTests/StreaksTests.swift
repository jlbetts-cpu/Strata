import Testing
import Foundation
@testable import Strata

/// Consecutive days.
///
/// These exist because six milestones — "Week Strong" through "Year One" —
/// were defined, listed in the app, and unreachable: `MilestoneDetector` was
/// handed a literal `0` for the longest streak. Pure functions over day keys,
/// so the boundaries can be tested at the boundary rather than inferred from
/// a screenshot.
@Suite("Streaks")
struct StreaksTests {

    @Test("no days is no streak")
    func emptyIsZero() {
        #expect(Streaks.longest(among: [String]()) == 0)
    }

    @Test("one day is a streak of one")
    func singleDay() {
        #expect(Streaks.longest(among: ["2026-09-10"]) == 1)
    }

    @Test("consecutive days run together")
    func consecutiveDaysRun() {
        #expect(Streaks.longest(among: ["2026-09-08", "2026-09-09", "2026-09-10"]) == 3)
    }

    @Test("a gap breaks the run")
    func aGapBreaksIt() {
        // Three, then a missing day, then two.
        let days = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-05", "2026-09-06"]
        #expect(Streaks.longest(among: days) == 3)
    }

    /// The caller hands over log rows, and two wins on one day are one day.
    @Test("the same day twice is still one day")
    func duplicatesCollapse() {
        #expect(Streaks.longest(among: ["2026-09-09", "2026-09-09", "2026-09-10"]) == 2)
    }

    /// Rows arrive in whatever order the store gives them.
    @Test("order does not matter")
    func orderDoesNotMatter() {
        let forwards = ["2026-09-08", "2026-09-09", "2026-09-10"]
        #expect(Streaks.longest(among: forwards.reversed()) == 3)
        #expect(Streaks.longest(among: forwards.shuffled()) == 3)
    }

    /// The boundary that a naive "add one to the string" gets wrong.
    @Test("a run crosses the end of a month")
    func crossesAMonth() {
        #expect(Streaks.longest(among: ["2026-01-30", "2026-01-31", "2026-02-01"]) == 3)
    }

    @Test("a run crosses the end of a year")
    func crossesAYear() {
        #expect(Streaks.longest(among: ["2025-12-31", "2026-01-01"]) == 2)
    }

    @Test("a run crosses a leap day")
    func crossesALeapDay() {
        #expect(Streaks.longest(among: ["2028-02-28", "2028-02-29", "2028-03-01"]) == 3)
    }

    @Test("the longest run wins, not the last one")
    func longestNotLast() {
        let days = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04",
                    "2026-09-09", "2026-09-10"]
        #expect(Streaks.longest(among: days) == 4)
    }

    // MARK: - The run that is still alive

    private func key(_ daysAgo: Int, from today: Date) -> String {
        DateUtils.dateString(
            from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
        )
    }

    @Test("a run ending today is current")
    func currentEndsToday() {
        let today = Date()
        let days = (0...4).map { key($0, from: today) }
        #expect(Streaks.current(among: days, today: today) == 5)
    }

    /// **Yesterday counts.** A streak is not broken until a day passes with
    /// nothing in it — at 9am your run of a hundred days has not ended
    /// because today is young.
    @Test("a run ending yesterday is still alive")
    func yesterdayStillCounts() {
        let today = Date()
        let days = (1...3).map { key($0, from: today) }
        #expect(Streaks.current(among: days, today: today) == 3)
    }

    @Test("a run that ended two days ago is over")
    func twoDaysAgoIsOver() {
        let today = Date()
        let days = (2...6).map { key($0, from: today) }
        #expect(Streaks.current(among: days, today: today) == 0)
    }

    @Test("nothing at all is no current streak")
    func noDaysNoCurrent() {
        #expect(Streaks.current(among: [String]()) == 0)
    }
}
