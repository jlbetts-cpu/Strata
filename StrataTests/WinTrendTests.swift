import Testing
import Foundation
@testable import Strata

/// Wins per day, week and month, and the trend sentence above Profile's chart.
///
/// The sentence is the part somebody reads, so every branch of it is pinned
/// here: a wrong "more than usual" is a small lie the app tells every time
/// the page opens.
@Suite("WinTrend")
struct WinTrendTests {

    /// Monday-first Gregorian in the current zone — the zone `DateUtils`
    /// parses day keys in.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }()

    private func day(_ key: String) -> Date { DateUtils.date(from: key)! }

    /// Thursday 10 September 2026. Its Monday-first week starts on the 7th.
    private var today: Date { day("2026-09-10") }

    /// One day inside each FINISHED period before the current one, oldest
    /// first, holding that many wins. A zero leaves the period empty.
    private func finished(_ unit: WinTrend.Unit, _ perPeriod: [Int]) -> [String: Int] {
        let current = calendar.dateInterval(of: unit.component, for: today)!.start
        var out: [String: Int] = [:]
        for (index, wins) in perPeriod.enumerated() where wins > 0 {
            let start = calendar.date(byAdding: unit.component, value: index - perPeriod.count, to: current)!
            let inside = unit == .day ? start : calendar.date(byAdding: .day, value: 2, to: start)!
            out[DateUtils.dateString(from: inside)] = wins
        }
        return out
    }

    private func kind(_ unit: WinTrend.Unit, _ counts: [String: Int]) -> WinTrend.Kind {
        WinTrend.summary(dayCounts: counts, unit: unit, today: today, calendar: calendar).kind
    }

    // MARK: - Bars

    @Test("twelve weeks, oldest first, ending with this one")
    func weekShape() {
        let bars = WinTrend.bars(dayCounts: [:], unit: .week, today: today, calendar: calendar)
        #expect(bars.count == 12)
        #expect(bars.last?.start == day("2026-09-07"))
        #expect(bars.first?.start == day("2026-06-22"))
        #expect(bars.last?.isCurrent == true)
        #expect(bars.dropLast().allSatisfy { !$0.isCurrent })
    }

    @Test("fourteen days end today; twelve months end this month")
    func dayAndMonthShape() {
        let days = WinTrend.bars(dayCounts: [:], unit: .day, today: today, calendar: calendar)
        #expect(days.count == 14)
        #expect(days.last?.start == day("2026-09-10"))
        #expect(days.first?.start == day("2026-08-28"))

        let months = WinTrend.bars(dayCounts: [:], unit: .month, today: today, calendar: calendar)
        #expect(months.count == 12)
        #expect(months.last?.start == day("2026-09-01"))
        #expect(months.first?.start == day("2025-10-01"))
    }

    @Test("a win lands in the week that contains its day")
    func weekBucketing() {
        // Monday and Thursday of this week; the Sunday before is last week.
        let counts = ["2026-09-07": 2, "2026-09-10": 1, "2026-09-06": 3]
        let bars = WinTrend.bars(dayCounts: counts, unit: .week, today: today, calendar: calendar)
        #expect(bars.last?.count == 3)
        #expect(bars.dropLast().last?.count == 3)
    }

    @Test("days and months bucket too")
    func dayAndMonthBucketing() {
        let counts = ["2026-09-10": 2, "2026-09-09": 1, "2026-08-31": 4]
        let days = WinTrend.bars(dayCounts: counts, unit: .day, today: today, calendar: calendar)
        #expect(days.last?.count == 2)
        #expect(days.dropLast().last?.count == 1)

        let months = WinTrend.bars(dayCounts: counts, unit: .month, today: today, calendar: calendar)
        #expect(months.last?.count == 3)
        #expect(months.dropLast().last?.count == 4)
    }

    @Test("wins older than the window are not drawn")
    func outsideWindow() {
        let bars = WinTrend.bars(dayCounts: ["2026-01-05": 9], unit: .week, today: today, calendar: calendar)
        #expect(bars.allSatisfy { $0.count == 0 })
    }

    // MARK: - Summary

    @Test("no wins at all is empty")
    func empty() {
        #expect(kind(.week, [:]) == .empty)
    }

    @Test("wins only this week are not enough to compare")
    func onlyThisWeek() {
        #expect(kind(.week, ["2026-09-08": 5]) == .notEnough)
    }

    @Test("five finished weeks is one short of a baseline; six is enough")
    func weekThreshold() {
        #expect(kind(.week, finished(.week, [3, 3, 3, 3, 3])) == .notEnough)
        #expect(kind(.week, finished(.week, [3, 3, 3, 3, 3, 3])) == .same)
    }

    @Test("doubling is more, halving is fewer")
    func moreAndFewer() {
        #expect(kind(.week, finished(.week, [2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4])) == .more)
        #expect(kind(.week, finished(.week, [6, 6, 6, 6, 6, 6, 6, 6, 3, 3, 3, 3])) == .fewer)
    }

    @Test("a change inside the band is the same")
    func insideBand() {
        // 5.5 against 5 is +10%, under the 20% band.
        #expect(kind(.week, finished(.week, [5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 5, 6])) == .same)
    }

    @Test("the summary carries both averages, for the sentence to quote")
    func averages() {
        let summary = WinTrend.summary(dayCounts: finished(.week, [2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4]),
                                       unit: .week, today: today, calendar: calendar)
        #expect(summary.recentAverage == 4)
        #expect(summary.usualAverage == 2)
    }

    @Test("four empty recent weeks after a steady run is fewer, not empty")
    func stoppedLogging() {
        #expect(kind(.week, finished(.week, [4, 4, 4, 4, 0, 0, 0, 0])) == .fewer)
    }

    @Test("periods before the first win do not count as quiet ones")
    func beforeTheApp() {
        #expect(kind(.week, finished(.week, [0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3])) == .same)
    }

    @Test("the unfinished period does not move the verdict")
    func unfinishedIgnored() {
        var counts = finished(.week, [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
        counts["2026-09-08"] = 40
        #expect(kind(.week, counts) == .same)
    }

    @Test("days compare the last week with the three before it")
    func dayWindows() {
        let steady = Array(repeating: 2, count: 21) + Array(repeating: 4, count: 7)
        #expect(kind(.day, finished(.day, steady)) == .more)
        #expect(kind(.day, finished(.day, Array(repeating: 2, count: 13))) == .notEnough)
        #expect(kind(.day, finished(.day, Array(repeating: 2, count: 14))) == .same)
    }

    @Test("months compare the last three with the nine before")
    func monthWindows() {
        #expect(kind(.month, finished(.month, [10, 10, 10, 10, 10, 10, 10, 10, 10, 4, 4, 4])) == .fewer)
        #expect(kind(.month, finished(.month, [10, 10, 10, 10])) == .notEnough)
    }
}
