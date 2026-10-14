import Foundation
import Testing
import UIKit
@testable import Strata

/// **The hold menu on a chat line** (the owner, 2026-10-13: a friend's line
/// "Reply, Heart, Copy, Report", your own "Reply, Heart, Copy, Delete";
/// `docs/qol-research-2026-10-13.md` M2, M2c, M1).
///
/// The store's half: a reply quotes a line by its id on the existing
/// `quoteWinID` field, a deleted line leaves this screen at once and
/// everyone's chat only after Undo has passed, a plan's line is never
/// deleted, and a line that did not go can be tried again.
@MainActor
@Suite("Chat hold menu", .serialized)
struct ChatHoldMenuTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "chat-hold-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        await b.refresh()
        return (a, b, crew)
    }

    // MARK: Reply

    @Test("a reply quotes one of today's lines by its id, with no new field")
    func aReplyQuotesALine() async throws {
        let (a, b, crew) = try await pair()
        #expect(await b.send("see you at 6", in: crew.id) == .sent)
        await a.refresh()
        let line = try #require(a.messages(in: crew.id).first)
        #expect(await a.send("works for me", in: crew.id, answering: line.messageID) == .sent)
        await b.refresh()
        let reply = try #require(b.messages(in: crew.id).last)
        #expect(reply.quoteWinID == line.messageID && reply.text == "works for me")
        #expect(Set(CrewRecords.fields(reply).keys).isSubset(of: CrewRecords.messageKeys))
        #expect(!b.isWinLine(reply), "a reply on a line read as a win said")
    }

    @Test("a reply to a line that has gone goes as a plain line, and an unknown id is still refused")
    func aReplyToAGoneLine() async throws {
        let (a, _, crew) = try await pair()
        #expect(await a.send("hello", in: crew.id, answering: UUID()) == .sent)
        #expect(a.messages(in: crew.id).last?.quoteWinID == nil)
        #expect(await a.send("hello", in: crew.id, quoting: UUID()) == .notAllowed)
    }

    // MARK: Delete

    @Test("Delete hides the line at once, Undo brings it back, and only the expiry takes it from everyone")
    func deleteWithUndo() async throws {
        let (a, b, crew) = try await pair()
        #expect(await a.send("oops", in: crew.id) == .sent)
        let line = try #require(a.messages(in: crew.id).last)
        #expect(a.canDelete(line))

        a.holdBack(line: line.messageID)
        #expect(a.messages(in: crew.id).isEmpty, "the deleted line stayed on screen")
        await b.refresh()
        #expect(b.messages(in: crew.id).count == 1, "the delete left before Undo had passed")

        a.keepLine(line.messageID)
        #expect(a.messages(in: crew.id).count == 1, "Undo did not bring it back")

        a.holdBack(line: line.messageID)
        await a.deleteLine(line.messageID, in: crew.id)
        #expect(a.messages(in: crew.id).isEmpty)
        #expect(world.records(of: .message, in: crew.id).isEmpty, "the record stayed in the crew")
        await b.refresh()
        #expect(b.messages(in: crew.id).isEmpty, "the friend still sees it")
        await a.refresh()
        #expect(a.messages(in: crew.id).isEmpty, "a refresh brought it back")
    }

    @Test("only your own line can be deleted, and never a plan's")
    func whoMayDelete() async throws {
        let (a, b, crew) = try await pair()
        #expect(await b.send("mine, not yours", in: crew.id) == .sent)
        await a.refresh()
        let friends = try #require(a.messages(in: crew.id).first)
        #expect(!a.canDelete(friends))
        await a.deleteLine(friends.messageID, in: crew.id)
        await b.refresh()
        #expect(b.messages(in: crew.id).count == 1, "Jayden deleted Sam's line")

        let day = CrewDay.string(for: a.now(), in: crew.timeZone)
        let plan = await a.sendPlan(title: "Walk", when: .day(day), in: crew.id)
        let planLine = try #require(a.messages(in: crew.id).last)
        #expect(plan.outcome == .sent && planLine.groupPlan != nil)
        #expect(!a.canDelete(planLine), "a plan's line left the chat")
    }

    @Test("a deleted line's picture leaves the phone with it")
    func deleteTakesThePicture() async throws {
        let (a, _, crew) = try await pair()
        a.photoCheck = { _ in true }
        let png = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }.pngData()!
        #expect(await a.sendDoodle(png, in: crew.id) == .sent)
        let line = try #require(a.messages(in: crew.id).last)
        let file = try #require(line.sketch)
        #expect(FileManager.default.fileExists(atPath: file.path))
        await a.deleteLine(line.messageID, in: crew.id)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: Copy

    @Test("Copy is offered on words only")
    func copyIsForWords() {
        func line(_ text: String, sketch: URL? = nil) -> CrewMessage {
            CrewMessage(messageID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam, crewDay: "2026-10-14",
                        text: text, sketch: sketch, createdAt: .now)
        }
        let file = URL(fileURLWithPath: "/tmp/x.png")
        #expect(line("see you at 6").hasWordsToCopy)
        #expect(!line("", sketch: file).hasWordsToCopy, "a doodle")
        #expect(!line(CrewMessage.stripMarker, sketch: file).hasWordsToCopy, "a strip")
        #expect(!line(CrewMessage.pictureMarker + SocialStore.stickerWord, sketch: file).hasWordsToCopy, "a sticker")
        let plan = GroupPlan.line(title: "Walk", when: .day("2026-10-14"), sentOn: "2026-10-14") ?? ""
        #expect(!line(plan).hasWordsToCopy, "a plan's card")
    }

    // MARK: Not sent (M1)

    @Test("a line still waiting after ten seconds says it did not go, and Try Again sends it")
    func notSent() async throws {
        let (a, b, crew) = try await pair()
        // Written with no signal: drawn as sent at once, and kept in the
        // outbox, as a phone in a tunnel keeps it.
        let fake = try #require(a.cloud as? FakeCrewCloud)
        fake.offline = true
        #expect(await a.send("anyone?", in: crew.id) == .sent)
        fake.offline = false
        let line = try #require(a.messages(in: crew.id).last)
        #expect(!a.isUnsent(line, now: line.createdAt.addingTimeInterval(2)), "a line on its way said it failed")
        #expect(a.isUnsent(line, now: line.createdAt.addingTimeInterval(CrewMessage.unsentAfter)))
        await a.retry(line)
        #expect(!a.isUnsent(line, now: line.createdAt.addingTimeInterval(60)), "Try Again did not send it")
        await b.refresh()
        #expect(b.messages(in: crew.id).map(\.text) == ["anyone?"])
    }
}
