import CloudKit
import Testing
import Foundation
@testable import Strata

/// **A ping that did not go is tried again, three times at most** (the
/// 2026-10-08 launch audit: a failed Ping save was dropped).
@MainActor
@Suite("Crew ping retry", .serialized)
struct CrewPingRetryTests {
    let world = FakeCrewWorld()

    func store(_ me: UUID) -> (SocialStore, FakeCrewCloud) {
        let suite = "ping-retry-\(UUID().uuidString)"
        let cloud = FakeCrewCloud(world: world, me: me)
        let store = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.derive = { $0 }
        store.sendsPings = true
        return (store, cloud)
    }

    func win() -> OwnWin {
        OwnWin(winID: UUID(), title: "Gym", colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    var winPings: Int { world.pings.values.filter { $0[CrewPingRecord.kind] == "win" }.count }

    @Test func theWaitsDoubleHonourCloudKitAndStopAtThree() {
        #expect(CrewPingRetry.wait(afterAttempts: 1, serverSays: nil) == 5)
        #expect(CrewPingRetry.wait(afterAttempts: 2, serverSays: nil) == 10)
        #expect(CrewPingRetry.wait(afterAttempts: 1, serverSays: 30) == 30)
        #expect(CrewPingRetry.wait(afterAttempts: 2, serverSays: 1) == 10)
        #expect(CrewPingRetry.wait(afterAttempts: 3, serverSays: nil) == nil)
    }

    @Test func aPingThatFailedForWantOfSignalGoesLaterOnce() async throws {
        let (a, cloud) = store(UUID())
        var clock = Date()
        a.now = { clock }
        let (crew, _) = try await a.createCrew(name: "One")
        cloud.pingError = CKError(.networkFailure)
        await a.post(win(), to: [crew.id])
        #expect(winPings == 0)
        cloud.pingError = nil
        await a.retryPings()
        #expect(winPings == 0, "not before its wait")
        clock = clock.addingTimeInterval(6)
        await a.retryPings()
        #expect(winPings == 1)
        clock = clock.addingTimeInterval(60)
        await a.retryPings()
        #expect(winPings == 1, "never twice")
    }

    @Test func threeTriesAndItIsLetGo() async throws {
        let (a, cloud) = store(UUID())
        var clock = Date()
        a.now = { clock }
        let (crew, _) = try await a.createCrew(name: "One")
        cloud.pingError = CKError(.serviceUnavailable)
        await a.post(win(), to: [crew.id])           // try 1
        clock = clock.addingTimeInterval(6)
        await a.retryPings()                          // try 2
        clock = clock.addingTimeInterval(11)
        await a.retryPings()                          // try 3, the last
        cloud.pingError = nil
        clock = clock.addingTimeInterval(60)
        await a.retryPings()
        #expect(winPings == 0)
    }

    @Test func aRealFailureIsNotTriedAgain() async throws {
        let (a, cloud) = store(UUID())
        var clock = Date()
        a.now = { clock }
        let (crew, _) = try await a.createCrew(name: "One")
        cloud.pingError = CKError(.permissionFailure)
        await a.post(win(), to: [crew.id])
        cloud.pingError = nil
        clock = clock.addingTimeInterval(60)
        await a.retryPings()
        #expect(winPings == 0)
    }
}
