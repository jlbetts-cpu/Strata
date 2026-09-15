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

    // MARK: - The widget's streak

    private func noon(_ key: String) -> Date {
        DateUtils.date(from: key)!.addingTimeInterval(12 * 3600)
    }

    /// The widget's streak was worked out over `MainAppView`'s `logs`, which
    /// is narrowed to the current month, so on the 3rd a ten-day run read 3
    /// and on the 1st every streak read 1. It is worked out over the
    /// 400-day horizon now; this is that run, both ways.
    @Test("a current streak crossing the 1st of the month is not reset")
    func currentCrossesTheFirst() {
        let today = noon("2026-09-03")
        let window = (0..<10).map { key($0, from: today) }   // Aug 25 to Sep 3
        #expect(Streaks.current(among: window, today: today) == 10)
        #expect(window.allSatisfy { $0 >= Streaks.horizonKey(today: today) })

        // What the month-narrowed rows could see.
        let monthOnly = window.filter { $0 >= "2026-09-01" }
        #expect(Streaks.current(among: monthOnly, today: today) == 3)
    }

    @Test("the horizon is 400 days back")
    func horizon() {
        #expect(Streaks.horizonKey(today: noon("2026-09-14")) == "2025-08-10")
    }

    @Test("the memo answers from the same days without recounting, and recounts when they change")
    func memoRecountsOnChange() {
        let today = noon("2026-09-03")
        var memo = Streaks.Memo()
        let days = (0..<10).map { key($0, from: today) }
        #expect(memo.current(among: days, today: today) == 10)
        let first = memo.signature
        #expect(memo.current(among: days.shuffled() + days, today: today) == 10)
        #expect(memo.signature == first)

        // A gap four days back: the run is now the last four days.
        let gapped = days.filter { $0 != key(4, from: today) }
        #expect(memo.current(among: gapped, today: today) == 4)

        // Two days on with nothing logged, the run is over.
        #expect(memo.current(among: gapped, today: noon("2026-09-05")) == 0)
    }

    // MARK: - When the widget's days need no fetch

    @Test("nothing fetched yet is never current")
    func widgetDaysStartUnknown() {
        var days = Streaks.WidgetDays()
        let r1 = days.isCurrent(lifetime: 0, todayKey: "2026-09-15")
        #expect(!r1)
    }

    @Test("the same lifetime count needs no fetch, even on a new day")
    func sameCountIsCurrent() {
        var days = Streaks.WidgetDays()
        days.replace(days: ["2026-09-14"], lifetime: 5)
        let r2 = days.isCurrent(lifetime: 5, todayKey: "2026-09-14")
        #expect(r2)
        let r3 = days.isCurrent(lifetime: 5, todayKey: "2026-09-15")
        #expect(r3)
    }

    /// Every win after the first of a day: the new row is on a day already
    /// in the set, so the set is still exact and the drop costs no fetch.
    @Test("one more win on a day that already had one needs no fetch, and the count moves along")
    func anotherWinTodayIsCurrent() {
        var days = Streaks.WidgetDays()
        days.replace(days: ["2026-09-14", "2026-09-15"], lifetime: 5)
        let r4 = days.isCurrent(lifetime: 6, todayKey: "2026-09-15")
        #expect(r4)
        #expect(days.lifetime == 6)
        let r5 = days.isCurrent(lifetime: 7, todayKey: "2026-09-15")
        #expect(r5)
    }

    /// The day's first win: today is not in the set yet. It joins locally,
    /// so the widget is written once with the right streak rather than once
    /// with the old one and again after a fetch.
    @Test("the day's first win adds today without a fetch, and the streak it gives is right")
    func firstWinOfTheDayAddsToday() {
        var days = Streaks.WidgetDays()
        days.replace(days: ["2026-09-13", "2026-09-14"], lifetime: 5)
        let current = days.isCurrent(lifetime: 6, todayKey: "2026-09-15")
        #expect(current)
        #expect(days.days == ["2026-09-13", "2026-09-14", "2026-09-15"])
        #expect(days.lifetime == 6)
        #expect(Streaks.current(among: days.days!, today: noon("2026-09-15")) == 3)
    }

    @Test("a deletion or a jump of two needs a fetch, and changes nothing until it lands")
    func otherChangesNeedAFetch() {
        var days = Streaks.WidgetDays()
        days.replace(days: ["2026-09-14"], lifetime: 5)
        let deleted = days.isCurrent(lifetime: 4, todayKey: "2026-09-14")
        #expect(!deleted)
        let jumped = days.isCurrent(lifetime: 7, todayKey: "2026-09-15")
        #expect(!jumped)
        #expect(days.lifetime == 5)
        #expect(days.days == ["2026-09-14"])
    }
}
