import Testing
import Foundation
@testable import Strata

/// **What a folder says about its day.**
///
/// Two lines of text, and both of them are decisions rather than formatting.
@MainActor
@Suite("What a day's folder is labelled")
struct RecentDayTests {

    private func day(_ dateString: String, count: Int, isToday: Bool = false) -> RecentDay {
        RecentDay(id: dateString,
                  date: DateUtils.date(from: dateString) ?? Date(),
                  count: count, peek: [], isToday: isToday)
    }

    /// **The rule this app is built on**, in the one place a number could
    /// have broken it: state changes because somebody did something, never
    /// because they did not. "0 wins" is a score, and a score of zero is a
    /// mark against you on a screen you open every morning before you have
    /// done anything.
    ///
    /// This can fail: writing the count unconditionally puts the nought back.
    @Test("An empty day is never given a nought")
    func emptyDaysAreNotScored() {
        let label = day("2026-09-22", count: 0).countLabel
        #expect(label == "Nothing yet")
        #expect(!label.contains("0"))
    }

    @Test("One win is singular")
    func oneIsSingular() {
        #expect(day("2026-09-22", count: 1).countLabel == "1 win")
        #expect(day("2026-09-22", count: 2).countLabel == "2 wins")
        #expect(day("2026-09-22", count: 14).countLabel == "14 wins")
    }

    /// Today and yesterday get their words because that is what a person
    /// calls them; a date would make you do arithmetic to find out you are
    /// looking at this morning.
    @Test("Today and yesterday are named rather than dated")
    func nearDaysAreNamed() throws {
        let now = Date()
        let today = RecentDay(id: DateUtils.dateString(from: now),
                              date: now, count: 3, isToday: true)
        #expect(today.title(now: now) == "Today")

        let yesterdayDate = try #require(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let yesterday = RecentDay(id: DateUtils.dateString(from: yesterdayDate),
                                  date: yesterdayDate, count: 1)
        #expect(yesterday.title(now: now) == "Yesterday")
    }

    /// Anything older is the weekday and the day number, which is the
    /// shortest form still unambiguous inside a week — and it must never
    /// silently fall back to "Today" for a day that is not.
    @Test("An older day is dated, and is never mistaken for today")
    func olderDaysAreDated() throws {
        let now = Date()
        let old = try #require(Calendar.current.date(byAdding: .day, value: -5, to: now))
        let title = RecentDay(id: DateUtils.dateString(from: old),
                              date: old, count: 2).title(now: now)
        #expect(title != "Today")
        #expect(title != "Yesterday")
        #expect(!title.isEmpty)
    }

    /// The row is rebuilt whenever this changes, so equality has to notice a
    /// win landing. It compared ids alone once, and a win added to today did
    /// not redraw the folder it went into.
    @Test("A day that has gained a win is not equal to the one before it")
    func equalityNoticesAWin() {
        let before = day("2026-09-22", count: 3, isToday: true)
        let after = day("2026-09-22", count: 4, isToday: true)
        #expect(before != after)
        #expect(before == day("2026-09-22", count: 3, isToday: true))
    }
}
