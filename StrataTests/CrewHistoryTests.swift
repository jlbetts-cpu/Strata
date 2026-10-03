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

    @Test func aDayCountsOnlyWhenEveryonePosted() {
        var history = CrewHistory()
        let members = [member(jayden, joined: "2026-09-28"), member(sam, joined: "2026-09-28")]
        history.record([win(jayden, on: "2026-09-29"), win(sam, on: "2026-09-29"),
                        win(jayden, on: "2026-09-30"), win(sam, on: "2026-09-30"),
                        win(jayden, on: "2026-10-01")],
                       from: "2026-09-29", through: "2026-10-01")
        let full = history.fullDays(members: members, zone: zone)
        #expect(full == ["2026-09-29", "2026-09-30"])
        // Today is still open: the streak runs through yesterday.
        #expect(CrewHistory.streak(full, today: "2026-10-01", zone: zone) == 2)
        #expect(CrewHistory.best(full, zone: zone) == 2)
        #expect(history.waiting(today: "2026-10-01", members: members).map(\.profileID) == [sam])
    }

    @Test func someoneWhoJoinedLaterNeverBrokeAnEarlierDay() {
        var history = CrewHistory()
        let members = [member(jayden, joined: "2026-09-28"), member(sam, joined: "2026-09-30")]
        history.record([win(jayden, on: "2026-09-29"), win(jayden, on: "2026-09-30"), win(sam, on: "2026-09-30")],
                       from: "2026-09-29", through: "2026-09-30")
        let full = history.fullDays(members: members, zone: zone)
        #expect(CrewHistory.streak(full, today: "2026-09-30", zone: zone) == 2)
    }

    @Test func theCloudsDaysAreRewrittenAndOlderOnesKept() {
        var history = CrewHistory()
        history.record([win(jayden, on: "2026-09-20"), win(jayden, on: "2026-09-29")], from: "2026-09-17", through: "2026-09-29")
        // Later: the 20th has left the cloud, and the 29th's win was withdrawn.
        history.record([], from: "2026-09-27", through: "2026-09-30")
        #expect(history.totals == ["2026-09-20": 1])
    }

    @Test func aBreakEndsTheCurrentStreakNotTheBest() {
        var history = CrewHistory()
        let members = [member(jayden, joined: "2026-09-01")]
        let days = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-05"]
        history.record(days.map { win(jayden, on: $0) }, from: "2026-09-01", through: "2026-09-05")
        let full = history.fullDays(members: members, zone: zone)
        #expect(CrewHistory.streak(full, today: "2026-09-05", zone: zone) == 1)
        #expect(CrewHistory.best(full, zone: zone) == 3)
    }

    @Test func aCrewDayIsOneReplayDay() throws {
        let period = try #require(ReplayPeriod.day("2026-10-02", name: "Roommates"))
        #expect(period.days == ["2026-10-02"])
        #expect(period.title == "Roommates")
        #expect(period.range(relativeTo: date("2026-10-02"), locale: Locale(identifier: "en_US")) == "Roommates, 10/2")
    }
}
