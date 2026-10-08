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
    /// The shared database: only crews you joined live there.
    case crews
    /// The private database: a crew, or only your own wins.
    case checkPrivate
    /// Someone else's subscription (SwiftData's own), which it handles itself.
    case notCrews

    static let privateID = "crews-private"
    static let sharedID = "crews-shared"

    static func route(subscriptionID: String?) -> CrewPushRoute {
        switch subscriptionID {
        case sharedID: .crews
        case privateID: .checkPrivate
        default: .notCrews
        }
    }

    static func route(userInfo: [AnyHashable: Any]) -> CrewPushRoute {
        route(subscriptionID: CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID)
    }

    /// A crew's zone among the zones that changed. Crew zones are named
    /// `crew-…` (`CloudKitCrewCloud`); SwiftData's is its own.
    static func touchesCrews(_ zoneNames: [String]) -> Bool {
        zoneNames.contains { $0.hasPrefix("crew-") }
    }
}
