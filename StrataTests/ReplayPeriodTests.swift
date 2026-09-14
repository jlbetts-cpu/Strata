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

    @Test("range strings")
    func ranges() {
        let now = at(2026, 9, 13)
        #expect(ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar).range(relativeTo: now) == "7 to 13 September")
        #expect(ReplayPeriod.week(containing: at(2026, 10, 1), calendar: calendar).range(relativeTo: now) == "28 September to 4 October")
        #expect(ReplayPeriod.week(containing: at(2025, 9, 10), calendar: calendar).range(relativeTo: now) == "8 to 14 September 2025")
        #expect(ReplayPeriod.month(containing: at(2026, 9, 9), calendar: calendar).range(relativeTo: now) == "September")
        #expect(ReplayPeriod.month(containing: at(2025, 9, 9), calendar: calendar).range(relativeTo: now) == "September 2025")
    }

    @Test("labels: weekday names for a week, day numbers for a month; ordinals in sentences")
    func labels() {
        let week = ReplayPeriod.week(containing: at(2026, 9, 9), calendar: calendar)
        let month = ReplayPeriod.month(containing: at(2026, 9, 9), calendar: calendar)
        #expect(week.label(forDay: 0) == "Monday")
        #expect(week.label(forDay: 6) == "Sunday")
        #expect(month.label(forDay: 13) == "14")
        #expect(week.dayName(3, capitalised: false) == "Thursday")
        #expect(month.dayName(0, capitalised: true) == "The 1st")
        #expect(month.dayName(1, capitalised: false) == "the 2nd")
        #expect(month.dayName(2, capitalised: false) == "the 3rd")
        #expect(month.dayName(10, capitalised: false) == "the 11th")
        #expect(month.dayName(11, capitalised: false) == "the 12th")
        #expect(month.dayName(12, capitalised: false) == "the 13th")
        #expect(month.dayName(20, capitalised: false) == "the 21st")
        #expect(month.dayName(22, capitalised: false) == "the 23rd")
    }

    @Test("finished periods are newest first and exclude the one still running")
    func finished() {
        let weeks = ReplayPeriod.finished(.week, before: at(2026, 9, 16), count: 4, calendar: calendar)
        #expect(weeks.map { $0.days.first! } == ["2026-09-07", "2026-08-31", "2026-08-24", "2026-08-17"])
        let months = ReplayPeriod.finished(.month, before: at(2026, 9, 16), count: 2, calendar: calendar)
        #expect(months.map { $0.days.first! } == ["2026-08-01", "2026-07-01"])
    }
}
