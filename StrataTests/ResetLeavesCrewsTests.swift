import Foundation
import Testing
@testable import Strata

/// Reset All Data deletes what is shared in crews too (the App Store audit,
/// 2026-10-17: it left your member record and the crews you started).
@MainActor
@Suite("Reset leaves crews", .serialized)
struct ResetLeavesCrewsTests {
    @Test func resetTakesYouOutOfEveryCrew() async throws {
        let world = FakeCrewWorld()
        let store = SocialStore(cloud: FakeCrewCloud(world: world), defaults: UserDefaults(suiteName: "reset-\(UUID())")!,
                                directory: FileManager.default.temporaryDirectory.appending(path: "reset-\(UUID())"))
        store.isEnabled = { true }
        _ = try await store.createCrew(name: "Roommates")
        _ = try await store.createCrew(name: "Run Club")
        await store.refresh()
        #expect(store.crews.count == 2)
        await store.withdrawEverything()
        await store.refresh()
        #expect(store.crews.isEmpty, "Reset All Data left you in a crew")
    }
}
