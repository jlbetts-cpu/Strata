import Testing
import Foundation
import SwiftData
@testable import Strata

/// **The rung that did not exist, and the rung that was a lie.**
///
/// `SharedModelContainer` used to have two rungs: the store, and an IN-MEMORY
/// container. The second one set a flag, let the app run, and threw away every
/// win logged from that moment on. Nobody ever fell down it, which is how it
/// survived: a fallback nobody has tested is a fallback nobody has read.
///
/// These drive each branch. To re-inject the bug, make
/// `SharedModelContainer.configuration(.recovery, _)` return
/// `isStoredInMemoryOnly: true` and `recoveryRungStaysOnDisk` fails; delete the
/// `.unavailable` case and `bothRungsFailingNeverClaimsToSave` stops compiling.
@MainActor
@Suite("StoreLadder")
struct StoreLadderTests {

    /// A container the ladder's rungs can be given without touching the real
    /// store on disk. The rung being tested is which one gets asked and what
    /// the ladder then SAYS, not which file it opened.
    private func stand(in _: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true))
    }

    @Test("an ordinary launch asks for the primary rung and nothing else")
    func ordinaryLaunch() throws {
        var asked: [StoreRung] = []
        let result = SharedModelContainer.climb { rung, config in
            asked.append(rung)
            return try stand(in: config)
        }
        #expect(asked == [.primary])
        #expect(result.opening == .onDisk)
        #expect(result.opening.savesToDisk)
    }

    @Test("the primary rung failing falls to the recovery rung, which is ON DISK")
    func recoveryRungStaysOnDisk() throws {
        var asked: [StoreRung] = []
        var sawInMemory: [StoreRung] = []
        let result = SharedModelContainer.climb { rung, config in
            asked.append(rung)
            if config.isStoredInMemoryOnly { sawInMemory.append(rung) }
            if rung == .primary { throw StoreOpenError.forcedByHarness(rung) }
            return try stand(in: config)
        }
        #expect(asked == [.primary, .recovery])
        // The assertion that matters. The old second rung was in memory, and
        // that is precisely what made a broken store look like a working app.
        #expect(sawInMemory.isEmpty)
        #expect(result.opening.savesToDisk)
        guard case .recovered = result.opening else {
            Issue.record("expected a recovered opening, got \(result.opening.summary)")
            return
        }
    }

    @Test("the recovery rung failing too never claims to be saving")
    func bothRungsFailingNeverClaimsToSave() throws {
        var asked: [StoreRung] = []
        let result = SharedModelContainer.climb { rung, _ in
            asked.append(rung)
            throw StoreOpenError.forcedByHarness(rung)
        }
        #expect(asked == [.primary, .recovery])
        #expect(result.opening.savesToDisk == false)
        guard case .unavailable = result.opening else {
            Issue.record("expected an unavailable opening, got \(result.opening.summary)")
            return
        }
        // The container handed back exists only for SwiftUI to hold. It must
        // never be mistaken for a store: nothing that reads or writes a win is
        // put in front of it, and `savesToDisk` above is what decides that.
        #expect(result.container.configurations.first?.isStoredInMemoryOnly == true)
    }

    @Test("the reason the store gave is carried, not swallowed")
    func reasonSurvives() throws {
        let result = SharedModelContainer.climb { rung, _ in
            throw StoreOpenError.forcedByHarness(rung)
        }
        #expect(result.opening.summary.contains("recovery"))
    }
}
