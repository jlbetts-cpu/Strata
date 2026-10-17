import Foundation
import Testing
@testable import Strata

/// **Crews on opening** (the owner's sister, 2026-10-16: "every time she
/// updates it looks like she needs to start a new club for a little bit").
@MainActor
@Suite("Crews on opening", .serialized)
struct CrewLaunchTests {
    @Test("a cold launch shows the crews this phone last read, before iCloud answers, and with no signal")
    func coldLaunchShowsCachedCrews() async throws {
        let world = FakeCrewWorld()
        let me = UUID()
        let suite = "launch-\(UUID().uuidString)"
        let dir = FileManager.default.temporaryDirectory.appending(path: suite)
        let cloud = FakeCrewCloud(world: world, me: me)
        let first = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!, directory: dir)
        first.isEnabled = { true }
        let (crew, _) = try await first.createCrew(name: "Roommates")
        await first.refresh()
        #expect(first.crews.map(\.id) == [crew.id])
        // The update: a new store on the same phone, and iCloud not there yet.
        cloud.offline = true
        let again = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!, directory: dir)
        again.isEnabled = { true }
        #expect(again.crews.isEmpty)
        await again.refresh()
        #expect(again.crews.map(\.id) == [crew.id])
        #expect(again.crews.first?.name == "Roommates")
    }

    @Test("signed out, or another account, while the app was closed: nothing of the last one's crews")
    func signedOutNoSeed() async throws {
        let world = FakeCrewWorld()
        let suite = "launch-\(UUID().uuidString)"
        let dir = FileManager.default.temporaryDirectory.appending(path: suite)
        let cloud = FakeCrewCloud(world: world, me: UUID())
        let first = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!, directory: dir)
        first.isEnabled = { true }
        _ = try await first.createCrew(name: "Roommates")
        await first.refresh()
        cloud.offline = true
        cloud.signedIn = .signedOut
        let out = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!, directory: dir)
        out.isEnabled = { true }
        await out.refresh()
        #expect(out.crews.isEmpty)
        cloud.signedIn = .signedIn("someone-else")
        let other = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!, directory: dir)
        other.isEnabled = { true }
        await other.refresh()
        #expect(other.crews.isEmpty)
    }

    @Test("signing out and back in keeps the crews' history this phone counted")
    func historySurvivesSignOut() async throws {
        let world = FakeCrewWorld()
        let suite = "launch-\(UUID().uuidString)"
        let dir = FileManager.default.temporaryDirectory.appending(path: suite).appending(path: "crews")
        let cloud = FakeCrewCloud(world: world, me: UUID())
        let store = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!, directory: dir)
        store.isEnabled = { true }
        let (crew, _) = try await store.createCrew(name: "Roommates")
        await store.refresh()
        var history = CrewHistory()
        history.days["2026-09-01"] = [UUID().uuidString: 2]
        store.debugSetHistory(history, for: crew.id)
        cloud.signedIn = .signedOut
        await store.accountChanged()
        cloud.signedIn = .signedIn("fake-account")
        await store.accountChanged()
        #expect(store.history[crew.id]?.days["2026-09-01"] != nil)
    }

    @Test("a phone that never saw an account shows nothing from the cache")
    func noAccountNoSeed() async throws {
        let world = FakeCrewWorld()
        let suite = "launch-\(UUID().uuidString)"
        let cloud = FakeCrewCloud(world: world, me: UUID())
        let store = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        cloud.offline = true
        await store.refresh()
        #expect(store.crews.isEmpty)
    }
}
