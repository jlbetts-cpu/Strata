import CoreGraphics
import Foundation
import Testing
@testable import Strata

@Suite("Replay")
struct ReplayTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private var week: ReplayPeriod {
        ReplayPeriod.week(containing: calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!, calendar: calendar)
    }
    private var month: ReplayPeriod {
        ReplayPeriod.month(containing: calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!, calendar: calendar)
    }

    private func win(_ day: String, hour: Int, _ size: BlockSize = .small, _ title: String = "Walk") -> ReplayWin {
        let parts = day.split(separator: "-").map { Int($0)! }
        let at = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour))!
        return ReplayWin(id: UUID(), dateString: day, completedAt: at, title: title,
                         category: .health, size: size, photo: nil, crop: .zero)
    }

    @Test("wins drop in day order, then time order, and wins outside the period are ignored")
    func order() {
        let a = win("2026-09-08", hour: 9)
        let b = win("2026-09-07", hour: 20)
        let c = win("2026-09-07", hour: 8)
        let outside = win("2026-09-14", hour: 8)
        let r = Replay(period: week, wins: [a, b, c, outside])
        #expect(r.blocks.map(\.win.id) == [c.id, b.id, a.id])
        #expect(r.blocks.map(\.day) == [0, 0, 1])
        #expect(r.countsByDay == [2, 1, 0, 0, 0, 0, 0])
        #expect(r.count == 3)
    }

    @Test("packing is the tower's first-fit, in drop order")
    func packing() {
        let wins = [win("2026-09-07", hour: 8, .hard), win("2026-09-07", hour: 9, .small),
                    win("2026-09-07", hour: 10, .medium), win("2026-09-07", hour: 11, .small)]
        let r = Replay(period: week, wins: wins)
        var grid: [[Bool]] = []
        let expected = wins.map { w in
            GridPacker.firstFit(columnSpan: w.size.columnSpan, rowSpan: w.size.rowSpan,
                                columns: GridConstants.columnCount, grid: &grid)!
        }
        #expect(r.blocks.map { [$0.column, $0.row] } == expected.map { [$0.column, $0.row] })
        #expect(r.rows == (grid.lastIndex { $0.contains(true) }.map { $0 + 1 } ?? 0))
    }

    @Test("VoiceOver hears the title, the spoken range and the count, and nothing about a busiest day")
    func announcement() {
        var wins: [ReplayWin] = []
        for (day, n) in [("2026-09-07", 4), ("2026-09-08", 5), ("2026-09-09", 3), ("2026-09-10", 7),
                         ("2026-09-11", 4), ("2026-09-12", 5), ("2026-09-13", 3)] {
            wins += (0..<n).map { win(day, hour: 8 + $0) }
        }
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        let r = Replay(period: week, wins: wins)
        #expect(r.announcement(now: now) == "Your week, 7 to 13 September. 31 wins.")
        let one = Replay(period: week, wins: [win("2026-09-10", hour: 8)])
        #expect(one.announcement(now: now) == "Your week, 7 to 13 September. 1 win.")
        #expect(Replay(period: week, wins: []).announcement(now: now) == "Your week, 7 to 13 September. 0 wins.")
    }

    @Test("no wins, no rows")
    func empty() {
        #expect(Replay(period: week, wins: []).rows == 0)
    }
}
