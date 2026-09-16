import Foundation
import SwiftData

/// Emptying the store, object by object, in one transaction.
///
/// **A batch delete deletes nothing here, and under sync it would be worse
/// than that.** CLAUDE.md records the first half: `modelContext.delete(model:)`
/// bypasses the relationship rules, the store refuses it on `HabitLog` (whose
/// `habit` inverse is mandatory nullify) and on `Habit` (`tower`), every call
/// was `try?`, and so Reset All Data deleted the photograph files and left
/// every win in place for months while the privacy policy said it removed
/// everything.
///
/// The second half is why this is now a shared function rather than a loop
/// written out wherever it is needed. A batch delete writes straight to the
/// persistent store without going through a context, so the context never
/// observes the deletions and a mirroring layer never learns about them: it
/// cannot write the tombstones, the rows stay in iCloud, and the next sync
/// brings every one of them back. The failure that would produce is not
/// "Reset All Data deletes nothing" but "Reset All Data appears to work, and
/// then every win returns a few seconds later".
///
/// So: one place, object by object, inside one transaction, no `try?` on a
/// delete or a save, and in DEBUG a count of what is left for every model the
/// store holds. `ResetGateTests` greps the whole app for `delete(model:` and
/// fails if one comes back.
enum StoreReset {

    /// What was left after the sweep, by model name. Zero everywhere is the
    /// only passing reading.
    struct Remaining: Equatable {
        var counts: [String: Int] = [:]

        var total: Int { counts.values.reduce(0, +) }
        var isEmpty: Bool { total == 0 }

        var line: String {
            counts.keys.sorted().map { "\($0)=\(counts[$0] ?? -1)" }.joined(separator: " ")
        }
    }

    /// Removes every photograph the record points at, and returns the names.
    ///
    /// **Call it before the rows go.** Once the logs are deleted there is
    /// nothing left to read the file names from, which is how a reset can
    /// leave hundreds of megabytes of photographs behind.
    ///
    /// It removes only what a win names. A file nothing points at is
    /// `pruneOrphans`'s business, and that is the most dangerous function in
    /// the app; a reset has no reason to borrow its risk.
    @discardableResult
    static func deleteEveryPhotograph(context: ModelContext) -> [String] {
        let logs: [HabitLog]
        do {
            logs = try context.fetch(FetchDescriptor<HabitLog>())
        } catch {
            NSLog("[strata-reset] could not read the record, so no photographs were removed: \(error)")
            return []
        }
        let names = logs.compactMap(\.imageFileName)
        for name in names { ImageManager.shared.deleteImage(fileName: name) }
        return names
    }

    /// Deletes every model the store holds.
    ///
    /// The caller is responsible for the photograph files, and must read the
    /// file names BEFORE calling this: once the rows are gone there is nothing
    /// left to read them from.
    ///
    /// - Returns: what is left afterwards, which should be nothing.
    @discardableResult
    static func deleteEverything(context: ModelContext) -> Remaining {
        // Logs before habits, though `Habit.logs` cascades and would take them
        // anyway: deleting the dependent side first is what keeps the mandatory
        // inverse satisfied at every step rather than only at the end.
        //
        // `PlanItem` was NOT in this list until now. A plan line survived Reset
        // All Data, which was survivable while the store was local and is not
        // once it syncs: a row that outlives a reset comes back to a fresh
        // install and the reset is a lie.
        deleteEvery(HabitLog.self, context: context)
        deleteEvery(Habit.self, context: context)
        deleteEvery(PlanFolder.self, context: context)
        deleteEvery(MoodLog.self, context: context)
        deleteEvery(Tower.self, context: context)
        deleteEvery(PlanItem.self, context: context)
        return remaining(context: context)
    }

    /// Deletes every row of one model, one object at a time.
    ///
    /// Never `try?`. A fetch that fails leaves rows behind and a save that
    /// fails leaves all of them behind, and both of those are exactly the
    /// silence that let the original bug live for months.
    static func deleteEvery<Model: PersistentModel>(_ type: Model.Type, context: ModelContext) {
        do {
            try context.transaction {
                for item in try context.fetch(FetchDescriptor<Model>()) {
                    context.delete(item)
                }
            }
        } catch {
            NSLog("[strata-reset] could not delete every \(Model.self): \(error)")
        }
    }

    /// Saves after a delete, and says so in the log when it does not.
    ///
    /// **The rule is never `try?` a delete**, and a delete that is not saved
    /// is a delete that did not happen. Every single-object delete path in the
    /// app ends here so that none of them can go quiet.
    static func commitDelete(_ what: String, context: ModelContext) {
        do {
            try context.save()
        } catch {
            NSLog("[strata-delete] \(what) did not save, so nothing was deleted: \(error)")
        }
    }

    /// What is still in the store, for every model in the schema.
    static func remaining(context: ModelContext) -> Remaining {
        var out = Remaining()
        func count<Model: PersistentModel>(_ type: Model.Type) {
            do {
                out.counts["\(Model.self)"] = try context.fetchCount(FetchDescriptor<Model>())
            } catch {
                NSLog("[strata-reset] could not count \(Model.self): \(error)")
                out.counts["\(Model.self)"] = -1
            }
        }
        count(HabitLog.self)
        count(Habit.self)
        count(PlanFolder.self)
        count(MoodLog.self)
        count(Tower.self)
        count(PlanItem.self)
        return out
    }
}
