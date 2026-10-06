import Testing
import Foundation
@testable import Strata

/// Some Wins Plus, the plumbing (`PlusStore`). The plan is the owner's,
/// 2026-10-06: yearly with a free trial, monthly, lifetime; 3 crews free.
@MainActor
@Suite("Some Wins Plus")
struct PlusStoreTests {
    @Test("any of the three products is Plus, and nothing else is")
    func entitlement() {
        #expect(PlusStore.entitled(by: ["somewins.plus.yearly"]))
        #expect(PlusStore.entitled(by: ["somewins.plus.monthly"]))
        #expect(PlusStore.entitled(by: ["somewins.plus.lifetime"]))
        #expect(!PlusStore.entitled(by: []))
        #expect(!PlusStore.entitled(by: ["somewins.tip.small"]))
    }

    @Test("yearly is offered first, because it carries the trial")
    func yearlyFirst() {
        #expect(PlusStore.ProductID.all.first == PlusStore.ProductID.yearly)
        #expect(PlusStore.ProductID.all.count == 3, "a weekly plan was offered and not chosen")
    }

    @Test("three crews free, more with Plus")
    func crewLimit() {
        #expect(PlusStore.crewLimit(plus: false) == 3)
        #expect(PlusStore.crewLimit(plus: true) > 3)
    }

    @Test("the cached entitlement is read at start, so nothing flashes locked")
    func cachedAtStart() {
        let defaults = UserDefaults(suiteName: "plus.\(UUID())")!
        defaults.set(true, forKey: PlusStore.cacheKey)
        #expect(PlusStore(defaults: defaults).isPlus)
        #expect(!PlusStore(defaults: UserDefaults(suiteName: "plus.\(UUID())")!).isPlus)
    }
}
