import Foundation
import Testing
import UIKit
@testable import Strata

/// **The chat's plus row, finished** (the owner, 2026-10-13: "the + button in
/// the chat needs like real care done to it", and "finish the recommended";
/// `docs/chat-plus-research-2026-10-13.md`, sections 3 and 4).
///
/// Win opens over the chat and the win lands in it as a line quoting it,
/// which rings nobody a second time; the empty strip page has a way forward.
@MainActor
@Suite("Chat plus row", .serialized)
struct ChatPlusRowTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "chat-plus-\(UUID().uuidString)"
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

    func win(_ title: String) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    func pings(_ kind: CrewPingRecord.Kind) -> [[String: String]] {
        world.pings.values.filter { $0[CrewPingRecord.kind] == kind.rawValue }
    }

    @Test("a win said in the chat is a line quoting it, with its title, on the existing record")
    func aWinIsSaid() async throws {
        let (a, b, crew) = try await pair()
        let gym = win("  Gym ")
        await a.post(gym, to: [crew.id])
        #expect(await a.sendWinLine(gym.winID, in: crew.id) == .sent)
        await b.refresh()
        let line = try #require(b.messages(in: crew.id).last)
        #expect(line.text == "Gym" && line.quoteWinID == gym.winID)
        #expect(b.isWinLine(line), "the friend's phone does not read it as the win said")
        #expect(Set(CrewRecords.fields(line).keys).isSubset(of: CrewRecords.messageKeys), "no new field")
    }

    @Test("only your own win, and one that reached this crew, is said")
    func onlyYourOwn() async throws {
        let (a, b, crew) = try await pair()
        let gym = win("Gym")
        await a.post(gym, to: [crew.id])
        await b.refresh()
        #expect(await b.sendWinLine(gym.winID, in: crew.id) == .notAllowed, "Sam said Jayden's win")
        #expect(await a.sendWinLine(UUID(), in: crew.id) == .notAllowed, "a win this crew never got")
    }

    @Test("an unnamed win is said as A win")
    func unnamed() {
        #expect(CrewMessage.winLineText("") == "A win")
        #expect(CrewMessage.winLineText("  Run ") == "Run")
    }

    @Test("a reply on your own win with other words is not a win said")
    func aReplyIsNotTheWin() {
        let crew = CrewID(rawValue: "c")
        let shared = SharedWin(winID: UUID(), crewID: crew, senderProfileID: jayden, crewDay: "2026-10-14", title: "Gym",
                               colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                               createdAt: .now, updatedAt: .now)
        #expect(CrewMessage.isWinLine(text: "Gym", sender: jayden, sketch: false, quoting: shared))
        #expect(!CrewMessage.isWinLine(text: "leg day done", sender: jayden, sketch: false, quoting: shared))
        #expect(!CrewMessage.isWinLine(text: "Gym", sender: sam, sketch: false, quoting: shared), "a friend quoting it")
        #expect(!CrewMessage.isWinLine(text: "Gym", sender: jayden, sketch: true, quoting: shared), "a doodle on it")
        #expect(!CrewMessage.isWinLine(text: "Gym", sender: jayden, sketch: false, quoting: nil))
    }

    @Test("the win's line rings nobody a second time: no chat ping, no chat alert")
    func noSecondRing() async throws {
        let (a, b, crew) = try await pair()
        a.sendsPings = true
        let gym = win("Gym")
        await a.post(gym, to: [crew.id])
        #expect(pings(.win).count == 1, "the win itself tells the crew")
        #expect(await a.sendWinLine(gym.winID, in: crew.id) == .sent)
        #expect(pings(.message).isEmpty, "the win's line pinged as a chat line")
        // An ordinary line after it still rings, so the gate was not spent.
        a.now = { Date().addingTimeInterval(SocialStore.messagePingGap + 1) }
        #expect(await a.send("see you there", in: crew.id) == .sent)
        #expect(pings(.message).count == 1)

        // The alert path, for a phone whose pings are not live.
        await b.refresh()
        let news = CrewNotifications.chatNews(b, seen: [], window: 3600, now: Date(), visible: nil)
        let counted = (news.grouped[crew.id] ?? []).map(\.text)
        #expect(!counted.contains("Gym"), "the win's line was counted as chat news")
        #expect(counted.contains("see you there"))
    }

    @Test("the strip's empty page says one thing and offers one way on")
    func emptyStrip() throws {
        #expect(CrewStripSendSheet.empty == "No photos today")
        #expect(CrewStripSendSheet.addWord == "Add a Win")
        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        #expect(chat.contains("addWin: { afterSheet { addWin(photo: nil) } }"), "the strip's Add a Win goes somewhere else")
        // **The camera card since 2026-10-18** (the owner: one way into Add a
        // Win, the old sheet gone). A kept chat photo still goes on your tower
        // only; the chat's own Add a Win, to it.
        #expect(chat.contains("AddWinRouter.shared.open(AddWinOpening("))
        #expect(chat.contains("crews: photo == nil ? [crew] : [], photo: photo"))
        #expect(!chat.contains("EditWinSheet("), "the chat opens the old sheet again")
    }
}
