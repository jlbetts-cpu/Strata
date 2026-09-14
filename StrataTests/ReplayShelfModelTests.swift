import CoreGraphics
import Foundation
import Testing
@testable import Strata

@Suite("Replay shelf")
struct ReplayShelfModelTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private func at(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    @Test("twelve finished months and four finished weeks, newest first")
    func finishedOnly() {
        let p = ReplayShelfModel.periods(now: at(9, 16), calendar: calendar)
        #expect(p.months.count == 12)
        #expect(p.months.first?.days.first == "2026-08-01")
        #expect(p.weeks.count == 4)
        #expect(p.weeks.first?.days.first == "2026-09-07")
    }

    @Test("a period whose window is open joins the front of its row")
    func openWindowJoins() {
        let p = ReplayShelfModel.periods(now: at(9, 30, 18), calendar: calendar)
        #expect(p.months.first?.days.first == "2026-09-01")
        #expect(p.months.count == 13)
    }

    @Test("the card's week name is short enough for a narrow card")
    func shortWeek() {
        let now = at(9, 16)
        let week = ReplayPeriod.week(containing: at(9, 9), calendar: calendar)
        #expect(ReplayShelf.name(of: week, now: now) == "7 to 13 Sep")
        let across = ReplayPeriod.week(containing: at(10, 1), calendar: calendar)
        #expect(ReplayShelf.name(of: across, now: now) == "28 Sep to 4 Oct")
        let month = ReplayPeriod.month(containing: at(8, 9), calendar: calendar)
        #expect(ReplayShelf.name(of: month, now: now) == "August")
    }

    @Test("an edit to a past period changes its signature, so its card redraws")
    func signature() {
        let period = ReplayPeriod.week(containing: at(9, 9), calendar: calendar)
        func win(_ i: Int, photo: ReplayPhoto?) -> ReplayWin {
            ReplayWin(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
                      dateString: period.days[i % 7], completedAt: period.date(ofDay: i % 7),
                      title: "Win", category: .health, size: .small, photo: photo)
        }
        let base = Replay(period: period, wins: [win(1, photo: nil), win(2, photo: nil)])
        let same = Replay(period: period, wins: [win(1, photo: nil), win(2, photo: nil)])
        let photographed = Replay(period: period, wins: [win(1, photo: .stored("a.jpg")), win(2, photo: nil)])
        let longer = Replay(period: period, wins: [win(1, photo: nil), win(2, photo: nil), win(3, photo: nil)])
        #expect(ReplayShelfModel.signature(base) == ReplayShelfModel.signature(same))
        #expect(ReplayShelfModel.signature(base) != ReplayShelfModel.signature(photographed))
        #expect(ReplayShelfModel.signature(base) != ReplayShelfModel.signature(longer))
    }
}

@Suite("Replay block hit testing")
struct ReplayBlockHitTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func script(_ kind: ReplayKind, wins n: Int) -> ReplayScript {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!
        let period = kind == .week ? ReplayPeriod.week(containing: anchor, calendar: calendar)
                                   : ReplayPeriod.month(containing: anchor, calendar: calendar)
        let sizes: [BlockSize] = [.small, .medium, .small, .hard, .small]
        let wins = (0..<n).map { i -> ReplayWin in
            let day = i % period.days.count
            return ReplayWin(id: UUID(), dateString: period.days[day],
                             completedAt: period.date(ofDay: day).addingTimeInterval(Double(3600 + i)),
                             title: "Win \(i)", category: .health, size: sizes[i % sizes.count], photo: nil)
        }
        return ReplayScript(replay: Replay(period: period, wins: wins),
                            metrics: .standard(frame: CGSize(width: 402, height: 874)), reduceMotion: false)
    }

    @Test("at the close, the centre of every block hits that block", arguments: [6, 31, 150])
    func centres(n: Int) {
        let s = script(n > 40 ? .month : .week, wins: n)
        for i in s.replay.blocks.indices {
            let r = s.screenRect(ofBlock: i, at: s.duration)
            #expect(s.block(at: CGPoint(x: r.midX, y: r.midY), t: s.duration) == i)
        }
    }

    @Test("the drawn rect's top is where the script already says a block's top is")
    func agreesWithScreenTop() {
        let s = script(.week, wins: 31)
        for i in s.replay.blocks.indices {
            #expect(abs(s.screenRect(ofBlock: i, at: s.duration).minY - s.screenTop(ofBlock: i, at: s.duration)) < 0.001)
        }
    }

    @Test("a tap well away from the tower hits nothing")
    func miss() {
        let s = script(.week, wins: 12)
        #expect(s.block(at: CGPoint(x: 201, y: 860), t: s.duration) == nil)
        #expect(s.block(at: CGPoint(x: 201, y: 10), t: s.duration) == nil)
    }

    @Test("a block drawn smaller than a finger still takes a tap just outside it")
    func slop() {
        let s = script(.month, wins: 150)
        #expect(s.fitScale < 0.3)
        let r = s.screenRect(ofBlock: 0, at: s.duration)
        #expect(r.width < 44)
        // Just below the base, under the first block.
        #expect(s.block(at: CGPoint(x: r.midX, y: r.maxY + 6), t: s.duration) != nil)
    }
}
