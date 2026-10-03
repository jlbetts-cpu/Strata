import Testing
import Foundation
@testable import Strata

/// `SocialStore` on a pretend iCloud: two phones, one world.
@MainActor
@Suite("Crew store", .serialized)
struct CrewStoreTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID, on: Bool = true) -> (SocialStore, FakeCrewCloud, UserDefaults) {
        let suite = "crew-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let dir = FileManager.default.temporaryDirectory.appending(path: suite, directoryHint: .isDirectory)
        let cloud = FakeCrewCloud(world: world, me: me)
        let store = SocialStore(cloud: cloud, defaults: defaults, directory: dir)
        store.isEnabled = { on }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return (store, cloud, defaults)
    }

    func win(_ title: String = "Gym", photo: Data? = nil, at date: Date = .now) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: photo, cropX: nil, cropY: nil, createdAt: date, updatedAt: date)
    }

    /// Jayden starts a crew and Sam joins it.
    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let (a, _, _) = store(jayden)
        let (b, _, _) = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        return (a, b, crew)
    }

    @Test func aSixthCrewIsRefused() async throws {
        let (a, _, _) = store(jayden)
        for i in 0..<CrewCaps.crews { _ = try await a.createCrew(name: "Crew \(i)") }
        await #expect(throws: CrewError.tooManyCrews) { try await a.createCrew(name: "One more") }
    }

    @Test func aNinthPersonIsRefusedFromEitherSide() async throws {
        let (owner, _, _) = store(jayden)
        let (crew, link) = try await owner.createCrew(name: "Big")
        for _ in 0..<(CrewCaps.members - 1) {
            let (friend, _, _) = store(UUID())
            _ = try await friend.accept(CrewInvite(url: link))
        }
        await owner.refresh()
        #expect(owner.crew(crew.id)?.members.count == CrewCaps.members)
        // The inviter cannot make a ninth link...
        await #expect(throws: CrewError.crewFull) { try await owner.inviteURL(for: crew.id) }
        // ...and a ninth person holding an old link cannot get in.
        let (late, lateCloud, _) = store(UUID())
        await #expect(throws: CrewError.crewFull) { try await late.accept(CrewInvite(url: link)) }
        #expect(world.zones[crew.id]?.participants.contains(lateCloud.myProfileID) == false)
    }

    @Test func aWinPostedToTwoCrewsMakesTwoCopiesInEachCrewsDay() async throws {
        let (a, _, _) = store(jayden)
        let (one, _) = try await a.createCrew(name: "One")
        let (two, _) = try await a.createCrew(name: "Two")
        let mine = win()
        await a.post(mine, to: [one.id, two.id])
        #expect(world.records(of: .sharedWin, in: one.id).count == 1)
        #expect(world.records(of: .sharedWin, in: two.id).count == 1)
        #expect(a.crews(holding: mine.winID) == [one.id, two.id])
        let day = CrewDay.string(for: mine.createdAt, in: one.timeZone)
        #expect(world.records(of: .sharedWin, in: one.id).values.first?["crewDay"] == .string(day))
    }

    @Test func aFriendSeesTheWinAndItIsUnread() async throws {
        let (a, b, crew) = try await pair()
        await a.post(win("Run"), to: [crew.id])
        await b.refresh()
        #expect(b.today(in: crew.id).map(\.title) == ["Run"])
        #expect(b.unread == [crew.id])
        #expect(a.unread.isEmpty, "your own win is never unread")
        b.markSeen(crew.id)
        #expect(b.unread.isEmpty)
    }

    @Test func uncheckingWithdrawsAndDeletingRemovesEveryCopy() async throws {
        let (a, _, _) = store(jayden)
        let (one, _) = try await a.createCrew(name: "One")
        let (two, _) = try await a.createCrew(name: "Two")
        let mine = win()
        await a.post(mine, to: [one.id, two.id])
        await a.setCrews(for: mine, to: [two.id])
        #expect(world.records(of: .sharedWin, in: one.id).isEmpty)
        #expect(world.records(of: .sharedWin, in: two.id).count == 1)
        await a.deleteEverywhere(winID: mine.winID)
        #expect(world.records(of: .sharedWin, in: two.id).isEmpty)
        #expect(a.crews(holding: mine.winID).isEmpty)
    }

    @Test func removingAPhotoKeepsTheWin() async throws {
        let (a, _, _) = store(jayden)
        let (crew, _) = try await a.createCrew(name: "One")
        let mine = win(photo: Data([0xFF, 0xD8, 0xFF]))
        await a.post(mine, to: [crew.id])
        #expect(world.records(of: .sharedWin, in: crew.id).values.first?["photo"] != nil)
        await a.removePhotoEverywhere(winID: mine.winID)
        let record = try #require(world.records(of: .sharedWin, in: crew.id).values.first)
        #expect(record["photo"] == nil)
        #expect(record["title"] == .string("Gym"))
    }

    @Test func thirteenToFifteenNeverSendsAPhoto() async throws {
        let (a, _, _) = store(jayden)
        a.photosAllowed = { false }
        let (crew, _) = try await a.createCrew(name: "One")
        await a.post(win(photo: Data([0xFF, 0xD8, 0xFF])), to: [crew.id])
        #expect(world.records(of: .sharedWin, in: crew.id).values.first?["photo"] == nil)
    }

    @Test func anOfflineWriteWaitsAndIsSentLater() async throws {
        let (a, cloud, _) = store(jayden)
        let (crew, _) = try await a.createCrew(name: "One")
        cloud.offline = true
        let mine = win()
        await a.post(mine, to: [crew.id])
        #expect(world.records(of: .sharedWin, in: crew.id).isEmpty)
        #expect(a.pendingCrews(for: mine.winID) == [crew.id])
        cloud.offline = false
        await a.flush()
        #expect(world.records(of: .sharedWin, in: crew.id).count == 1)
        #expect(a.pendingCrews(for: mine.winID).isEmpty)
    }

    @Test func theStickyChoicePersistsAndForgetsACrewYouLeft() async throws {
        let (a, b, crew) = try await pair()
        let (_, _, samDefaults) = store(sam)
        CrewChoice.save([crew.id], samDefaults)
        #expect(CrewChoice.load(samDefaults) == [crew.id])
        CrewChoice.forget(crew.id, samDefaults)
        #expect(CrewChoice.load(samDefaults).isEmpty)
        _ = a
        try await b.leave(crew.id)
        #expect(b.crews.isEmpty)
        #expect(world.zones[crew.id]?.participants.contains(sam) == false)
    }

    @Test func leavingTakesYourWinsWithYou() async throws {
        let (a, b, crew) = try await pair()
        await b.post(win("Swim"), to: [crew.id])
        await a.post(win("Read"), to: [crew.id])
        await b.refresh()
        try await b.leave(crew.id)
        await a.refresh()
        #expect(a.today(in: crew.id).map(\.title) == ["Read"])
        #expect(a.crew(crew.id)?.members.map(\.profileID) == [jayden])
    }

    @Test func onlyTheOwnerEndsOrRemoves() async throws {
        let (a, b, crew) = try await pair()
        await #expect(throws: CrewError.notOwner) { try await b.end(crew.id) }
        await #expect(throws: CrewError.notOwner) { try await b.remove(member: jayden, from: crew.id) }
        try await a.remove(member: sam, from: crew.id)
        #expect(a.crew(crew.id)?.members.count == 1)
        try await a.end(crew.id)
        #expect(world.zones[crew.id] == nil)
    }

    @Test func oldWinsArePruned() async throws {
        let (a, _, _) = store(jayden)
        let (crew, _) = try await a.createCrew(name: "One")
        let now = Date()
        await a.post(win("Old", at: now.addingTimeInterval(-5 * 86_400)), to: [crew.id])
        await a.post(win("Yesterday", at: now.addingTimeInterval(-86_400)), to: [crew.id])
        a.prune()
        #expect(a.wins(in: crew.id).map(\.title) == ["Yesterday"])
        await a.flush()
        #expect(world.records(of: .sharedWin, in: crew.id).count == 1)
    }

    @Test func offMeansNothingIsAsked() async throws {
        let (a, cloud, _) = store(jayden, on: false)
        await #expect(throws: CrewError.flagOff) { try await a.createCrew(name: "One") }
        await a.post(win(), to: [CrewID(rawValue: "crew-x")])
        await a.refresh()
        await a.flush()
        await a.deleteEverywhere(winID: UUID())
        await a.setMyHead(Data([1]))
        #expect(cloud.calls == 0)
    }

    @Test func theFlagReadsItsLaunchArgument() {
        let defaults = UserDefaults(suiteName: "crew-flag-\(UUID().uuidString)")!
        #expect(!CrewsFlag.isOn(in: defaults, arguments: []))
        #expect(CrewsFlag.isOn(in: defaults, arguments: ["-strataCrews", "1"]))
        defaults.set(true, forKey: CrewsFlag.key)
        #expect(CrewsFlag.isOn(in: defaults, arguments: []))
        #expect(!CrewsFlag.isOn(in: defaults, arguments: ["-strataCrews", "0"]))
    }
}

