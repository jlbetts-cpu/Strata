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
    /// Quiet asks before slowing down.
    static let quietBeforeIdle = 3

    private(set) var quietAsks = 0

    /// The wait before the next ask.
    var interval: TimeInterval { quietAsks >= Self.quietBeforeIdle ? Self.idle : Self.quick }

    mutating func asked(changed: Bool) {
        quietAsks = changed ? 0 : quietAsks + 1
    }

    /// You did something: quick again.
    mutating func nudged() { quietAsks = 0 }
}
