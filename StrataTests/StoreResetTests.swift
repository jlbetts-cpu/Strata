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

    @Test("the reset removes the photographs the record names, and nothing else")
    func resetTakesItsOwnPhotographsOnly() throws {
        let context = try context()
        let directory = ImageManager.shared.imageDirectoryForTesting
        let mine = "reset-test-mine-\(UUID().uuidString).heic"
        let notMine = "reset-test-not-mine-\(UUID().uuidString).heic"
        defer {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(mine))
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(notMine))
        }
        try Data("a".utf8).write(to: directory.appendingPathComponent(mine))
        try Data("b".utf8).write(to: directory.appendingPathComponent(notMine))

        let habit = Habit(title: "Photographed", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-09-01", completed: true)
        log.imageFileName = mine
        context.insert(log)
        try context.save()

        let removed = StoreReset.deleteEveryPhotograph(context: context)

        #expect(removed == [mine])
        #expect(ImageManager.shared.fileExists(fileName: mine) == false)
        // A file no win points at is `pruneOrphans`'s business, and that is the
        // most dangerous function in the app. A reset has no reason to borrow
        // its risk, and a test that let it would be the one that finds out.
        #expect(ImageManager.shared.fileExists(fileName: notMine))
    }

    @Test("the photographs are read before the rows go")
    func photographsAreReadWhileThereIsStillSomethingToReadThemFrom() throws {
        let context = try context()
        let habit = Habit(title: "Photographed", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-09-01", completed: true)
        log.imageFileName = "gone-with-the-rows.heic"
        context.insert(log)
        try context.save()

        // Rows first, on purpose: this is the order the bug had.
        StoreReset.deleteEverything(context: context)
        #expect(StoreReset.deleteEveryPhotograph(context: context).isEmpty)
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
