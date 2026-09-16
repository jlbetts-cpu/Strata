import Testing
import Foundation
import SwiftData
@testable import Strata

/// **Reset All Data deleted the photograph files and left every win in place
/// for months.**
///
/// `modelContext.delete(model:)` is a batch delete, a batch delete bypasses
/// the relationship rules, and the store refuses it on `HabitLog` and `Habit`
/// because both have a mandatory nullify inverse. Every call was `try?`, so
/// there was nothing to read anywhere. The privacy policy said the button
/// removed everything.
///
/// Under sync the same mistake would be worse: a batch delete never goes
/// through a context, so a mirroring layer would not learn about it, would not
/// write the tombstones, and the next sync would bring every deleted win back
/// a few seconds after the reset appeared to work.
///
/// These pin what the reset must do. `noBatchDeleteInTheSource` is the gate
/// that stops it coming back.
@MainActor
@Suite("StoreReset", .serialized)
struct StoreResetTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func fillEverySort(_ context: ModelContext) throws {
        let tower = Tower(name: "Home", order: 0)
        context.insert(tower)
        context.insert(PlanFolder(name: "Errands"))
        context.insert(MoodLog(dateString: "2026-09-01", mood: 4, motivation: 4))
        context.insert(PlanItem(text: "Call the landlord", order: 0, category: .work))
        for i in 0..<4 {
            let habit = Habit(title: "Win \(i)", category: .health)
            habit.tower = tower
            context.insert(habit)
            context.insert(HabitLog(habit: habit, dateString: "2026-09-0\(i + 1)", completed: true))
        }
        try context.save()
    }

    @Test("a reset leaves zero of every model type")
    func resetEmptiesEverything() throws {
        let context = try context()
        try fillEverySort(context)

        let before = StoreReset.remaining(context: context)
        #expect(before.total > 0)
        // `PlanItem` is the one that used to survive. Without it in the sweep
        // this reading is 1 rather than 0 and the reset is a lie under sync.
        #expect(before.counts["PlanItem"] == 1)

        let after = StoreReset.deleteEverything(context: context)
        #expect(after.isEmpty, "the store was not emptied: \(after.line)")
        for name in ["HabitLog", "Habit", "PlanFolder", "MoodLog", "Tower", "PlanItem"] {
            #expect(after.counts[name] == 0, "\(name) survived the reset")
        }
    }

    /// Writes a real file into the image directory and returns its name.
    private func photoFile(_ tag: String) throws -> String {
        let name = "reset-test-\(tag)-\(UUID().uuidString).heic"
        try Data(tag.utf8).write(to: ImageManager.shared.imageDirectoryForTesting.appendingPathComponent(name))
        return name
    }

    private func removeFile(_ name: String) {
        try? FileManager.default.removeItem(
            at: ImageManager.shared.imageDirectoryForTesting.appendingPathComponent(name))
    }

    private func photographedWin(_ file: String, _ context: ModelContext) throws {
        let habit = Habit(title: "Photographed", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-09-01", completed: true)
        log.imageFileName = file
        context.insert(log)
        try context.save()
    }

    @Test("the reset removes the photographs the record named, and nothing else")
    func resetTakesItsOwnPhotographsOnly() throws {
        let context = try context()
        let mine = try photoFile("mine")
        let notMine = try photoFile("not-mine")
        defer { removeFile(mine); removeFile(notMine) }
        try photographedWin(mine, context)

        let names = try StoreReset.photographNames(context: context)
        StoreReset.deleteEverything(context: context)
        let removed = StoreReset.removePhotographs(names, context: context)

        #expect(removed == [mine])
        #expect(ImageManager.shared.fileExists(fileName: mine) == false)
        // A file no win points at is `pruneOrphans`'s business, and that is
        // the most dangerous function in the app. A reset has no reason to
        // borrow its risk.
        #expect(ImageManager.shared.fileExists(fileName: notMine))
    }

    /// **The order that was the bug, pinned the safe way round.** Reset used
    /// to delete the files and then the rows; a row delete that failed left
    /// every win naming a photograph that was already gone.
    @Test("the files are still there after the names are read and until the rows have gone")
    func filesOutliveTheRowsNotTheOtherWayRound() throws {
        let context = try context()
        let file = try photoFile("order")
        defer { removeFile(file) }
        try photographedWin(file, context)

        let names = try StoreReset.photographNames(context: context)
        #expect(names == [file])
        // Reading the names touches nothing.
        #expect(ImageManager.shared.fileExists(fileName: file))

        let remaining = StoreReset.deleteEverything(context: context)
        #expect(remaining.isEmpty)
        // The rows are gone and the file is STILL there: nothing removes a
        // photograph as a side effect of deleting rows.
        #expect(ImageManager.shared.fileExists(fileName: file))

        StoreReset.removePhotographs(names, context: context)
        #expect(ImageManager.shared.fileExists(fileName: file) == false)
    }

    @Test("a photograph a surviving win still names is never removed")
    func stillNamedPhotographsStay() throws {
        let context = try context()
        let file = try photoFile("kept")
        defer { removeFile(file) }
        try photographedWin(file, context)

        // Handed the name, but no reset happened: the win still names it.
        let removed = StoreReset.removePhotographs([file], context: context)
        #expect(removed.isEmpty)
        #expect(ImageManager.shared.fileExists(fileName: file))
    }

    @Test("a reading that could not count something is never empty")
    func unreadCountsDoNotAddUpToZero() {
        var remaining = StoreReset.Remaining(counts: ["Habit": -1, "Tower": 1])
        #expect(remaining.total == 0)
        #expect(remaining.isEmpty == false)
        remaining = StoreReset.Remaining(counts: ["Habit": 0], failure: "boom")
        #expect(remaining.isEmpty == false)
    }

    /// **The gate.** Not a style rule: `delete(model:)` fails outright on two
    /// of this app's six models, and under sync it would silently skip the
    /// tombstones on the other four.
    ///
    /// Reads the working tree through `#filePath`, which is the compile-time
    /// path of this file. If a batch delete ever comes back this fails and
    /// names the line.
    @Test("no batch delete anywhere in the app's source")
    func noBatchDeleteInTheSource() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // StrataTests
            .deletingLastPathComponent()   // the checkout
        // Assembled rather than written out, or this line would flag itself.
        let needle = "delete(" + "model:"
        var offenders: [String] = []
        let enumerator = try #require(
            FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil),
            "the gate could not read the checkout at \(root.path), so it cannot fail and must not pass")
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                // The comments that explain the bug say the words, so a line
                // that is only a comment does not count.
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), !code.hasPrefix("///") else { continue }
                if code.contains(needle) {
                    offenders.append("\(url.lastPathComponent):\(n + 1)")
                }
            }
        }
        #expect(offenders.isEmpty, "batch delete found at \(offenders.joined(separator: ", "))")
    }
}
