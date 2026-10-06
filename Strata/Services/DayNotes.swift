import Foundation
import SwiftData

/// **The day's journal, one entry a day.**
///
/// Every read and write of a journal entry goes through here, so "one per
/// `dateString`" is a rule in one place rather than a hope in three views.
/// The entry is a `MoodLog` (see the note there for why that model and not a
/// new one).
///
/// **A row is made only when there is something to keep.** Opening a day and
/// closing it again writes nothing: an empty row would sync to iCloud, fill
/// the journal button for a day with nothing in it, and block a backup's note
/// from coming back on restore. A note written and then cleared keeps its
/// row, empty, because a save never deletes (`BackupRestore` makes the same
/// promise, and treats an empty row as no note).
///
/// **Two phones can each make the day's row** before iCloud brings the other
/// one over. Reads take the first row with something in it, lowest id first,
/// so both phones agree on which one they are showing, and a write goes to
/// that same row.
@MainActor
enum DayNotes {

    /// The day's entry, or nil when nothing has been written for it.
    static func entry(for dateString: String, context: ModelContext) -> MoodLog? {
        let rows = rows(for: dateString, context: context)
        return rows.first(where: \.hasContent) ?? rows.first
    }

    /// Get or create. Inserts a row when the day has none; does not save.
    static func entryOrNew(for dateString: String, context: ModelContext) -> MoodLog {
        if let existing = entry(for: dateString, context: context) { return existing }
        // `mood` and `motivation` are the scale's middle and never read. See
        // `MoodLog`: the day's emoji is a symbol, not a score.
        let made = MoodLog(dateString: dateString, mood: 3, motivation: 3)
        context.insert(made)
        return made
    }

    /// Writes the day's words and emoji, and saves.
    ///
    /// Nothing is made for a day that has no row and nothing to put in one.
    /// The sketch is not touched here: it has its own files and its own
    /// write, `setSketch(_:for:context:)` in `JournalSketches.swift`.
    static func save(note: String?, symbol: String?, for dateString: String, context: ModelContext) {
        let words = note.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let mark = symbol.flatMap { $0.isEmpty ? nil : $0 }
        let entry: MoodLog
        if let existing = Self.entry(for: dateString, context: context) {
            entry = existing
        } else {
            guard words != nil || mark != nil else { return }
            entry = entryOrNew(for: dateString, context: context)
        }
        guard entry.note != words || entry.symbol != mark else { return }
        entry.note = words
        entry.symbol = mark
        do { try context.save() } catch { NSLog("[journal] the day's note did not save: \(error)") }
    }

    /// Whether the day has a note (the journal button says "Written").
    static func hasNote(on dateString: String, context: ModelContext) -> Bool {
        entry(for: dateString, context: context)?.hasContent ?? false
    }

    /// Every emoji between two days, `from` included and `to` not, keyed by
    /// day: one fetch for a whole month of calendar cells.
    static func symbols(from loKey: String, to hiKey: String, context: ModelContext) -> [String: String] {
        let descriptor = FetchDescriptor<MoodLog>(
            predicate: #Predicate { $0.dateString >= loKey && $0.dateString < hiKey },
            sortBy: [SortDescriptor(\.dateString)])
        var out: [String: String] = [:]
        for row in (try? context.fetch(descriptor)) ?? [] {
            if out[row.dateString] == nil, let symbol = row.symbol { out[row.dateString] = symbol }
        }
        return out
    }

    private static func rows(for dateString: String, context: ModelContext) -> [MoodLog] {
        let descriptor = FetchDescriptor<MoodLog>(predicate: #Predicate { $0.dateString == dateString })
        return ((try? context.fetch(descriptor)) ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
