import Foundation

/// **A small limit on how fast this phone writes to a crew** (the
/// 2026-10-08 audit). Lines, doodles and reactions had none, so a stuck key,
/// a script, or someone set on flooding a crew could fill its chat and its
/// starter's iCloud as fast as CloudKit would take it.
///
/// - Lines and doodles: one a second, and 200 a crew a crew day.
/// - Reactions: two a second.
///
/// Too fast is dropped quietly (a second tap on a reaction, a double send);
/// the daily cap gets one calm sentence in the chat. Kept on disk, so a
/// relaunch does not reset the day's count. Per phone, not per person: it is
/// a guard against accidents and casual abuse, not a security boundary.
nonisolated struct CrewSendThrottle: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case message
        case reaction
    }

    enum Verdict: Equatable, Sendable {
        case allowed
        case tooFast
        case dailyLimit
    }

    static func minimumGap(_ kind: Kind) -> TimeInterval {
        switch kind {
        case .message: 1
        case .reaction: 0.5
        }
    }

    static func dailyCap(_ kind: Kind) -> Int? {
        switch kind {
        case .message: 200
        case .reaction: nil
        }
    }

    /// Last write, by "crew|kind", in seconds since 1970.
    private(set) var last: [String: Double] = [:]
    /// Writes today, by "crew|kind|crew day". Only the current day is kept.
    private(set) var counts: [String: Int] = [:]

    private static func key(_ kind: Kind, _ crew: String) -> String { "\(crew)|\(kind.rawValue)" }
    private static func dayKey(_ kind: Kind, _ crew: String, _ day: String) -> String {
        "\(crew)|\(kind.rawValue)|\(day)"
    }

    func verdict(_ kind: Kind, crew: String, day: String, at now: Date) -> Verdict {
        if let cap = Self.dailyCap(kind), counts[Self.dayKey(kind, crew, day), default: 0] >= cap {
            return .dailyLimit
        }
        if let previous = last[Self.key(kind, crew)],
           now.timeIntervalSince1970 - previous < Self.minimumGap(kind),
           now.timeIntervalSince1970 >= previous {
            return .tooFast
        }
        return .allowed
    }

    mutating func record(_ kind: Kind, crew: String, day: String, at now: Date) {
        last[Self.key(kind, crew)] = now.timeIntervalSince1970
        let prefix = Self.key(kind, crew) + "|"
        let today = Self.dayKey(kind, crew, day)
        // Another day's count for this crew is never read again.
        counts = counts.filter { !$0.key.hasPrefix(prefix) || $0.key == today }
        counts[today, default: 0] += 1
    }
}
