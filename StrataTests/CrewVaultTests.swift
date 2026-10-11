import Foundation
import Testing
@testable import Strata

/// **Crews outlive the app on the phone** (the owner, 2026-10-10: "every
/// time a new build is pushed to TestFlight, all existing crews disappear").
/// The keys and the identity are kept in the Keychain as well as in private
/// iCloud (`CrewVault`), the two copies are read as one, and a crew that
/// could not be read is never taken for a crew that is gone.
@MainActor
@Suite("Crews outlive the app", .serialized)
struct CrewVaultTests {
    let x = "crew-AAAA", y = "crew-BBBB"
    let key1 = CrewKey.new().linkText, key2 = CrewKey.new().linkText

    // MARK: What a phone does with the copies it can read

    /// The owner's own case: iCloud storage is full, so the private copy
    /// was never written. The app is deleted and put back. The Keychain's
    /// copy alone brings every crew back.
    @Test("a reinstall with a full iCloud still gets its crews back")
    func reinstallWithAFullICloud() {
        let vault = CrewKeyBackup.text(.init(keys: [x: key1, y: key2], keyedAt: [x: 1_000, y: 2_000]))
        // Nothing on the phone, nothing in private iCloud (never written).
        let plan = CrewKeyBackup.plan(local: .init(), cloud: "", vault: vault, now: 9_000)
        #expect(plan.take == [x: key1, y: key2])
        #expect(plan.forget.isEmpty)
        // And with private iCloud not answering at all.
        let offline = CrewKeyBackup.plan(local: .init(), cloud: nil, vault: vault, now: 9_000)
        #expect(offline.take == [x: key1, y: key2])
    }

    @Test("nothing readable anywhere changes nothing")
    func nothingReadable() {
        let local = CrewKeyBackup.Local(keys: [x: key1], keyedAt: [x: 1_000])
        let plan = CrewKeyBackup.plan(local: local, cloud: nil, vault: nil, now: 9_000)
        #expect(plan.take.isEmpty && plan.forget.isEmpty)
        #expect(plan.out.keys == [x: key1], "what this phone holds is what gets kept")
    }

    @Test("a crew left stays left, whichever copy still has its key")
    func leftStaysLeft() {
        // Private iCloud knows the leaving; the Keychain copy is older and
        // still carries the key.
        let cloud = CrewKeyBackup.text(.init(left: [x: 5_000]))
        let vault = CrewKeyBackup.text(.init(keys: [x: key1], keyedAt: [x: 1_000]))
        let fresh = CrewKeyBackup.plan(local: .init(), cloud: cloud, vault: vault, now: 9_000)
        #expect(fresh.take.isEmpty, "a reinstall does not put you back in a crew you left")
        #expect(fresh.out.left[x] == 5_000)
        // A phone still holding the key drops it.
        let holding = CrewKeyBackup.plan(local: .init(keys: [x: key1], keyedAt: [x: 1_000]), cloud: cloud, vault: vault, now: 9_000)
        #expect(holding.forget == [x])
        // The other way round too.
        let swapped = CrewKeyBackup.plan(local: .init(), cloud: vault, vault: cloud, now: 9_000)
        #expect(swapped.take.isEmpty)
    }

    @Test("joined again after leaving, the key wins in either copy")
    func rejoinWins() {
        let cloud = CrewKeyBackup.text(.init(left: [x: 5_000]))
        let vault = CrewKeyBackup.text(.init(keys: [x: key2], keyedAt: [x: 6_000]))
        let plan = CrewKeyBackup.plan(local: .init(), cloud: cloud, vault: vault, now: 9_000)
        #expect(plan.take == [x: key2])
        #expect(plan.out.left[x] == nil)
    }

    /// Two phones writing one Keychain item: the last writer's copy is the
    /// one that stays. Each write is this phone's keys AND what the copy
    /// already held, so neither phone's crew is lost.
    @Test("one phone's copy never erases another's crew")
    func neitherPhoneErasesTheOther() {
        // Phone B holds y and reads a copy phone A wrote with x in it.
        let fromA = CrewKeyBackup.text(.init(keys: [x: key1], keyedAt: [x: 1_000]))
        let b = CrewKeyBackup.plan(local: .init(keys: [y: key2], keyedAt: [y: 2_000]), cloud: nil, vault: fromA, now: 9_000)
        #expect(b.take == [x: key1])
        #expect(Set(b.out.keys.keys) == [x, y], "what B writes back carries both")
    }

