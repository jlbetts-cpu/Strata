import Testing
import Foundation
@testable import Strata

/// A crew's days as numbers: the streak everyone keeps together.
@Suite("Crew history")
struct CrewHistoryTests {
    let zone = TimeZone(identifier: "America/Los_Angeles")!
    let jayden = UUID()
    let sam = UUID()
    let crew = CrewID(rawValue: "crew-test")

    func date(_ day: String, hour: Int = 12) -> Date {
        CrewDay.start(of: day, in: zone)!.addingTimeInterval(Double(hour) * 3600)
    }

    func member(_ id: UUID, joined day: String) -> CrewMember {
        CrewMember(profileID: id, firstName: id == jayden ? "Jayden" : "Sam", head: nil, joinedAt: date(day, hour: 1))
    }

    func win(_ who: UUID, on day: String) -> SharedWin {
        SharedWin(winID: UUID(), crewID: crew, senderProfileID: who, crewDay: day, title: "Gym",
                  colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                  createdAt: date(day), updatedAt: date(day))
    }

    /// A crew of two still needs both (half of two, at least two).
    @Test func aDayCountsOnlyWhenEveryonePosted() {
        var history = CrewHistory()
        let members = [member(jayden, joined: "2026-09-28"), member(sam, joined: "2026-09-28")]
        history.record([win(jayden, on: "2026-09-29"), win(sam, on: "2026-09-29"),
                        win(jayden, on: "2026-09-30"), win(sam, on: "2026-09-30"),
                        win(jayden, on: "2026-10-01")],
                       from: "2026-09-29", through: "2026-10-01")
        let full = history.keptDays(members: members, zone: zone)
        #expect(full == ["2026-09-29", "2026-09-30"])
        // Today is still open: the streak runs through yesterday.
        #expect(CrewHistory.streak(full, today: "2026-10-01", zone: zone) == 2)
        #expect(CrewHistory.best(full, zone: zone) == 2)
        #expect(history.waiting(today: "2026-10-01", members: members).map(\.profileID) == [sam])
    }

    /// **Half the crew keeps the day** (2026-10-09): in a crew of four, two
    /// posting is a kept day and one is not; in a crew of five it takes three.
    @Test func halfTheCrewKeepsTheDay() {
        let four = (0..<4).map { _ in UUID() }
        var history = CrewHistory()
        let members = four.map { member($0, joined: "2026-09-28") }
        history.record([win(four[0], on: "2026-09-29"), win(four[1], on: "2026-09-29"),
                        win(four[2], on: "2026-09-30")],
                       from: "2026-09-29", through: "2026-09-30")
        #expect(history.keptDays(members: members, zone: zone) == ["2026-09-29"])
        #expect(CrewHistory.needed(of: 1) == 1)
        #expect(CrewHistory.needed(of: 2) == 2)
        #expect(CrewHistory.needed(of: 3) == 2)
        #expect(CrewHistory.needed(of: 5) == 3)
    }

    @Test func someoneWhoJoinedLaterNeverBrokeAnEarlierDay() {
        var history = CrewHistory()
        let members = [member(jayden, joined: "2026-09-28"), member(sam, joined: "2026-09-30")]
        history.record([win(jayden, on: "2026-09-29"), win(jayden, on: "2026-09-30"), win(sam, on: "2026-09-30")],
                       from: "2026-09-29", through: "2026-09-30")
        let full = history.keptDays(members: members, zone: zone)
        #expect(CrewHistory.streak(full, today: "2026-09-30", zone: zone) == 2)
    }

    /// The window grew from three days to fourteen (2026-10-05) while the
    /// cloud held only three: a day the phone already counted is never
    /// emptied by a cloud that no longer holds it, and a day it never saw is
    /// filled in.
    @Test func olderDaysFillInButAreNeverEmptied() {
        var history = CrewHistory()
        history.days["2026-09-20"] = [jayden.uuidString: 2]
        history.record([win(sam, on: "2026-09-22"), win(jayden, on: "2026-09-29")],
                       from: "2026-09-16", rewritingFrom: "2026-09-28", through: "2026-09-30")
        #expect(history.totals == ["2026-09-20": 2, "2026-09-22": 1, "2026-09-29": 1])
        history.record([win(jayden, on: "2026-09-22"), win(jayden, on: "2026-09-22")],
                       from: "2026-09-16", rewritingFrom: "2026-09-28", through: "2026-09-30")
        #expect(history.totals["2026-09-22"] == 1)
        #expect(history.totals["2026-09-29"] == nil)
    }

    @Test func theCloudsDaysAreRewrittenAndOlderOnesKept() {
        var history = CrewHistory()
        history.record([win(jayden, on: "2026-09-20"), win(jayden, on: "2026-09-29")], from: "2026-09-17", through: "2026-09-29")
        // Later: the 20th has left the cloud, and the 29th's win was withdrawn.
        history.record([], from: "2026-09-27", through: "2026-09-30")
        #expect(history.totals == ["2026-09-20": 1])
    }

    /// The break was one missed day until rest days (2026-10-06): a crew
    /// keeps two a week, so it takes three missed days in a row to end a run.
    @Test func aBreakEndsTheCurrentStreakNotTheBest() {
        var history = CrewHistory()
        let members = [member(jayden, joined: "2026-09-01")]
        let days = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-07"]
        history.record(days.map { win(jayden, on: $0) }, from: "2026-09-01", through: "2026-09-07")
        let full = history.keptDays(members: members, zone: zone)
        #expect(CrewHistory.streak(full, today: "2026-09-07", zone: zone) == 1)
        #expect(CrewHistory.best(full, zone: zone) == 3)
    }

    @Test func twoDaysOffAWeekKeepTheCrewsStreak() {
        let full: Set<String> = ["2026-09-01", "2026-09-02", "2026-09-04", "2026-09-06", "2026-09-07"]
        // The 3rd and the 5th are rest days: five days won, one run.
        #expect(CrewHistory.streak(full, today: "2026-09-07", zone: zone) == 5)
        #expect(CrewHistory.best(full, zone: zone) == 5)
    }

    @Test func aCrewDayIsOneReplayDay() throws {
        let period = try #require(ReplayPeriod.day("2026-10-02", name: "Roommates"))
        #expect(period.days == ["2026-10-02"])
        #expect(period.title == "Roommates")
        #expect(period.range(relativeTo: date("2026-10-02"), locale: Locale(identifier: "en_US")) == "Roommates, 10/2")
    }
}
