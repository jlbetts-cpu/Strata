import Foundation
import Testing
@testable import Strata

/// Reset All Data takes you out of the crews you joined (the App Store audit,
/// 2026-10-17), and never ends a crew you started for the people in it (the
/// second reader: that is the owner's call).
@MainActor
@Suite("Reset leaves crews", .serialized)
struct ResetLeavesCrewsTests {
    func store(_ world: FakeCrewWorld) -> SocialStore {
        let s = SocialStore(cloud: FakeCrewCloud(world: world, me: UUID()),
                            defaults: UserDefaults(suiteName: "reset-\(UUID())")!,
                            directory: FileManager.default.temporaryDirectory.appending(path: "reset-\(UUID())"))
        s.isEnabled = { true }
        return s
    }

    @Test func resetLeavesWhatYouJoinedAndKeepsWhatYouStarted() async throws {
        let world = FakeCrewWorld()
        let sam = store(world), you = store(world)
        let (theirs, link) = try await sam.createCrew(name: "Roommates")
        _ = try await you.accept(CrewInvite(url: link))
        let (yours, _) = try await you.createCrew(name: "Run Club")
        await you.refresh()
        #expect(you.crews.count == 2)
        await you.withdrawEverything()
        await you.refresh()
        #expect(you.crew(theirs.id) == nil, "Reset All Data left you in a crew you joined")
        #expect(you.crew(yours.id) != nil, "Reset ended a crew you started for everyone in it")
        await sam.refresh()
        #expect(sam.crew(theirs.id) != nil, "the friend's crew went with your reset")
    }
}
