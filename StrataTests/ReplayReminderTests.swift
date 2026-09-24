import Foundation
import SwiftData
import Testing
@testable import Strata

@Suite("Replay reminders and entry")
struct ReplayReminderTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private func at(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    @Test("the coming Sunday and 1st are scheduled when their periods have wins")
    func scheduledWithWins() {
        let up = ReplayReminder.upcoming(now: at(9, 9), calendar: calendar) { _ in true }
        #expect(up.map(\.date).contains(at(9, 13, 18)))
        #expect(up.map(\.date).contains(at(10, 1, 10)))
        #expect(up.first { $0.date == at(9, 13, 18) }?.title == "Your week is ready")
        #expect(up.first { $0.date == at(10, 1, 10) }?.title == "September is ready")
    }

    @Test("nothing is scheduled for a period without wins")
    func nothingWithoutWins() {
        #expect(ReplayReminder.upcoming(now: at(9, 9), calendar: calendar) { _ in false }.isEmpty)
    }

    @Test("a time already passed is not scheduled")
    func pastNotScheduled() {
        let up = ReplayReminder.upcoming(now: at(9, 13, 19), calendar: calendar) { _ in true }
        #expect(!up.map(\.date).contains(at(9, 13, 18)))
    }

    @Test("the pill wakes at the next window edge: Sunday 5pm, Tuesday as it starts, the last day 5pm, the 3rd")
    func nextEdge() {
        // Wednesday 9 September, noon: the week's window opens Sunday 13 at 5pm.
        #expect(ReplayEntry.nextEdge(after: at(9, 9), calendar: calendar) == at(9, 13, 17))
        // Sunday 13 at 6pm, the week open: it closes as Tuesday 15 starts.
        #expect(ReplayEntry.nextEdge(after: at(9, 13, 18), calendar: calendar) == at(9, 15, 0))
        // Exactly on an edge: the NEXT one, never the same instant again.
        #expect(ReplayEntry.nextEdge(after: at(9, 13, 17), calendar: calendar) == at(9, 15, 0))
        // Tuesday 29 September, noon: the last week's window closed at
        // midnight and the next opens on 4 October, so the month opens
        // first, 30 September at 5pm.
        #expect(ReplayEntry.nextEdge(after: at(9, 29), calendar: calendar) == at(9, 30, 17))
        // 2 October: the month's window closes as the 3rd starts.
        #expect(ReplayEntry.nextEdge(after: at(10, 2), calendar: calendar) == at(10, 3, 0))
        // Every edge found is in the future.
        var t = at(1, 1)
        while t < at(12, 31) {
            let e = ReplayEntry.nextEdge(after: t, calendar: calendar)
            #expect(e != nil && e! > t)
            t = e ?? at(12, 31)
        }
    }

    @Test("the pill: the month wins when both windows are open")
    func monthWins() {
        // 30 September 2026 is a Wednesday; use a month ending on a Sunday: May 2026 ends Sunday 31.
        let live = ReplayEntry.live(now: at(5, 31, 18), calendar: calendar) { _ in true }
        #expect(live?.kind == .month)
        #expect(ReplayEntry.live(now: at(9, 13, 18), calendar: calendar) { _ in true }?.kind == .week)
        #expect(ReplayEntry.live(now: at(9, 13, 18), calendar: calendar) { _ in false } == nil)
    }

    @Test("copy has no long dashes")
    func copy() {
        for item in ReplayReminder.upcoming(now: at(9, 9), calendar: calendar, hasWins: { _ in true }) {
            #expect(!(item.title + item.body).contains("—") && !(item.title + item.body).contains("–"))
        }
    }
}

/// `ReplayLoader.hasWins` had no test at all. A limit-1 fetch count is easy to
/// get backwards (an empty period reading as having wins, or the reverse), and
/// it is the one call `ReplayReminder.schedule` and the pill both hang on.
@MainActor
@Suite("ReplayLoader.hasWins")
struct ReplayLoaderHasWinsTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test("a period with a completed win today reports true")
    func trueWithAWin() throws {
        let context = try context()
        _ = try QuickWinService.logWin(title: "Ran", category: .health, context: context, tower: nil)
        let week = ReplayPeriod.week(containing: Date())
        #expect(ReplayLoader.hasWins(week, context: context))
    }

    @Test("a period with no wins reports false")
    func falseWithNoWins() throws {
        let context = try context()
        let week = ReplayPeriod.week(containing: Date())
        #expect(!ReplayLoader.hasWins(week, context: context))
    }

    /// A skipped habit's log, the way the Plan leaves one: not completed,
    /// skipped, with its habit. The tower draws it as a block.
    private func skippedLog(on day: Date, context: ModelContext) throws -> HabitLog {
        let habit = Habit(title: "Stretch", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: DateUtils.dateString(from: day), completed: false)
        log.skipped = true
        context.insert(log)
        try context.save()
        return log
    }

    @Test("a skipped log is a block, as on the tower: hasWins, the replay and Replay.wins agree")
    func skippedCountsLikeTheTower() throws {
        let context = try context()
        let log = try skippedLog(on: Date(), context: context)
        let week = ReplayPeriod.week(containing: Date())
        #expect(Replay.isBlock(log))
        #expect(ReplayLoader.hasWins(week, context: context))
        let replay = ReplayLoader.replay(for: week, context: context)
        #expect(replay.count == 1, "hasWins said yes and the replay had \(replay.count) blocks")
        #expect(Replay.wins(from: [log]).count == 1)
    }

    @Test("a log neither completed nor skipped is no block: hasWins says no and the replay is empty")
    func undoneLogIsNothing() throws {
        let context = try context()
        let log = try skippedLog(on: Date(), context: context)
        log.skipped = false
        try context.save()
        let week = ReplayPeriod.week(containing: Date())
        #expect(!Replay.isBlock(log))
        #expect(!ReplayLoader.hasWins(week, context: context))
        #expect(ReplayLoader.replay(for: week, context: context).count == 0)
    }

    @Test("a win outside the period's days does not count")
    func falseWhenWinIsOutsideRange() throws {
        let context = try context()
        let longAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        _ = try QuickWinService.logWin(title: "Old", category: .health, on: longAgo, context: context, tower: nil)
        let week = ReplayPeriod.week(containing: Date())
        #expect(!ReplayLoader.hasWins(week, context: context))
    }
}
