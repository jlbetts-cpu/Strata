import Foundation
import Testing
@testable import Strata

/// **A reply to a story goes to your personal chat** (the owner,
/// 2026-10-16). A crew of two, its invitation sealed to the friend alone in a
/// crew you share (`CrewPersonal`).
@MainActor
@Suite("Personal chats", .serialized)
struct PersonalChatTests {
    let world = FakeCrewWorld()
    let jayden = UUID(), sam = UUID(), ana = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "personal-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : me == sam ? "Sam" : "Ana" }
        return store
    }

    func win(_ title: String = "Morning run") -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    /// Three friends in one crew; Sam has a story up.
    func setUp() async throws -> (SocialStore, SocialStore, SocialStore, Crew, CrewStory) {
        let a = store(jayden), b = store(sam), c = store(ana)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        _ = try await c.accept(CrewInvite(url: link))
        await a.refresh(); await b.refresh()
        await b.postStory(win())
        await a.refresh()
        let story = try #require(a.storiesByCrew[crew.id]?.first { $0.sender == sam })
        return (a, b, c, crew, story)
    }

    @Test("a reply makes a personal chat, the friend joins it, and the line says what it answers")
    func replyLandsInPersonalChat() async throws {
        let (a, b, _, crew, story) = try await setUp()
        #expect(await a.replyToStory("that's so good", story: story) == .sent)
        let personal = try #require(a.personalCrew(with: sam))
        #expect(personal.isPersonal)
        #expect(a.groupCrewCount == 1)
        // Sam's phone finds the invitation on its next sync and joins.
        await b.refresh()
        let theirs = try #require(b.crews.first { $0.id == personal.id })
        #expect(theirs.isPersonal && theirs.member(jayden) != nil)
        let line = try #require(b.messages(in: personal.id).first)
        #expect(line.text == "that's so good")
        #expect(line.storyQuote == "Morning run")
        // Once Sam is in, Jayden's phone deletes the invitation.
        await a.refresh()
        #expect(world.records(of: .personal, in: crew.id).isEmpty)
        // And the next reply goes straight there.
        #expect(await a.replyToStory("again", story: story) == .sent)
        #expect(a.crews.filter(\.isPersonal).count == 1)
    }

    @Test("nobody else in the crew can open the invitation")
    func sealedToTheFriendAlone() async throws {
        let (a, _, c, crew, story) = try await setUp()
        _ = await a.replyToStory("hi", story: story)
        let invite = try #require(try await (c.cloud as! FakeCrewCloud).fetchPersonals(in: crew.id).first)
        #expect(invite.to == sam)
        #expect(c.cloud.openSealed(invite.sealed, info: CrewSealedNote.info(from: jayden, to: sam)) == nil)
        await c.refresh()
        #expect(!c.crews.contains { $0.isPersonal })
    }

    @Test("a personal chat counts against no cap and takes no third person")
    func twoAndNoMore() async throws {
        let (a, b, _, _, story) = try await setUp()
        _ = await a.replyToStory("hi", story: story)
        let personal = try #require(a.personalCrew(with: sam))
        await b.refresh()
        await a.refresh()
        #expect(a.crew(personal.id)?.members.count == 2)
        // Two in it, so no link for a third is made.
        var refused = false
        do { _ = try await a.inviteURL(for: personal.id) } catch { refused = true }
        #expect(refused)
        #expect(a.groupCrewCount == 1 && b.groupCrewCount == 1)
    }

    @Test("both start one at once: one chat stands, the same on both phones")
    func bothAtOnce() async throws {
        let (a, b, _, _, story) = try await setUp()
        await a.postStory(win("Read a chapter"))
        await b.refresh()
        let mine = try #require(b.storiesByCrew.values.flatMap { $0 }.first { $0.sender == jayden })
        _ = await a.replyToStory("nice", story: story)
        _ = await b.replyToStory("you too", story: mine)
        await a.refresh(); await b.refresh(); await a.refresh(); await b.refresh()
        let aPersonal = a.crews.filter { $0.isPersonal && $0.members.count == 2 }
        let bPersonal = b.crews.filter { $0.isPersonal && $0.members.count == 2 }
        #expect(aPersonal.count == 1 && bPersonal.count == 1)
        #expect(aPersonal.first?.id == bPersonal.first?.id)
    }

    @Test("someone blocked cannot pull you into a chat")
    func blockedNeverJoins() async throws {
        let (a, b, _, _, story) = try await setUp()
        b.block(jayden, name: "Jayden")
        _ = await a.replyToStory("hey", story: story)
        await b.refresh()
        #expect(!b.crews.contains { $0.isPersonal })
    }
}
