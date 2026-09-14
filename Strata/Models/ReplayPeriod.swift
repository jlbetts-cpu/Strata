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

    private func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    /// "7 to 13 September", "28 September to 4 October", "September",
    /// with the year added when it is not `now`'s year.
    func range(relativeTo now: Date) -> String {
        let first = firstDay
        let last = date(ofDay: days.count - 1)
        let otherYear = calendar.component(.year, from: last) != calendar.component(.year, from: now)
        switch kind {
        case .month:
            return formatter(otherYear ? "MMMM yyyy" : "MMMM").string(from: first)
        case .week:
            let sameMonth = calendar.component(.month, from: first) == calendar.component(.month, from: last)
            let yearsDiffer = calendar.component(.year, from: first) != calendar.component(.year, from: last)
            let head = formatter(yearsDiffer ? "d MMMM yyyy" : (sameMonth ? "d" : "d MMMM")).string(from: first)
            let tail = formatter(otherYear || yearsDiffer ? "d MMMM yyyy" : "d MMMM").string(from: last)
            return "\(head) to \(tail)"
        }
    }

    /// The running label: "Monday" in a week, "14" in a month.
    func label(forDay index: Int) -> String {
        kind == .week
            ? formatter("EEEE").string(from: date(ofDay: index))
            : String(index + 1)
    }

    /// A day as a sentence names it: "Thursday", "the 14th" ("The 14th" to start one).
    func dayName(_ index: Int, capitalised: Bool) -> String {
        if kind == .week { return formatter("EEEE").string(from: date(ofDay: index)) }
        let n = index + 1
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return (capitalised ? "The " : "the ") + "\(n)\(suffix)"
    }
}
