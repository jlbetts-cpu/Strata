import Foundation

/// **How often the crew on screen asks for changes** (the 2026-10-08 audit).
///
/// Every 3 seconds while anything is moving; after three asks in a row that
/// found nothing, every 12. Back to 3 the moment something changes or you
/// post, say or react (`SocialStore.liveNudge`). It asked every 3 seconds
/// for as long as a crew stayed open, so a phone left on a quiet crew made
/// twenty requests a minute against the starter's iCloud for nothing.
nonisolated struct CrewLivePace: Equatable, Sendable {
    static let quick: TimeInterval = 3
    static let idle: TimeInterval = 12
    static let quietBeforeIdle = 3
    /// **While pushes are doing the telling** (2026-10-10, the owner: "I
    /// think we should lean on push notifications"): iCloud's silent push
    /// says "this crew changed" within a second or two, so the open crew
    /// reads on the push and only asks on its own now and then, in case one
    /// was dropped. Four in a minute and a half, where it was thirty.
    static let pushedQuick: TimeInterval = 8
    static let pushedIdle: TimeInterval = 40
    /// Changes found by asking, with no push to say so, before pushes are
    /// taken not to be arriving. Two, not one: a push still on its way when
    /// the ask happened to land is not a push that failed.
    static let missesBeforeDistrust = 2

    private(set) var quietAsks = 0
    /// Whether pushes have been seen to arrive, and not since to be missing.
    /// Not trusted until one has: a phone that gets none asks as it always did.
    private(set) var pushesArrive = false
    private var missed = 0
    /// **A push that found nothing is followed up** (found by review,
    /// 2026-10-10). iCloud's push can arrive a second or two before its own
    /// query will return the record, and the full read a push also starts
    /// makes this one stand aside. The ask a push asked for then came back
    /// empty and the next was eight or forty seconds away: slower than
    /// before pushes. So it is asked twice more at the quick pace.
    static let followUps = 2
    private var chasing = 0

    var interval: TimeInterval {
        if chasing > 0 { return Self.quick }
        let idle = quietAsks >= Self.quietBeforeIdle
        return pushesArrive ? (idle ? Self.pushedIdle : Self.pushedQuick) : (idle ? Self.idle : Self.quick)
    }

    /// An ask was made. `byPush`: it was made because a push said to.
    mutating func asked(changed: Bool, byPush: Bool = false) {
        if byPush {
            pushesArrive = true
            missed = 0
            chasing = changed ? 0 : Self.followUps
            if changed { quietAsks = 0 }
            return
        }
        if chasing > 0 {
            // Still the push's ask: what it finds is the push's news, not a
            // change no push announced.
            chasing = changed ? 0 : chasing - 1
            if changed { quietAsks = 0 }
            return
        }
        quietAsks = changed ? 0 : quietAsks + 1
        if changed {
            missed += 1
            if missed >= Self.missesBeforeDistrust { pushesArrive = false }
        }
    }

    mutating func nudged() { quietAsks = 0 }
}
