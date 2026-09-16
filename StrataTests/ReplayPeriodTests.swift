import Foundation
import Testing
@testable import Strata

@Suite("Replay periods")
struct ReplayPeriodTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("a week runs Monday to Sunday, whatever day it is asked from")
    func weekIsMondayToSunday() {
        // 13 September 2026 is a Sunday.
        let fromSunday = ReplayPeriod.week(containing: at(2026, 9, 13), calendar: calendar)
        let fromWednesday = ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar)
        #expect(fromSunday.days.first == "2026-09-07")
        #expect(fromSunday.days.last == "2026-09-13")
        #expect(fromSunday == fromWednesday)
        #expect(fromSunday.days.count == 7)
    }

    @Test("a week crossing a month keeps seven consecutive days")
    func weekAcrossMonth() {
        let p = ReplayPeriod.week(containing: at(2026, 10, 1), calendar: calendar)
        #expect(p.days == ["2026-09-28", "2026-09-29", "2026-09-30",
                           "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"])
    }

    @Test("days come from the calendar, so a DST week is still seven days")
    func weekAcrossDST() {
        // US clocks go back on 1 November 2026.
        let p = ReplayPeriod.week(containing: at(2026, 11, 1), calendar: calendar)
        #expect(p.days.count == 7)
        #expect(p.days.last == "2026-11-01")
    }

    @Test("a month has its own length")
    func monthLengths() {
        #expect(ReplayPeriod.month(containing: at(2026, 2, 10), calendar: calendar).days.count == 28)
        #expect(ReplayPeriod.month(containing: at(2028, 2, 10), calendar: calendar).days.count == 29)
        #expect(ReplayPeriod.month(containing: at(2026, 9, 30), calendar: calendar).days.count == 30)
    }

    @Test("the week window opens Sunday at 5pm and closes as Tuesday starts")
    func weekWindow() {
        #expect(ReplayPeriod.current(.week, at: at(2026, 9, 13, 16, 59), calendar: calendar) == nil)
        #expect(ReplayPeriod.current(.week, at: at(2026, 9, 13, 17), calendar: calendar)?.days.first == "2026-09-07")
        #expect(ReplayPeriod.current(.week, at: at(2026, 9, 14, 23, 59), calendar: calendar)?.days.first == "2026-09-07")
        #expect(ReplayPeriod.current(.week, at: at(2026, 9, 15, 0, 0), calendar: calendar) == nil)
    }

    @Test("the month window opens on the last day at 5pm and closes as the 3rd starts")
    func monthWindow() {
        #expect(ReplayPeriod.current(.month, at: at(2026, 9, 30, 16, 59), calendar: calendar) == nil)
        #expect(ReplayPeriod.current(.month, at: at(2026, 9, 30, 17), calendar: calendar)?.days.first == "2026-09-01")
        #expect(ReplayPeriod.current(.month, at: at(2026, 10, 2, 23, 59), calendar: calendar)?.days.first == "2026-09-01")
        #expect(ReplayPeriod.current(.month, at: at(2026, 10, 3, 0, 0), calendar: calendar) == nil)
    }

    @Test("notifications: Sunday 6pm for a week, the 1st at 10am for a month")
    func notificationDates() {
        let week = ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar)
        let month = ReplayPeriod.month(containing: at(2026, 9, 9), calendar: calendar)
        #expect(week.notificationDate == at(2026, 9, 13, 18))
        #expect(month.notificationDate == at(2026, 10, 1, 10))
    }

    @Test("a week's range is numbers and a hyphen, in the reader's order, with the year only when it is not this year's")
    func ranges() {
        let now = at(2026, 9, 13)
        let us = Locale(identifier: "en_US")
        #expect(ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar).range(relativeTo: now, locale: us) == "9/7-9/13")
        #expect(ReplayPeriod.week(containing: at(2026, 10, 1), calendar: calendar).range(relativeTo: now, locale: us) == "9/28-10/4")
        #expect(ReplayPeriod.week(containing: at(2025, 9, 10), calendar: calendar).range(relativeTo: now, locale: us) == "9/8/25-9/14/25")
        // Across New Year, seen from the new year: both ends carry their year.
        let newYear = ReplayPeriod.week(containing: at(2025, 12, 31), calendar: calendar)
        #expect(newYear.range(relativeTo: at(2026, 1, 5), locale: us) == "12/29/25-1/4/26")
        // Day before month where the reader writes it that way.
        let gb = ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar)
            .range(relativeTo: now, locale: Locale(identifier: "en_GB"))
        #expect(gb == "07/09-13/09", "the UK reads \(gb)")
        // A reader who writes dates with hyphens gets a spaced hyphen between
        // the ends, never one run of numbers and never a long dash.
        let nl = ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar)
            .range(relativeTo: now, locale: Locale(identifier: "nl_NL"))
        #expect(nl.contains(" - ") && !nl.contains("\u{2013}") && !nl.contains("\u{2014}"), "Dutch reads \(nl)")
        #expect(nl.hasPrefix("7-9") && nl.hasSuffix("13-9"), "Dutch reads \(nl)")
        #expect(ReplayPeriod.month(containing: at(2026, 9, 9), calendar: calendar).range(relativeTo: now, locale: us) == "September")
        #expect(ReplayPeriod.month(containing: at(2025, 9, 9), calendar: calendar).range(relativeTo: now, locale: us) == "September 2025")
    }

    @Test("no long dash in any range, printed or spoken")
    func noLongDashes() {
        let now = at(2026, 9, 13)
        for date in [at(2026, 9, 9), at(2026, 10, 1), at(2025, 12, 31), at(2025, 9, 10)] {
            for p in [ReplayPeriod.week(containing: date, calendar: calendar), ReplayPeriod.month(containing: date, calendar: calendar)] {
                for text in [p.range(relativeTo: now), p.range(relativeTo: now, locale: Locale(identifier: "en_US")), p.spokenRange(relativeTo: now)] {
                    #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"), "\(text)")
                }
            }
        }
    }

    @Test("the spoken range keeps the words, for VoiceOver")
    func spokenRanges() {
        let now = at(2026, 9, 13)
        #expect(ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar).spokenRange(relativeTo: now) == "7 to 13 September")
        #expect(ReplayPeriod.week(containing: at(2026, 10, 1), calendar: calendar).spokenRange(relativeTo: now) == "28 September to 4 October")
        #expect(ReplayPeriod.week(containing: at(2025, 9, 10), calendar: calendar).spokenRange(relativeTo: now) == "8 September 2025 to 14 September 2025")
        // Across New Year, seen from the new year: the same rule as the printed range.
        #expect(ReplayPeriod.week(containing: at(2025, 12, 31), calendar: calendar).spokenRange(relativeTo: at(2026, 1, 5))
                == "29 December 2025 to 4 January 2026")
        #expect(ReplayPeriod.month(containing: at(2025, 9, 9), calendar: calendar).spokenRange(relativeTo: now) == "September 2025")
    }

    @Test("finished periods are newest first and exclude the one still running")
    func finished() {
        let weeks = ReplayPeriod.finished(.week, before: at(2026, 9, 16), count: 4, calendar: calendar)
        #expect(weeks.map { $0.days.first! } == ["2026-09-07", "2026-08-31", "2026-08-24", "2026-08-17"])
        let months = ReplayPeriod.finished(.month, before: at(2026, 9, 16), count: 2, calendar: calendar)
        #expect(months.map { $0.days.first! } == ["2026-08-01", "2026-07-01"])
    }
}
