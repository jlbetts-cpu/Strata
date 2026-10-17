import Foundation
import Testing
@testable import Strata

/// **The Crews corner's notifications** (the add-on to the launch pass).
struct ActivityFeedTests {
    let me = UUID(), sam = UUID(), ana = UUID(), eve = UUID()
    let crew = CrewID(rawValue: "c")

    func win(_ id: UUID, by sender: UUID, _ title: String) -> SharedWin {
        SharedWin(winID: id, crewID: crew, senderProfileID: sender, crewDay: "2026-10-16", title: title,
                  colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                  createdAt: .now, updatedAt: .now)
    }

    func reaction(_ by: UUID, on win: UUID, _ emoji: String, ago: TimeInterval) -> Reaction {
        Reaction(winID: win, crewID: crew, profileID: by, emoji: emoji, createdAt: Date().addingTimeInterval(-ago))
    }

    @Test("every reaction on one of your wins is one line, newest first; never yours, never someone blocked, never last month")
    func groups() {
        let walk = UUID(), theirs = UUID()
        let members = [me, sam, ana, eve].map { CrewMember(profileID: $0, firstName: "x", head: nil, joinedAt: .distantPast) }
        let c = Crew(id: crew, name: "Roommates", ownerProfileID: me, timeZoneIdentifier: "UTC", createdAt: .distantPast, photo: nil, members: members)
        let feed = ActivityFeed.gather(
            crews: [c], wins: [crew: [win(walk, by: me, "Walk"), win(theirs, by: sam, "Gym")]], messages: [:],
            reactions: [crew: [reaction(sam, on: walk, "❤️", ago: 60), reaction(ana, on: walk, "🔥", ago: 30),
                               reaction(eve, on: walk, "🔥", ago: 10), reaction(me, on: walk, "👑", ago: 5),
                               reaction(ana, on: theirs, "❤️", ago: 5), reaction(sam, on: walk, "👑", ago: 40 * 86_400)]],
            stories: [:], me: me, blocked: [eve], now: .now)
        #expect(feed.count == 1)
        #expect(feed.first?.people == [ana, sam])
        #expect(feed.first?.words.hasSuffix("to Walk") == true)
        #expect(feed.first?.words.contains("👑") == false)
    }

    private func roommates() -> Crew {
        let members = [me, sam, ana, eve].map { CrewMember(profileID: $0, firstName: "x", head: nil, joinedAt: .distantPast) }
        return Crew(id: crew, name: "Roommates", ownerProfileID: me, timeZoneIdentifier: "UTC", createdAt: .distantPast,
                    photo: nil, members: members)
    }

    /// The owner, 2026-10-17: "Ana reacted to 3 of your wins," tap to see each.
    @Test("one person on several of your wins in a day is one line that opens out")
    func onePersonManyWins() {
        let a = UUID(), b = UUID(), c = UUID()
        let feed = ActivityFeed.gather(
            crews: [roommates()], wins: [crew: [win(a, by: me, "Walk"), win(b, by: me, "Gym"), win(c, by: me, "Read")]],
            messages: [:],
            reactions: [crew: [reaction(ana, on: a, "❤️", ago: 30), reaction(ana, on: b, "🔥", ago: 20),
                               reaction(ana, on: c, "❤️", ago: 10)]],
            stories: [:], me: me, blocked: [], now: .now)
        #expect(feed.count == 1)
        #expect(feed.first?.words == "reacted to 3 of your wins")
        #expect(feed.first?.children.count == 3)
        #expect(feed.first?.children.map(\.winID) == [c, b, a], "the parts, newest first")
    }

    /// "Grouped within a sensible window of time so old and new don't merge."
    @Test("reactions on one win days apart are separate lines; several people the same day are one")
    func aDayIsTheWindow() {
        let walk = UUID()
        let feed = ActivityFeed.gather(
            crews: [roommates()], wins: [crew: [win(walk, by: me, "Walk")]], messages: [:],
            reactions: [crew: [reaction(sam, on: walk, "❤️", ago: 3 * 86_400), reaction(ana, on: walk, "🔥", ago: 20),
                               reaction(eve, on: walk, "❤️", ago: 10)]],
            stories: [:], me: me, blocked: [], now: .now)
        #expect(feed.count == 2)
        #expect(feed.first?.people == [eve, ana])
        #expect(feed.first?.children.count == 2, "each person, one tap away")
        #expect(feed.last?.people == [sam])
    }
}
