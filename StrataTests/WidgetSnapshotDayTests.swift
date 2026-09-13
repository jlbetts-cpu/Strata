import Testing
import Foundation
@testable import Strata

/// The widget redraws just after midnight from whatever the app last wrote.
@Suite("Widget snapshot across midnight")
struct WidgetSnapshotDayTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func day(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: h))!
    }

    private func snapshot(today: Int, streak: Int, writtenOn written: Date) -> WidgetSnapshot {
        let block = WidgetSnapshot.Block(columns: 1, rows: 1, hex: "10B77F", photo: "a.jpg")
        return WidgetSnapshot(total: 40, today: today, streak: streak,
                              blocks: Array(repeating: block, count: today), updated: written)
    }

    @Test("the same day draws as written")
    func sameDay() {
        let s = snapshot(today: 6, streak: 5, writtenOn: day(12, 9))
        #expect(s.asOf(day(12, 23), calendar: calendar) == s)
    }

    @Test("the next day, yesterday's wins are not today's")
    func nextDayEmptiesToday() {
        let s = snapshot(today: 6, streak: 5, writtenOn: day(12, 21)).asOf(day(13, 0), calendar: calendar)
        #expect(s.today == 0)
        #expect(s.blocks.isEmpty)
        #expect(s.photos.isEmpty)
        // Lifetime never goes backwards.
        #expect(s.total == 40)
    }

    @Test("a streak survives one empty morning and not a whole empty day")
    func streakFollowsTheOneDayGrace() {
        let won = snapshot(today: 6, streak: 5, writtenOn: day(12, 21))
        #expect(won.asOf(day(13, 8), calendar: calendar).streak == 5)
        #expect(won.asOf(day(14, 8), calendar: calendar).streak == 0)

        // Written on a day with no wins yet: the run already ended the day
        // before, so the next morning it has had a whole empty day.
        let quiet = snapshot(today: 0, streak: 5, writtenOn: day(12, 9))
        #expect(quiet.asOf(day(13, 8), calendar: calendar).streak == 0)
    }
}
