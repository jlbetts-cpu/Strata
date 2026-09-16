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
        /// Set when the sweep's transaction threw, in which case nothing was
        /// deleted at all.
        var failure: String?

        var total: Int { counts.values.reduce(0, +) }
        /// Every count read and every count zero. A count that could not be
        /// read is -1 and never passes, so two failures cannot add up to zero.
        var isEmpty: Bool { failure == nil && !counts.isEmpty && counts.values.allSatisfy { $0 == 0 } }

        var line: String {
            let body = counts.keys.sorted().map { "\($0)=\(counts[$0] ?? -1)" }.joined(separator: " ")
            return failure.map { "\(body) FAILED: \($0)" } ?? body
        }
    }

    /// The photograph file names the record points at.
    ///
    /// **Read, never removed, here.** Reset used to delete the files first and
    /// the rows second, which is the exact shape of the bug that ran for months:
    /// if the row delete fails, every photograph is already gone and every win
    /// still names one. The names are read while there is still a record to
    /// read them from; the files go in `removePhotographs`, after the rows have
    /// committed.
    ///
    /// Throws rather than returning an empty list, so a failed read can never
    /// look like "no photographs".
    static func photographNames(context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<HabitLog>()).compactMap(\.imageFileName)
    }

    /// Removes the files a reset read before the rows went, but only the ones
    /// no remaining win still names.
    ///
    /// Asks the store again rather than trusting the caller, so a partial
    /// delete can never take a photograph a surviving win points at. If that
    /// question cannot be answered, nothing is removed. It only ever removes
    /// names it is handed: a file nothing points at is `pruneOrphans`'s
    /// business, and that is the most dangerous function in the app.
    ///
    /// - Returns: the names removed.
    @discardableResult
    static func removePhotographs(_ names: [String], context: ModelContext) -> [String] {
        let stillNamed: Set<String>
        do {
            stillNamed = Set(try photographNames(context: context))
        } catch {
            NSLog("[strata-reset] could not check which photographs are still in use, so none were removed: \(error)")
            return []
        }
        let removable = names.filter { !stillNamed.contains($0) }
        for name in removable { ImageManager.shared.deleteImage(fileName: name) }
        return removable
    }

    /// Deletes every model the store holds, in ONE transaction.
    ///
    /// **One, not six.** Each model had its own transaction, so a failure on
    /// `Tower` left the logs, habits, folders and moods already gone: a half
    /// reset, which under sync is a half reset on every device. Now it is all
    /// of it or none of it.
    ///
    /// The caller is responsible for the photograph files: read the names with
    /// `photographNames` BEFORE this, remove them with `removePhotographs`
    /// AFTER it.
    ///
    /// - Returns: what is left afterwards, which should be nothing.
    @discardableResult
    static func deleteEverything(context: ModelContext) -> Remaining {
        var failure: String?
        do {
            try context.transaction {
                // Logs before habits, though `Habit.logs` cascades and would
                // take them anyway: deleting the dependent side first keeps
                // the mandatory inverse satisfied at every step.
                //
                // `PlanItem` was not in the original list. A plan line survived
                // Reset All Data, which under sync is a row that outlives a
                // reset and comes back to a fresh install.
                for item in try context.fetch(FetchDescriptor<HabitLog>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<Habit>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<PlanFolder>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<MoodLog>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<Tower>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<PlanItem>()) { context.delete(item) }
            }
        } catch {
            NSLog("[strata-reset] the reset did not commit, so nothing was deleted: \(error)")
            // A thrown transaction can leave the deletes pending in the
            // context. Roll them back so a later autosave cannot commit half.
            context.rollback()
            failure = String(describing: error)
        }
        var out = remaining(context: context)
        out.failure = failure
        return out
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
