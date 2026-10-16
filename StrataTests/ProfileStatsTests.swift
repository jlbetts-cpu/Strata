import Foundation
import Testing
@testable import Strata

/// **Your Stats** (2026-10-15): this week against last, the record so far,
/// and a favourite only when there is one.
@Suite("Your Stats")
struct ProfileStatsTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 1
        return calendar
    }

    func win(_ day: String, _ colour: HabitCategory = .health, _ size: BlockSize = .small,
             photo: Bool = false) -> ProfileStats.Win {
        ProfileStats.Win(dateString: day, category: colour, size: size, hasPhoto: photo)
    }

    /// Thursday 15 October 2026; its week runs Sunday 11 to Saturday 17.
    var today: Date { DateUtils.date(from: "2026-10-15")! }

    @Test("this week is counted against the week before")
    func weeks() {
        let stats = ProfileStats.make([
            win("2026-10-12"), win("2026-10-14"), win("2026-10-15"),
            win("2026-10-06"),
            win("2026-09-20"),
        ], today: today, calendar: calendar)
        #expect(stats.thisWeek == 3)
        #expect(stats.lastWeek == 1)
        #expect(stats.weekCompared == "2 more than last week")
        #expect(stats.wins == 5)
    }

    @Test("the score, the photos, and the size scale")
    func record() {
        let stats = ProfileStats.make([win("2026-10-12", .work, .hard, photo: true),
                                       win("2026-10-13", .work, .medium),
                                       win("2026-10-14", .health, .small, photo: true)],
                                      today: today, calendar: calendar)
        #expect(stats.score == 6)
        #expect(stats.photos == 2)
        #expect(stats.topColour == .work)
    }

    @Test("a tie names no favourite colour, and a few wins name no best day")
    func ties() {
        let stats = ProfileStats.make([win("2026-10-12", .work), win("2026-10-13", .health)],
                                      today: today, calendar: calendar)
        #expect(stats.topColour == nil)
        #expect(stats.bestDay == nil)
        #expect(ProfileStats.make([], today: today, calendar: calendar).weekCompared == "Same as last week")
    }

    @Test("the day most wins land on")
    func bestDay() {
        let stats = ProfileStats.make([win("2026-10-06"), win("2026-10-13"), win("2026-10-14")],
                                      today: today, calendar: calendar)
        #expect(stats.bestDay == "Tuesday")
    }
}
