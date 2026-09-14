import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
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

    @Test("the shelf says it has not loaded until a reload has asked, even when it finds nothing")
    @MainActor func hasLoadedOnlyAfterAReload() async throws {
        let container = try ModelContainer(for: Habit.self, HabitLog.self, Tower.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let model = ReplayShelfModel()
        #expect(!model.hasLoaded)
        await model.reload(context: ModelContext(container), colorScheme: .light, displayScale: 1, now: Date())
        #expect(model.hasLoaded)
        #expect(model.months.isEmpty && model.weeks.isEmpty)
        withExtendedLifetime(container) {}
    }

    @Test("a cancelled reload stops before it decides anything")
    @MainActor func cancelledReloadStops() async throws {
        let container = try ModelContainer(for: Habit.self, HabitLog.self, Tower.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        _ = try QuickWinService.logWin(title: "Ran", category: .health, context: context, tower: nil)
        let model = ReplayShelfModel()
        // Cancelled before it runs: this test holds the main actor until the
        // await, so the task cannot have started.
        let task = Task { await model.reload(context: context, colorScheme: .light, displayScale: 1, now: Date()) }
        task.cancel()
        await task.value
        #expect(!model.hasLoaded)
        #expect(model.cards.isEmpty)
        // And an uncancelled one after it does the work.
        await model.reload(context: context, colorScheme: .light, displayScale: 1, now: Date())
        #expect(model.hasLoaded)
        withExtendedLifetime(container) {}
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

@Suite("Replay shelf posters")
struct ReplayPosterTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func month(_ m: Int, wins n: Int) -> Replay {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: m, day: 9))!
        let period = ReplayPeriod.month(containing: anchor, calendar: calendar)
        let wins = (0..<n).map { i -> ReplayWin in
            let day = i % period.days.count
            return ReplayWin(id: UUID(), dateString: period.days[day],
                             completedAt: period.date(ofDay: day).addingTimeInterval(Double(3600 + i)),
                             title: "Win", category: .health, size: .small, photo: nil)
        }
        return Replay(period: period, wins: wins)
    }

    @Test("a row shares one scale, so a bigger month stands taller than a smaller one")
    func sharedScale() {
        let big = month(8, wins: 86), small = month(7, wins: 40)
        let row = ReplayShelfModel.rowTowerHeight([big, small])
        let scale = ReplayCard.posterScale(rowTowerHeight: row)
        let cell = ReplayScript.Metrics.standard(frame: ReplayCard.size).cell
        let bigDrawn = GridConstants.gridHeight(rows: big.rows, cellSize: cell) * scale
        let smallDrawn = GridConstants.gridHeight(rows: small.rows, cellSize: cell) * scale
        #expect(big.rows > small.rows)
        #expect(bigDrawn > smallDrawn)
        // The tallest fills the poster less its margins, and nothing leaves it.
        #expect(bigDrawn <= ReplayCard.size.height - 2 * ReplayCard.posterMargin + 0.001)
        let width = GridConstants.gridWidth(cellSize: cell) * scale
        #expect(width <= ReplayCard.size.width - 2 * ReplayCard.posterMargin + 0.001)
    }

    @Test("a taller tower joining the row changes every poster's signature, and the scheme keys the cache")
    func rowAndScheme() {
        let r = month(7, wins: 40)
        #expect(ReplayShelfModel.signature(r, rowTowerHeight: 500, pixelScale: 1.1)
                != ReplayShelfModel.signature(r, rowTowerHeight: 620, pixelScale: 1.1))
        #expect(ReplayShelfModel.key(r, scheme: .light) != ReplayShelfModel.key(r, scheme: .dark))
    }
}
