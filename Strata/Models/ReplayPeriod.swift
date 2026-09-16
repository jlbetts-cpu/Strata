import Foundation

/// A stretch of days a replay covers: a week (Monday to Sunday) or a
/// calendar month.
///
/// **Monday to Sunday, not the locale's week.** The replay arrives on Sunday
/// evening; in a locale whose week starts on Sunday, "this week" at that
/// moment is one day long.
///
/// Every day is stepped through `Calendar`, never by adding 86,400 seconds, for
/// the reason `Streaks` gives: a day is not always that long.
enum ReplayKind: String, Hashable {
    case week, month
}

struct ReplayPeriod: Hashable, Identifiable {
    let kind: ReplayKind
    /// `yyyy-MM-dd`, first to last.
    let days: [String]
    /// Start of the first day.
    let firstDay: Date
    let calendar: Calendar

    var id: String { "\(kind.rawValue)-\(days.first ?? "")" }

    static func == (a: ReplayPeriod, b: ReplayPeriod) -> Bool { a.kind == b.kind && a.days == b.days }
    func hash(into h: inout Hasher) { h.combine(kind); h.combine(days) }

    // MARK: - Making one

    static func week(containing date: Date, calendar: Calendar = .current) -> ReplayPeriod {
        let start = calendar.startOfDay(for: date)
        // .weekday: 1 is Sunday. Days back to Monday: Sunday 6, Monday 0.
        let back = (calendar.component(.weekday, from: start) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -back, to: start)!
        return make(.week, from: monday, count: 7, calendar: calendar)
    }

    static func month(containing date: Date, calendar: Calendar = .current) -> ReplayPeriod {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let count = calendar.range(of: .day, in: .month, for: first)!.count
        return make(.month, from: first, count: count, calendar: calendar)
    }

    private static func make(_ kind: ReplayKind, from first: Date, count: Int, calendar: Calendar) -> ReplayPeriod {
        let days = (0..<count).map { key(calendar.date(byAdding: .day, value: $0, to: first)!, calendar: calendar) }
        return ReplayPeriod(kind: kind, days: days, firstDay: first, calendar: calendar)
    }

