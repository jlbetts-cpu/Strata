import Foundation

/// Consecutive days you did something.
///
/// **This exists because six milestones could not be won.** `MilestoneDetector`
/// takes a `longestStreak` and `MainAppView` passed it a literal `0` with a
/// `// TODO: compute from streaks` beside it — so "Week Strong", "Fortnight",
/// "Monthly", "Habit Formed", "Triple Digits" and "Year One" were defined,
/// listed, and unreachable. Somebody could use this app every day for a year
/// and never unlock the one called "Year One". A promise the app makes and
/// cannot keep is worse than one it never made.
///
/// A namespace of value functions over `yyyy-MM-dd` strings, by the same
/// pattern as `MonthTower` and `PlaceMap`: no SwiftData, no `Calendar`
/// ambiguity at the boundaries, testable with plain literals.
enum Streaks {

    /// The longest run of consecutive days in a set of day keys.
    ///
    /// **Order-independent and duplicate-tolerant**, because the caller is
    /// handing over log rows: two wins on one day are one day, and the rows
    /// arrive in whatever order the store gives them.
    ///
    /// Days are `yyyy-MM-dd`, which sorts lexicographically in date order —
    /// that is the whole reason this app stores them that way, and it is why
    /// the neighbour test below can be a string comparison rather than a
    /// calendar computation.
    static func longest(among dayKeys: some Sequence<String>,
                        calendar: Calendar = .current) -> Int {
        let days = Set(dayKeys).sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for (previous, day) in zip(days, days.dropFirst()) {
            if isNextDay(day, after: previous, calendar: calendar) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    /// The run that is still alive — ending today, or yesterday.
    ///
    /// **Yesterday counts**, and that is deliberate rather than generous: a
    /// streak is not broken until a day passes with nothing in it, and at
    /// 9am your run of a hundred days has not ended just because today is
    /// young. Ending it at midnight would mean the app told you that you had
    /// lost something you had not.
    static func current(among dayKeys: some Sequence<String>,
                        today: Date = Date(),
                        calendar: Calendar = .current) -> Int {
        let days = Set(dayKeys)
        let todayKey = DateUtils.dateString(from: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        let yesterdayKey = DateUtils.dateString(from: yesterday)

        var cursor: Date
        if days.contains(todayKey) {
            cursor = today
        } else if days.contains(yesterdayKey) {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        while days.contains(DateUtils.dateString(from: cursor)) {
            count += 1
            guard let back = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = back
        }
        return count
    }

    /// Whether `day` is the calendar day immediately after `previous`.
    ///
    /// Via `Calendar`, not by adding one to the string: months end, years end,
    /// and — the one that actually bites — a day is not always 86,400 seconds
    /// long. Across a daylight-saving change adding 24 hours to a date lands
    /// on the same day again or skips one, and a streak that silently breaks
    /// once every spring is the worst kind of bug to be told about.
    private static func isNextDay(_ day: String, after previous: String,
                                  calendar: Calendar) -> Bool {
        guard let previousDate = DateUtils.date(from: previous),
              let next = calendar.date(byAdding: .day, value: 1, to: previousDate) else {
            return false
        }
        return DateUtils.dateString(from: next) == day
    }
}
