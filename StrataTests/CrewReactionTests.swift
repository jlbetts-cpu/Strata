import Testing
import Foundation
@testable import Strata

/// **Reacting to a friend's win, and choosing what you hear.**
@MainActor
@Suite("Crew reactions", .serialized)
struct CrewReactionTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "react-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    func win(_ title: String = "Gym") -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        return (a, b, crew)
    }

    @Test func theReactionKeysAreExactly() {
        // "line" since 2026-10-05: a reply, seen only by the win's owner.
        #expect(CrewRecords.reactionKeys == ["winID", "profileID", "emoji", "createdAt", "line"])
    }

    /// A reply is for the win's owner (and its writer), and nobody else in
    /// the crew sees the words.
    @Test func aReplyIsSeenOnlyByTheOwnerAndTheWriter() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.canReply = { true }
        #expect(await b.reply("nice one", emoji: "🔥", to: run.winID, in: crew.id) == .sent)
        await a.refresh()
        #expect(a.replies(to: run.winID, in: crew.id).map(\.line) == ["nice one"])
        #expect(b.replies(to: run.winID, in: crew.id).map(\.line) == ["nice one"])
        // A third person sees the emoji and not the words.
        let c = store(UUID())
        c.adopt(crews: a.crews, wins: a.winsByCrew)
        for reaction in a.reactionsByCrew[crew.id] ?? [] { c.receive(reaction) }
        #expect(c.replies(to: run.winID, in: crew.id).isEmpty)
        #expect(c.reactions(to: run.winID, in: crew.id).map(\.emoji) == ["🔥"])
    }

    @Test func aReplyWithRefusedWordsIsNotSent() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.canReply = { true }
        #expect(await b.reply("k y s", emoji: "🔥", to: run.winID, in: crew.id) == .refusedWords)
        #expect(await b.reply("you r3tard", emoji: "🔥", to: run.winID, in: crew.id) == .refusedWords)
        #expect(CrewWords.isAcceptable("first class run"))
        await a.refresh()
        #expect(a.replies(to: run.winID, in: crew.id).isEmpty)
    }

    @Test func aDeclinedAgeCannotReply() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.canReply = { false }
        #expect(await b.reply("nice", emoji: "🔥", to: run.winID, in: crew.id) == .notAllowed)
    }

    @Test func aReplyClearsWhenTheDayEnds() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.canReply = { true }
        await b.reply("nice one", emoji: "🔥", to: run.winID, in: crew.id)
        let tomorrow = Date().addingTimeInterval(86_400)
        a.now = { tomorrow }
        b.now = { tomorrow }
        #expect(a.replies(to: run.winID, in: crew.id).isEmpty)
        b.prune()
        await b.flush()
        await a.refresh()
        #expect(a.reactionsByCrew[crew.id]?.first?.line == nil)
        #expect(a.reactionsByCrew[crew.id]?.first?.emoji == "🔥")
    }

    @Test func aReactionReplacesAndTheSameOneTakesItBack() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        await b.react("🔥", to: run.winID, in: crew.id)
        await a.refresh()
        #expect(a.reactions(to: run.winID, in: crew.id).map(\.emoji) == ["🔥"])
        #expect(a.unread == [crew.id], "a reaction to your win is something new")
        await b.react("👑", to: run.winID, in: crew.id)
        await a.refresh()
        #expect(a.reactions(to: run.winID, in: crew.id).map(\.emoji) == ["👑"], "one per person")
        await b.react("👑", to: run.winID, in: crew.id)
        await a.refresh()
        #expect(a.reactions(to: run.winID, in: crew.id).isEmpty, "the same one again takes it back")
    }

    @Test func youDoNotReactToYourOwnWin() async throws {
        let (a, _, crew) = try await pair()
        let mine = win()
        await a.post(mine, to: [crew.id])
        await a.react("❤️", to: mine.winID, in: crew.id)
        #expect(a.reactions(to: mine.winID, in: crew.id).isEmpty)
    }

    @Test func aWithdrawnWinTakesItsReactionsWithIt() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        await b.react("❤️", to: run.winID, in: crew.id)
        await a.withdraw(winID: run.winID, from: crew.id)
        await b.refresh()
        #expect(b.reactions(to: run.winID, in: crew.id).isEmpty)
        await b.flush()
        #expect(world.records(of: .reaction, in: crew.id).isEmpty)
    }

    @Test func aBlockedPersonsReactionsDisappear() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        await b.react("🔥", to: run.winID, in: crew.id)
        await a.refresh()
        a.block(sam)
        #expect(a.reactions(to: run.winID, in: crew.id).isEmpty)
    }

    @Test func muteLastsAsLongAsChosen() async throws {
        let a = store(jayden)
        let (crew, _) = try await a.createCrew(name: "One")
        var clock = Date()
        a.now = { clock }
        a.mute(crew.id, .hour)
        #expect(a.isMuted(crew.id))
        clock = clock.addingTimeInterval(3601)
        #expect(!a.isMuted(crew.id), "an hour's mute ends on its own")
        a.mute(crew.id, .always)
        clock = clock.addingTimeInterval(365 * 86_400)
        #expect(a.isMuted(crew.id))
        a.mute(crew.id, nil)
        #expect(!a.isMuted(crew.id))
        a.setReactionAlerts(false, for: crew.id)
        #expect(!a.reactionAlerts(crew.id))
        a.setReactionAlerts(true, for: crew.id)
        #expect(a.reactionAlerts(crew.id))
    }

    @Test func aReactionNotificationReadsLikeMessages() {
        let crew = Crew(id: CrewID(rawValue: "crew-r"), name: "Roommates", ownerProfileID: jayden, timeZoneIdentifier: "UTC",
                        createdAt: .now, photo: nil,
                        members: [CrewMember(profileID: sam, firstName: "Sam", head: nil, joinedAt: .now)])
        let run = SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: jayden, crewDay: "2026-10-02", title: "Gym",
                            colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                            createdAt: .now, updatedAt: .now)
        let reaction = Reaction(winID: run.winID, crewID: crew.id, profileID: sam, emoji: "🔥", createdAt: .now)
        #expect(CrewNotifications.Text.reacted(reaction, to: run, in: crew) == "Sam reacted 🔥 to \u{201C}Gym\u{201D}")
    }

    @Test func aRecordCannotSmuggleAMessage() {
        let fields: RecordFields = ["winID": .uuid(UUID()), "profileID": .uuid(UUID()),
                                    "emoji": .string("🔥 nice one"), "createdAt": .date(.now)]
        #expect(CrewRecords.reaction(fields, crew: CrewID(rawValue: "c"))?.emoji == "🔥")
    }
}