extension CrewStoreTests {
    @Test func aFlaggedPhotoStaysAndTheWinStillGoes() async throws {
        let (a, _, _) = store(jayden)
        a.photoCheck = { _ in false }
        let (crew, _) = try await a.createCrew(name: "One")
        let mine = win(photo: Data([0xFF, 0xD8, 0xFF]))
        await a.post(mine, to: [crew.id])
        let record = try #require(world.records(of: .sharedWin, in: crew.id).values.first)
        #expect(record["photo"] == nil)
        #expect(record["title"] == .string("Gym"))
        #expect(a.heldBackPhoto == mine.winID)
    }
}

extension CrewStoreTests {
    @Test func aCrewPictureFollowsTheSameRules() async throws {
        let (a, _, _) = store(jayden)
        let (crew, _) = try await a.createCrew(name: "One")
        a.photosAllowed = { false }
        await #expect(throws: CrewError.photoNotAllowed) { try await a.setPhoto(crew.id, jpeg: Data([1, 2, 3])) }
        a.photosAllowed = { true }
        a.photoCheck = { _ in false }
        await #expect(throws: CrewError.photoNotAllowed) { try await a.setPhoto(crew.id, jpeg: Data([1, 2, 3])) }
        a.photoCheck = { _ in true }
        try await a.setPhoto(crew.id, jpeg: Data([1, 2, 3]))
        #expect(a.crew(crew.id)?.photo != nil)
    }
}

