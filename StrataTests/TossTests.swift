import Testing
import Foundation
import UIKit
@testable import Strata

/// **A drawing thrown onto a crew's tower** (the owner, 2026-10-07): one a
/// person a day, carried as a marked chat doodle, never shown in the chat,
/// gone at the crew's midnight, tucked per phone, and landing ON the blocks.
@MainActor
@Suite("Tosses", .serialized)
struct TossTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "toss-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        let name = me == jayden ? "Jayden" : "Sam"
        store.myFirstName = { name }
        store.derive = { $0 }
        return store
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        return (a, b, crew)
    }

    func png(_ side: CGFloat = 12) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 2, y: 2, width: side - 4, height: side - 4))
        }.pngData()!
    }

    // MARK: - One a person a day

    @Test func oneDrawingAPersonADay() async throws {
        let (a, b, crew) = try await pair()
        #expect(await b.toss(png(), in: crew.id) == .sent)
        #expect(await b.toss(png(), in: crew.id) == .notAllowed, "a second toss the same day is refused")
        #expect(world.records(of: .message, in: crew.id).count == 1)
        await a.refresh()
        #expect(a.tosses(in: crew.id).map(\.senderProfileID) == [sam])
        // Yours too, alongside: one each, in the order thrown.
        #expect(await a.toss(png(), in: crew.id) == .sent)
        #expect(a.tosses(in: crew.id).map(\.senderProfileID) == [sam, jayden])
        #expect(a.myToss(in: crew.id) != nil)
        // A second record from the same sender, written by anything else,
        // is never shown: the first of the day stands.
        let first = try #require(a.tosses(in: crew.id).first)
        let later = CrewMessage(messageID: UUID(), crewID: crew.id, senderProfileID: sam, crewDay: first.crewDay,
                                text: CrewMessage.tossMarker, sketch: first.sketch,
                                createdAt: first.createdAt.addingTimeInterval(60))
        a.receive(later)
        #expect(a.tosses(in: crew.id).filter { $0.senderProfileID == sam }.map(\.messageID) == [first.messageID])
    }

    /// The age gate is the chat's: an age not shared draws nothing.
    @Test func theChatsGateHolds() async throws {
        let (_, b, crew) = try await pair()
        b.canReply = { false }
        #expect(await b.toss(png(), in: crew.id) == .notAllowed)
        #expect(world.records(of: .message, in: crew.id).isEmpty)
    }

    // MARK: - The marker

    /// It survives the record both ways, passes the word filter, and the
    /// decoder's whitespace trim leaves it alone.
    @Test func theMarkerRoundTrips() {
        let toss = CrewMessage(messageID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam,
                               crewDay: "2026-10-07", text: CrewMessage.tossMarker,
                               sketch: URL(fileURLWithPath: "/tmp/t.png"), createdAt: .now)
        let back = CrewRecords.message(CrewRecords.fields(toss), crew: toss.crewID)
        #expect(back == toss)
        #expect(back?.isToss == true)
        #expect(CrewWords.isAcceptable(CrewMessage.tossMarker))
        #expect(CrewMessage.tossMarker.trimmingCharacters(in: .whitespacesAndNewlines) == CrewMessage.tossMarker)
        // The injection, so this can fail: words are not a toss, and nor is
        // the marker without a drawing.
        var words = toss
        words.text = "hi"
        #expect(!words.isToss)
        let bare = CrewMessage(messageID: UUID(), crewID: toss.crewID, senderProfileID: sam, crewDay: "2026-10-07",
                               text: CrewMessage.tossMarker, createdAt: .now)
        #expect(!bare.isToss)
    }

    /// The chat never shows a toss, so it lights no dot and asks no alert;
    /// a plain doodle still shows.
    @Test func theChatHidesTosses() async throws {
        let (a, b, crew) = try await pair()
        await b.toss(png(), in: crew.id)
        await a.refresh()
        #expect(a.tosses(in: crew.id).count == 1)
        #expect(a.messages(in: crew.id).isEmpty)
        #expect(!a.hasUnreadChat(crew.id))
        let news = CrewNotifications.chatNews(a, seen: [], window: 3600, now: .now, visible: nil)
        #expect(news.grouped.isEmpty && news.quotedToMe.isEmpty)
        await b.sendDoodle(png(), in: crew.id)
        await a.refresh()
        #expect(a.messages(in: crew.id).count == 1, "an ordinary doodle is still a chat line")
        #expect(a.tosses(in: crew.id).count == 1)
    }

    @Test func aBlockedSendersDrawingIsHidden() async throws {
        let (a, b, crew) = try await pair()
        await b.toss(png(), in: crew.id)
        await a.refresh()
        a.block(sam)
        #expect(a.tosses(in: crew.id).isEmpty)
        a.unblock(sam)
        #expect(a.tosses(in: crew.id).count == 1)
    }

    // MARK: - Midnight

    @Test func goneAtTheCrewsMidnight() async throws {
        let (a, b, crew) = try await pair()
        await b.toss(png(), in: crew.id)
        await a.refresh()
        #expect(a.tosses(in: crew.id).count == 1)
        let tomorrow = Date().addingTimeInterval(86_400)
        a.now = { tomorrow }
        #expect(a.tosses(in: crew.id).isEmpty, "a reader past midnight shows nothing from yesterday")
        // And the writer may throw again the next day.
        b.now = { tomorrow }
        #expect(b.myToss(in: crew.id) == nil)
        #expect(await b.toss(png(), in: crew.id) == .sent)
        // The writer's phone deletes its own at the end of the day.
        b.now = { tomorrow.addingTimeInterval(86_400) }
        b.prune()
        await b.flush()
        #expect(world.records(of: .message, in: crew.id).isEmpty)
    }

    // MARK: - Tucked, per phone, per day

    @Test func tuckedPersistsForTheDayOnly() {
        let defaults = UserDefaults(suiteName: "toss-shelf-\(UUID().uuidString)")!
        let crew = CrewID(rawValue: "crew-x")
        let one = UUID(), two = UUID()
        let shelf = CrewTossShelf(crewID: crew, defaults: defaults)
        shelf.tuck(one, on: "2026-10-07")
        shelf.tuck(two, on: "2026-10-07")
        shelf.tuck(one, on: "2026-10-07")
        // A new shelf on the same defaults: what a relaunch reads.
        let again = CrewTossShelf(crewID: crew, defaults: defaults)
        #expect(again.tucked(on: "2026-10-07") == [one, two])
        #expect(again.tucked(on: "2026-10-08").isEmpty, "midnight empties it")
        #expect(CrewTossShelf(crewID: CrewID(rawValue: "other"), defaults: defaults).tucked(on: "2026-10-07").isEmpty)
        again.markLanded(one, on: "2026-10-07")
        again.putBack(one, on: "2026-10-07")
        #expect(again.tucked(on: "2026-10-07") == [two])
        #expect(!again.landed(on: "2026-10-07").contains(one), "put back, it falls in again")
        // A tuck on a new day starts that day's list afresh.
        again.tuck(one, on: "2026-10-08")
        #expect(again.tucked(on: "2026-10-08") == [one])
        #expect(again.tucked(on: "2026-10-07").isEmpty)
    }

    // MARK: - The physics

    /// A 393pt-wide tower, cells 85.25, a block two rows tall in column 1.
    func world(blocks: [TowerCompanionWorld.Cell], slot: CGRect? = nil) -> TossWorld {
        let cell: CGFloat = 85.25, floor: CGFloat = 700
        let gridH = CGFloat(3) * cell + 2 * GridConstants.spacing
        let sky = TowerSkyline.build(cells: blocks, originX: 16, cellSize: cell, gutter: GridConstants.spacing,
                                     gridTopY: floor - gridH, gridHeight: gridH, cornerInset: 12)
        return TossWorld(skyline: sky, floorY: floor, left: 2, right: 391, solids: slot.map { [$0] } ?? [],
                         gravity: GridConstants.dropGravity)
    }

    /// **It comes to rest ON the block, not inside it**, over every seed:
    /// the ink's foot on the highest top under it, to half a point.
    @Test func aDrawingRestsOnTheBlockNotInIt() {
        let w = world(blocks: [.init(1, 0, 1, 2), .init(3, 0, 1, 1)])
        var onABlock = 0
        for n in 0..<120 {
            var bodies = [TossPhysics.spawn(id: UUID(), seed: UInt64(n) &* 7919 | 1, aspect: 1.2,
                                            longest: 90...110, sinkFraction: 0.05, above: 0, in: w)]
            TossPhysics.settle(&bodies, in: w)
            let b = bodies[0]
            #expect(b.resting, "seed \(n) never came to rest")
            let span = TossPhysics.span(b)
            let support = w.skyline.highestTop(from: span.lowerBound, to: span.upperBound)
            let foot = TossPhysics.bottom(b)
            #expect(foot <= support + 0.5, "seed \(n): foot \(foot) is inside the block topped at \(support)")
            #expect(foot >= support - 0.5, "seed \(n): foot \(foot) floats over \(support)")
            #expect(b.position.x - TossPhysics.extent(b).width >= w.left - 0.5)
            #expect(b.position.x + TossPhysics.extent(b).width <= w.right + 0.5)
            if support < w.floorY - 1 { onABlock += 1 }
        }
        // The injection, so this can fail: some of them land on a block.
        #expect(onABlock > 10, "only \(onABlock) of 120 landed on a block; the test is not testing that")
    }

    /// The slot is a solid: a drawing never ends over it.
    @Test func neverOverTheSlot() {
        let cell: CGFloat = 85.25
        let slot = CGRect(x: 16 + (cell + 4) * 2, y: 700 - cell, width: cell, height: cell)
        let w = world(blocks: [.init(0, 0, 1, 1)], slot: slot)
        for n in 0..<60 {
            var bodies = [TossPhysics.spawn(id: UUID(), seed: UInt64(n) &* 104_729 | 1, aspect: 0.8,
                                            longest: 90...110, above: 0, in: w)]
            TossPhysics.settle(&bodies, in: w)
            let b = bodies[0]
            let e = TossPhysics.extent(b)
            let frame = CGRect(x: b.position.x - e.width * TossPhysics.footprint, y: b.position.y - e.height,
                               width: e.width * 2 * TossPhysics.footprint, height: e.height * 2 - b.sink - 1)
            #expect(!frame.intersects(slot), "seed \(n) lies over the slot")
        }
    }

    /// Two drawings land in order and the second stands on the first when
    /// it falls on it; the ground rising under one lifts it.
    @Test func theyStackAndRiseWithTheTower() {
        let w = world(blocks: [])
        var bodies = [TossPhysics.spawn(id: UUID(), seed: 3, aspect: 1, longest: 100...100, above: 0, in: w)]
        TossPhysics.settle(&bodies, in: w)
        var second = TossPhysics.spawn(id: UUID(), seed: 5, aspect: 1, longest: 100...100, above: 0, in: w)
        second.position.x = bodies[0].position.x
        second.velocity = .zero
        bodies.append(second)
        TossPhysics.settle(&bodies, only: 1, in: w)
        #expect(TossPhysics.bottom(bodies[1]) < bodies[0].position.y, "the second stands on the first")
        // A block lands under the first: it is lifted onto it, not left inside.
        let column = w.skyline.columnIndex(atX: bodies[0].position.x)
        let risen = world(blocks: [.init(column, 0, 1, 1)])
        TossPhysics.settle(&bodies, in: risen)
        let span = TossPhysics.span(bodies[0])
        #expect(TossPhysics.bottom(bodies[0]) <= risen.skyline.highestTop(from: span.lowerBound, to: span.upperBound) + 0.5)
        #expect(TossPhysics.bottom(bodies[0]) < w.floorY - 10, "it was lifted off the ground")
        #expect(TossPhysics.bottom(bodies[1]) < bodies[0].position.y, "and the one on it rose too")
    }

    /// The same drawing on the same phone lands in the same place; another
    /// phone's salt lands it elsewhere.
    @Test func aLandingIsStablePerPhone() {
        let w = world(blocks: [.init(0, 0, 2, 1)])
        let id = UUID()
        func land(_ salt: UUID) -> CGPoint {
            var bodies = [TossPhysics.spawn(id: id, seed: TossPhysics.seed(for: id, salt: salt), aspect: 1,
                                            longest: GridConstants.tossSide, above: 0, in: w)]
            TossPhysics.settle(&bodies, in: w)
            return bodies[0].position
        }
        #expect(land(jayden) == land(jayden))
        #expect(land(jayden) != land(sam))
    }
}
