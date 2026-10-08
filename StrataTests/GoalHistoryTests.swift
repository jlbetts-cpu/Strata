import Testing
import Foundation
@testable import Strata

/// The goal's two weeks (2026-10-08): fourteen days before today, today left
/// out, and a sentence that counts days at or over the goal.
///
/// Self-test: include today in `GoalHistory.make` and `todayIsLeftOut` fails.
@Suite("Goal history")
struct GoalHistoryTests {
    let calendar = DateUtils.keyCalendar(in: TimeZone(identifier: "America/Los_Angeles")!)
    var today: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))! }

    @Test func fourteenDaysOldestFirst() {
        let h = GoalHistory.make(counts: ["2026-10-01": 2, "2026-10-14": 5], today: today, calendar: calendar)
        #expect(h.days.count == 14)
        #expect(h.days.first == 2 && h.days.last == 5)
    }

    @Test func todayIsLeftOut() {
        let h = GoalHistory.make(counts: ["2026-10-15": 9], today: today, calendar: calendar)
        #expect(h.days.allSatisfy { $0 == 0 })
    }

    @Test func theSentenceCountsDaysAtOrOverTheGoal() {
        let h = GoalHistory(days: [3, 4, 1, 0, 3, 2, 5, 3, 0, 1, 3, 2, 6, 3])
        #expect(h.reached(3) == 8)
        #expect(h.sentence(goal: 3) == "You reached 3 on 8 of the last 14 days.")
        #expect(GoalHistory(days: Array(repeating: 1, count: 14)).sentence(goal: 2) == "None of the last 14 days reached 2 yet.")
        #expect(!GoalHistory(days: [0, 0, 1] + Array(repeating: 0, count: 11)).isReadable)
    }
}
