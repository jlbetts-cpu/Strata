import Foundation
import SwiftData
import Testing
@testable import Strata

/// A note on a win, and the day's wins drawn in that day's journal
/// (`WinNote`, the owner's idea of 2026-10-13).
@MainActor
@Suite("A note on a win")
struct WinNoteTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }
    private let noon = Date(timeIntervalSince1970: 1_791_900_000)
    private func win(_ title: String, _ note: String?, done: TimeInterval, loggedLate: Bool = false) -> WinNote.Win {
        let at = noon.addingTimeInterval(done)
        return WinNote.Win(id: UUID(), title: title, note: note,
                           createdAt: loggedLate ? at.addingTimeInterval(6 * 3600) : at.addingTimeInterval(20), completedAt: at)
    }

    @Test("a note is trimmed and capped, and nothing is none")
    func tidy() {
        #expect(WinNote.tidy("  Slow, but I went. \n") == "Slow, but I went.")
        #expect(WinNote.tidy("   \n ") == nil)
        #expect(WinNote.tidy(String(repeating: "a", count: 400))?.count == WinNote.limit)
    }

    @Test("a day with no note draws nothing; one note brings the whole day, in the order it was lived")
    func lines() {
        let plain = [win("Walk", nil, done: 0), win("Read", "  ", done: 600)]
        #expect(WinNote.lines(plain).isEmpty)
        let run = win("Morning run", "Slow, but I went.", done: 60)
        let lunch = win("Lunch with Maya", "First time since August.", done: 7200, loggedLate: true)
        let read = win("Read a chapter", nil, done: 3600)
        let day = WinNote.lines([lunch, read, run])
        #expect(day.map(\.title) == ["Morning run", "Read a chapter", "Lunch with Maya"])
        #expect(day.map(\.note) == ["Slow, but I went.", nil, "First time since August."])
        // The hour is said only of a noted win logged as it happened.
        #expect(day[0].time != nil)
        #expect(day[1].time == nil, "no note, no hour")
        #expect(day[2].time == nil, "added that night: its hour would be untrue")
    }

    @Test("where a note shows is said once, after the first one, and never again")
    func hint() throws {
        let defaults = try #require(UserDefaults(suiteName: "win-note-\(UUID().uuidString)"))
        #expect(!WinNote.hintDue(defaults: defaults))
        WinNote.noteSaved(defaults: defaults)
        #expect(WinNote.hintDue(defaults: defaults))
        WinNote.markHintShown(defaults: defaults)
        #expect(!WinNote.hintDue(defaults: defaults))
        WinNote.noteSaved(defaults: defaults)
        #expect(!WinNote.hintDue(defaults: defaults))
        #expect(WinNote.hintLine.count <= TipCopy.longestMessage)
        for line in [WinNote.hintTitle, WinNote.hintLine, WinNote.prompt] {
            #expect(!line.contains("!") && !line.contains("?") && !line.contains("\u{2014}"))
        }
    }

    @Test("the note is the win's own field, kept with it")
    func stored() throws {
        let ctx = ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanItem.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let tower = Tower(name: "Wins")
        ctx.insert(tower)
        let made = try QuickWinService.logWin(title: "Morning run", category: .health, size: .small, context: ctx, tower: tower)
        let log = try #require((made.habit.logs ?? []).first { $0.id == made.logID })
        #expect(log.note == nil)
        log.note = WinNote.tidy(" Slow, but I went. ")
        try ctx.save()
        let read = try #require(try ctx.fetch(FetchDescriptor<HabitLog>()).first { $0.id == made.logID })
        #expect(read.note == "Slow, but I went.")
        let drawn = WinNote.lines([WinNote.Win(id: read.id, title: read.habit?.title ?? "", note: read.note,
                                               createdAt: read.createdAt, completedAt: read.completedAt)])
        #expect(drawn.map(\.note) == ["Slow, but I went."])
    }

    @Test("it is written at the win after the win exists, never in a fresh Add, and never leaves for a crew")
    func whereItLives() throws {
        let add = try code("Strata/Views/AddWinSheet.swift")
        // Only on a win being edited, and not past a locked journal.
        #expect(add.contains("if editingLog != nil, !(journalLocked && !JournalLock.shared.isUnlocked) {\n                            TextField(WinNote.prompt"))
        #expect(add.components(separatedBy: "WinNote.prompt").count == 3, "one field, and its prompt")
        // A menu still waits for the keyboard when it is the note being typed.
        #expect(add.contains("guard titleFocused || noteFocused else { open(); return }"))
        let journal = try code("Strata/Views/DaySheet.swift")
        #expect(journal.contains("DayWinNotes(dateString: dateString, shown: $winNotesShown)\n            editor"))
        #expect(journal.contains("sketchName == nil && !winNotesShown"))
        // Drawn live from the wins: nothing of them is written into the journal's own words.
        let drawn = try code("Strata/Views/DayWinNotes.swift")
        #expect(!drawn.contains("MoodLog"))
        // The crew's copy of a win has no place for a note.
        let sync = try code("Strata/Social/CrewSync.swift")
        #expect(!sync.contains(".note"))
    }
}
