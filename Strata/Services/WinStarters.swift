import Foundation
import SwiftData

/// **Your own wins, offered back while the name is empty** (the owner,
/// 2026-10-05: "a lot of days I dont have a lot of wins to post").
///
/// Small progress is the biggest single lift to a day (Amabile and Kramer,
/// The Progress Principle, 2011), and the hard part with ADHD is recalling it
/// and starting. A word you can tap is cheaper than a sentence you have to
/// find. **Only your own words**: a list of generic ones ("made food") reads
/// as patronising, and `docs/research/concept-and-social.md` idea 9 allows
/// starters "only as recents of your own past wins, never a list you
/// maintain". No history, no row: a new user sees the sheet as it was.
enum WinStarters {
    /// At most three, so the row is one glance and never a menu.
    static let count = 3
    /// How far back "what you usually do" looks.
    static let windowDays = 30
    /// Said at least this often to count as a habit rather than a one-off.
    static let minimumRepeats = 2

    struct Starter: Equatable, Identifiable {
        /// The spelling last used.
        let title: String
        let category: HabitCategory
        let size: BlockSize
        var id: String { Album.titleKey(title) }
    }

    /// One logged win, as much of it as the choice needs.
    struct Past {
        let title: String
        let category: HabitCategory
        let size: BlockSize
        let at: Date
    }

    /// The titles you repeat most, most repeated first, ties to the most
    /// recent. A title already logged today is left out: it is done, and the
    /// row is for what else the day held.
    static func pick(from past: [Past], now: Date = Date(),
                     calendar: Calendar = .current) -> [Starter] {
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: now) else { return [] }
        var groups: [String: (count: Int, last: Past)] = [:]
        var doneToday = Set<String>()
        for win in past where win.at >= start && win.at <= now {
            let key = Album.titleKey(win.title)
            guard Album.isCuratable(key) else { continue }
            if calendar.isDate(win.at, inSameDayAs: now) { doneToday.insert(key) }
            if let group = groups[key] {
                groups[key] = (group.count + 1, win.at > group.last.at ? win : group.last)
            } else {
                groups[key] = (1, win)
            }
        }
        let kept: [(count: Int, last: Past)] = groups
            .filter { $0.value.count >= minimumRepeats && !doneToday.contains($0.key) }
            .map { $0.value }
        let ranked = kept.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a.last.at > b.last.at
        }
        return ranked.prefix(count).map { group in
            Starter(title: group.last.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: group.last.category, size: group.last.size)
        }
    }

    /// The window's wins from the store, by their logs: a win's day is its
    /// log's, and a `Habit`'s own `createdAt` is when the row was made, which
    /// for a win backdated to yesterday is today.
    @MainActor
    static func load(from context: ModelContext, now: Date = Date()) -> [Starter] {
        guard let start = Calendar.current.date(byAdding: .day, value: -windowDays, to: now) else { return [] }
        let from = DateUtils.dateString(from: start)
        let descriptor = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed && $0.dateString >= from })
        let logs = (try? context.fetch(descriptor)) ?? []
        let past: [Past] = logs.compactMap { log in
            guard let habit = log.habit else { return nil }
            return Past(title: habit.title, category: habit.displayCategory,
                        size: habit.blockSize, at: log.completedAt ?? log.createdAt)
        }
        return pick(from: past, now: now)
    }
}
