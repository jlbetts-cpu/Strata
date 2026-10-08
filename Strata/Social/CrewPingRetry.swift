import Foundation

/// **A ping that did not go, tried again** (the 2026-10-08 audit). A failed
/// Ping save was logged and dropped, so a friend's phone that missed the
/// app's own refresh never heard about the win at all. Now a failure that
/// says nothing about the ping itself (no signal, a busy or limited server)
/// is kept and tried again: three tries in all, each after the longer of
/// CloudKit's own `retryAfterSeconds` and a doubling wait. A real failure is
/// still dropped, and so is a ping more than an hour old: by then it would
/// only wake someone for nothing.
nonisolated struct CrewPingRetry: Codable, Equatable, Sendable {
    /// What `SocialStore` remembers a ping by ("win-<id>", "reaction-<id>").
    var key: String
    var fields: [String: String]
    /// Tries made so far.
    var attempts: Int
    /// Not before this, in seconds since 1970.
    var notBefore: Double
    /// When it was first tried, in seconds since 1970.
    var firstTried: Double

    static let tries = 3
    static let staleAfter: TimeInterval = 3600

    /// The wait before the next try, after `attempts` tries have failed, or
    /// nil when it has been tried enough.
    static func wait(afterAttempts attempts: Int, serverSays: TimeInterval?) -> TimeInterval? {
        guard attempts < tries else { return nil }
        let doubling = 5 * pow(2, Double(max(attempts - 1, 0)))
        return max(serverSays ?? 0, doubling)
    }

    func isDue(at now: Date) -> Bool { now.timeIntervalSince1970 >= notBefore }
    func isStale(at now: Date) -> Bool { now.timeIntervalSince1970 - firstTried > Self.staleAfter }
}
