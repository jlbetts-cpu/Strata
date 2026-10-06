import Testing
import Foundation
import UIKit
@testable import Strata

/// **The crew's day chat** (the owner, 2026-10-05): text and emoji, up to 280
/// characters, cleared at the crew's midnight. A reply on a win and a doodle
/// both post here now, quoting the win, instead of riding on a reaction that
/// only the win's owner could see.
@MainActor
@Suite("Crew chat", .serialized)
struct CrewChatTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID, name: String? = nil) -> SocialStore {
        let suite = "chat-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        let given = name ?? (me == jayden ? "Jayden" : "Sam")
        store.myFirstName = { given }
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

    /// A small PNG, standing in for an exported doodle.
    func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 2, y: 2, width: 8, height: 8))
        }.pngData()!
    }

    // MARK: - The record

    /// The contract with every friend's phone, as the other three types have:
    /// it fails the day a field is added "just for the tooltip".
    @Test func theMessageKeysAreExactly() {
        #expect(CrewRecordType.message.rawValue == "CrewMessage")
        #expect(CrewRecordType.allCases.contains(.message))
        #expect(CrewRecords.messageKeys == ["messageID", "senderProfileID", "crewDay", "text",
                                            "quoteWinID", "sketch", "createdAt"])
        #expect(CrewRecords.keys(of: .message) == CrewRecords.messageKeys)
        let full = CrewMessage(messageID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam,
                               crewDay: "2026-10-05", text: "nice", quoteWinID: UUID(),
                               sketch: URL(fileURLWithPath: "/tmp/m.png"), createdAt: .now)
        #expect(Set(CrewRecords.fields(full).keys) == CrewRecords.messageKeys)
        #expect(CrewRecords.message(CrewRecords.fields(full), crew: full.crewID) == full)
        // A plain line carries no quote and no sketch: absent, not empty.
        let plain = CrewMessage(messageID: UUID(), crewID: full.crewID, senderProfileID: sam,
                                crewDay: "2026-10-05", text: "hi", createdAt: .now)
        #expect(CrewRecords.fields(plain)["quoteWinID"] == nil)
        #expect(CrewRecords.fields(plain)["sketch"] == nil)
    }

    /// Whatever a record claims, a message is a line of words or a doodle,
    /// never longer than 280 and never empty.
    @Test func aRecordCannotSmuggleMoreThanALine() {
        let crew = CrewID(rawValue: "c")
        var fields: RecordFields = ["messageID": .uuid(UUID()), "senderProfileID": .uuid(sam),
                                    "crewDay": .string("2026-10-05"), "createdAt": .date(.now),
                                    "text": .string(String(repeating: "a", count: 900))]
        #expect(CrewRecords.message(fields, crew: crew)?.text.count == CrewMessage.textLimit)
        fields["text"] = .string("   ")
        #expect(CrewRecords.message(fields, crew: crew) == nil, "an empty message is not one")
        fields["sketch"] = .asset(URL(fileURLWithPath: "/tmp/d.png"))
        #expect(CrewRecords.message(fields, crew: crew)?.sketch != nil, "a doodle needs no words")
    }

    // MARK: - Round trip

    @Test func aMessageGoesRoundTheCrew() async throws {
        let (a, b, crew) = try await pair()
        #expect(await b.send("  morning all  ", in: crew.id) == .sent)
        await a.refresh()
        let seen = a.messages(in: crew.id)
        #expect(seen.map(\.text) == ["morning all"])
        #expect(seen.first?.senderProfileID == sam)
        #expect(world.records(of: .message, in: crew.id).count == 1)
        // Both ways, in the order they were said.
        #expect(await a.send("hey 👋", in: crew.id) == .sent)
        await b.refresh()
        #expect(b.messages(in: crew.id).map(\.text) == ["morning all", "hey 👋"])
    }

    @Test func aLongMessageIsCutTo280() async throws {
        let (a, b, crew) = try await pair()
        await b.send(String(repeating: "x", count: 400), in: crew.id)
        await a.refresh()
        #expect(a.messages(in: crew.id).first?.text.count == 280)
    }

    // MARK: - The day

    /// The crew's midnight clears it: no phone shows another day's message,
    /// and each phone deletes its own.
    @Test func theChatClearsAtTheCrewsMidnight() async throws {
        let (a, b, crew) = try await pair()
        await b.send("today only", in: crew.id)
        #expect(await b.sendDoodle(png(), in: crew.id) == .sent)
        let file = try #require(b.messagesByCrew[crew.id]?.first { $0.sketch != nil }?.sketch)
        await a.refresh()
        #expect(a.messages(in: crew.id).count == 2)
        // The injection, so this can fail: a reader past midnight shows
        // nothing from yesterday, before anyone has deleted anything.
        let tomorrow = Date().addingTimeInterval(86_400)
        a.now = { tomorrow }
        #expect(a.messages(in: crew.id).isEmpty)
        // The writer's phone deletes its own, file and all.
        b.now = { tomorrow }
        b.prune()
        await b.flush()
        #expect(world.records(of: .message, in: crew.id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        // And today's message goes into today.
        await b.send("new day", in: crew.id)
        await a.refresh()
        #expect(a.messages(in: crew.id).map(\.text) == ["new day"])
    }

    /// The day is the crew's zone's, not the phone's.
    @Test func aMessageBelongsToTheCrewsDay() async throws {
        let (a, _, crew) = try await pair()
        await a.send("hi", in: crew.id)
        let sent = try #require(a.messagesByCrew[crew.id]?.first)
        #expect(sent.crewDay == CrewDay.string(for: sent.createdAt, in: crew.timeZone))
    }

    // MARK: - Words

    @Test func refusedWordsAreNeitherSentNorShown() async throws {
        let (a, b, crew) = try await pair()
        #expect(await b.send("k y s", in: crew.id) == .refusedWords)
        #expect(await b.send("you r3tard", in: crew.id) == .refusedWords)
        #expect(world.records(of: .message, in: crew.id).isEmpty)
        // A record written by anything else is checked on the reading phone.
        try await FakeCrewCloud(world: world, me: sam).save(
            ["messageID": .uuid(UUID()), "senderProfileID": .uuid(sam), "crewDay": .string(today(crew)),
             "createdAt": .date(.now), "text": .string("kys")],
            type: .message, name: UUID().uuidString, in: crew.id)
        await a.refresh()
        #expect(a.messages(in: crew.id).isEmpty)
        #expect(await b.send("first class run", in: crew.id) == .sent)
    }

    @Test func aDeclinedAgeReadsButCannotSend() async throws {
        let (a, b, crew) = try await pair()
        await a.send("hello", in: crew.id)
        b.canReply = { false }
        #expect(await b.send("hi", in: crew.id) == .notAllowed)
        #expect(await b.sendDoodle(png(), in: crew.id) == .notAllowed)
        await b.refresh()
        #expect(b.messages(in: crew.id).map(\.text) == ["hello"], "reading is still allowed")
    }

    // MARK: - People

    @Test func blockedPeopleAreDropped() async throws {
        let (a, b, crew) = try await pair()
        await b.send("hi", in: crew.id)
        await a.refresh()
        #expect(a.messages(in: crew.id).count == 1)
        a.block(sam)
        #expect(a.messages(in: crew.id).isEmpty)
        #expect(!a.hasUnreadChat(crew.id), "a blocked person's message is nothing new")
        a.unblock(sam)
        #expect(a.messages(in: crew.id).count == 1)
    }

    /// Only members: someone removed is gone with their messages, whoever's
    /// phone had not yet deleted them.
    @Test func onlyMembersMessagesAreKept() async throws {
        let (a, b, crew) = try await pair()
        await b.send("still here?", in: crew.id)
        try await a.remove(member: sam, from: crew.id)
        // Written back by a phone that had not heard, as an old record would be.
        world.zones[crew.id]?.records["\(CrewRecordType.message.rawValue)/\(UUID().uuidString)"] =
            ["messageID": .uuid(UUID()), "senderProfileID": .uuid(sam), "crewDay": .string(today(crew)),
             "createdAt": .date(.now), "text": .string("ghost")]
        await a.refresh()
        #expect(a.messages(in: crew.id).isEmpty)
        _ = b
    }

    // MARK: - Replies and doodles

    /// **Reply posts into the chat**, quoting the win, for the whole crew;
    /// it is no longer a line on a reaction.
    @Test func aReplyBecomesAQuotedMessage() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Morning run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        #expect(await b.reply("so proud", to: run.winID, in: crew.id) == .sent)
        await a.refresh()
        let said = try #require(a.messages(in: crew.id).first)
        #expect(said.text == "so proud")
        #expect(said.quoteWinID == run.winID)
        #expect(a.reactions(to: run.winID, in: crew.id).isEmpty, "a reply no longer rides on a reaction")
        // Anyone else in the crew sees it too: it is the crew's chat now.
        let c = store(UUID())
        c.adopt(crews: a.crews, wins: a.winsByCrew)
        for message in a.messagesByCrew[crew.id] ?? [] { c.receive(message) }
        #expect(c.messages(in: crew.id).map(\.quoteWinID) == [run.winID])
        // A reply needs a win that is in the crew.
        #expect(await b.reply("?", to: UUID(), in: crew.id) == .notAllowed)
    }

    @Test func aDoodleBecomesAMessageAndKeepsItsChecks() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.photoCheck = { _ in false }
        #expect(await b.doodle(png(), to: run.winID, in: crew.id) == .refusedSketch, "checked on the way out")
        #expect(world.records(of: .message, in: crew.id).isEmpty)
        b.photoCheck = { _ in true }
        #expect(await b.doodle(png(), to: run.winID, in: crew.id) == .sent)
        // Checked again on arrival: unchecked or flagged, never shown.
        a.incomingPolicy = { .check }
        a.incomingCheck = { _ in false }
        await a.refresh()
        await a.checkArrivedPhotos()
        #expect(a.messages(in: crew.id).isEmpty)
        // The injection: a phone whose check passes it shows it.
        let d = store(jayden)
        d.adopt(crews: a.crews, wins: a.winsByCrew)
        for message in a.messagesByCrew[crew.id] ?? [] { d.receive(message) }
        d.incomingPolicy = { .check }
        d.incomingCheck = { _ in true }
        await d.checkArrivedPhotos()
        let shown = try #require(d.messages(in: crew.id).first)
        #expect(shown.quoteWinID == run.winID)
        #expect(shown.sketch.flatMap { try? Data(contentsOf: $0) } == png())
    }

    /// Old data reads harmlessly: a reaction that still carries yesterday's
    /// kind of reply decodes, keeps its emoji, and nothing crashes.
    @Test func anOldReplyOnAReactionStillReads() {
        let fields: RecordFields = ["winID": .uuid(UUID()), "profileID": .uuid(sam), "emoji": .string("🔥"),
                                    "createdAt": .date(.now), "line": .string("nice one"),
                                    "sketch": .asset(URL(fileURLWithPath: "/tmp/old.png"))]
        let old = CrewRecords.reaction(fields, crew: CrewID(rawValue: "c"))
        #expect(old?.emoji == "🔥")
        #expect(old?.line == "nice one")
    }

    // MARK: - Unread

    @Test func unreadIsAFriendsMessageYouHaveNotOpened() async throws {
        let (a, b, crew) = try await pair()
        #expect(!a.hasUnreadChat(crew.id))
        await a.send("mine", in: crew.id)
        #expect(!a.hasUnreadChat(crew.id), "your own message is never news to you")
        await b.send("theirs", in: crew.id)
        await a.refresh()
        #expect(a.hasUnreadChat(crew.id))
        #expect(a.unreadChats == [crew.id])
        a.markChatSeen(crew.id)
        #expect(!a.hasUnreadChat(crew.id))
        // A newer one is unread again.
        await b.send("again", in: crew.id)
        await a.refresh()
        #expect(a.hasUnreadChat(crew.id))
        // A message from yesterday is not unread today.
        a.markChatSeen(crew.id)
        a.now = { Date().addingTimeInterval(86_400) }
        #expect(!a.hasUnreadChat(crew.id))
    }

    // MARK: - Notifications

    /// At most one a crew an hour, saying how many: "3 new in Roommates".
    @Test func chatAlertsAreGroupedHourly() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        var state = ChatAlerts.State()
        var step = ChatAlerts.step(state, fresh: ["m1"], now: start)
        #expect(step.post == 1, "the first one in an hour goes out")
        state = step.state
        step = ChatAlerts.step(state, fresh: ["m2", "m3"], now: start.addingTimeInterval(600))
        #expect(step.post == nil, "inside the hour, held")
        state = step.state
        step = ChatAlerts.step(state, fresh: ["m3", "m4"], now: start.addingTimeInterval(1800))
        #expect(step.post == nil)
        state = step.state
        step = ChatAlerts.step(state, fresh: [], now: start.addingTimeInterval(3600))
        #expect(step.post == 3, "an hour on, everything held is one notification, each message once")
        state = step.state
        #expect(ChatAlerts.step(state, fresh: [], now: start.addingTimeInterval(9000)).post == nil,
                "nothing new, nothing said")
    }

    @Test func aChatAlertReadsLikeTheOwnerAsked() async throws {
        let (a, b, crew) = try await pair()
        let known = try #require(a.crew(crew.id))
        #expect(CrewNotifications.Text.chat(count: 3, in: known, me: jayden) == "3 new in Roommates")
        #expect(CrewNotifications.Text.chat(count: 1, in: known, me: jayden) == "1 new in Roommates")
        // A reply quoting your win reads as a reply did: "Sam: so proud".
        let run = win("Morning run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        await b.reply("so proud", to: run.winID, in: crew.id)
        await a.refresh()
        let said = try #require(a.messages(in: crew.id).first)
        #expect(CrewNotifications.Text.quoted(said, in: known) == "Sam: so proud")
    }

    /// Which messages are news, and how: a quote of your own win is its own
    /// "Sam: …"; everything else from friends is counted for the hour; your
    /// own, a blocked person's and a muted crew's are not news at all.
    @Test func whatTheChatSays() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Morning run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        await b.send("hi", in: crew.id)
        await b.reply("so proud", to: run.winID, in: crew.id)
        await a.send("mine", in: crew.id)
        await a.refresh()
        var news = CrewNotifications.chatNews(a, seen: [], window: 3600, now: .now, visible: nil)
        #expect(news.grouped[crew.id]?.map(\.text) == ["hi"])
        #expect(news.quotedToMe.map(\.text) == ["so proud"])
        // Already seen: nothing.
        let ids = Set((a.messagesByCrew[crew.id] ?? []).map(\.messageID.uuidString))
        news = CrewNotifications.chatNews(a, seen: ids, window: 3600, now: .now, visible: nil)
        #expect(news.grouped.isEmpty && news.quotedToMe.isEmpty)
        // The crew on screen: nothing.
        news = CrewNotifications.chatNews(a, seen: [], window: 3600, now: .now, visible: crew.id)
        #expect(news.grouped.isEmpty && news.quotedToMe.isEmpty)
        // Muted: nothing.
        a.mute(crew.id, .hour)
        news = CrewNotifications.chatNews(a, seen: [], window: 3600, now: .now, visible: nil)
        #expect(news.grouped.isEmpty && news.quotedToMe.isEmpty)
        a.mute(crew.id, nil)
        // Blocked: nothing.
        a.block(sam)
        news = CrewNotifications.chatNews(a, seen: [], window: 3600, now: .now, visible: nil)
        #expect(news.grouped.isEmpty && news.quotedToMe.isEmpty)
    }

    private func today(_ crew: Crew) -> String { CrewDay.string(for: .now, in: crew.timeZone) }
}
