import Testing
import Foundation
import UIKit
@testable import Strata

/// **Reacting to a chat line, with an emoji or a sticker** (the owner,
/// 2026-10-06: "make it so you can react to chat messages with stickers and
/// emojis").
///
/// No CloudKit schema change: a line's reaction is a `Reaction` record whose
/// `winID` holds the line's `messageID`, a sticker's mark is "sticker:<file>"
/// and its picture rides in `sketch`. These hold that mapping, the fence
/// between a win's reactions and a line's, one a person a line, and the
/// chat's own wiring.
@MainActor
@Suite("Chat reactions", .serialized)
struct ChatReactionTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "chat-react-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    func win(_ title: String = "Gym") -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    /// Jayden and Sam in one crew, and a line from Jayden that Sam can see.
    func pairWithALine() async throws -> (SocialStore, SocialStore, Crew, CrewMessage) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        #expect(await a.send("morning all", in: crew.id) == .sent)
        await b.refresh()
        let line = try #require(b.messages(in: crew.id).first)
        return (a, b, crew, line)
    }

    /// A sticker as the store keeps one: bigger than it is sent.
    func sticker(side: CGFloat = 600) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side * 0.8), format: format).pngData { ctx in
            UIColor.systemYellow.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 20, y: 20, width: side - 40, height: side * 0.8 - 40))
        }
    }

    // MARK: - The record

    @Test("a line's reaction is a Reaction record whose winID is the line, on the same keys")
    func theRecordMapping() throws {
        let line = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "reaction-\(UUID().uuidString).png")
        let stuck = Reaction(winID: line, crewID: CrewID(rawValue: "c"), profileID: sam,
                             emoji: Reaction.Pick.sticker(name: "sticker-1a2b3c4d.png", png: Data()).mark,
                             createdAt: .now, sketch: url)
        let fields = CrewRecords.fields(stuck)
        #expect(Set(fields.keys).isSubset(of: CrewRecords.reactionKeys), "no new field: the schema stays")
        #expect(CrewRecords.reactionKeys == ["winID", "profileID", "emoji", "createdAt", "line", "sketch"])
        #expect(fields["winID"]?.uuid == line, "the line's id rides in winID")
        #expect(fields["emoji"]?.string == "sticker:sticker-1a2b3c4d.png", "the journal's own spelling of a sticker")
        #expect(fields["sketch"] == .asset(url), "the picture travels as the sketch asset")
        let back = try #require(CrewRecords.reaction(fields, crew: CrewID(rawValue: "c")))
        #expect(back.winID == line && back.isSticker && back.stickerName == "sticker-1a2b3c4d.png")
        #expect(Reaction.stickerPrefix == StickerStore.prefix, "one spelling of a sticker across the app")

        // An emoji is still one grapheme, whatever the record claims.
        var emoji = fields
        emoji["emoji"] = .string("🔥🔥🔥")
        emoji["sketch"] = nil
        #expect(CrewRecords.reaction(emoji, crew: CrewID(rawValue: "c"))?.emoji == "🔥")
        // A sticker with no picture is nothing to show.
        var bare = fields
        bare["sketch"] = nil
        #expect(CrewRecords.reaction(bare, crew: CrewID(rawValue: "c")) == nil)
        // And a sticker's name is a plain file name, never a path.
        var path = fields
        path["emoji"] = .string("sticker:../../Library/secret")
        #expect(CrewRecords.reaction(path, crew: CrewID(rawValue: "c")) == nil)
        #expect(Reaction.stickerName(in: "sticker:") == nil)
        #expect(Reaction.stickerName(in: "🔥") == nil)
    }

    // MARK: - The fence between a win and a line

    @Test("a line's reaction lands under the line, travels as a record on the line's id, and never on a win")
    func aLinesReactionIsNotAWins() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        await b.react("❤️", to: run.winID, in: crew.id)
        #expect(await b.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id) == .sent)
        await a.refresh()

        #expect(a.reactions(to: run.winID, in: crew.id).map(\.emoji) == ["❤️"], "the line's 🔥 counted on the win")
        #expect(a.messageReactions(in: crew.id)[line.messageID]?.map(\.emoji) == ["🔥"])
        #expect(a.messageReactions(in: crew.id).count == 1, "the win's ❤️ showed under a line")
        let records = world.records(of: .reaction, in: crew.id)
        let record = try #require(records[Reaction.name(winID: line.messageID, profileID: sam)])
        #expect(record["winID"]?.uuid == line.messageID)
        // The refresh pruned, and a line's reaction is not an orphan of no win.
        #expect(world.records(of: .reaction, in: crew.id).count == 2, "a line's reaction was pruned as an orphan")
    }

    @Test("a reaction to your line is not a reaction to your win: no invite, no alert, no ping")
    func aLinesReactionIsNotNewsAboutAWin() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        b.sendsPings = true
        await b.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id)
        await a.refresh()
        #expect(!FirstWinInvite.hasReceivedReaction(wins: a.winsByCrew, reactions: a.reactionsByCrew, me: jayden))
        #expect(a.unread.isEmpty, "a line's reaction lit the crew as news about a win")
        #expect(world.pings.isEmpty, "a line's reaction woke a phone as a reaction to a win")
        // The alerts read only reactions to your own wins.
        let alerts = SourceSweep.code(try SourceSweep.read("Strata/Social/CrewNotifications.swift"))
        #expect(alerts.contains("for reaction in store.reactionsByCrew[crew.id] ?? [] where mine[reaction.winID] != nil"))
    }

    // MARK: - One a person a line

    @Test("a new emoji replaces yours, and the same one again takes it back")
    func oneEmojiAPerson() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        await b.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id)
        await b.react(.emoji("👑"), toMessage: line.messageID, in: crew.id)
        await a.refresh()
        #expect(a.messageReactions(in: crew.id)[line.messageID]?.map(\.emoji) == ["👑"], "one per person")
        await b.react(.emoji("👑"), toMessage: line.messageID, in: crew.id)
        await a.refresh()
        #expect(a.messageReactions(in: crew.id)[line.messageID] == nil, "the same one again takes it back")
        #expect(world.records(of: .reaction, in: crew.id).isEmpty)
    }

    @Test("a sticker is sent small, as a picture, and the same sticker again takes it back")
    func aStickerTravelsAndToggles() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        let png = sticker()
        #expect(await b.react(.sticker(name: "sticker-aa11bb22.png", png: png),
                              toMessage: line.messageID, in: crew.id) == .sent)
        await a.refresh()
        let got = try #require(a.messageReactions(in: crew.id)[line.messageID]?.first)
        #expect(got.isSticker && got.stickerName == "sticker-aa11bb22.png")
        let file = try #require(got.sketch)
        let image = try #require(UIImage(contentsOfFile: file.path))
        #expect(max(image.size.width * image.scale, image.size.height * image.scale) <= CGFloat(Reaction.stickerSide),
                "a sticker left the phone at full size")
        // Another of yours replaces it; an emoji replaces that.
        await b.react(.sticker(name: "sticker-cc33dd44.png", png: png), toMessage: line.messageID, in: crew.id)
        #expect(b.myReaction(toMessage: line.messageID, in: crew.id)?.stickerName == "sticker-cc33dd44.png")
        #expect(!FileManager.default.fileExists(atPath: file.path),
                "the replaced sticker's picture stayed on the sender's phone")
        await b.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id)
        #expect(b.myReaction(toMessage: line.messageID, in: crew.id)?.emoji == "🔥")
        #expect(b.myReaction(toMessage: line.messageID, in: crew.id)?.sketch == nil)
        // The same sticker twice: on, then off.
        await b.react(.sticker(name: "sticker-cc33dd44.png", png: png), toMessage: line.messageID, in: crew.id)
        let sent = try #require(b.myReaction(toMessage: line.messageID, in: crew.id)?.sketch)
        await b.react(.sticker(name: "sticker-cc33dd44.png", png: png), toMessage: line.messageID, in: crew.id)
        #expect(b.myReaction(toMessage: line.messageID, in: crew.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: sent.path), "a taken-back sticker left its picture behind")
        #expect(world.records(of: .reaction, in: crew.id).isEmpty)
    }

    @Test("your own line takes no reaction from you, and a sticker needs photos allowed and the photo check")
    func whoMayReact() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        #expect(await a.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id) == .notAllowed)
        #expect(await b.react(.emoji("🔥"), toMessage: UUID(), in: crew.id) == .notAllowed, "a line nobody can see")
        b.photosAllowed = { false }
        #expect(await b.react(.sticker(name: "sticker-aa11bb22.png", png: sticker()),
                              toMessage: line.messageID, in: crew.id) == .notAllowed, "13 to 15 sent a sticker")
        #expect(await b.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id) == .sent, "emoji are for everyone")
        b.photosAllowed = { true }
        b.photoCheck = { _ in false }
        #expect(await b.react(.sticker(name: "sticker-aa11bb22.png", png: sticker()),
                              toMessage: line.messageID, in: crew.id) == .refusedSketch)
        #expect(b.myReaction(toMessage: line.messageID, in: crew.id)?.emoji == "🔥", "a refused sticker took the emoji")
    }

    @Test("a friend's sticker shows only once this phone's photo check has passed it")
    func aFriendsStickerIsChecked() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        await b.react(.sticker(name: "sticker-aa11bb22.png", png: sticker()), toMessage: line.messageID, in: crew.id)
        a.incomingPolicy = { .check }
        a.incomingCheck = { _ in false }
        await a.refresh()
        await a.checkArrivedPhotos()
        #expect(a.messageReactions(in: crew.id)[line.messageID] == nil, "a sticker the check held back is shown")
        let c = store(UUID())
        c.incomingPolicy = { .check }
        c.incomingCheck = { _ in true }
        c.adopt(crews: a.crews, wins: a.winsByCrew)
        for message in a.messagesByCrew[crew.id] ?? [] { c.receive(message) }
        for reaction in a.reactionsByCrew[crew.id] ?? [] { c.receive(reaction) }
        await c.checkArrivedPhotos()
        #expect(c.messageReactions(in: crew.id)[line.messageID]?.count == 1)
    }

    @Test("a line's reactions end with its day, the sender's own deleted from the cloud")
    func reactionsEndWithTheDay() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        await b.react(.sticker(name: "sticker-aa11bb22.png", png: sticker()), toMessage: line.messageID, in: crew.id)
        let file = try #require(b.myReaction(toMessage: line.messageID, in: crew.id)?.sketch)
        b.prune()
        #expect(b.myReaction(toMessage: line.messageID, in: crew.id) != nil, "today's line's reaction was pruned")
        let tomorrow = Date().addingTimeInterval(86_400)
        a.now = { tomorrow }
        b.now = { tomorrow }
        b.prune()
        await b.flush()
        #expect(b.reactionsByCrew[crew.id]?.isEmpty ?? true)
        #expect(world.records(of: .reaction, in: crew.id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: - The chips

    @Test("chips: one a mark, yours first and lifted, a count only when several chose it")
    func chips() {
        let line = UUID(), ana = UUID(), crew = CrewID(rawValue: "c")
        let t = Date()
        let reactions = [
            Reaction(winID: line, crewID: crew, profileID: sam, emoji: "❤️", createdAt: t),
            Reaction(winID: line, crewID: crew, profileID: ana, emoji: "🔥", createdAt: t.addingTimeInterval(1)),
            Reaction(winID: line, crewID: crew, profileID: jayden, emoji: "❤️", createdAt: t.addingTimeInterval(2)),
        ]
        let chips = ChatReactionChips.chips(reactions, me: jayden)
        #expect(chips.map(\.mark) == ["❤️", "🔥"])
        #expect(chips.map(\.people.count) == [2, 1])
        #expect(chips.map(\.mine) == [true, false])
        // Two stickers are two chips: each is someone's own.
        let stickers = [
            Reaction(winID: line, crewID: crew, profileID: sam, emoji: "sticker:a.png", createdAt: t,
                     sketch: URL(fileURLWithPath: "/tmp/a.png")),
            Reaction(winID: line, crewID: crew, profileID: ana, emoji: "sticker:b.png", createdAt: t,
                     sketch: URL(fileURLWithPath: "/tmp/b.png")),
        ]
        #expect(ChatReactionChips.chips(stickers, me: jayden).count == 2)
        #expect(ChatReactionChips.chips(stickers, me: jayden).allSatisfy { $0.sticker != nil })
    }

    // MARK: - The chat's wiring

    @Test("the chat shows chips under a line and a hold opens the bar")
    func theChatIsWired() throws {
        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        #expect(chat.contains("let reactions = store.messageReactions(in: crewID)"))
        #expect(chat.contains("ChatReactionChips(reactions: reactions, me: store.me"), "the chips are gone")
        #expect(chat.contains("LongPressGesture(minimumDuration: Self.holdToReact)"), "a hold no longer reacts")
        #expect(chat.contains("if reacting == message.messageID, !mine {\n                reactionBar(message)"),
                "the bar no longer opens under a held friend's line")
        #expect(chat.contains("store.react(.emoji(emoji), toMessage: id, in: crewID)"))
        #expect(chat.contains("store.react(.sticker(name: file, png: png)"))
        #expect(chat.contains(".accessibilityAction(named: \"React\")"), "VoiceOver cannot hold a line")
        // Report and Block stay reachable from the hold, in the bar's ⋯.
        #expect(chat.contains("report: { closeBar(); reporting = message }"))
        #expect(chat.contains("block: { closeBar(); blocking = message }"))
        #expect(!chat.contains(".contextMenu"), "the hold is two things again")

        let bar = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/ChatReactions.swift"))
        #expect(bar.contains("ReactionBar(mine: mine.flatMap { $0.isSticker ? nil : $0.emoji }, bare: true)"),
                "the chat's bar is a private copy of the win's")
        #expect(bar.contains(".glassCapsule(onPage: true, interactive: false)"), "one still glass capsule")
        #expect(bar.components(separatedBy: ".glassCapsule(").count == 2, "a second glass element on the chat")
        #expect(bar.contains("Button(\"Report\"") && bar.contains("Button(\"Block \\(sender)\""))
        #expect(!bar.contains(".shadow("), "chrome casts no shadow")
        #expect(!bar.contains(".buttonStyle(.plain)"), "a sticker tile is not glass")
    }

    /// The owner, 2026-10-06: "understand the connection of all the
    /// elements". A friend reacting to your line is news in the chat, so it
    /// lights the chat's dot (and through it the crew's row, the Crews
    /// button and the app's badge), and opening the chat puts it out.
    @Test("a friend's reaction to your line lights the chat, and opening it puts it out")
    func reactionIsNews() async throws {
        let (a, b, crew, line) = try await pairWithALine()
        a.markChatSeen(crew.id)
        #expect(!a.hasUnreadChat(crew.id))
        await b.react(.emoji("🔥"), toMessage: line.messageID, in: crew.id)
        await a.refresh()
        #expect(a.hasUnreadChat(crew.id))
        #expect(a.unreadChats == [crew.id])
        a.markChatSeen(crew.id)
        #expect(!a.hasUnreadChat(crew.id))
        #expect(a.unreadChats.isEmpty)
        // Your own reaction to their line is never news to you.
        await b.send("you too", in: crew.id)
        await a.refresh()
        a.markChatSeen(crew.id)
        let theirs = try #require(a.messages(in: crew.id).first { $0.senderProfileID == sam })
        await a.react(.emoji("👏"), toMessage: theirs.messageID, in: crew.id)
        await a.refresh()
        #expect(!a.hasUnreadChat(crew.id))
    }

    @Test("the app's badge counts crews with a new chat, and opening one updates it")
    func badgeCountsChats() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Social/SocialStore.swift"))
        #expect(code.contains("let count = unread.union(unreadChats).count"))
        let seen = try #require(code.range(of: "func markChatSeen"))
        #expect(code[seen.lowerBound...].prefix(600).contains("updateBadge()"))
    }
}
