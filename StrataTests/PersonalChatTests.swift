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

    @Test("New Message: everyone you share a crew with, once, not you, not blocked; the thread names them before they join")
    func newMessage() async throws {
        let (a, b, _, _, _) = try await setUp()
        #expect(Set(a.messageablePeople.map(\.member.profileID)) == [sam, ana])
        a.block(ana, name: "Ana")
        #expect(a.messageablePeople.map(\.member.profileID) == [sam])
        let dm = try #require(await a.startPersonal(with: sam))
        // Before Sam has joined, the thread is still Sam's.
        #expect(a.directFriend(dm.id)?.profileID == sam)
        // A second start opens the same one.
        #expect(await a.startPersonal(with: sam)?.id == dm.id)
        await b.refresh()
        #expect(b.directFriend(dm.id)?.profileID == jayden)
        // A message thread is never a crew to send wins or plans to.
        #expect(!a.groupCrews.contains { $0.id == dm.id })
        // Someone blocked is nobody in it.
        a.block(sam, name: "Sam")
        #expect(a.directFriend(dm.id) == nil)
    }

    @Test("a message thread keeps two weeks of lines; a crew's chat is today's")
    func threadKeepsDays() async throws {
        let (a, b, _, crew, _) = try await setUp()
        let dm = try #require(await a.startPersonal(with: sam))
        await b.refresh()
        await b.send("yesterday's", in: dm.id)
        await b.send("crew yesterday", in: crew.id)
        await a.refresh()
        // A day later, by the store's clock.
        let tomorrow = Date().addingTimeInterval(86_400)
        a.now = { tomorrow }
        // The midnight sweep keeps a conversation's lines, here and in the
        // cloud (the review: it cleared them as a crew's chat).
        a.prune()
        await a.flush()
        #expect(a.messages(in: dm.id).map(\.text).contains("yesterday's"))
        #expect(!a.messages(in: crew.id).map(\.text).contains("crew yesterday"))
        b.now = { tomorrow }
        b.prune()
        await b.flush()
        #expect(!world.records(of: .message, in: dm.id).isEmpty, "the sender's phone kept its line in the cloud")
        // Past two weeks, gone from the thread too.
        a.now = { Date().addingTimeInterval(86_400 * 16) }
        #expect(!a.messages(in: dm.id).map(\.text).contains("yesterday's"))
    }

    @Test("a reply makes a personal chat, the friend joins it, and the line says what it answers")
    func replyLandsInPersonalChat() async throws {
        let (a, b, _, crew, story) = try await setUp()
        #expect(await a.replyToStory("that's so good", story: story).outcome == .sent)
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
        #expect(await a.replyToStory("again", story: story).outcome == .sent)
        #expect(a.crews.filter(\.isPersonal).count == 1)
    }

    @Test("nobody else in the crew can open the invitation")
    func sealedToTheFriendAlone() async throws {
        let (a, _, c, crew, story) = try await setUp()
        _ = await a.replyToStory("hi", story: story)
        let invite = try #require(try await (c.cloud as! FakeCrewCloud).fetchPersonals(in: crew.id).first)
        // Ana can see Jayden left one, not who it is for, and cannot open it.
        #expect(c.cloud.openSealed(invite.sealed, info: CrewSealedNote.info(from: jayden)) == nil)
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

    @Test("a forged invitation cannot put you into someone else's crew")
    func forgedInvitationRefused() async throws {
        let (a, b, c, crew, _) = try await setUp()
        // Ana starts an ordinary crew and seals its link to Sam, claiming to
        // be from someone who is not in the crew at all.
        let (trap, trapLink) = try await c.createCrew(name: "Trap")
        let stranger = UUID()
        let key = try #require(c.cloud.memberPublicKey(sam, in: crew.id))
        let note = try JSONEncoder().encode(PersonalNote(to: sam, link: trapLink.absoluteString))
        let sealed = try #require(CrewSealedNote.seal(note, to: key, info: CrewSealedNote.info(from: stranger)))
        try await c.cloud.save(CrewRecords.fields(PersonalInvite(from: stranger, sealed: sealed, createdAt: .now)),
                               type: .personal, name: "forged-1", in: crew.id)
        // And one honestly from Ana, pointing at a group crew.
        let sealed2 = try #require(CrewSealedNote.seal(note, to: key, info: CrewSealedNote.info(from: ana)))
        try await c.cloud.save(CrewRecords.fields(PersonalInvite(from: ana, sealed: sealed2, createdAt: .now)),
                               type: .personal, name: "forged-2", in: crew.id)
        await b.refresh()
        #expect(!b.crews.contains { $0.id == trap.id })
        _ = a
    }

    @Test("leaving a personal chat is respected: their next reply does not pull you back")
    func leavingIsRespected() async throws {
        let (a, b, _, _, story) = try await setUp()
        _ = await a.replyToStory("hi", story: story)
        await b.refresh()
        let personal = try #require(b.crews.first { $0.isPersonal })
        try await b.leave(personal.id)
        await a.refresh()
        // Jayden replies to another story of Sam's.
        await b.postStory(win("Second"))
        await a.refresh()
        let second = try #require(a.storiesByCrew.values.flatMap { $0 }.first { $0.sender == sam && $0.win.title == "Second" })
        _ = await a.replyToStory("again", story: second)
        await b.refresh()
        #expect(!b.crews.contains { $0.isPersonal })
    }

    @Test("two quick replies make one chat")
    func quickRepliesOneChat() async throws {
        let (a, _, _, _, story) = try await setUp()
        async let one = a.replyToStory("one", story: story)
        async let two = a.replyToStory("two", story: story)
        _ = await (one, two)
        #expect(a.crews.filter(\.isPersonal).count == 1)
    }

    @Test("stories go to group crews only, never into a personal chat")
    func storiesSkipPersonalChats() async throws {
        let (a, b, _, _, story) = try await setUp()
        _ = await a.replyToStory("hi", story: story)
        await b.refresh()
        let personal = try #require(a.personalCrew(with: sam))
        await a.postStory(win("Mine"))
        #expect(world.records(of: .story, in: personal.id).isEmpty)
    }

    @Test("a crew-mate's chat that calls itself someone else is refused")
    func impersonationRefused() async throws {
        let (_, b, c, crew, _) = try await setUp()
        // Ana makes a personal chat, then writes her member record in it alone
        // as "Jayden".
        let made = try await c.createCrew(name: "", personal: true)
        let posing = CrewMember(profileID: ana, firstName: "Jayden", joinedAt: .now)
        try await c.cloud.save(CrewRecords.fields(posing), type: .member, name: CrewRecords.name(of: posing), in: made.crew.id)
        let key = try #require(c.cloud.memberPublicKey(sam, in: crew.id))
        let note = try JSONEncoder().encode(PersonalNote(to: sam, link: made.invite.absoluteString))
        let sealed = try #require(CrewSealedNote.seal(note, to: key, info: CrewSealedNote.info(from: ana)))
        try await c.cloud.save(CrewRecords.fields(PersonalInvite(from: ana, sealed: sealed, createdAt: .now)),
                               type: .personal, name: "pose", in: crew.id)
        await b.refresh()
        #expect(!b.crews.contains { $0.id == made.crew.id })
    }

    @Test("an invitation that waited is sent again, and the chat keeps what was said")
    func waitingInvitationRenewed() async throws {
        let (a, b, _, crew, story) = try await setUp()
        _ = await a.replyToStory("first", story: story)
        let personal = try #require(a.personalCrew(with: sam))
        a.now = { Date().addingTimeInterval(4 * 86_400) }
        await a.refresh()
        #expect(a.crew(personal.id) != nil)
        #expect(world.records(of: .personal, in: crew.id).count == 1)
        a.now = Date.init
        await b.refresh()
        #expect(b.crews.contains { $0.id == personal.id })
    }

    @Test("a personal chat shows them as the crew you share does, whatever they write in it")
    func namedFromTheSharedCrew() {
        let shared = Crew(id: CrewID(rawValue: "g"), name: "Roommates", ownerProfileID: jayden, timeZoneIdentifier: "UTC",
                          createdAt: .now, photo: nil,
                          members: [CrewMember(profileID: jayden, firstName: "Jayden", joinedAt: .now),
                                    CrewMember(profileID: sam, firstName: "Sam", joinedAt: .now)])
        let chat = Crew(id: CrewID(rawValue: "p"), name: "", ownerProfileID: sam, timeZoneIdentifier: "UTC",
                        createdAt: .now, photo: nil,
                        members: [CrewMember(profileID: sam, firstName: "Ana", joinedAt: .now),
                                  CrewMember(profileID: jayden, firstName: "Jayden", joinedAt: .now)],
                        personal: true)
        let named = SocialStore.personalNamedFromShared([shared, chat], me: jayden)
        #expect(named[1].member(sam)?.firstName == "Sam")
        #expect(named[0] == shared)
    }
}