    static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func date(ofDay index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: firstDay)!
    }

    // MARK: - When it is shown

    /// The last day at 5pm.
    var windowOpens: Date {
        calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date(ofDay: days.count - 1))!
    }

    /// A week: as Tuesday starts. A month: as the 3rd starts.
    var windowCloses: Date {
        date(ofDay: days.count + (kind == .week ? 1 : 2))
    }

    /// A week: Sunday at 6pm. A month: the 1st of the next month at 10am.
    var notificationDate: Date {
        switch kind {
        case .week:
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date(ofDay: 6))!
        case .month:
            return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date(ofDay: days.count))!
        }
    }

    /// The period whose window contains `now`, if any.
    static func current(_ kind: ReplayKind, at now: Date, calendar: Calendar = .current) -> ReplayPeriod? {
        let candidates: [ReplayPeriod]
        switch kind {
        case .week:
            let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
            candidates = [week(containing: now, calendar: calendar), week(containing: lastWeek, calendar: calendar)]
        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let lastMonth = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
            candidates = [month(containing: now, calendar: calendar), month(containing: lastMonth, calendar: calendar)]
        }
        return candidates.first { $0.windowOpens <= now && now < $0.windowCloses }
    }

    /// The `count` most recent periods that have ended before `now`, newest first.
    static func finished(_ kind: ReplayKind, before now: Date, count: Int, calendar: Calendar = .current) -> [ReplayPeriod] {
        var out: [ReplayPeriod] = []
        let running = kind == .week ? week(containing: now, calendar: calendar) : month(containing: now, calendar: calendar)
        var cursor = calendar.date(byAdding: .day, value: -1, to: running.firstDay)!
        while out.count < count {
            let p = kind == .week ? week(containing: cursor, calendar: calendar) : month(containing: cursor, calendar: calendar)
            out.append(p)
            cursor = calendar.date(byAdding: .day, value: -1, to: p.firstDay)!
        }
        return out
    }

    // MARK: - Words

    var title: String { kind == .week ? "Your week" : "Your month" }

    /// Made once per format, locale, calendar and time zone, and kept.
    ///
    /// A replay draws its range on every frame, so a fresh `DateFormatter`
    /// per call was one allocation (and one ICU pattern parse) per string per
    /// frame, for the whole of playback and every frame of the saved video.
    /// A static dictionary is only safe because every caller is on the main
    /// actor: the frame, the shelf, the reminder and the exporter.
    private static var formatters: [String: DateFormatter] = [:]

    /// The app's words are English, so names of months and days come from
    /// one fixed English locale. The numeric week range is the one thing set
    /// in the reader's own order, below.
    private static let wordsLocale = Locale(identifier: "en_GB")

    private func formatter(_ format: String, template: Bool = false, locale: Locale = ReplayPeriod.wordsLocale) -> DateFormatter {
        let key = "\(format)|\(template)|\(locale.identifier)|\(calendar.identifier)|\(calendar.timeZone.identifier)"
        if let cached = Self.formatters[key] { return cached }
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        if template { f.setLocalizedDateFormatFromTemplate(format) } else { f.dateFormat = format }
        Self.formatters[key] = f
        return f
    }

    /// What the replay and the shelf print: "9/7-9/13" for a week, in the
    /// reader's own month and day order ("07/09-13/09" in the UK), and
    /// "September" for a month.
    ///
    /// **Numbers and a plain hyphen, the owner's call (2026-09-15):** "7 to
    /// 13 September" read as a sentence where a glance was wanted. The year
    /// is added only when some of the week is not in `now`'s year, and then
    /// to both ends, so a week across New Year reads "12/29/25-1/4/26"
    /// rather than leaving one end to guess. A month adds its year the same
    /// way: "September 2025".
    ///
    /// **A reader whose dates are written with hyphens** ("7-9" in Dutch)
    /// gets the two ends joined by a spaced hyphen, "7-9 - 13-9", so the
    /// range never reads as one run of numbers. Never a long dash.
    func range(relativeTo now: Date, locale: Locale = .current) -> String {
        let first = firstDay
        let last = date(ofDay: days.count - 1)
        let nowYear = calendar.component(.year, from: now)
        switch kind {
        case .month:
            return formatter(calendar.component(.year, from: first) != nowYear ? "MMMM yyyy" : "MMMM").string(from: first)
        case .week:
            let otherYear = calendar.component(.year, from: first) != nowYear
                || calendar.component(.year, from: last) != nowYear
            let f = formatter(otherYear ? "yyMd" : "Md", template: true, locale: locale)
            let head = f.string(from: first), tail = f.string(from: last)
            let joint = head.contains("-") || tail.contains("-") ? " - " : "-"
            return head + joint + tail
        }
    }

    /// The range as it is SPOKEN: "7 to 13 September", "28 September to 4
    /// October", with the year when it is not `now`'s. VoiceOver reads
    /// "9/7-9/13" as a string of numbers and slashes, so the announcement and
    /// the shelf's accessibility labels keep the words.
    func spokenRange(relativeTo now: Date) -> String {
        let first = firstDay
        let last = date(ofDay: days.count - 1)
        let nowYear = calendar.component(.year, from: now)
        // The year rule `range` uses: both ends carry it when either end is
        // not in `now`'s year.
        let otherYear = calendar.component(.year, from: first) != nowYear
            || calendar.component(.year, from: last) != nowYear
        switch kind {
        case .month:
            return formatter(otherYear ? "MMMM yyyy" : "MMMM").string(from: first)
        case .week:
            let sameMonth = calendar.component(.month, from: first) == calendar.component(.month, from: last)
            let head = formatter(otherYear ? "d MMMM yyyy" : (sameMonth ? "d" : "d MMMM")).string(from: first)
            let tail = formatter(otherYear ? "d MMMM yyyy" : "d MMMM").string(from: last)
            return "\(head) to \(tail)"
        }
    }
}