extension CrewStoreTests {
    @Test func aCrewStartsWithAPhotoUnlessYouAreUnderSixteen() async throws {
        let (a, _, _) = store(jayden)
        a.requiresCrewPhoto = true
        await #expect(throws: CrewError.photoNeeded) { try await a.createCrew(name: "No picture") }
        let (crew, _) = try await a.createCrew(name: "Picture", photoJPEG: Data([1, 2, 3]))
        #expect(crew.photo != nil)
        #expect(world.records(of: .crew, in: crew.id).values.first?["photo"] != nil)
        a.photosAllowed = { false }
        let (teen, _) = try await a.createCrew(name: "Faces")
        #expect(teen.photo == nil, "13 to 15 start crews with everyone's faces")
    }

    @Test func aMemberWithNoHeadSharesTheirPhotoButNotUnderSixteen() async throws {
        let (a, _, _) = store(jayden)
        a.myPhoto = { Data([9, 9, 9]) }
        let (crew, _) = try await a.createCrew(name: "One")
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["photo"] != nil)
        a.photosAllowed = { false }
        await a.shareMyself()
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["photo"] == nil)
    }
}

extension CrewStoreTests {
    /// The owner's sister, 2026-10-02: she joined, made a head, and it never
    /// reached him. A head made after joining, or on a build that never sent
    /// it, goes on the next launch's first refresh.
    @Test func aHeadMadeAfterJoiningReachesTheCrew() async throws {
        let (a, b, crew) = try await pair()
        await a.refresh()
        #expect(a.crew(crew.id)?.member(sam)?.head == nil)
        b.announces = true
        b.myHeadPack = { Data([7, 7, 7]) }
        await b.refresh()
        await a.refresh()
        let head = try #require(a.crew(crew.id)?.member(sam)?.head)
        #expect(try Data(contentsOf: head) == Data([7, 7, 7]))
        // Once a launch, and not again for nothing.
        let calls = world.records(of: .member, in: crew.id).count
        await b.refresh()
        #expect(world.records(of: .member, in: crew.id).count == calls)
    }

    @Test func nothingChangedSendsNothing() async throws {
        let (_, b, _) = try await pair()
        b.myHeadPack = { Data([1]) }
        await b.shareMyself()
        b.checkedSelf = false
        let (_, cloud, _) = (b, b.cloud as! FakeCrewCloud, ())
        let before = cloud.calls
        await b.shareMyselfIfChanged()
        #expect(cloud.calls == before)
        b.checkedSelf = false
        b.myHeadPack = { Data([2]) }
        await b.shareMyselfIfChanged()
        #expect(cloud.calls > before)
    }
}

extension CrewStoreTests {
    /// The owner, 2026-10-02: "make sure the reactions update immediately
    /// and on everyones end". The crew on screen syncs its zone every few
    /// seconds; a friend's reaction is on this phone after one.
    @Test func aFriendsReactionReachesTheOpenCrewOnTheNextLiveSync() async throws {
        let (a, b, crew) = try await pair()
        await a.post(win("Gym"), to: [crew.id])
        await b.refresh()
        let gym = try #require(b.wins(in: crew.id).first)
        await a.refreshLive(crew.id)
        await b.react("🔥", to: gym.winID, in: crew.id)
        #expect(a.reactions(to: gym.winID, in: crew.id).isEmpty)
        await a.refreshLive(crew.id)
        #expect(a.reactions(to: gym.winID, in: crew.id).map(\.emoji) == ["🔥"])
        // Nothing new: nothing fetched beyond the one check.
        await a.refreshLive(crew.id)
        #expect(a.reactions(to: gym.winID, in: crew.id).count == 1)
    }
}
