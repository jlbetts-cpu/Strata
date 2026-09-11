import Foundation

/// Wins per day, week or month, and what the recent stretch says next to the
/// stretch before it.
///
/// Pure, over `yyyy-MM-dd` day keys, for the same reason `Streaks` is: the
/// boundaries can be tested at the boundary rather than inferred from a
/// screenshot. `ProfileViewModel` does the fetching.
///
/// ## Why the verdict is a band, not a direction
///
/// Apple Fitness's Trends compare the last 90 days with the last 365, so one
/// unusual day cannot flip the arrow. Strata's people log far fewer things
/// than a step counter does, so the windows are shorter — a week against the
/// three before it, four weeks against eight, three months against nine — and
/// a change has to clear 20% either way before it is called one. Without the
/// band, a week of 5 against an average of 4.9 would be announced as "more
/// than usual", which is noise described as news.
nonisolated enum WinTrend {

    nonisolated enum Unit: String, CaseIterable, Identifiable, Sendable {
        case day, week, month

        var id: String { rawValue }

        var component: Calendar.Component {
            switch self {
            case .day:   .day
            case .week:  .weekOfYear
            case .month: .month
            }
        }

        /// Bars drawn. Fourteen days is two weeks you can still read one bar
        /// of; twelve weeks is a season; twelve months is a year.
        var shown: Int {
            switch self {
            case .day:   14
            case .week:  12
            case .month: 12
            }
        }

        /// The recent stretch, in finished periods.
        var recent: Int {
            switch self {
            case .day:   7
            case .week:  4
            case .month: 3
            }
        }

        /// How far back "usual" reaches, in finished periods before the recent
        /// ones.
        var baseline: Int {
            switch self {
            case .day:   21
            case .week:  8
            case .month: 9
            }
        }

        /// The fewest earlier periods that can honestly be called "usual".
        var minimumBaseline: Int {
            switch self {
            case .day:   7
            case .week:  2
            case .month: 2
            }
        }

        var name: String { rawValue }
        var plural: String { rawValue + "s" }
        var title: String { rawValue.capitalized }
    }

    nonisolated struct Bar: Equatable, Identifiable, Sendable {
        /// The first moment of the period, in the calendar's own convention.
        let start: Date
        let count: Int
        /// The period we are in, which has not finished yet.
        let isCurrent: Bool
        var id: Date { start }
    }

    nonisolated enum Kind: Equatable, Sendable {
        case more, same, fewer
        /// There are wins, but not enough finished periods of them to compare.
        case notEnough
        /// No wins in the window at all.
        case empty
    }

    nonisolated struct Summary: Equatable, Sendable {
        let kind: Kind
        /// Wins per period over the recent stretch, and over the stretch
        /// before it. Zero when there is nothing to compare.
        var recentAverage: Double = 0
        var usualAverage: Double = 0
    }

    static let band = 0.2

    /// The last `count` periods, oldest first, ending with the current one.
    static func bars(dayCounts: [String: Int],
                     unit: Unit,
                     count: Int? = nil,
                     today: Date = Date(),
                     calendar: Calendar = .current) -> [Bar] {
        let count = count ?? unit.shown
        guard count > 0,
              let current = calendar.dateInterval(of: unit.component, for: today)?.start else { return [] }
        var totals: [Date: Int] = [:]
        for (key, wins) in dayCounts {
            guard let day = DateUtils.date(from: key),
                  let start = calendar.dateInterval(of: unit.component, for: day)?.start else { continue }
            totals[start, default: 0] += wins
        }
        return (0..<count).compactMap { index in
            // Re-derived from the interval rather than trusted from the
            // addition, so a daylight-saving change cannot leave a period's
            // key an hour away from the one its wins were filed under.
            guard let shifted = calendar.date(byAdding: unit.component, value: index - (count - 1), to: current),
                  let start = calendar.dateInterval(of: unit.component, for: shifted)?.start else { return nil }
            return Bar(start: start, count: totals[start] ?? 0, isCurrent: index == count - 1)
        }
    }

    static func summary(dayCounts: [String: Int],
                        unit: Unit,
                        today: Date = Date(),
                        calendar: Calendar = .current) -> Summary {
        guard let firstKey = dayCounts.filter({ $0.value > 0 }).keys.min(),
              let firstDay = DateUtils.date(from: firstKey),
              let firstPeriod = calendar.dateInterval(of: unit.component, for: firstDay)?.start else {
            return Summary(kind: .empty)
        }

        // One more than the window, so the unfinished period can be dropped:
        // a Tuesday's count is not a quiet week, it is two days.
        let finished = bars(dayCounts: dayCounts, unit: unit,
                            count: unit.recent + unit.baseline + 1,
                            today: today, calendar: calendar).dropLast()
        // Periods before the first win are not quiet ones. They are before
        // the person had the app, and counting them as zeros would tell every
        // new user they are doing "more than usual".
        let lived = finished.filter { $0.start >= firstPeriod }
        guard lived.count - unit.recent >= unit.minimumBaseline else { return Summary(kind: .notEnough) }

        let recent = lived.suffix(unit.recent)
        let usual = lived.dropLast(unit.recent).suffix(unit.baseline)
        let recentAverage = Double(recent.map(\.count).reduce(0, +)) / Double(recent.count)
        let usualAverage = Double(usual.map(\.count).reduce(0, +)) / Double(usual.count)

        let kind: Kind
        if usualAverage == 0 {
            kind = recentAverage > 0 ? .more : .same
        } else {
            let ratio = recentAverage / usualAverage
            kind = ratio >= 1 + band ? .more : (ratio <= 1 - band ? .fewer : .same)
        }
        return Summary(kind: kind, recentAverage: recentAverage, usualAverage: usualAverage)
    }
}
