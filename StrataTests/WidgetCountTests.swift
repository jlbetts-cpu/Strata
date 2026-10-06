import Testing
import Foundation
@testable import Strata

/// A win logged from a widget, Control Center, the Lock Screen, Siri or the
/// reminder used to leave the widgets showing the count they already had: only
/// the open app wrote the snapshot (found 2026-10-06).
@Suite("Widgets count a win logged outside the app")
struct WidgetCountTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func at(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test("one more win: today and the total go up, the streak only on the day's first")
    func afterWin() {
        let morning = WidgetSnapshot(total: 10, today: 2, streak: 4, blocks: [], updated: at(6, 8))
        let next = morning.afterWin(todayCount: 3, now: at(6, 12), calendar: calendar)
        #expect(next.today == 3 && next.total == 11 && next.streak == 4)

        let yesterday = WidgetSnapshot(total: 10, today: 2, streak: 4, blocks: [], updated: at(5, 20))
        let first = yesterday.afterWin(todayCount: 1, now: at(6, 9), calendar: calendar)
        #expect(first.today == 1, "a new day starts from zero")
        #expect(first.streak == 5, "the day's first win carries the streak")
    }

    @Test("the intent writes the snapshot before it asks the widgets to redraw")
    func intentWrites() throws {
        let intent = SourceSweep.code(try SourceSweep.read("Strata/Intents/LogWinIntent.swift"))
        let write = try #require(intent.range(of: "afterWin(todayCount:"))
        let reload = try #require(intent.range(of: "WidgetReloader.reload()"))
        #expect(write.lowerBound < reload.lowerBound)
    }
}
