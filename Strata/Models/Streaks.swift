import Foundation

/// Consecutive days you did something.
///
/// Read by Profile's current and best streak and by the widget. (It was
/// written for streak milestones, which were removed on 2026-09-13: their
/// celebration only ever drew behind an open edit sheet.)
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
                        calendar: Calendar = .current,
                        restsPerWeek: Int = 0) -> Int {
        if restsPerWeek > 0 { return Rest.longest(Set(dayKeys), restsPerWeek: restsPerWeek) }
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
                        calendar: Calendar = .current,
                        restsPerWeek: Int = 0) -> Int {
        let days = Set(dayKeys)
        let todayKey = DateUtils.dateString(from: today)
        if restsPerWeek > 0 { return Rest.current(days, today: todayKey, restsPerWeek: restsPerWeek) }
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

    /// How far back a streak is looked for: the widget and Profile both
    /// fetch this many days of wins, never the whole store.
    static let horizonDays = 400

    /// The oldest day key inside the horizon, for a `dateString >=` predicate.
    static func horizonKey(today: Date = Date(), calendar: Calendar = .current) -> String {
        calendar.date(byAdding: .day, value: -horizonDays, to: today)
            .map { DateUtils.dateString(from: $0) } ?? ""
    }

    /// The current streak, remembered until the days it was worked out from
    /// change.
    ///
    /// `refreshData()` publishes the widget on every save, and walking a
    /// run back through `Calendar` a day at a time is not free. The signature
    /// is `distinct day count | newest day | today`: a new day, a day emptied,
    /// or midnight passing all change it. Pure, so the month boundary that
    /// used to reset the widget's streak can be tested with literals.
    struct Memo {
        private(set) var signature: String?
        private(set) var value = 0

        static func signature(of days: Set<String>, today: Date) -> String {
            "\(days.count)|\(days.max() ?? "")|\(DateUtils.dateString(from: today))"
        }

        mutating func current(among dayKeys: some Sequence<String>,
                              today: Date = Date(),
                              calendar: Calendar = .current,
                              restsPerWeek: Int = 0) -> Int {
            let days = Set(dayKeys)
            let sig = Self.signature(of: days, today: today)
            if sig != signature {
                value = Streaks.current(among: days, today: today, calendar: calendar, restsPerWeek: restsPerWeek)
                signature = sig
            }
            return value
        }
    }

    /// The widget's set of days with a win, and when it can be trusted
    /// without asking the store again.
    ///
    /// Pure. The rule, as `advance(lifetime:todayKey:)` answers it:
    /// - **The same lifetime count:** the same days. Current.
    /// - **One more, on the day the set was last made exact:** a win logged
    ///   in the app is dated the day it is logged, so today joins the set.
    /// - **One more, but the day has changed since** (a Siri win saved at
    ///   23:50 while the app was suspended, published the next morning; or a
    ///   publish straddling midnight): the new win's day is not knowable from
    ///   the clock. Ask the store for the newest completed day, one row, and
    ///   `insert(newestKey:)` it. Inserting today there showed a one-day
    ///   streak for the rest of the session.
    /// - **Anything else** (a deletion, several at once): fetch the lot.
    struct WidgetDays {
        enum Decision: Equatable {
            case current
            case needsNewestKey
            case needsFetch
        }

        private(set) var days: Set<String>?
        private(set) var lifetime: Int?
        /// The day on which `days` was last known exact for `lifetime`. Not
        /// moved along by an unchanged count: a win saved elsewhere before
        /// midnight may not be visible to the count until after it.
        private(set) var dayKey: String?

        mutating func advance(lifetime newLifetime: Int, todayKey: String) -> Decision {
            guard days != nil, let lifetime else { return .needsFetch }
            if newLifetime == lifetime { return .current }
            guard newLifetime == lifetime + 1 else { return .needsFetch }
            guard todayKey == dayKey else { return .needsNewestKey }
            days?.insert(todayKey)
            self.lifetime = newLifetime
            return .current
        }

        /// The answer to `.needsNewestKey`: the newest completed day in the
        /// store, which is the day the one new win was logged on.
        mutating func insert(newestKey: String, lifetime newLifetime: Int, todayKey: String) {
            guard days != nil else { return }
            days?.insert(newestKey)
            lifetime = newLifetime
            dayKey = todayKey
        }

        mutating func replace(days newDays: Set<String>, lifetime newLifetime: Int, todayKey: String) {
            days = newDays
            lifetime = newLifetime
            dayKey = todayKey
        }
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

// MARK: - Rest days

extension Streaks {
    /// **Rest days** (2026-10-06, the retention pass the owner asked for:
    /// "building the habit of coming back and the ritual of winning
    /// together").
    ///
    /// An all-or-nothing streak is the loudest way an app can tell someone
    /// with ADHD they failed, and the research is plain that a broken streak
    /// makes people stop rather than start again. So a missed day is a rest
    /// day, free, as long as a week holds no more than a few of them: one for
    /// your own streak, two for a crew's, because a crew needs everyone on
    /// the same day. Nothing is paid for, nothing is restored by hand, and
    /// nothing says a day was missed. A rest day bridges a run; it is never
    /// counted in it, so the number is still days you won.
    ///
    /// "A week" is any seven days in a row, not a calendar week, so a run
    /// cannot save up rest days at the end of one week and spend them at the
    /// start of the next.
    enum Rest {
        static let profile = 1
        static let crew = 2

        /// The run still alive. Today is open, so it is never a rest day:
        /// the walk starts today if today is won, otherwise yesterday.
        static func current(_ keys: Set<String>, today: String, restsPerWeek: Int) -> Int {
            let days = Set(keys.compactMap(ordinal))
            guard let now = ordinal(today) else { return 0 }
            return run(endingAt: days.contains(now) ? now : now - 1, in: days, restsPerWeek: restsPerWeek)
        }

        /// The longest run there has been, rest days bridging it.
        static func longest(_ keys: Set<String>, restsPerWeek: Int) -> Int {
            let days = Set(keys.compactMap(ordinal))
            // A run can only end on a won day whose next day was not won.
            return days.filter { !days.contains($0 + 1) }
                .map { run(endingAt: $0, in: days, restsPerWeek: restsPerWeek) }
                .max() ?? 0
        }

        /// Won days counted back from `end`. A day not won is a rest while
        /// the seven days from it onward hold fewer than `restsPerWeek` rests
        /// already, and while there is a won day before it to bridge to.
        static func run(endingAt end: Int, in days: Set<Int>, restsPerWeek: Int) -> Int {
            guard let first = days.min() else { return 0 }
            var count = 0
            var rests: [Int] = []
            var day = end
            while day >= first {
                if days.contains(day) {
                    count += 1
                } else {
                    rests.removeAll { $0 > day + 6 }
                    guard rests.count < restsPerWeek else { break }
                    rests.append(day)
                }
                day -= 1
            }
            return count
        }

        /// A `yyyy-MM-dd` key as a day number, so neighbours are one apart
        /// without a `Calendar` (days from civil, proleptic Gregorian).
        static func ordinal(_ key: String) -> Int? {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            let m = parts[1], d = parts[2]
            let y = parts[0] - (m <= 2 ? 1 : 0)
            let era = (y >= 0 ? y : y - 399) / 400
            let yoe = y - era * 400
            let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
            let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
            return era * 146_097 + doe
        }
    }
}
