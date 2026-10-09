import CloudKit

/// **What a silent push is for** (2026-10-08, the scale audit). Every silent
/// push the app received ran a full crew refresh: listing zones in both
/// databases, syncing every crew, pings, photos. But crews you started live in
/// your PRIVATE database, which is also where SwiftData keeps your own wins in
/// sync, so every one of your wins syncing between your devices woke the app
/// for a crew refresh that found nothing. Now a push refreshes crews only when
/// it came from a crew subscription, and the private one only when a crew's
/// zone is among what changed.
nonisolated enum CrewPushRoute: Equatable {
    case crews
    case notCrews

    /// The public database's subscription on this phone's crews
    /// (`PublicCrewCloud.subscriptionID`), the one crew push since crews
    /// moved out of personal iCloud (2026-10-09). The old private and shared
    /// database subscriptions are deleted once by `PublicCrewCloud`; a push
    /// still in flight from either routes nowhere.
    static let publicID = "crews-public"

    static func route(subscriptionID: String?) -> CrewPushRoute {
        subscriptionID == publicID ? .crews : .notCrews
    }

    static func route(userInfo: [AnyHashable: Any]) -> CrewPushRoute {
        route(subscriptionID: CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID)
    }
}
