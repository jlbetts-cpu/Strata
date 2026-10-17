import Foundation

/// Shared date formatting utility — eliminates duplicate DateFormatter closures across the codebase.
/// Intent files and services use this directly; TimelineViewModel delegates to it.
/// `nonisolated`: it is called from `Task.detached` in `SpotlightIndexer`,
/// and default main-actor isolation would otherwise make that a Swift 6 error.
nonisolated enum DateUtils {

    /// **A key is Gregorian and POSIX on every phone** (2026-10-08). The
    /// formatter used to take the device's calendar, so on a phone set to
    /// the Buddhist calendar today's key was "2569-10-08" and on a Japanese
    /// one the year was the era's: `DayTitle`, `Album`, `Streaks.ordinal` and
    /// a crew's `CrewDay` (Gregorian) all read a different day from the same
    /// win. The zone is left as it was, the phone's, because a day is the
    /// day where the person is. Display formatters are NOT this: they follow
    /// the reader.
    static func keyFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        // **The zone where the person is, now** (the rare-bug hunt,
        // 2026-10-16): a formatter kept for the app's life took the zone it
        // was made in, so after a flight with the app suspended, a win
        // logged between the new midnight and the old one went to
        // yesterday. `autoupdatingCurrent` follows the phone's zone.
        f.timeZone = TimeZone.autoupdatingCurrent
        f.dateFormat = format
        return f
    }

    /// The calendar a key's numbers are read and written in: Gregorian, in
    /// `zone`. For code that builds a key from components rather than a
    /// formatter, so the year it writes is the year the key means.
    static func keyCalendar(in zone: TimeZone = .current) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    /// **Read in the zone the phone is in now, every time** (the rare-bug
    /// hunt, 2026-10-16). A formatter kept for the app's life keeps the zone
    /// it was made in (`AlbumFormatsTests` measured it), so after a flight
    /// with the app suspended a win logged between the new midnight and the
    /// old one was filed under yesterday. A calendar made per call reads the
    /// zone as it is; the numbers are the formatter's, Gregorian and POSIX.
    /// **Told when the phone's zone changes**, so the next key reads it:
    /// the system zone is cached until it is reset.
    static func followZoneChanges() {
        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: nil) { _ in
            NSTimeZone.resetSystemTimeZone()
        }
    }

    static func dateString(from date: Date) -> String {
        let parts = keyCalendar(in: NSTimeZone.default).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The inverse: the day's start in the phone's zone now. Nil for anything
    /// that is not `yyyy-MM-dd`.
    static func date(from dateString: String) -> Date? {
        let parts = dateString.split(separator: "-", omittingEmptySubsequences: false)
        guard dateString.count == 10, parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let calendar = keyCalendar(in: NSTimeZone.default)
        guard let day = calendar.date(from: DateComponents(year: y, month: m, day: d)),
              calendar.component(.day, from: day) == d else { return nil }
        return day
    }
}