    @Test("the later key of a crew is the one taken")
    func combineTakesTheLaterKey() {
        let a = CrewKeyBackup.Remote(keys: [x: key1], keyedAt: [x: 1_000], left: [y: 3_000])
        let b = CrewKeyBackup.Remote(keys: [x: key2], keyedAt: [x: 2_000], left: [y: 4_000])
        for both in [CrewKeyBackup.combine(a, b), CrewKeyBackup.combine(b, a)] {
            #expect(both.keys == [x: key2] && both.keyedAt == [x: 2_000] && both.left == [y: 4_000])
        }
    }

    @Test("two copies that disagree at the same moment settle the same way round")
    func combineIsTheSameEitherWay() {
        let a = CrewKeyBackup.Remote(keys: [x: key1], keyedAt: [x: 1_000])
        let b = CrewKeyBackup.Remote(keys: [x: key2], keyedAt: [x: 1_000])
        #expect(CrewKeyBackup.combine(a, b) == CrewKeyBackup.combine(b, a))
    }

    // MARK: The vault itself

    @Test("the vault keeps keys and identity by account")
    func vaultByAccount() {
        let vault = CrewVault.memory()
        let me = UUID()
        vault.setKeys("\(x).\(key1)@1000", for: "_account-one")
        vault.setIdentity(me, for: "_account-one")
        #expect(vault.keys(for: "_account-one") == "\(x).\(key1)@1000")
        #expect(vault.identity(for: "_account-one") == me)
        // Another iCloud account on the same phone sees none of it.
        #expect(vault.keys(for: "_account-two") == nil)
        #expect(vault.identity(for: "_account-two") == nil)
        // No crews left: the copy goes, the identity stays.
        vault.setKeys("", for: "_account-one")
        #expect(vault.keys(for: "_account-one") == nil)
        #expect(vault.identity(for: "_account-one") == me)
    }

    /// The real Keychain, where the simulator has one: written, read back,
    /// written over, removed.
    @Test("the Keychain copy reads back what was written")
    func keychainRoundTrip() {
        let vault = CrewVault.keychain
        let account = "_test-\(UUID().uuidString)"
        vault.setKeys("one", for: account)
        // Not skipped when there is no Keychain: a pass that proved nothing
        // (found by review). The test host is the app, which has one.
        #expect(vault.keys(for: account) == "one")
        vault.setKeys("two", for: account)
        #expect(vault.keys(for: account) == "two")
        vault.setKeys("", for: account)
        #expect(vault.keys(for: account) == nil)
    }

    // MARK: Not read is not gone

    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "crew-vault-tests-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    func win(_ title: String) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    /// A cold start with no signal, or a cache that would not open: the
    /// cloud holds the crew's key and could not read the crew. It used to
    /// be dropped from the list and forgotten, the streak this phone had
    /// counted for it with it.
    @Test("a crew that could not be read stays, with what the phone knew of it")
    func unreadIsNotGone() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        let (other, _) = try await a.createCrew(name: "Family")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        await b.post(win("Gym"), to: [crew.id])
        await a.refresh()
        #expect(a.wins(in: crew.id).map(\.title) == ["Gym"])
        var history = CrewHistory()
        history.days["2026-09-01"] = [jayden.uuidString: 1, sam.uuidString: 1]
        a.debugSetHistory(history, for: crew.id)

        let cloud = try #require(a.cloud as? FakeCrewCloud)
        cloud.unreadable = [crew.id]
        await a.refresh()
        #expect(a.crews.map(\.id) == [crew.id, other.id], "still in the list, in its place")
        #expect(a.wins(in: crew.id).map(\.title) == ["Gym"], "with the wins it last read")
        #expect(a.history[crew.id]?.days["2026-09-01"] != nil, "and the streak this phone counted")

        // Readable again: nothing was lost in between.
        cloud.unreadable = []
        await a.refresh()
        #expect(a.crews.map(\.id) == [crew.id, other.id])
        #expect(a.history[crew.id]?.days["2026-09-01"] != nil)
    }

    @Test("a crew the cloud has let go of is still forgotten")
    func goneIsStillGone() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        await b.refresh()
        #expect(b.crews.count == 1)
        try await a.remove(member: sam, from: crew.id)
        await b.refresh()
        #expect(b.crews.isEmpty, "removed by the starter: gone from the list")
    }
}
