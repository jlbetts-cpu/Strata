import Testing
import Foundation
@testable import Strata

/// Pings: what leaves the phone when a win or a reaction is sent, and what
/// each phone asks iCloud to tell it about.
@MainActor
@Suite("Crew pings", .serialized)
struct CrewPingTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "crew-ping-tests-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        store.sendsPings = true
        return store
    }

    func win(_ title: String = "Gym", at date: Date = .now) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: date, updatedAt: date)
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        await b.refresh()
        return (a, b, crew)
    }

    @Test func aWinLeavesOnePingWithIdsAndNothingElse() async throws {
        let (a, _, crew) = try await pair()
        let mine = win("Gym")
        await a.post(mine, to: [crew.id])
        let pings = world.pings.values.filter { $0[CrewPingRecord.kind] == "win" }
        #expect(pings.count == 1)
        let ping = try #require(pings.first)
        #expect(Set(ping.keys) == [CrewPingRecord.crew, CrewPingRecord.sender, CrewPingRecord.kind, CrewPingRecord.win])
        // Tags, never the ids themselves: a public record names nobody.
        #expect(ping[CrewPingRecord.crew] == CrewPingRecord.tag(crew.id.rawValue))
        #expect(ping[CrewPingRecord.sender] == CrewPingRecord.tag(jayden.uuidString))
        #expect(!ping.values.contains(crew.id.rawValue))
        #expect(!ping.values.contains(jayden.uuidString))
        #expect(!ping.values.contains("Gym"))
        // Sent again (an edit): not news.
        await a.update(mine)
        #expect(world.pings.values.filter { $0[CrewPingRecord.kind] == "win" }.count == 1)
    }

    @Test func aWinSentLongAfterItWasMadeDoesNotPing() async throws {
        let (a, _, crew) = try await pair()
        await a.post(win(at: Date().addingTimeInterval(-8 * 3600)), to: [crew.id])
        #expect(world.pings.values.filter { $0[CrewPingRecord.kind] == "win" }.isEmpty)
    }

    @Test func aReactionPingsTheWinsOwnerOnly() async throws {
        let (a, b, crew) = try await pair()
        let mine = win("Gym")
        await a.post(mine, to: [crew.id])
        await b.refresh()
        await b.react("🔥", to: mine.winID, in: crew.id)
        let ping = try #require(world.pings.values.first { $0[CrewPingRecord.kind] == "reaction" })
        #expect(ping[CrewPingRecord.recipient] == CrewPingRecord.tag(jayden.uuidString))
        #expect(ping[CrewPingRecord.sender] == CrewPingRecord.tag(sam.uuidString))
        #expect(!ping.values.contains("🔥"))
    }

    @Test func thePlanLeavesOutMutedCrewsBlockedPeopleAndQuietReactions() async throws {
        let (a, _, crew) = try await pair()
        let crewTag = CrewPingRecord.tag(crew.id.rawValue)
        var plan = a.pingPlan()
        #expect(plan.winCrews == [crewTag])
        #expect(plan.reactionCrews == [crewTag])
        #expect(plan.excluding == [CrewPingRecord.tag(jayden.uuidString)])

        a.setReactionAlerts(false, for: crew.id)
        plan = a.pingPlan()
        #expect(plan.winCrews == [crewTag])
        #expect(plan.reactionCrews.isEmpty)

        a.mute(crew.id, .hour)
        #expect(a.pingPlan().winCrews.isEmpty)

        a.block(sam, name: "Sam")
        #expect(a.pingPlan().excluding.contains(CrewPingRecord.tag(sam.uuidString)))

        a.mute(crew.id, nil)
        a.setReactionAlerts(true, for: crew.id)
        a.unblock(sam)
    }

    @Test func iCloudHearsThePlanOnRefreshAndPingsGoLive() async throws {
        let (a, _, crew) = try await pair()
        let cloud = try #require(a.cloud as? FakeCrewCloud)
        #expect(cloud.listening?.winCrews == [CrewPingRecord.tag(crew.id.rawValue)])
        #expect(a.pingsLive)
    }

    @Test func pingsAreDeletedSoonAfter() async throws {
        let (a, _, crew) = try await pair()
        await a.post(win(), to: [crew.id])
        #expect(!world.pings.isEmpty)
        await a.deleteOldPings()
        #expect(!world.pings.isEmpty)
        a.now = { Date().addingTimeInterval(SocialStore.pingLifetime + 60) }
        await a.deleteOldPings()
        #expect(world.pings.values.filter { $0[CrewPingRecord.sender] == CrewPingRecord.tag(jayden.uuidString) }.isEmpty)
    }

    @Test func theNoteCacheHoldsNamesNeverPhotos() async throws {
        let (a, _, crew) = try await pair()
        await a.post(win("Gym"), to: [crew.id])
        let cache = a.noteCache()
        let entry = try #require(cache.crews[CrewPingRecord.tag(crew.id.rawValue)])
        #expect(entry.zoneName == crew.id.rawValue)
        #expect(entry.members[CrewPingRecord.tag(sam.uuidString)]?.name == "Sam")
        #expect(entry.myWins.values.contains("Gym"))
        #expect(!entry.joined)
    }

    @Test func theWordsSayWhoAndWhat() {
        let cache = CrewNoteCache(me: "me", crews: [
            "crew-1": .init(title: "Roommates", zoneName: "crew-x", zoneOwner: "o", joined: true,
                            members: ["sam": .init(profileID: "p", name: "Sam")], myWins: ["w1": "Gym"]),
        ])
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w2", title: "Run", emoji: nil)
                == ("Roommates", "Sam: Run"))
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w2", title: nil, emoji: nil)
                == ("Roommates", "Sam added a win"))
        #expect(cache.words(kind: .reaction, crew: "crew-1", sender: "sam", winID: "w1", title: nil, emoji: "🔥")
                == ("Roommates", "Sam reacted 🔥 to \u{201C}Gym\u{201D}"))
        #expect(cache.words(kind: .win, crew: "crew-9", sender: "x", winID: "w", title: nil, emoji: nil)
                == ("Some Wins", "A friend added a win"))
    }
}
