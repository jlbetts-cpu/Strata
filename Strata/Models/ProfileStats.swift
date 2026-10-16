import Foundation

/// **What Your Stats says** (the owner, 2026-10-15: "how its scored isnt
/// useful ... information that you want to read like the stats"). Counted
/// from your logged wins every time it opens, never stored, as the score is
/// (`WinsScore`). A delete changes it the moment it happens.
nonisolated struct ProfileStats: Equatable, Sendable {
    /// One logged win, as much as the stats need of it.
    struct Win: Equatable, Sendable {
        let dateString: String
        let category: HabitCategory
        let size: BlockSize
        let hasPhoto: Bool
    }

    var score = 0
    var wins = 0
    var photos = 0
    var thisWeek = 0
    var lastWeek = 0
    /// The colour most of your wins are, when one leads.
    var topColour: HabitCategory?
    /// The weekday most of your wins land on, "Tuesday", when one leads.
    var bestDay: String?

    static func make(_ wins: [Win], today: Date = Date(), calendar: Calendar = .current,
                     locale: Locale = .current) -> ProfileStats {
        var stats = ProfileStats()
        let tally = WinsScore.tally(wins.map(\.size))
        stats.score = tally.score
        stats.wins = tally.wins
        stats.photos = wins.filter(\.hasPhoto).count

        // The week as the phone's calendar counts it, and the one before.
        if let week = calendar.dateInterval(of: .weekOfYear, for: today),
           let previous = calendar.date(byAdding: .day, value: -7, to: week.start) {
            for win in wins {
                guard let day = DateUtils.date(from: win.dateString) else { continue }
                if day >= week.start && day < week.end { stats.thisWeek += 1 }
                else if day >= previous && day < week.start { stats.lastWeek += 1 }
            }
        }

        // A favourite only when it is one: a tie names nothing.
        let colours = Dictionary(grouping: wins.filter { $0.category != .unlabeled }, by: \.category)
            .mapValues(\.count)
        if let top = colours.max(by: { $0.value < $1.value }),
           colours.values.filter({ $0 == top.value }).count == 1 {
            stats.topColour = top.key
        }
        var weekdays: [Int: Int] = [:]
        for win in wins {
            guard let day = DateUtils.date(from: win.dateString) else { continue }
            weekdays[calendar.component(.weekday, from: day), default: 0] += 1
        }
        if let top = weekdays.max(by: { $0.value < $1.value }),
           weekdays.values.filter({ $0 == top.value }).count == 1, wins.count >= 3 {
            var symbols = calendar
            symbols.locale = locale
            stats.bestDay = symbols.weekdaySymbols[top.key - 1]
        }
        return stats
    }

    /// "2 more than last week", "Same as last week", "1 fewer than last week".
    var weekCompared: String {
        let change = thisWeek - lastWeek
        if change == 0 { return "Same as last week" }
        return change > 0 ? "\(change) more than last week" : "\(-change) fewer than last week"
    }
}
