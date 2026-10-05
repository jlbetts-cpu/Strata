import Foundation

/// Which day a moment belongs to, in a crew.
///
/// **The crew's zone, not yours.** A crew day closes at the midnight of the
/// person who started it (the owner, 2026-10-02), so a win at 11pm in New
/// York lands in the same day as one at 8pm in San Francisco when the crew is
/// a San Francisco crew. Always through `Calendar`: string arithmetic on dates
/// is wrong twice a year (see `Streaks`).
nonisolated enum CrewDay {
    /// **How far back a crew keeps its days: two weeks.** Wins, photos and
    /// reactions older than this leave the cloud (`SocialStore.prune`); the
    /// counts stay on the phone for good (`CrewHistory`). It was "today and
    /// a couple of days of grace" until the owner asked for past days "saved
    /// in the chat... like recents" (2026-10-05) and picked two weeks: long
    /// enough to look back, short enough that posting stays light, and
    /// about 35 MB a full crew on the iCloud of whoever started it.
    static let keptDays = 14

    /// The oldest day a crew still holds.
    static func oldestKept(today: String, in zone: TimeZone) -> String? {
        day(today, offsetBy: -keptDays, in: zone)
    }

    static func string(for date: Date, in zone: TimeZone) -> String {
        let parts = calendar(zone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The day `days` away from `day`, in the same zone.
    static func day(_ day: String, offsetBy days: Int, in zone: TimeZone) -> String? {
        guard let start = start(of: day, in: zone),
              let moved = calendar(zone).date(byAdding: .day, value: days, to: start) else { return nil }
        return string(for: moved, in: zone)
    }

    /// Midnight at the start of `day` in `zone`.
    static func start(of day: String, in zone: TimeZone) -> Date? {
        let bits = day.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        return calendar(zone).date(from: DateComponents(year: bits[0], month: bits[1], day: bits[2]))
    }

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }
}
