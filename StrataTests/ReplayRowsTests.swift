import Foundation
import Testing
@testable import Strata

/// **Which replays the Memories page offers, and that the week can reach one.**
///
/// The Wins tab's `headerReplayPill` was deleted on 2026-10-01 and it was the
/// only route in the app to the open WEEK's replay. The owner's call, with that
/// cost named, was that all replays live in Memories. `ReplayShelfModel.live` is
/// the rule the page uses to put the second row there, and this is the test that
/// can fail if it stops working: `weekIsReachable` is the regression itself.
@Suite("Replay rows on Memories")
struct ReplayRowsTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func at(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    /// Every replay the shelf would hold at `now`, each with one win on its
    /// first day so none of them is empty.
    private func loaded(at now: Date) -> [Replay] {
        let p = ReplayShelfModel.periods(now: now, calendar: calendar)
        return (p.months + p.weeks).map { period in
            Replay(period: period, wins: [
                ReplayWin(id: UUID(), dateString: period.days[0],
                          completedAt: period.firstDay, title: "Win",
                          category: .health, size: .small, photo: nil)
            ])
        }
    }

    private func replay(_ kind: ReplayKind, containing date: Date) -> Replay {
        let period = kind == .week
            ? ReplayPeriod.week(containing: date, calendar: calendar)
            : ReplayPeriod.month(containing: date, calendar: calendar)
        return Replay(period: period, wins: [
            ReplayWin(id: UUID(), dateString: period.days[0], completedAt: period.firstDay,
                      title: "Win", category: .health, size: .small, photo: nil)
        ])
    }

    /// **The regression this exists for.** Sunday 13 September at 6pm: the
    /// week's window is open, the month's is not, and the page is showing
    /// September. Before the second row there was no route to that week from
    /// anywhere in the app.
    @Test("a week whose window is open is offered beside the month")
    func weekIsReachable() {
        let now = at(9, 13, 18)
        let month = replay(.month, containing: now)
        let live = ReplayShelfModel.live(in: loaded(at: now), besides: month,
                                         now: now, calendar: calendar)
        #expect(live?.period.kind == .week)
        #expect(live?.period.days.first == "2026-09-07")
    }

    /// Nothing is open on an ordinary Wednesday, so the page shows one row.
    @Test("no open window, no second row")
    func quietDay() {
        let now = at(9, 16)
        #expect(ReplayShelfModel.live(in: loaded(at: now), besides: replay(.month, containing: now),
                                      now: now, calendar: calendar) == nil)
    }

    /// The turn of a month: September's window is open and the picker is on
    /// October, so the page offers both.
    @Test("at the turn of a month the open month gets the second row")
    func turnOfTheMonth() {
        let now = at(10, 1, 9)
        let october = replay(.month, containing: now)
        let live = ReplayShelfModel.live(in: loaded(at: now), besides: october,
                                         now: now, calendar: calendar)
        #expect(live?.period.kind == .month)
        #expect(live?.period.days.first == "2026-09-01")
    }

    /// **One row, not two.** Step the picker back to September on the 1st of
    /// October and the first row already IS the open period.
    @Test("the open period is not offered twice")
    func dedupe() {
        let now = at(10, 1, 9)
        let september = replay(.month, containing: at(9, 15))
        #expect(ReplayShelfModel.live(in: loaded(at: now), besides: september,
                                      now: now, calendar: calendar) == nil)
    }

    /// **A week beats a month here, which inverts `ReplayEntry.live`.** Sunday
    /// 31 May at 6pm has both windows open. `ReplayEntry` prefers the month
    /// because "the week is on its shelf either way", and the week is on no
    /// shelf any more, while a month is one named tap away in the picker.
    @Test("both windows open: the week wins, where the notification prefers the month")
    func weekBeatsMonth() {
        let now = at(5, 31, 18)
        let june = replay(.month, containing: at(6, 15))
        let live = ReplayShelfModel.live(in: loaded(at: now), besides: june,
                                         now: now, calendar: calendar)
        #expect(live?.period.kind == .week)
        // The rule the notifications still use, and the two differ on purpose.
        let reminder = ReplayEntry.live(now: now, calendar: calendar) { _ in true }
        #expect(reminder?.kind == .month)
    }

    /// A period whose replay the shelf never loaded (no wins in it) is not
    /// offered: the row would open an empty replay, which is the fault the Wins
    /// pill had before `hasWins` was added to it.
    @Test("an open period with no wins is not offered")
    func emptyPeriodIsNotOffered() {
        let now = at(9, 13, 18)
        #expect(ReplayShelfModel.live(in: [], besides: nil, now: now, calendar: calendar) == nil)
    }
}
