import Testing
@testable import Strata

/// A silent push refreshes crews only when it is about a crew (2026-10-08).
///
/// Self-test: make `route(subscriptionID:)` answer `.crews` for everything and
/// `swiftDataPushesAreNotCrews` fails, which is the old behaviour of every
/// synced win waking a full crew refresh.
@Suite("CrewPushRoute")
struct CrewPushRouteTests {
    @Test("SwiftData's own sync pushes do not refresh crews")
    func swiftDataPushesAreNotCrews() {
        #expect(CrewPushRoute.route(subscriptionID: "com.apple.coredata.cloudkit.private.subscription") == .notCrews)
        #expect(CrewPushRoute.route(subscriptionID: nil) == .notCrews)
    }

    @Test("the shared database is always crews; the private one is checked")
    func crewSubscriptions() {
        #expect(CrewPushRoute.route(subscriptionID: CrewPushRoute.sharedID) == .crews)
        #expect(CrewPushRoute.route(subscriptionID: CrewPushRoute.privateID) == .checkPrivate)
    }

    @Test("only a crew zone among the changes counts")
    func crewZones() {
        #expect(!CrewPushRoute.touchesCrews(["com.apple.coredata.cloudkit.zone"]))
        #expect(CrewPushRoute.touchesCrews(["com.apple.coredata.cloudkit.zone", "crew-1A2B"]))
        #expect(!CrewPushRoute.touchesCrews([]))
    }
}
