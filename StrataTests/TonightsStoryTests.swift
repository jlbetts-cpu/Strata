import Foundation
import Testing
import UIKit
@testable import Strata

/// **Tonight's Story** (2026-10-15; `docs/superpowers/plans/2026-10-15-tonights-story.md`):
/// the clock (R5, R6), the record (R17), posting and taking off (R1 to R4),
/// the row's order (R7), and reactions that outlive the night (R12).
@MainActor
@Suite("Tonight's Story", .serialized)
struct TonightsStoryTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()
    let la = TimeZone(identifier: "America/Los_Angeles")!
    let ny = TimeZone(identifier: "America/New_York")!

    func store(_ me: UUID) -> SocialStore {
        let suite = "story-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        return store
    }

    func date(_ day: String, _ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        let start = CrewDay.start(of: day, in: zone)!
        return c.date(bySettingHour: hour, minute: minute, second: 0, of: start)!
    }

    func story(_ sender: UUID, day: String = "2026-10-15", made: Date, photo: URL? = nil, ends: Date? = nil) -> CrewStory {
        let win = SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sender, crewDay: day,
                            title: "Run", colour: .health, icon: .health, blockSize: .small, photo: photo,
                            cropX: nil, cropY: nil, createdAt: made, updatedAt: made)
        return CrewStory(win: win, endsAt: ends ?? StoryClock.endsAt(of: day, in: la)!)
    }

    func win(_ title: String = "Run", at made: Date = .now, photo: Data? = nil) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: photo, cropX: nil, cropY: nil, createdAt: made, updatedAt: made)
    }

    // MARK: The clock

    @Test("it waits before 8pm, opens at 8pm and is gone at 9am, by the viewer's clock")
    func windows() {
        let s = story(sam, made: date("2026-10-15", 14, in: la))
        #expect(StoryClock.phase(of: s, at: date("2026-10-15", 19, 59, in: la), in: la) == .waiting)
        #expect(StoryClock.phase(of: s, at: date("2026-10-15", 20, in: la), in: la) == .open)
        #expect(StoryClock.phase(of: s, at: date("2026-10-16", 8, 59, in: la), in: la) == .open)
        #expect(StoryClock.phase(of: s, at: date("2026-10-16", 9, in: la), in: la) == .gone)
        // A friend in New York sees it at their own 8pm, three hours sooner.
        #expect(StoryClock.phase(of: s, at: date("2026-10-15", 20, 30, in: ny), in: ny) == .open)
        #expect(StoryClock.phase(of: s, at: date("2026-10-15", 19, 30, in: ny), in: ny) == .waiting)
    }

    @Test("the sealed end wins over any clock, and a night days away never lights a ring")
    func hardEnd() {
        let ends = date("2026-10-16", 12, in: la)
        #expect(StoryClock.endsAt(of: "2026-10-15", in: la) == ends)
        // Far to the west, 9am comes after the poster's noon: the end decides.
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        let s = story(sam, made: date("2026-10-15", 14, in: la))
        #expect(StoryClock.phase(of: s, at: ends.addingTimeInterval(-60), in: honolulu) == .open)
        #expect(StoryClock.phase(of: s, at: ends, in: honolulu) == .gone)
        let ahead = story(sam, day: "2026-10-18", made: date("2026-10-15", 14, in: la))
        #expect(StoryClock.phase(of: ahead, at: date("2026-10-15", 15, in: la), in: la) == .gone)
    }

    @Test("only today's wins go on a story")
    func onlyToday() {
        let now = date("2026-10-15", 22, in: la)
        #expect(StoryClock.canPost(winMadeAt: date("2026-10-15", 8, in: la), at: now, in: la))
        #expect(!StoryClock.canPost(winMadeAt: date("2026-10-14", 23, in: la), at: now, in: la))
    }

    // MARK: The record

    @Test("a story record round-trips, and one without its end is not a story")
    func roundTrip() throws {
        let s = story(sam, made: date("2026-10-15", 14, in: la))
        let fields = CrewRecords.fields(s)
        #expect(Set(fields.keys).isSubset(of: CrewRecords.storyKeys))
        let back = try #require(CrewRecords.story(fields, crew: CrewID(rawValue: "c")))
        #expect(back == s)
        var endless = fields
        endless["endsAt"] = nil
        #expect(CrewRecords.story(endless, crew: CrewID(rawValue: "c")) == nil)
        // Its photo files are a family of their own, never the crew copy's.
        #expect(PublicCrewCloud.family(.story, name: "w") != PublicCrewCloud.family(.sharedWin, name: "w"))
    }

    // MARK: Posting

    @Test("a story reaches a friend, once, and comes off at once")
    func postAndWithdraw() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        let (second, link2) = try await a.createCrew(name: "Team")
        _ = try await b.accept(CrewInvite(url: link2))
        await a.refresh()
        let run = win()
        await a.postStory(run)
        #expect(a.isOnStory(run.winID))
        #expect(a.myStory.map(\.id) == [run.winID])
        // Into every crew, sealed with each.
        #expect(world.records(of: .story, in: crew.id)[run.winID.uuidString] != nil)
        #expect(world.records(of: .story, in: second.id)[run.winID.uuidString] != nil)
        await b.refresh()
        let tonight = date(CrewDay.string(for: .now, in: .current), 21, in: .current)
        let row = b.storyPeople(at: tonight)
        #expect(row.count == 1)
        #expect(row.first?.profileID == jayden && row.first?.stories.count == 1 && row.first?.phase == .open)
        await a.withdrawStory(winID: run.winID)
        #expect(!a.isOnStory(run.winID))
        #expect(world.records(of: .story, in: crew.id)[run.winID.uuidString] == nil)
        #expect(world.records(of: .story, in: second.id)[run.winID.uuidString] == nil)
    }

    @Test("deleting the win takes it off the story")
    func deleteTakesItOff() async throws {
        let a = store(jayden)
        let (crew, _) = try await a.createCrew(name: "Roommates")
        let run = win()
        await a.postStory(run)
        await a.deleteEverywhere(winID: run.winID)
        #expect(!a.isOnStory(run.winID))
        #expect(world.records(of: .story, in: crew.id).isEmpty)
    }

    @Test("13 to 15 send the block and never the photo")
    func teenSendsTheBlock() async throws {
        let a = store(jayden)
        a.photosAllowed = { false }
        let (crew, _) = try await a.createCrew(name: "Roommates")
        let jpeg = try #require(UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { ctx in
            UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }.jpegData(compressionQuality: 0.8))
        let run = win(photo: jpeg)
        await a.postStory(run)
        let record = try #require(world.records(of: .story, in: crew.id)[run.winID.uuidString])
        #expect(record["photo"] == nil)
        #expect(record["title"] != nil)
    }

    @Test("yesterday's win cannot go on tonight's story")
    func notYesterday() async throws {
        let a = store(jayden)
        let (crew, _) = try await a.createCrew(name: "Roommates")
        let old = win(at: Date().addingTimeInterval(-2 * 86_400))
        await a.postStory(old)
        #expect(!a.isOnStory(old.winID))
        #expect(world.records(of: .story, in: crew.id).isEmpty)
    }

    @Test("past its end the poster's phone deletes it")
    func sweep() async throws {
        let a = store(jayden)
        let (crew, _) = try await a.createCrew(name: "Roommates")
        await a.refresh()
        let run = win()
        await a.postStory(run)
        a.now = { Date().addingTimeInterval(2 * 86_400) }
        a.prune()
        await a.flush()
        #expect(!a.isOnStory(run.winID))
        #expect(world.records(of: .story, in: crew.id).isEmpty)
    }

    // MARK: The row

    @Test("unwatched first, newest first; then watched; then waiting; never blocked, hidden or you")
    func order() {
        let c = CrewID(rawValue: "c")
        let ana = UUID(), ben = UUID(), cat = UUID(), dan = UUID(), eve = UUID()
        let evening = date("2026-10-15", 21, in: la)
        let anaS = story(ana, made: date("2026-10-15", 10, in: la))
        let benS = story(ben, made: date("2026-10-15", 12, in: la))
        let catS = story(cat, made: date("2026-10-15", 13, in: la))
        let mine = story(jayden, made: date("2026-10-15", 14, in: la))
        let danS = story(dan, made: date("2026-10-15", 15, in: la))
        let eveS = story(eve, made: date("2026-10-15", 16, in: la))
        let all = [c: [anaS, benS, catS, mine, danS, eveS]]
        let row = StoryPerson.gather(all, crewOrder: [c], me: jayden, blocked: [dan], hidden: [eve: "2026-10-15"],
                                     seen: [benS.id], now: evening, zone: la)
        #expect(row.map(\.profileID) == [cat, ana, ben])
        #expect(row.last?.watched == true)
        // Before 8pm the same people wait, and nobody has watched anything.
        let afternoon = StoryPerson.gather(all, crewOrder: [c], me: jayden, blocked: [], hidden: [:],
                                           seen: [benS.id], now: date("2026-10-15", 15, in: la), zone: la)
        #expect(afternoon.allSatisfy { $0.phase == .waiting && !$0.watched })
    }

    @Test("a friend in two crews is one person with each story once")
    func onceAcrossCrews() {
        let one = CrewID(rawValue: "one"), two = CrewID(rawValue: "two")
        let s = story(sam, made: date("2026-10-15", 10, in: la))
        var copy = s
        copy.win = SharedWin(winID: s.id, crewID: two, senderProfileID: sam, crewDay: s.day, title: "Run",
                             colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                             createdAt: s.win.createdAt, updatedAt: s.win.updatedAt)
        let row = StoryPerson.gather([one: [s], two: [copy]], crewOrder: [one, two], me: jayden, blocked: [],
                                     hidden: [:], seen: [], now: date("2026-10-15", 21, in: la), zone: la)
        #expect(row.count == 1 && row.first?.stories.count == 1)
        #expect(row.first?.stories.first?.win.crewID == s.win.crewID)
    }

    // MARK: One tower

    @Test("a reaction to your story lands on your block and stays after the night")
    func reactionStays() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        let run = win()
        await a.postStory(run)
        await b.refresh()
        await b.react("🔥", to: run.winID, in: crew.id)
        await a.refresh()
        #expect(a.reactionsToMyWins()[run.winID]?.map(\.emoji) == ["🔥"])
        // The night ends: the story goes, and Sam's phone clears its reaction.
        a.now = { Date().addingTimeInterval(2 * 86_400) }
        b.now = { Date().addingTimeInterval(2 * 86_400) }
        a.prune()
        await a.flush()
        await b.refresh()
        b.prune()
        await b.flush()
        await a.refresh()
        #expect(a.storiesByCrew[crew.id]?.isEmpty ?? true)
        #expect(a.reactionsToMyWins()[run.winID]?.map(\.emoji) == ["🔥"])
    }
}
