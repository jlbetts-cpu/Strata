import Testing
import Foundation
import SwiftData
@testable import Strata

/// **Shared wins: "with Sam".** A win can name up to three people in the
/// crews it goes to, and each of them is asked once whether to keep a copy
/// (spec `2026-10-05-shared-wins-journal-doodles-design.md`, section 1).
///
/// Saying no is silent, the tagger is never told, and a tag from someone
/// you blocked never asks you anything.
@MainActor
@Suite("Crew tags", .serialized)
struct CrewTagTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID, name: String? = nil, defaults: UserDefaults? = nil) -> SocialStore {
        let suite = "tag-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: defaults ?? UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.myFirstName = { name ?? (me == jayden ? "Jayden" : "Sam") }
        store.derive = { $0 }
        return store
    }

    func win(_ title: String = "Morning run", with people: [UUID] = []) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .medium,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now, withPeople: people)
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        return (a, b, crew)
    }

    // MARK: The record

    @Test func aTagCrossesToTheTaggedPhone() async throws {
        let (a, b, crew) = try await pair()
        let run = win(with: [sam])
        await a.post(run, to: [crew.id])
        let record = try #require(world.records(of: .sharedWin, in: crew.id).values.first)
        #expect(record["withPeople"] == .string(sam.uuidString))
        await b.refresh()
        #expect(b.today(in: crew.id).first?.withPeople == [sam])
        #expect(b.tagToAsk(in: crew.id)?.winID == run.winID)
        // The tagger is never asked about their own win.
        #expect(a.tagToAsk(in: crew.id) == nil)
    }

    @Test func anUntaggedWinWritesNoField() async throws {
        let (a, _, crew) = try await pair()
        await a.post(win(), to: [crew.id])
        #expect(world.records(of: .sharedWin, in: crew.id).values.first?["withPeople"] == nil)
    }

    /// The owner's number (spec 1): up to three. Yourself, and anyone not in
    /// the crew, never make it into the record.
    @Test func aWinNamesThreePeopleAtMost() async throws {
        let a = store(jayden)
        let (crew, link) = try await a.createCrew(name: "Big")
        var friends: [UUID] = []
        for i in 0..<5 {
            let id = UUID()
            _ = try await store(id, name: "F\(i)").accept(CrewInvite(url: link))
            friends.append(id)
        }
        await a.refresh()
        await a.post(win(with: [jayden, UUID()] + friends), to: [crew.id])
        let shared = try #require(a.wins(in: crew.id).first)
        #expect(shared.withPeople == Array(friends.prefix(CrewCaps.withPeople)))
        #expect(CrewCaps.withPeople == 3)
        // And a record that claims more is read as three.
        var fields = CrewRecords.fields(shared)
        fields["withPeople"] = .string(friends.map(\.uuidString).joined(separator: ","))
        #expect(CrewRecords.sharedWin(fields, crew: crew.id)?.withPeople.count == 3)
    }

    /// Only your crew sees who a win was with: a tag of someone who is not
    /// in a crew is not sent to it.
    @Test func eachCrewOnlyHearsItsOwnPeople() async throws {
        let a = store(jayden)
        let (one, link) = try await a.createCrew(name: "One")
        let (two, _) = try await a.createCrew(name: "Two")
        _ = try await store(sam).accept(CrewInvite(url: link))
        await a.refresh()
        await a.post(win(with: [sam]), to: [one.id, two.id])
        #expect(world.records(of: .sharedWin, in: one.id).values.first?["withPeople"] == .string(sam.uuidString))
        #expect(world.records(of: .sharedWin, in: two.id).values.first?["withPeople"] == nil)
    }

    /// An edit is rebuilt from the `HabitLog`, which knows nothing of tags.
    /// It must not strip them.
    @Test func anEditKeepsTheTags() async throws {
        let (a, b, crew) = try await pair()
        var run = win(with: [sam])
        await a.post(run, to: [crew.id])
        run.title = "Long run"
        run.withPeople = []
        run.updatedAt = .now.addingTimeInterval(5)
        await a.update(run)
        await b.refresh()
        #expect(b.today(in: crew.id).first?.title == "Long run")
        #expect(b.today(in: crew.id).first?.withPeople == [sam])
    }

    // MARK: Keep it?

    @Test func keepCallsTheHookOnceAndAsksNoMore() async throws {
        let (a, b, crew) = try await pair()
        await a.post(win(with: [sam]), to: [crew.id])
        await b.refresh()
        var kept: [SharedWin] = []
        b.keepTaggedWin = { kept.append($0) }
        let asked = try #require(b.tagToAsk(in: crew.id))
        await b.answer(asked, keep: true)
        await b.answer(asked, keep: true)
        #expect(kept.map(\.winID) == [asked.winID])
        #expect(kept.first?.title == "Morning run")
        #expect(b.tagToAsk(in: crew.id) == nil)
    }

    @Test func notThisOneNeverAsksAgain() async throws {
        let (a, _, crew) = try await pair()
        let suite = "tag-answers-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        // Sam's phone, with the defaults a relaunch would read.
        let phone = store(sam, defaults: defaults)
        await a.post(win(with: [sam]), to: [crew.id])
        await phone.refresh()
        var kept = 0
        phone.keepTaggedWin = { _ in kept += 1 }
        let asked = try #require(phone.tagToAsk(in: crew.id))
        await phone.answer(asked, keep: false)
        #expect(phone.tagToAsk(in: crew.id) == nil)
        #expect(kept == 0)
        // Silent: nothing is written for the tagger to see.
        #expect(world.records(of: .reaction, in: crew.id).isEmpty)
        // A relaunch, and a refresh, still do not ask.
        let relaunched = store(sam, defaults: defaults)
        await relaunched.refresh()
        #expect(relaunched.today(in: crew.id).count == 1)
        #expect(relaunched.tagToAsk(in: crew.id) == nil)
    }

    /// The same win sent to two crews you are both in is one question.
    @Test func oneWinInTwoCrewsAsksOnce() async throws {
        let a = store(jayden), b = store(sam)
        let (one, linkOne) = try await a.createCrew(name: "One")
        let (two, linkTwo) = try await a.createCrew(name: "Two")
        _ = try await b.accept(CrewInvite(url: linkOne))
        _ = try await b.accept(CrewInvite(url: linkTwo))
        await a.refresh()
        await a.post(win(with: [sam]), to: [one.id, two.id])
        await b.refresh()
        let asked = try #require(b.tagToAsk())
        await b.answer(asked, keep: false)
        #expect(b.tagToAsk() == nil)
    }

    @Test func aBlockedTaggerIsIgnored() async throws {
        let (a, b, crew) = try await pair()
        await a.post(win(with: [sam]), to: [crew.id])
        await b.refresh()
        #expect(b.tagToAsk(in: crew.id) != nil)
        b.block(jayden)
        #expect(b.tagToAsk(in: crew.id) == nil)
        #expect(b.tagToAsk() == nil)
    }

    /// The With row lists the people in the chosen crews: never you, never
    /// anyone you blocked, each once.
    @Test func theWithRowListsTheChosenCrewsPeople() async throws {
        let a = store(jayden)
        let (one, linkOne) = try await a.createCrew(name: "One")
        let (two, linkTwo) = try await a.createCrew(name: "Two")
        let b = store(sam)
        _ = try await b.accept(CrewInvite(url: linkOne))
        _ = try await b.accept(CrewInvite(url: linkTwo))
        let ana = UUID()
        _ = try await store(ana, name: "Ana").accept(CrewInvite(url: linkTwo))
        await a.refresh()
        #expect(a.taggable(in: [one.id]).map(\.profileID) == [sam])
        #expect(a.taggable(in: [one.id, two.id]).map(\.profileID) == [sam, ana])
        #expect(a.taggable(in: []).isEmpty)
        a.block(ana)
        #expect(a.taggable(in: [one.id, two.id]).map(\.profileID) == [sam])
    }

    // MARK: The block's sender line

    @Test func theSenderLineSaysWhoItWasWith() {
        let me = UUID(), ana = UUID(), leo = UUID()
        let names = [sam: "Sam", ana: "Ana", leo: "Leo", me: "Jayden"]
        func shared(from sender: UUID, with people: [UUID]) -> SharedWin {
            SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sender, crewDay: "2026-10-05",
                      title: "Run", colour: .health, icon: .health, blockSize: .small, photo: nil,
                      cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now, withPeople: people)
        }
        #expect(CrewTowerModel.senderLine(shared(from: sam, with: []), me: me, names: names) == "Sam")
        #expect(CrewTowerModel.senderLine(shared(from: sam, with: [ana]), me: me, names: names) == "Sam with Ana")
        #expect(CrewTowerModel.senderLine(shared(from: sam, with: [me]), me: me, names: names) == "Sam with you")
        #expect(CrewTowerModel.senderLine(shared(from: sam, with: [me, ana, leo]), me: me, names: names)
                == "Sam with Ana, Leo & you")
        #expect(CrewTowerModel.senderLine(shared(from: me, with: []), me: me, names: names) == nil)
        #expect(CrewTowerModel.senderLine(shared(from: me, with: [sam]), me: me, names: names) == "You with Sam")
        #expect(CrewTowerModel.senderLine(shared(from: me, with: [sam, ana]), me: me, names: names)
                == "You with Sam & Ana")
        // Someone no longer in the crew is dropped from the line.
        #expect(CrewTowerModel.senderLine(shared(from: sam, with: [UUID()]), me: me, names: names) == "Sam")
    }

    @Test func aTaggedBlockOfYoursIsStillYours() throws {
        let me = UUID()
        let model = CrewTowerModel()
        let mine = SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: me,
                             crewDay: "2026-10-05", title: "Run", colour: .health, icon: .health, blockSize: .small,
                             photo: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now, withPeople: [sam])
        model.rebuild(wins: [mine], me: me, names: [sam: "Sam"])
        let look = try #require(model.tower.placedBlocks.first?.look)
        #expect(look.sender == "You with Sam")
        #expect(look.isMine)
    }

    // MARK: Keeping a copy, in the app

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    /// Keep writes a copy through the normal logging path: the same title,
    /// colour and size, the win's own date, and an id of its own, so the
    /// tagger editing or withdrawing theirs never reaches it.
    @Test func aKeptWinIsANewWinOfYourOwn() async throws {
        let context = try context()
        let when = Date().addingTimeInterval(-26 * 3600)
        let theirs = SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam,
                               crewDay: "2026-10-04", title: "Morning run", colour: .creativity, icon: .unlabeled,
                               blockSize: .hard, photo: nil, cropX: nil, cropY: nil,
                               createdAt: when, updatedAt: when, withPeople: [jayden])
        let log = try await TaggedWinKeeper.keep(theirs, context: context, tower: nil)
        #expect(log.id != theirs.winID)
        #expect(log.habit?.title == "Morning run")
        #expect(log.habit?.displayCategory == .creativity)
        #expect(log.habit?.category == .unlabeled)
        #expect(log.habit?.blockSize == .hard)
        #expect(log.completed)
        #expect(log.dateString == DateUtils.dateString(from: when))
        #expect(log.completedAt == when)
        #expect(log.habit?.isQuickWin == true)
        #expect(try context.fetch(FetchDescriptor<HabitLog>()).count == 1)
    }

    @Test func anUnnamedWinIsKeptUnnamed() async throws {
        let context = try context()
        let theirs = SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam,
                               crewDay: "2026-10-05", title: "", colour: .health, icon: .health,
                               blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                               createdAt: .now, updatedAt: .now, withPeople: [jayden])
        let log = try await TaggedWinKeeper.keep(theirs, context: context, tower: nil)
        #expect(log.habit?.title == QuickWinService.untitled)
        #expect(log.habit?.category == .health)
    }
}
