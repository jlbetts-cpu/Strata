import Foundation

/// **A note on a win** (the owner, 2026-10-13: "an option to add more
/// information about a given win and it would automatically format them in
/// the journal for you ... sleek and usable ... keep the minimalism").
///
/// **Where it is written.** After the win exists, at the win: one line
/// under its name when you edit it, and in the journal on its own line.
/// Never in a fresh Add: that sheet stands its block just over the keys,
/// and an empty optional field there is a form. This is what the quiet
/// apps do (BeReal's caption, Things' notes, Gentler Streak): the note is
/// added at the thing, after the thing, with nothing drawn until then.
///
/// **Where it shows.** Once any win of a day has a note, that day's journal
/// draws the day's wins above your own words: the name, the note under it.
/// Drawn live from the wins, never saved into the journal's own text, so a
/// rename follows and a deleted win leaves no stale line. A day with no
/// note is the journal exactly as it was.
///
/// **Kept in `HabitLog.note`**, a field the model has always had and no
/// screen used: already in backups and the delete's undo, and held out of
/// crews by a test (`CrewSyncTests`). Private to you, always. No new field.
nonisolated enum WinNote {
    /// A note is a sentence or two, not an entry.
    static let limit = 280
    static let prompt = "Add a note"

    /// What is kept: trimmed, capped, and nothing for nothing.
    static func tidy(_ text: String) -> String? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? nil : String(words.prefix(limit))
    }

    struct Win: Sendable {
        let id: UUID
        let title: String
        let note: String?
        let createdAt: Date
        let completedAt: Date?
    }

    struct Line: Equatable, Identifiable, Sendable {
        let id: UUID
        let title: String
        let note: String?
        /// When it was done, for a noted win logged as it happened.
        let time: Date?
    }

    /// A win logged within this of being done was logged as it happened;
    /// one added that night says nothing true about an hour.
    static let asItHappened: TimeInterval = 10 * 60

    /// The day's wins as the journal draws them, in the order they were
    /// done. Empty unless one of them has a note: the list is the notes'
    /// setting, not a second tower.
    static func lines(_ wins: [Win]) -> [Line] {
        guard wins.contains(where: { tidy($0.note ?? "") != nil }) else { return [] }
        return wins.sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }.map { win in
            let note = tidy(win.note ?? "")
            let live = win.completedAt.map { abs($0.timeIntervalSince(win.createdAt)) <= asItHappened } ?? false
            return Line(id: win.id, title: win.title, note: note, time: note != nil && live ? win.completedAt : nil)
        }
    }

    // MARK: Said once

    static let hintTitle = "A note on a win"
    // One line beside the mark (`TipCopy.longestMessage`).
    static let hintLine = "It shows in that day's journal."
    static let hintDueKey = "hint.winNote.due"
    static let hintShownKey = "hint.winNote.shown"

    /// A first note was saved: the hint is owed, once ever.
    static func noteSaved(defaults: UserDefaults = .standard) {
        if !defaults.bool(forKey: hintShownKey) { defaults.set(true, forKey: hintDueKey) }
    }

    static func hintDue(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: hintDueKey) && !defaults.bool(forKey: hintShownKey)
    }

    static func markHintShown(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: hintShownKey)
        defaults.removeObject(forKey: hintDueKey)
    }
}
