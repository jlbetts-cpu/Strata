import Foundation
import Testing
@testable import Strata

/// **Usernames** (2026-10-16): the rules, first come, once a month, and the
/// handle on your member record.
@MainActor
@Suite("Usernames", .serialized)
struct HandleTests {
    let world = FakeCrewWorld()

    final class Kept { var handle: String?; var at: Date? }

    func store(_ me: UUID, kept: Kept) -> SocialStore {
        let suite = "handle-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.myFirstName = { "Sam" }
        store.myHandle = { kept.handle }
        store.myHandleSetAt = { kept.at }
        store.keepMyHandle = { kept.handle = $0; kept.at = $1 }
        return store
    }

    @Test("the rules")
    func rules() {
        #expect(Handle.normalized("  @Sam.Betts ") == "sam.betts")
        #expect(Handle.problem("sam") == nil)
        #expect(Handle.problem("sam_b.2") == nil)
        #expect(Handle.problem("sa") != nil)
        #expect(Handle.problem(String(repeating: "a", count: 21)) != nil)
        #expect(Handle.problem("sam b") != nil)
        #expect(Handle.problem(".sam") != nil)
        #expect(Handle.problem("sam.") != nil)
        #expect(Handle.problem("s..am") != nil)
        #expect(Handle.problem("somewins") != nil)
    }

    @Test("first come: a name someone has is taken, yours stays yours")
    func firstCome() async {
        let a = Kept(), b = Kept()
        let sam = store(UUID(), kept: a), ana = store(UUID(), kept: b)
        #expect(await sam.setHandle("sam") == .saved)
        #expect(a.handle == "sam")
        #expect(await ana.setHandle("@SAM") == .taken)
        #expect(b.handle == nil)
        #expect(await sam.setHandle("sam") == .same)
    }

    @Test("once a month, and the old name is let go")
    func monthly() async {
        let a = Kept(), b = Kept()
        let sam = store(UUID(), kept: a), ana = store(UUID(), kept: b)
        let start = Date()
        #expect(await sam.setHandle("sam", now: start) == .saved)
        if case .tooSoon = await sam.setHandle("sammy", now: start.addingTimeInterval(86_400)) {} else {
            Issue.record("changed within the month")
        }
        #expect(await sam.setHandle("sammy", now: start.addingTimeInterval(Handle.changeEvery + 60)) == .saved)
        #expect(a.handle == "sammy")
        // "sam" is free again.
        #expect(await ana.setHandle("sam") == .saved)
    }

    @Test("it rides on the member record, and a bad one read back is dropped")
    func onTheMemberRecord() {
        var member = CrewMember(profileID: UUID(), firstName: "Sam", head: nil, joinedAt: .now)
        member.handle = "sam"
        let fields = CrewRecords.fields(member)
        #expect(CrewRecords.member(fields)?.handle == "sam")
        var bad = fields
        bad["handle"] = .string("no spaces allowed")
        #expect(CrewRecords.member(bad)?.handle == nil)
    }

    @Test("names run together are still checked; nothing passes for the app")
    func filter() {
        #expect(Handle.problem("xniggerx") != nil)
        #expect(Handle.problem("rapist4life") != nil)
        #expect(Handle.problem("somewins_official") != nil)
        #expect(Handle.problem("tycoon") == nil)
        #expect(Handle.problem("grapes") == nil)
    }

    @Test("a friend's username shows only once it is theirs")
    func verified() async throws {
        let a = Kept(), b = Kept()
        let samID = UUID(), anaID = UUID()
        let sam = store(samID, kept: a), ana = store(anaID, kept: b)
        let (crew, link) = try await sam.createCrew(name: "Roommates")
        _ = try await ana.accept(CrewInvite(url: link))
        #expect(await ana.setHandle("ana") == .saved)
        await sam.refresh()
        let member = try #require(sam.crew(crew.id)?.member(anaID))
        #expect(member.handle == "ana")
        #expect(sam.shownHandle(of: member) == "ana")
        // One that is not theirs is not shown.
        var forged = member
        forged.handle = "sam"
        world.handles["sam"] = samID
        sam.handleChecked = [:]
        #expect(sam.shownHandle(of: forged) == nil)
    }

