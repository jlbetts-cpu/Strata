import Testing
import Foundation
@testable import Strata

/// **Who may be in a crew, at every way in** (the 2026-10-08 launch audit).
/// Crews need iOS 26; an invitation waits for the rules and an age; a known
/// child never joins.
@MainActor
@Suite("Crew launch gate", .serialized)
struct CrewLaunchGateTests {
    let world = FakeCrewWorld()

    func store(_ me: UUID, gate: CrewGate = .open) -> SocialStore {
        let suite = "gate-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.joinGate = { gate }
        store.derive = { $0 }
        return store
    }

    @Test func belowIOS26NothingElseIsAsked() {
        for age in [CrewAge.unknown, .under13, .teen, .adult, .declined] {
            for rules in [false, true] {
                #expect(CrewGate.check(osSupportsCrews: false, rulesAccepted: rules, age: age) == .needsNewerOS)
            }
        }
        #expect(CrewGate.needsNewerOS.isFinal)
        #expect(!CrewGate.newerOSWords.contains("\u{2014}") && !CrewGate.newerOSWords.contains("\u{2013}"))
    }

    @Test func aKnownChildIsToldBeforeTheRules() {
        #expect(CrewGate.check(osSupportsCrews: true, rulesAccepted: false, age: .under13) == .tooYoung)
        #expect(CrewGate.check(osSupportsCrews: true, rulesAccepted: true, age: .under13) == .tooYoung)
        #expect(CrewGate.tooYoung.isFinal)
    }

    @Test func theRulesThenAnAgeThenOpen() {
        #expect(CrewGate.check(osSupportsCrews: true, rulesAccepted: false, age: .unknown) == .needsRules)
        #expect(CrewGate.check(osSupportsCrews: true, rulesAccepted: false, age: .adult) == .needsRules)
        #expect(CrewGate.check(osSupportsCrews: true, rulesAccepted: true, age: .unknown) == .needsAge)
        for age in [CrewAge.teen, .adult, .declined] {
            #expect(CrewGate.check(osSupportsCrews: true, rulesAccepted: true, age: age) == .open)
        }
        #expect(!CrewGate.needsRules.isFinal && !CrewGate.needsAge.isFinal)
    }

    /// The audit's finding: an invitation joined the share and wrote a
    /// Member record before the rules or the age had been asked.
    @Test func anInvitationWritesNothingUntilTheGateIsOpen() async throws {
        let owner = UUID(), friend = UUID()
        let a = store(owner)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        for gate in [CrewGate.needsRules, .needsAge, .tooYoung, .needsNewerOS] {
            let b = store(friend, gate: gate)
            await #expect(throws: CrewError.notReady) { try await b.accept(CrewInvite(url: link)) }
            #expect(world.zones[crew.id]?.participants.contains(friend) == false)
            #expect(world.records(of: .member, in: crew.id)[friend.uuidString] == nil)
        }
        let b = store(friend, gate: .open)
        _ = try await b.accept(CrewInvite(url: link))
        #expect(world.records(of: .member, in: crew.id)[friend.uuidString] != nil)
    }

    @Test func noCrewIsStartedBehindAClosedGate() async {
        let a = store(UUID(), gate: .needsRules)
        await #expect(throws: CrewError.notReady) { _ = try await a.createCrew(name: "One") }
        #expect(world.zones.isEmpty)
    }
}
