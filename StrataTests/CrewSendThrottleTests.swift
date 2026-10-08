import Testing
import Foundation
@testable import Strata

/// **How fast this phone may write to a crew** (the 2026-10-08 launch
/// audit): a line a second and 200 a crew day; reactions two a second.
@MainActor
@Suite("Crew send throttle", .serialized)
struct CrewSendThrottleTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aLineASecond() {
        var throttle = CrewSendThrottle()
        #expect(throttle.verdict(.message, crew: "a", day: "d", at: t0) == .allowed)
        throttle.record(.message, crew: "a", day: "d", at: t0)
        #expect(throttle.verdict(.message, crew: "a", day: "d", at: t0.addingTimeInterval(0.5)) == .tooFast)
        #expect(throttle.verdict(.message, crew: "a", day: "d", at: t0.addingTimeInterval(1)) == .allowed)
        // Another crew is its own.
        #expect(throttle.verdict(.message, crew: "b", day: "d", at: t0.addingTimeInterval(0.5)) == .allowed)
    }

    @Test func twoReactionsASecondAndNoDailyCap() {
        var throttle = CrewSendThrottle()
        throttle.record(.reaction, crew: "a", day: "d", at: t0)
        #expect(throttle.verdict(.reaction, crew: "a", day: "d", at: t0.addingTimeInterval(0.3)) == .tooFast)
        #expect(throttle.verdict(.reaction, crew: "a", day: "d", at: t0.addingTimeInterval(0.5)) == .allowed)
        for i in 0..<500 { throttle.record(.reaction, crew: "a", day: "d", at: t0.addingTimeInterval(Double(i))) }
        #expect(throttle.verdict(.reaction, crew: "a", day: "d", at: t0.addingTimeInterval(1000)) == .allowed)
    }

    @Test func twoHundredLinesACrewDay() {
        var throttle = CrewSendThrottle()
        for i in 0..<200 { throttle.record(.message, crew: "a", day: "d", at: t0.addingTimeInterval(Double(i) * 2)) }
        #expect(throttle.verdict(.message, crew: "a", day: "d", at: t0.addingTimeInterval(1000)) == .dailyLimit)
        // The crew's next day starts again, and the old day is not kept.
        #expect(throttle.verdict(.message, crew: "a", day: "e", at: t0.addingTimeInterval(1000)) == .allowed)
        throttle.record(.message, crew: "a", day: "e", at: t0.addingTimeInterval(1000))
        #expect(throttle.counts.count == 1)
    }

    @Test func itSurvivesARelaunch() throws {
        var throttle = CrewSendThrottle()
        for i in 0..<200 { throttle.record(.message, crew: "a", day: "d", at: t0.addingTimeInterval(Double(i) * 2)) }
        let again = try JSONDecoder().decode(CrewSendThrottle.self, from: JSONEncoder().encode(throttle))
        #expect(again.verdict(.message, crew: "a", day: "d", at: t0.addingTimeInterval(1000)) == .dailyLimit)
    }

    @Test func theStoreDropsATooFastLineAndSaysSoAtTheCap() async throws {
        let suite = "throttle-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.throttles = true
        var clock = Date()
        store.now = { clock }
        let (crew, _) = try await store.createCrew(name: "One")
        #expect(await store.send("hi", in: crew.id) == .sent)
        #expect(await store.send("hi again", in: crew.id) == .throttled)
        #expect(store.messages(in: crew.id).count == 1)
        for _ in 0..<199 {
            clock = clock.addingTimeInterval(1.5)
            #expect(await store.send("more", in: crew.id) == .sent)
        }
        clock = clock.addingTimeInterval(1.5)
        #expect(await store.send("one too many", in: crew.id) == .dailyLimit)
        #expect(store.messages(in: crew.id).count == 200)
    }
}
