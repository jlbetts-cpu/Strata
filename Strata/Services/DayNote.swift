import Foundation
import SwiftData

/// **One true, specific thing about today** (the owner's Launch Pack,
/// 2026-10-12, "Your own wins": "Your best Sunday in three weeks." and "Day
/// three. Don't look now.", with the full detail inside the app: "Eight wins
/// today. Your best Sunday in three weeks. Good one to look back on.").
///
/// It was not built in the first pass: the evening had only "Still room on
/// today's tower.", which is spare and says nothing only this day could.
/// `docs/voice.md`: specific over generic, and a notification invites.
///
/// **Only when it is true, and only then.** Most days have no note, and
/// then nothing is sent for it. It never counts a gap, never names a day
/// that fell short, and never says "streak".
///
/// **It takes the evening's one quiet slot.** On a day with a note it goes
/// where the past win would have (`PastWinReminder`, 8pm, passive), so the
/// evening still holds one line and not two.
nonisolated enum DayNote {
    struct Note: Equatable, Codable, Sendable {
        /// The day it is about, `yyyy-MM-dd`.
        let day: String
        /// The lock screen's line. It holds the number back.
        let outside: String
        /// In the app: the number.
        let headline: String
        /// In the app: what it means, and once in three a warm word after.
        let detail: String
    }

    /// The fewest wins a day needs before it is called anybody's best.
    static let fewest = 3
    /// The run lengths worth a word.
    static let days: Set<Int> = [3, 7, 14, 30, 50, 100]
    static let warm = "Good one to look back on."

    private static let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
                                "nine", "ten", "eleven", "twelve"]

    /// A number as a word up to twelve, as the owner's lines write them.
    static func word(_ n: Int) -> String { words.indices.contains(n) ? words[n] : "\(n)" }
    private static func capital(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    /// Today's note, or nil. `counts` is wins by day; `firstDay` the first
    /// day there is any record of, so a week before the app was installed is
    /// never one today "beat".
    static func pick(counts: [String: Int], firstDay: String, today: Date, calendar: Calendar,
                     weekday: (Date) -> String = { Album.Formats.weekday.string(from: $0) }) -> Note? {
        let key = DateUtils.dateString(from: today)
        let n = counts[key] ?? 0
        guard n > 0 else { return nil }

        // The best of its weekday for three weeks or more, this one counted.
        if n >= fewest {
            var beaten = 0
            for back in 1...12 {
                guard let then = calendar.date(byAdding: .day, value: -7 * back, to: today) else { break }
                let thenKey = DateUtils.dateString(from: then)
                // **A day with nothing on it ends the count** (found by
                // review, 2026-10-13): counted as beaten, a return after a
                // lapse read "your best Sunday in eleven weeks", which is
                // true and is also a count of the gap.
                guard thenKey >= firstDay, let then = counts[thenKey], then > 0, then < n else { break }
                beaten += 1
            }
            if beaten >= 2 {
                let line = "Your best \(weekday(today)) in \(word(beaten + 1)) weeks."
                // The warm word about one day in three, by the day, so it is
                // the same all evening.
                let isWarm = PastWin.stableHash(key) % 3 == 0
                return Note(day: key, outside: line,
                            headline: "\(capital(word(n))) wins today.",
                            detail: isWarm ? "\(line) \(warm)" : line)
            }
        }

        // Days in a row with a win, on the days it is worth saying.
        var run = 0, total = 0
        var cursor = today
        while let count = counts[DateUtils.dateString(from: cursor)], count > 0 {
            run += 1
            total += count
            guard let before = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = before
        }
        if days.contains(run) {
            return Note(day: key, outside: "Day \(word(run)). Don't look now.",
                        headline: "\(capital(word(run))) days running.",
                        detail: "\(capital(word(total))) wins across them.")
        }
        return nil
    }

    // MARK: Kept for the app to show

    static let storedKey = "dayNote.tonight"

    static func keep(_ note: Note?, defaults: UserDefaults = .standard) {
        if let note, let data = try? JSONEncoder().encode(note) { defaults.set(data, forKey: storedKey) }
        else { defaults.removeObject(forKey: storedKey) }
    }

    /// Tonight's note, if the one kept is today's.
    static func kept(today: String = DateUtils.dateString(from: Date()), defaults: UserDefaults = .standard) -> Note? {
        guard let data = defaults.data(forKey: storedKey),
              let note = try? JSONDecoder().decode(Note.self, from: data), note.day == today else { return nil }
        return note
    }

    static let shownKey = "dayNote.shownOn"
    /// The lock screen's line goes at eight (`PastWinReminder.hour`); the
    /// app says the rest from then on.
    static let fromHour = 20

    /// Tonight's note, when it is time to say it in full and it has not
    /// been said: once, in the evening, on the Wins page.
    static func due(now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Note? {
        let today = DateUtils.dateString(from: now)
        guard calendar.component(.hour, from: now) >= fromHour, defaults.string(forKey: shownKey) != today else { return nil }
        return kept(today: today, defaults: defaults)
    }

    static func markShown(_ note: Note, defaults: UserDefaults = .standard) {
        defaults.set(note.day, forKey: shownKey)
    }

    /// Today's note, from the store: the last hundred days of wins.
    @MainActor
    static func find(context: ModelContext, now: Date = Date()) -> Note? {
        let calendar = DateUtils.keyCalendar()
        guard let from = calendar.date(byAdding: .day, value: -100, to: now) else { return nil }
        let cutoff = DateUtils.dateString(from: from)
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.completed && $0.dateString >= cutoff }))) ?? []
        var counts: [String: Int] = [:]
        for log in logs { counts[log.dateString, default: 0] += 1 }
        var first = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed },
                                              sortBy: [SortDescriptor(\.dateString)])
        first.fetchLimit = 1
        let firstDay = (try? context.fetch(first))?.first?.dateString ?? DateUtils.dateString(from: now)
        return pick(counts: counts, firstDay: firstDay, today: now, calendar: calendar)
    }
}

