import Testing
import Foundation
@testable import Strata

/// Which days the reminder fires on.
@Suite("Daily reminder")
struct DailyReminderTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    @Test("a day that already has a win is not reminded")
    func skipsTodayOnceThereIsAWin() {
        let days = DailyReminder.days(from: at(13, 9), hour: 20, minute: 0, loggedToday: true, calendar: calendar)
        #expect(days.first == at(14, 20))
        #expect(days.count == DailyReminder.horizon - 1)
    }

    @Test("a day with nothing yet is reminded later that day")
    func remindsTodayWhenEmpty() {
        let days = DailyReminder.days(from: at(13, 9), hour: 20, minute: 0, loggedToday: false, calendar: calendar)
        #expect(days.first == at(13, 20))
        #expect(days.count == DailyReminder.horizon)
    }

    @Test("a reminder time that has already gone today starts tomorrow")
    func pastTimeStartsTomorrow() {
        let days = DailyReminder.days(from: at(13, 21), hour: 20, minute: 0, loggedToday: false, calendar: calendar)
        #expect(days.first == at(14, 20))
    }

    @Test("one reminder a day, each on its own day, across a month's end")
    func oneADay() {
        let days = DailyReminder.days(from: at(25, 9), hour: 8, minute: 30, loggedToday: false, calendar: calendar)
        #expect(days.first == at(26, 8, 30))   // 8:30 on the 25th has already gone
        let keys = Set(days.map { calendar.dateComponents([.year, .month, .day], from: $0) })
        #expect(keys.count == days.count)
        #expect(days.allSatisfy { calendar.component(.hour, from: $0) == 8 && calendar.component(.minute, from: $0) == 30 })
    }
}