    @Test("a release that fails is owed and paid later; changing keeps first")
    func owed() async {
        let a = Kept()
        let samID = UUID()
        let cloud = FakeCrewCloud(world: world, me: samID)
        let suite = "handle-\(UUID().uuidString)"
        let sam = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!,
                              directory: FileManager.default.temporaryDirectory.appending(path: suite))
        sam.isEnabled = { false }
        sam.myHandle = { a.handle }
        sam.myHandleSetAt = { a.at }
        sam.keepMyHandle = { a.handle = $0; a.at = $1 }
        #expect(await sam.setHandle("sam") == .saved)
        sam.oweHandleRelease("sam")
        a.handle = nil
        cloud.offline = true
        await sam.payHandleReleases()
        #expect(world.handles["sam"] == samID)
        cloud.offline = false
        await sam.payHandleReleases()
        #expect(world.handles["sam"] == nil)
    }

    @Test("another iCloud account does not keep this one's username")
    func accountChange() async {
        let a = Kept()
        let samID = UUID()
        let cloud = FakeCrewCloud(world: world, me: samID)
        let suite = "handle-\(UUID().uuidString)"
        let sam = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!,
                              directory: FileManager.default.temporaryDirectory.appending(path: suite))
        sam.isEnabled = { true }
        sam.myHandle = { a.handle }
        sam.myHandleSetAt = { a.at }
        sam.keepMyHandle = { a.handle = $0; a.at = $1 }
        sam.forgetMyHandle = { a.handle = nil; a.at = nil }
        #expect(await sam.setHandle("sam") == .saved)
        cloud.signedIn = .signedIn("first")
        await sam.accountChanged()
        cloud.signedIn = .signedIn("second")
        await sam.accountChanged()
        #expect(a.handle == nil)
    }

    @Test("featured wins travel as ids and listed prompts only")
    func featured() {
        let a = UUID(), b = UUID()
        let items = [FeaturedWins.Shared(win: a, prompt: "Proudest win lately"),
                     FeaturedWins.Shared(win: b, prompt: "")]
        #expect(FeaturedWins.decode(FeaturedWins.encode(items)) == items)
        // A prompt that is not the app's own is dropped.
        let typed = FeaturedWins.encode([FeaturedWins.Shared(win: a, prompt: "anything at all")])
        #expect(FeaturedWins.decode(typed).isEmpty)
        var member = CrewMember(profileID: UUID(), firstName: "Sam", head: nil, joinedAt: .now)
        member.featured = items
        #expect(CrewRecords.member(CrewRecords.fields(member))?.featured == items)
    }

    @Test("a crew is told only of featured wins it was sent")
    func featuredPerCrew() async throws {
        let a = Kept()
        let samID = UUID()
        let sam = store(samID, kept: a)
        let (crew, _) = try await sam.createCrew(name: "Roommates")
        let sentWin = UUID(), elsewhere = UUID()
        await sam.post(OwnWin(winID: sentWin, title: "Run", colour: .health, icon: .health, blockSize: .small,
                              photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now), to: [crew.id])
        sam.myFeatured = { [FeaturedWins.Shared(win: sentWin, prompt: "Proudest win lately"),
                            FeaturedWins.Shared(win: elsewhere, prompt: "")] }
        await sam.setMyHead(nil)
        let mine = try #require(sam.crew(crew.id)?.member(samID))
        #expect(mine.featured.map(\.win) == [sentWin])
    }
}

@Suite("High, low, buffalo")
struct StoryWordsTests {
    @Test("the journal keeps the three as lines, replaced not repeated, the rest kept")
    func journal() {
        let first = JournalWords.merge(note: "A good day overall.", words: StoryWords(high: "Ran 5k", low: "Rain", buffalo: ""))
        #expect(first == "High: Ran 5k\nLow: Rain\n\nA good day overall.")
        let again = JournalWords.merge(note: first, words: StoryWords(high: "Ran 6k", low: "", buffalo: "Honey never goes off"))
        #expect(again == "High: Ran 6k\nBuffalo: Honey never goes off\n\nA good day overall.")
    }

    @Test("the three ride on the story record, checked and cut to a line")
    func record() {
        let win = SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: UUID(), crewDay: "2026-10-16",
                            title: "Run", colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                            createdAt: .now, updatedAt: .now)
        let story = CrewStory(win: win, endsAt: .now, line: "High", low: "Low", buffalo: String(repeating: "b", count: 200))
        let back = CrewRecords.story(CrewRecords.fields(story), crew: CrewID(rawValue: "c"))
        #expect(back?.low == "Low")
        #expect(back?.buffalo?.count == StoryLine.limit)
    }
}
