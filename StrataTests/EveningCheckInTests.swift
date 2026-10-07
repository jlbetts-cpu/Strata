import Testing
import Foundation
@testable import Strata

/// **The evening's one question** (2026-10-06): one cue a day, whichever
/// way it comes.
@Suite("Evening check-in")
struct EveningCheckInTests {
    let calendar = Calendar.current
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
    func when(_ wins: Int, first: Date?, now: Date, seen: Bool = false) -> Date? {
        EveningCheckIn.when(winsToday: wins, firstWin: first, now: now, morningHour: 8, morningMinute: 0, cueSeenToday: seen)
    }

    @Test("a day with one or two wins, logged before the morning reminder, is asked at 7pm")
    func asks() {
        #expect(when(1, first: at(7, 30), now: at(12)) == at(19))
        #expect(when(2, first: at(7, 30), now: at(18)) == at(19))
    }

    @Test("never twice in a day: not after the morning reminder fired, not after the cue was seen")
    func once() {
        #expect(when(1, first: at(9), now: at(12)) == nil, "the morning reminder already asked")
        #expect(when(1, first: at(7), now: at(12), seen: true) == nil, "the tower already asked")
    }

    @Test("an empty day is the morning's, a good day is left alone, and a past evening is gone")
    func not() {
        #expect(when(0, first: nil, now: at(12)) == nil)
        #expect(when(3, first: at(7), now: at(12)) == nil)
        #expect(when(1, first: at(7), now: at(19, 30)) == nil)
    }

    @Test("it asks in the cue's own words, with the reminder's log actions, and lands on Wins")
    func words() {
        #expect(EveningCheckIn.title == WinCue.anythingElse)
        #expect(NotificationRoute.of(identifier: EveningCheckIn.identifier(for: Date()), userInfo: [:]) == .wins)
    }
}
