import Foundation

/// Shared date formatting utility — eliminates duplicate DateFormatter closures across the codebase.
/// Intent files and services use this directly; TimelineViewModel delegates to it.
/// `nonisolated`: it is called from `Task.detached` in `SpotlightIndexer`,
/// and default main-actor isolation would otherwise make that a Swift 6 error.
nonisolated enum DateUtils {
    private static let dateStringFormatter = keyFormatter("yyyy-MM-dd")

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

    static func dateString(from date: Date) -> String {
        dateStringFormatter.string(from: date)
    }

    /// The inverse. Nil for anything that is not `yyyy-MM-dd`.
    static func date(from dateString: String) -> Date? {
        dateStringFormatter.date(from: dateString)
    }
}