/// **What the empty tower says** (the Launch Pack: "Nothing logged yet. Just
/// the start of the day.", and of a quiet stretch, in the app only:
/// "You've been quiet a few days. No rush.").
///
/// The tower said one thing every morning, to everyone: "Tap the slot to add
/// a win. Hold it for a quick one." That is the right line for someone new
/// (`docs/voice.md`: never assume they already know) and is said until they
/// plainly do. After that the morning is his line, and a return after a few
/// days is met with the other. Neither counts anything.
nonisolated enum EmptyTower {
    static let teach = "Tap the slot to add a win. Hold it for a quick one."
    static let start = "Nothing logged yet. Just the start of the day."
    static let quiet = "You've been quiet a few days. No rush."

    /// Wins logged before the slot no longer needs explaining.
    static let knownAfter = 5
    /// Days without a win before a return is a return.
    static let quietAfter = 3

    static func line(total: Int, lastWinDay: String?, today: String, calendar: Calendar = DateUtils.keyCalendar()) -> String {
        guard total >= knownAfter else { return teach }
        if let last = lastWinDay, let then = DateUtils.date(from: last), let now = DateUtils.date(from: today),
           (calendar.dateComponents([.day], from: then, to: now).day ?? 0) >= quietAfter {
            return quiet
        }
        return start
    }

    static let keptKey = "tower.emptyLine"

    /// The line last worked out, so the page opens on it rather than
    /// changing its mind a moment in.
    static func kept(defaults: UserDefaults = .standard) -> String {
        let line = defaults.string(forKey: keptKey) ?? teach
        return [teach, start, quiet].contains(line) ? line : teach
    }

    @MainActor
    static func find(context: ModelContext, now: Date = Date(), defaults: UserDefaults = .standard) -> String {
        let total = (try? context.fetchCount(FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed }))) ?? 0
        var last = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed },
                                             sortBy: [SortDescriptor(\.dateString, order: .reverse)])
        last.fetchLimit = 1
        let lastDay = (try? context.fetch(last))?.first?.dateString
        let line = line(total: total, lastWinDay: lastDay, today: DateUtils.dateString(from: now))
        defaults.set(line, forKey: keptKey)
        return line
    }
}
