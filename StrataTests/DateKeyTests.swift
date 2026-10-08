import Testing
import Foundation
@testable import Strata

/// **A day key is Gregorian on every phone** (2026-10-08).
///
/// On a phone set to the Buddhist calendar (Thailand's default) the key
/// formatter wrote "2569-10-08", and on the Japanese calendar the era's year;
/// crews (`CrewDay`) are Gregorian, so the same win was two different days.
/// The global locale is never changed here: each test hands the code a
/// Buddhist or Japanese calendar explicitly, which is what the phone would.
///
/// Self-test: put `calendar` back in `DayTitle.date(forKey:)`, `ReplayPeriod.key`
/// or `MonthDrawingStore.key` and the matching test fails with year 483 or 8.
@Suite("Date keys")
@MainActor
struct DateKeyTests {
    private func calendar(_ id: Calendar.Identifier, _ locale: String) -> Calendar {
        var c = Calendar(identifier: id)
        c.locale = Locale(identifier: locale)
        c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        return c
    }

    /// 8 October 2026, midday in Bangkok.
    private var day: Date {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        return g.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12))!
    }

    @Test("the key formatter is Gregorian and POSIX whatever the phone says")
    func theFormatterIsFixed() {
        let f = DateUtils.keyFormatter("yyyy-MM-dd")
        #expect(f.calendar.identifier == .gregorian)
        #expect(f.locale.identifier == "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Bangkok")
        #expect(f.string(from: day) == "2026-10-08")
        // What the old formatter wrote on a Thai phone, so this suite is
        // measuring the thing it claims to.
        let old = DateFormatter()
        old.calendar = calendar(.buddhist, "th_TH")
        old.locale = Locale(identifier: "th_TH")
        old.timeZone = TimeZone(identifier: "Asia/Bangkok")
        old.dateFormat = "yyyy-MM-dd"
        #expect(old.string(from: day) == "2569-10-08")
    }

    @Test("a key reads back as the Gregorian day on a Buddhist phone")
    func titlesReadGregorian() throws {
        let read = try #require(DayTitle.date(forKey: "2026-10-08", calendar: calendar(.buddhist, "th_TH")))
        var g = Calendar(identifier: .gregorian)
        g.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        #expect(g.dateComponents([.year, .month, .day], from: read) == DateComponents(year: 2026, month: 10, day: 8))
    }

    @Test("a replay's days are Gregorian keys on Buddhist and Japanese phones")
    func replayKeys() throws {
        #expect(ReplayPeriod.key(day, calendar: calendar(.buddhist, "th_TH")) == "2026-10-08")
        #expect(ReplayPeriod.key(day, calendar: calendar(.japanese, "ja_JP")) == "2026-10-08")
        let one = try #require(ReplayPeriod.day("2026-10-08", name: nil, calendar: calendar(.buddhist, "th_TH")))
        #expect(one.days == ["2026-10-08"])
        #expect(Calendar(identifier: .gregorian).component(.year, from: one.firstDay) == 2026)
    }

    @Test("a month drawing's key is the Gregorian month")
    func monthKeys() {
        #expect(MonthDrawingStore.key(for: day, calendar: calendar(.buddhist, "th_TH")) == "2026-10")
        #expect(MonthDrawingStore.key(for: day, calendar: calendar(.japanese, "ja_JP")) == "2026-10")
    }

    @Test("the key calendar keeps the zone it is given")
    func zoneIsKept() {
        let zone = TimeZone(identifier: "Pacific/Auckland")!
        let c = DateUtils.keyCalendar(in: zone)
        #expect(c.identifier == .gregorian)
        #expect(c.timeZone == zone)
    }
}
