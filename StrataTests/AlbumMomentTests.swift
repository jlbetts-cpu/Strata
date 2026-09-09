import Foundation
import Testing
@testable import Strata

/// The rules that make an album out of *when* something happened.
///
/// Date arithmetic is where this kind of feature goes wrong, and it goes wrong
/// on days nobody tests: the 29th of February, the end of a month that the
/// previous month does not have, the week that straddles a year boundary. All
/// of it goes through `Calendar` for that reason, and these pin the behaviour
/// on exactly those days.
struct AlbumMomentTests {

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Self.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func record(_ date: Date, title: String = "Ran 5k", photo: String? = "p.heic") -> WinRecord {
        WinRecord(dateString: DateUtils.dateString(from: date),
                  completedAt: date, title: title, category: .health,
                  size: .small, photoFileName: photo)
    }

    private func moments(_ records: [WinRecord], now: Date) -> [Album] {
        Album.moments(from: records, calendar: Self.calendar, now: now)
    }

    // MARK: - Round-tripping the id

    @Test func everyRuleSurvivesBeingARoute() {
        for moment in AlbumMoment.all {
            #expect(AlbumMoment(id: moment.id) == moment)
        }
    }

    @Test func nonsenseIdsAreRefused() {
        #expect(AlbumMoment(id: "") == nil)
        #expect(AlbumMoment(id: "onThisDay") == nil)
        #expect(AlbumMoment(id: "onThisDay:banana") == nil)
    }

    // MARK: - On this day

    @Test func onThisDayIsTheSameCalendarDateAYearBack() {
        let now = date(2026, 9, 9)
        let rule = AlbumMoment.onThisDay(years: 1)
        #expect(rule.contains(date(2025, 9, 9), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2025, 9, 8), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2025, 9, 10), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2024, 9, 9), calendar: Self.calendar, now: now))
    }

    @Test func onThisDayIgnoresTheTimeOfDay() {
        let now = date(2026, 9, 9, 23)
        let rule = AlbumMoment.onThisDay(years: 1)
        #expect(rule.contains(date(2025, 9, 9, 0), calendar: Self.calendar, now: now))
        #expect(rule.contains(date(2025, 9, 9, 23), calendar: Self.calendar, now: now))
    }

    /// A year before 29 February does not exist. `Calendar` clamps to the
    /// 28th rather than trapping, which is the behaviour to pin — subtracting
    /// 365 days would silently land on the 1st of March.
    @Test func aLeapDayDoesNotTrap() {
        let now = date(2024, 2, 29)
        let rule = AlbumMoment.onThisDay(years: 1)
        #expect(rule.contains(date(2023, 2, 28), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2023, 3, 1), calendar: Self.calendar, now: now))
    }

    // MARK: - This week last year

    @Test func weekLastYearCoversThatWholeWeek() {
        // 2026-09-09 is a Wednesday; a year back is 2025-09-09, a Tuesday,
        // whose Monday-first week runs 8th to 14th September 2025.
        let now = date(2026, 9, 9)
        let rule = AlbumMoment.weekLastYear
        #expect(rule.contains(date(2025, 9, 8), calendar: Self.calendar, now: now))
        #expect(rule.contains(date(2025, 9, 14, 23), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2025, 9, 7), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2025, 9, 15), calendar: Self.calendar, now: now))
    }

    // MARK: - Last month

    @Test func lastMonthIsTheWholePreviousMonth() {
        let now = date(2026, 9, 9)
        let rule = AlbumMoment.lastMonth
        #expect(rule.contains(date(2026, 8, 1), calendar: Self.calendar, now: now))
        #expect(rule.contains(date(2026, 8, 31, 23), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2026, 7, 31), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2026, 9, 1), calendar: Self.calendar, now: now))
    }

    /// The 31st of March has no counterpart in February. Subtracting a month
    /// must land inside February rather than skipping it.
    @Test func aShortPreviousMonthStillResolves() {
        let now = date(2026, 3, 31)
        let rule = AlbumMoment.lastMonth
        #expect(rule.contains(date(2026, 2, 14), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2026, 3, 14), calendar: Self.calendar, now: now))
    }

    @Test func lastMonthCrossesTheYearBoundary() {
        let now = date(2026, 1, 15)
        let rule = AlbumMoment.lastMonth
        #expect(rule.contains(date(2025, 12, 25), calendar: Self.calendar, now: now))
        #expect(!rule.contains(date(2026, 1, 2), calendar: Self.calendar, now: now))
    }

    // MARK: - Earning a card

    @Test func twoPhotographsDoNotEarnAMoment() {
        let now = date(2026, 9, 9)
        let records = (0..<2).map { record(date(2025, 9, 9, 9 + $0), photo: "a\($0).heic") }
        #expect(moments(records, now: now).isEmpty)
    }

    @Test func threePhotographsDo() {
        let now = date(2026, 9, 9)
        let records = (0..<3).map { record(date(2025, 9, 9, 9 + $0), photo: "a\($0).heic") }
        let built = moments(records, now: now)
        // Two, not one: a date exactly a year ago is also inside that week a
        // year ago, so it earns both cards. That is correct and wanted — see
        // `aDayCanBelongToMoreThanOneMoment`.
        #expect(built.count == 2)
        #expect(built.first?.title == "A year ago today")
        #expect(built.first?.subtitle == "3 PHOTOS")
    }

    @Test func winsWithoutPhotographsNeverCount() {
        let now = date(2026, 9, 9)
        let records = (0..<6).map { record(date(2025, 9, 9, 9 + $0), photo: nil) }
        #expect(moments(records, now: now).isEmpty)
    }

    /// One day can satisfy more than one rule — a year ago today is also in
    /// that week last year. Both cards are correct, and both are wanted.
    @Test func aDayCanBelongToMoreThanOneMoment() {
        let now = date(2026, 9, 9)
        let records = (0..<4).map { record(date(2025, 9, 9, 9 + $0), photo: "a\($0).heic") }
        let ids = moments(records, now: now).map(\.id)
        #expect(ids.contains("moment:onThisDay:1"))
        #expect(ids.contains("moment:weekLastYear"))
    }

    @Test func momentsComeBackNewestRuleFirst() {
        let now = date(2026, 9, 9)
        var records = (0..<4).map { record(date(2025, 9, 9, 9 + $0), photo: "y\($0).heic") }
        records += (0..<4).map { record(date(2026, 8, 5, 9 + $0), photo: "m\($0).heic") }
        let ids = moments(records, now: now).map(\.id)
        #expect(ids.first == "moment:onThisDay:1")
        #expect(ids.last == "moment:lastMonth")
    }
}
