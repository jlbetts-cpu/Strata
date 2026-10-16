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

    @Test("a score record round-trips, and a wild count is held within reason")
    func roundTrip() {
        let fields = CrewRecords.scoreFields(profileID: sam, score: 11, wins: 8)
        let back = try? #require(CrewRecords.score(fields))
        #expect(back?.score == 11 && back?.wins == 8 && back?.profileID == sam)
        var wild = fields
        wild["score"] = .int(-40)
        wild["wins"] = .int(Int.max)
        #expect(CrewRecords.score(wild)?.score == 0)
        #expect(CrewRecords.score(wild)?.wins == 1_000_000)
        // A member is given only the score filed under their own profile.
        let member = CrewMember(profileID: sam, firstName: "Sam", head: nil, joinedAt: .now)
        let filedWrong = ["Score/\(sam.uuidString)": CrewRecords.scoreFields(profileID: jayden, score: 99, wins: 9)]
        #expect(CrewRecords.withScores([member], from: filedWrong).first?.score == nil)
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
        // On its own record: the member record (and the head on it) was not
        // written again.
        let member = try #require(world.records(of: .member, in: crew.id)[jayden.uuidString])
        #expect(member["score"] == nil)
        #expect(world.records(of: .score, in: crew.id)[jayden.uuidString] != nil)
    }
}
