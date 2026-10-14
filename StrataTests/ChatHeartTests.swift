import Foundation
import Testing
@testable import Strata

/// **Two taps heart a line** (the owner, 2026-10-13: "double tap a message to
/// heart it"; heart counts show a number only past one, "♥ 3").
///
/// No new field: a heart on a line is the `Reaction` record a line's
/// reactions already are, its `winID` holding the line's id.
@MainActor
@Suite("Chat hearts", .serialized)
struct ChatHeartTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "chat-heart-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    @Test("a heart from each of two people is one chip with a 2; one heart is the heart alone")
    func heartsCount() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        #expect(await a.send("ran 5k", in: crew.id) == .sent)
        await b.refresh()
        let line = try #require(b.messages(in: crew.id).first)

        #expect(await b.react(.emoji(Reaction.doubleTap), toMessage: line.messageID, in: crew.id) == .sent)
        await a.refresh()
        var chips = ChatReactionChips.chips(a.messageReactions(in: crew.id)[line.messageID] ?? [], me: jayden)
        #expect(chips.count == 1 && chips[0].mark == "❤️" && chips[0].people.count == 1, "one heart, no number")

        // Your own line takes your heart too.
        #expect(await a.react(.emoji(Reaction.doubleTap), toMessage: line.messageID, in: crew.id) == .sent)
        chips = ChatReactionChips.chips(a.messageReactions(in: crew.id)[line.messageID] ?? [], me: jayden)
        #expect(chips.count == 1 && chips[0].people.count == 2 && chips[0].mine, "two hearts, one chip, a 2")

        // Two taps again take yours back.
        #expect(await a.react(.emoji(Reaction.doubleTap), toMessage: line.messageID, in: crew.id) == .sent)
        #expect(a.myReaction(toMessage: line.messageID, in: crew.id) == nil)
        #expect(world.records(of: .reaction, in: crew.id).count == 1, "only Sam's heart is left")
    }

    @Test("the chat hearts on two taps, before a single tap opens anything")
    func wired() throws {
        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        let double = try #require(chat.range(of: ".onTapGesture(count: 2) { doubleTap(message) }"))
        let single = try #require(chat.range(of: ".onTapGesture {\n                // The lift that ended a hold is not a tap.")
                                  ?? chat.range(of: ".onTapGesture {"))
        #expect(double.lowerBound < single.lowerBound, "the single tap is checked first and eats the double")
        #expect(chat.contains("react(.emoji(Reaction.doubleTap), to: message.messageID)"))
        // The count is the chips' own: a number only when two chose the same.
        let chips = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/ChatReactions.swift"))
        #expect(chips.contains("if chip.people.count > 1 {"))
    }
}
