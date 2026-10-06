import Foundation

/// **One day's name, said the same way everywhere** (the owner's cohesion
/// pass, 2026-10-05).
///
/// "Today", "Yesterday", "Sunday 4 October", and the year on the end only
/// when it is not this year's ("Sunday 5 October 2025"). Before this there
/// were four spellings of the same fact: the journal sheet said "Today" and
/// then "Sunday 5 October" with no yesterday, a past day's page never said
/// "Today" at all, Crew Info said "Sunday, Oct 4" with a comma and a short
/// month, and none of them added the year, so last October's 4th and this
/// one's were the same title.
///
/// The format is fixed ("EEEE d MMMM"), not a localized template, for the
/// reason the journal sheet already recorded: the template put a comma in it.
/// The names inside it are the reader's language.
///
/// `PastWin.dateWords` is the CAPTION form ("March 4", "March 4, 2025") and
/// stays its own shape, but it asks `showsYear` here, so the two can never
/// disagree about when a year is worth saying.
nonisolated enum DayTitle {
    /// The day a `yyyy-MM-dd` key names, in `calendar`'s zone, as a title.
    /// A crew day passes a calendar in the crew's zone, so its "Today" is
    /// the crew's today, as the rest of a crew's page counts it.
    static func title(forKey key: String, now: Date = Date(),
                      calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let date = date(forKey: key, calendar: calendar) else { return key }
        return title(for: date, now: now, calendar: calendar, locale: locale)
    }

    static func title(for date: Date, now: Date = Date(),
                      calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        let out = DateFormatter()
        out.calendar = calendar
        out.timeZone = calendar.timeZone
        out.locale = locale
        out.dateFormat = showsYear(date, now: now, calendar: calendar) ? "EEEE d MMMM yyyy" : "EEEE d MMMM"
        return out.string(from: date)
    }

    /// **The day as a two-tone header** (Luma's "Tomorrow / Friday"; the
    /// owner's pick, 2026-10-06): the name the day goes by, then the rest in
    /// grey at the same size (`TwoToneTitle`). "Yesterday / Sunday",
    /// "Sunday / 4 October", "Sunday / 4 October 2025".
    static func twoTone(forKey key: String, now: Date = Date(),
                        calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let date = date(forKey: key, calendar: calendar) else { return key }
        let out = DateFormatter()
        out.calendar = calendar
        out.timeZone = calendar.timeZone
        out.locale = locale
        out.dateFormat = "EEEE"
        let weekday = out.string(from: date)
        let lead = title(for: date, now: now, calendar: calendar, locale: locale)
        if lead == "Today" || lead == "Yesterday" { return "\(lead) / \(weekday)" }
        out.dateFormat = showsYear(date, now: now, calendar: calendar) ? "d MMMM yyyy" : "d MMMM"
        return "\(weekday) / \(out.string(from: date))"
    }

    /// **The year rule**, the one place it is decided: a day from another
    /// year says which.
    static func showsYear(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        calendar.component(.year, from: date) != calendar.component(.year, from: now)
    }

    /// Midday of the day a key names, in `calendar`'s zone. Midday rather
    /// than midnight, so a day that starts at 1am (a clock change) still
    /// lands inside itself.
    static func date(forKey key: String, calendar: Calendar) -> Date? {
        let bits = key.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: bits[0], month: bits[1], day: bits[2], hour: 12))
    }
}
