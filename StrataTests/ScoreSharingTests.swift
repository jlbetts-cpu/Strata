import Foundation
import Testing
@testable import Strata

/// **Your score on a friend's profile** (2026-10-15): sent on your member
/// record when it moves, read back on their phone, and nothing sent when it
/// did not.
@MainActor
@Suite("Score on a friend's profile", .serialized)
struct ScoreSharingTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "score-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        return store
    }

    @Test("a member's score and wins round-trip, and a bad count reads as none below zero")
    func roundTrip() {
        let member = CrewMember(profileID: sam, firstName: "Sam", head: nil, joinedAt: .now, score: 11, wins: 8)
        let back = CrewRecords.member(CrewRecords.fields(member))
        #expect(back?.score == 11 && back?.wins == 8)
        var fields = CrewRecords.fields(member)
        fields["score"] = .int(-40)
        #expect(CrewRecords.member(fields)?.score == 0)
        // An older build's record carries neither.
        let old = CrewMember(profileID: sam, firstName: "Sam", head: nil, joinedAt: .now)
        #expect(CrewRecords.fields(old)["score"] == nil)
        #expect(CrewRecords.member(CrewRecords.fields(old))?.score == nil)
    }

    @Test("your score reaches your friend's phone")
    func reachesAFriend() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        a.noteMyScore(WinsScore.Tally(score: 11, wins: 8), settle: .zero)
        await a.scoreSoon?.value
        await b.refresh()
        let seen = try #require(b.crew(crew.id)?.member(jayden))
        #expect(seen.score == 11 && seen.wins == 8)
    }
}
