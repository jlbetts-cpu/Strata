import Testing
@testable import Strata

/// A silent push refreshes crews only when it is about a crew (2026-10-08;
/// one public subscription since crews left personal iCloud, 2026-10-09).
///
/// Self-test: make `route(subscriptionID:)` answer `.crews` for everything and
/// `swiftDataPushesAreNotCrews` fails, which is the old behaviour of every
/// synced win waking a full crew refresh.
@Suite("CrewPushRoute")
struct CrewPushRouteTests {
    @Test("SwiftData's own sync pushes, and the retired crew subscriptions, do not refresh crews")
    func swiftDataPushesAreNotCrews() {
        #expect(CrewPushRoute.route(subscriptionID: "com.apple.coredata.cloudkit.private.subscription") == .notCrews)
        #expect(CrewPushRoute.route(subscriptionID: "crews-private") == .notCrews)
        #expect(CrewPushRoute.route(subscriptionID: "crews-shared") == .notCrews)
        #expect(CrewPushRoute.route(subscriptionID: nil) == .notCrews)
    }

    @Test("the public crews subscription is crews")
    func crewSubscription() {
        #expect(CrewPushRoute.route(subscriptionID: CrewPushRoute.publicID) == .crews)
        #expect(CrewPushRoute.publicID == "crews-public")
    }
}
