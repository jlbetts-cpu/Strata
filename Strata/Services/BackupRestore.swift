import Foundation
import SwiftData

/// Putting a backup back.
///
/// # It merges. It never replaces.
///
/// **The decision, and why it is not configurable.** A restore adds what the
/// backup has and leaves everything else exactly as it is. It does not delete a
/// win, it does not overwrite a win, and there is no "replace everything"
/// alternative anywhere in this file.
///
/// The argument for replace is that a backup is a snapshot and restoring it
/// should reproduce that snapshot. The argument against is the situation this
/// feature exists for: somebody reinstalled the app, believed their wins were in
/// iCloud, found out they were not, and lost everything. The next thing that
/// person does is pick a file in a hurry, on a phone, possibly the wrong file,
/// possibly an old one. A replace would take the wins they logged since and
/// silently remove them, and it would do it at the exact moment they have
/// already been burned once. Merge is the only version where the worst case is
/// "some of this was already here" instead of "it happened again".
///
/// So the strongest thing this file can say is that it contains no delete. Read
/// it and check: the only mutations are `context.insert`, field assignment on
/// objects created here, and one assignment on an existing row — described
/// below, and only ever nil to a value.
///
/// # Merging needs identifiers, and version 1 has none
///
/// Version 2 of the format carries `Habit.id` and `HabitLog.id`, so a record
/// already on the phone is recognised exactly and a restore run twice adds
/// nothing the second time. Version 1 — every backup made before 2026-09-23 —
/// has neither, so records are matched on their content, and each local record
/// can only be matched once so two identical wins in a file both arrive.
///
/// # The one write to a row that already exists
///
/// If a win is already here with NO photograph, and the backup has one for it,
/// the photograph is attached. That is nil becoming a value: nothing is
/// replaced, nothing is deleted, and it is the case that happens in real life
/// (a win re-logged by hand after the loss, whose picture is still in the zip).
/// Every other field of an existing row is left exactly as it is, including a
/// photograph it already has.
@MainActor
enum BackupRestore {

    // MARK: - What is in the file

    /// The numbers a person confirms against, before anything happens.
    nonisolated struct Summary: Equatable, Sendable {
        var version: Int
        var exportDate: Date
        var appVersion: String
        /// Blocks marked done.
        var wins: Int
        /// Blocks in the file that are not marked done (skipped days). Shown
        /// only when there are any, so the common case reads as one number.
        var otherEntries: Int
        /// Distinct days the blocks fall on.
        var days: Int
        var firstDay: Date?
        var lastDay: Date?
        /// Photograph files inside the zip.
        var photographs: Int
        /// How many of those the file can actually put back on a win. Zero for
        /// every version-1 backup, because version 1 never wrote the file name
        /// down.
        var attachablePhotographs: Int
    }

    /// Which habit a log will hang off. A log with no habit never appears on the
    /// tower (`TowerViewModel` skips it), so this is resolved before anything is
    /// inserted rather than hoped for afterwards.
    nonisolated enum HabitTarget: Equatable, Sendable {
        /// A habit already on the phone.
        case existing(UUID)
        /// An index into `Plan.habitsToAdd`.
        case fromFile(Int)
    }

    /// Everything the restore will do, worked out before it does any of it.
    ///
    /// Built by reading the store and the archive's index only: **planning
    /// writes nothing**, so the preview screen can show these numbers and the
    /// person can still walk away.
    nonisolated struct Plan: Sendable {
        var summary: Summary
        var habitsToAdd: [BackupArchive.ExportHabit] = []
        var logsToAdd: [(log: BackupArchive.ExportLog, habit: HabitTarget)] = []
        /// Wins in the file that are already on this phone. Left untouched.
        var winsAlreadyHere: Int = 0
        /// Wins in the file with no habit to hang off, in the file or on the
        /// phone. Not restored, and said out loud.
        var winsWithoutATemplate: Int = 0
        /// Photograph file names to take in for wins being added.
        var photographsToRestore: [String] = []
        /// (id of a win already here that has no photograph, the file name in
        /// the backup that belongs to it).
        var photographsForExistingWins: [(logID: UUID, fileName: String)] = []
        /// Photographs in the zip that no win in the file names. For a
        /// version-1 backup this is all of them.
        var unattachablePhotographs: [String] = []

        var winsToAdd: Int { logsToAdd.count }
        var isEmptyOfWork: Bool {
            logsToAdd.isEmpty && habitsToAdd.isEmpty && photographsForExistingWins.isEmpty
        }

        /// The things a person should read BEFORE confirming, not after.
        var warnings: [String] {
            var lines: [String] = []
            if summary.version < BackupArchive.currentFormatVersion, summary.photographs > 0 {
                lines.append("This backup was made by an older version of Strata, which did not record which win each photograph belongs to. Its \(summary.photographs) photograph\(summary.photographs == 1 ? "" : "s") cannot be put back on your wins. You can still save them from the zip in the Files app.")
            }
            if winsWithoutATemplate > 0 {
                lines.append("\(winsWithoutATemplate) win\(winsWithoutATemplate == 1 ? "" : "s") in this backup doesn't say what kind of win it was, so \(winsWithoutATemplate == 1 ? "it" : "they") can't be restored.")
            }
            if summary.version >= BackupArchive.currentFormatVersion, !unattachablePhotographs.isEmpty {
                lines.append("\(unattachablePhotographs.count) photograph\(unattachablePhotographs.count == 1 ? "" : "s") in this backup isn't attached to any win, so \(unattachablePhotographs.count == 1 ? "it" : "they") won't be restored.")
            }
            return lines
        }
    }

    /// What actually happened, once it has.
    nonisolated struct Report: Sendable {
        var winsAdded = 0
        var daysAdded = 0
        var photographsRestored = 0
        /// Photographs the zip carried that were already on this phone under the
        /// same name. Left exactly as they were.
        var photographsAlreadyHere = 0
        /// Photographs put back onto wins that were already here without one.
        var photographsReattached = 0
        /// Named, individually. A count of failures is not something anybody can
        /// act on.
        var problems: [String] = []
        /// Set when the save threw, in which case NOTHING was added.
        var failure: String?

        var succeeded: Bool { failure == nil }
    }

    // MARK: - Planning

    /// Reads the archive and the store and works out the merge. Writes nothing.
    static func plan(_ contents: BackupArchive.Contents, context: ModelContext) throws -> Plan {
        let document = contents.document
        let localHabits = try context.fetch(FetchDescriptor<Habit>())
        let localLogs = try context.fetch(FetchDescriptor<HabitLog>())

        var plan = Plan(summary: summarise(contents))

        // MARK: habits

        let localHabitsByID = Dictionary(localHabits.map { ($0.id, $0) },
                                        uniquingKeysWith: { first, _ in first })
        // Content keys are a multiset: each local record can be claimed once,
        // so a file holding two identical wins restores both.
        var localHabitsByContent: [String: [Habit]] = [:]
        for habit in localHabits {
            localHabitsByContent[contentKey(habit), default: []].append(habit)
        }
        /// Where each habit in the file ended up: already here, or queued to add.
        var resolvedHabits: [HabitTarget] = []
        for habit in document.habits {
            if let id = habit.id, let existing = localHabitsByID[id] {
                resolvedHabits.append(.existing(existing.id))
                continue
            }
            if habit.id == nil, var candidates = localHabitsByContent[contentKey(habit)], !candidates.isEmpty {
                let claimed = candidates.removeFirst()
                localHabitsByContent[contentKey(habit)] = candidates
                resolvedHabits.append(.existing(claimed.id))
                continue
            }
            plan.habitsToAdd.append(habit)
            resolvedHabits.append(.fromFile(plan.habitsToAdd.count - 1))
        }

        // MARK: logs

        let localLogsByID = Dictionary(localLogs.map { ($0.id, $0) },
                                       uniquingKeysWith: { first, _ in first })
        var localLogsByContent: [String: [HabitLog]] = [:]
        for log in localLogs {
            localLogsByContent[contentKey(log), default: []].append(log)
        }

        // For a version-1 file, logs point at their habit by TITLE, and a tower
        // of one-tap wins is two hundred habits all called "Win". Pairing them
        // by title alone would hang every log off the first one, and every
        // block would then draw at that one's size and colour. So a one-time
        // habit (no weekday, which is what `QuickWinService` makes) is claimed
        // by the log nearest it in time and then cannot be claimed again; a
        // recurring habit is shared, because it really does own many logs.
        var byTitle: [String: [Int]] = [:]
        for (index, habit) in document.habits.enumerated() {
            byTitle[habit.title, default: []].append(index)
        }
        var claimedOneOffs = Set<Int>()

        var localPhotographNames = Set(localLogs.compactMap(\.imageFileName))
        var namesClaimedByNewWins = Set<String>()

        for log in document.logs {
            // Already here?
            if let id = log.id, localLogsByID[id] != nil {
                plan.winsAlreadyHere += 1
                if let existing = localLogsByID[id], existing.imageFileName == nil,
                   let name = log.imageFileName, contents.photoEntries[name] != nil,
                   !localPhotographNames.contains(name) {
                    // The one write to an existing row: nil becoming a value.
                    plan.photographsForExistingWins.append((existing.id, name))
                    localPhotographNames.insert(name)
                }
                continue
            }
            // Version 1: matched on content, and each local win can be claimed
            // only once, so a file holding two identical wins restores both.
            if log.id == nil, var candidates = localLogsByContent[contentKey(log)], !candidates.isEmpty {
                candidates.removeFirst()
                localLogsByContent[contentKey(log)] = candidates
                plan.winsAlreadyHere += 1
                continue
            }

            guard let target = resolveHabit(for: log,
                                            documentHabits: document.habits,
                                            resolved: resolvedHabits,
                                            byTitle: byTitle,
                                            claimedOneOffs: &claimedOneOffs,
                                            localHabits: localHabits) else {
                plan.winsWithoutATemplate += 1
                continue
            }
            plan.logsToAdd.append((log, target))
            if let name = log.imageFileName, contents.photoEntries[name] != nil,
               !namesClaimedByNewWins.contains(name) {
                plan.photographsToRestore.append(name)
                namesClaimedByNewWins.insert(name)
            }
        }

        // Photographs in the zip that nothing in the file points at. For a
        // version-1 backup that is every one of them, and `warnings` says so.
        let named = Set(document.logs.compactMap(\.imageFileName))
        plan.unattachablePhotographs = contents.photoEntries.keys.filter { !named.contains($0) }.sorted()

        return plan
    }

    /// The numbers, from the file alone.
    static func summarise(_ contents: BackupArchive.Contents) -> Summary {
        let document = contents.document
        let days = Set(document.logs.map(\.dateString)).filter { !$0.isEmpty }
        let dates = days.compactMap(DateUtils.date(from:)).sorted()
        let named = Set(document.logs.compactMap(\.imageFileName))
        return Summary(
            version: document.version,
            exportDate: document.exportDate,
            appVersion: document.appVersion,
            wins: document.logs.filter(\.completed).count,
            otherEntries: document.logs.filter { !$0.completed }.count,
            days: days.count,
            firstDay: dates.first,
            lastDay: dates.last,
            photographs: contents.photoEntries.count,
            attachablePhotographs: contents.photoEntries.keys.filter { named.contains($0) }.count)
    }

    // MARK: - Applying

    /// Does the plan. The only function here that writes anything.
    static func apply(_ plan: Plan, contents: BackupArchive.Contents,
                      context: ModelContext,
                      photographs: PhotoOutcome? = nil) -> Report {
        var report = Report()
        guard !plan.isEmptyOfWork else { return report }

        let localHabits: [Habit]
        let localLogs: [HabitLog]
        do {
            localHabits = try context.fetch(FetchDescriptor<Habit>())
            localLogs = try context.fetch(FetchDescriptor<HabitLog>())
        } catch {
            report.failure = "Strata could not read what is already on this phone (\(error.localizedDescription)), so nothing was added."
            return report
        }
        let habitsByID = Dictionary(localHabits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let logsByID = Dictionary(localLogs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // The tower a restored win belongs to. Tower membership is not in the
        // backup, and `TowerManager.ensureDefaultTower` adopts any habit with no
        // tower on the next launch anyway, so this does at restore time what the
        // app would do a moment later. Nil when the store has no tower yet,
        // which is the same state a fresh install is in.
        let tower = (try? context.fetch(FetchDescriptor<Tower>(sortBy: [SortDescriptor(\.order)])))?.first

        // **Photographs first, then rows, then one save.** A name is written on
        // a win only once its file is on disk, so a restored win can never point
        // at a photograph that is not there. If the save then fails, the files
        // are on disk with nothing referencing them, which the launch sweep
        // collects; the person's own photographs are untouched either way.
        //
        // Done here only when the caller did not already do it off the main
        // thread. Inflating and decoding a year of photographs is seconds of
        // work, and the screen freezing through a restore is the one moment this
        // app cannot afford to look broken, so `RestoreBackupView` hands in an
        // outcome it computed in the background. The tests take this path.
        let photographs = photographs ?? takePhotographs(for: plan, from: contents)
        let restoredNames = photographs.landed
        report.photographsRestored = photographs.restored
        report.photographsAlreadyHere = photographs.alreadyHere
        report.problems += photographs.problems

        var created: [Habit] = []
        for exported in plan.habitsToAdd {
            let habit = makeHabit(from: exported, tower: tower)
            context.insert(habit)
            created.append(habit)
        }

        var daysAdded = Set<String>()
        for (exported, target) in plan.logsToAdd {
            let habit: Habit?
            switch target {
            case .existing(let id): habit = habitsByID[id]
            case .fromFile(let index): habit = index < created.count ? created[index] : nil
            }
            guard let habit else {
                // Resolved at plan time and gone by now: report it rather than
                // inserting a log with no habit, which would never draw.
                report.problems.append("A win from \(exported.dateString) could not be matched to a kind of win, so it was not restored.")
                continue
            }
            let log = makeLog(from: exported, habit: habit,
                              photographRestored: exported.imageFileName.map { restoredNames.contains($0) } ?? false)
            context.insert(log)
            daysAdded.insert(log.dateString)
            report.winsAdded += 1
        }

        // The one write to a row that already exists: a photograph onto a win
        // that has none.
        for (logID, name) in plan.photographsForExistingWins {
            guard let log = logsByID[logID], log.imageFileName == nil else { continue }
            guard restoredNames.contains(name) else { continue }
            log.imageFileName = name
            report.photographsReattached += 1
        }

        do {
            try context.save()
        } catch {
            // **Rolled back, so a half-written restore is not left in the
            // store.** Every insert above is discarded and the person's existing
            // wins are exactly as they were.
            context.rollback()
            report.failure = "Strata could not save the restored wins (\(error.localizedDescription)). Nothing was added, and nothing you already had was changed."
            report.winsAdded = 0
            report.photographsReattached = 0
            // `photographsRestored` is left as it is: those files really are on
            // disk. Nothing points at them, so the launch sweep collects them,
            // and the screen shows the failure rather than the counts.
            return report
        }
        report.daysAdded = daysAdded.count
        return report
    }

    // MARK: - The photographs

    /// What became of the photographs. `landed` is the names that are now on
    /// disk, whether this restore wrote them or found them already there — the
    /// only names a win may be pointed at.
    nonisolated struct PhotoOutcome: Sendable {
        var landed: Set<String> = []
        var restored = 0
        var alreadyHere = 0
        var problems: [String] = []
    }

    /// Every photograph the plan needs, out of the archive and into the image
    /// directory, one at a time.
    ///
    /// **`nonisolated`, and the slow half of a restore.** Each photograph is
    /// inflated, decoded to prove it is an image, and written; a year's library
    /// is hundreds of them. It touches no model object, which is what lets it run
    /// off the main thread while the screen keeps saying what it is doing.
    nonisolated static func takePhotographs(for plan: Plan,
                                            from contents: BackupArchive.Contents) -> PhotoOutcome {
        var outcome = PhotoOutcome()
        let names = plan.photographsToRestore + plan.photographsForExistingWins.map(\.fileName)
        for name in names where !outcome.landed.contains(name) {
            switch take(name, from: contents) {
            case .written(let landed):
                outcome.landed.insert(landed)
                outcome.restored += 1
            case .alreadyHere(let landed):
                outcome.landed.insert(landed)
                outcome.alreadyHere += 1
            case .failed(let failedName, let reason):
                // Named individually. A count of failures is not something
                // anybody can act on, and the win is still restored — without
                // its photograph, and said out loud.
                outcome.problems.append("A photograph (\(failedName)) could not be restored: \(reason). Its win was restored without it.")
            }
        }
        return outcome
    }

    /// One photograph out of the archive and into the image directory, through
    /// `ImageManager`, which owns that folder.
    nonisolated private static func take(_ name: String,
                                         from contents: BackupArchive.Contents) -> ImageManager.Adoption {
        do {
            return ImageManager.shared.adopt(try contents.photograph(named: name), named: name)
        } catch let failure as ZipArchiveReader.Failure {
            return .failed(name: name, reason: BackupArchive.ReadFailure.archive(failure).message)
        } catch {
            return .failed(name: name, reason: error.localizedDescription)
        }
    }

    // MARK: - Building the objects

    private static func makeHabit(from exported: BackupArchive.ExportHabit, tower: Tower?) -> Habit {
        // An unknown category or size falls back rather than failing the
        // restore: a backup from a version that had a category this one does not
        // is still a backup worth having, and `.unlabeled`/`.small` are the
        // values the app already uses for "nobody said".
        let category = HabitCategory(rawValue: exported.category) ?? .unlabeled
        let habit = Habit(
            title: exported.title,
            category: category,
            blockSize: BlockSize(rawValue: exported.blockSize) ?? .small,
            frequency: exported.frequency.compactMap(DayCode.init(rawValue:)),
            scheduledTime: exported.scheduledTime,
            reminderEnabled: exported.reminderEnabled ?? false,
            isTodo: exported.isTodo ?? false,
            scheduledDate: exported.scheduledDate,
            graceDays: exported.graceDays ?? 2,
            timeOfDay: exported.timeOfDay.flatMap(TimeOfDay.init(rawValue:)) ?? .anytime,
            sortOrder: exported.sortOrder ?? 0)
        // The identity the backup carries, so restoring the same file twice adds
        // nothing the second time. A version-1 backup has none and gets a new
        // one, which is why version 1 is matched on content instead.
        if let id = exported.id { habit.id = id }
        habit.createdAt = exported.createdAt
        habit.updatedAt = exported.updatedAt ?? exported.createdAt
        habit.customDurationMinutes = exported.customDurationMinutes
        habit.isQuickWin = exported.isQuickWin ?? false
        habit.spontaneousCategoryRaw = exported.spontaneousCategoryRaw
        habit.tower = tower

        if exported.isQuickWin == nil {
            // **Version 1 did not record which habits were wins.** This is the
            // same inference `QuickWinService.migrateLegacyWins` makes, and for
            // the same reason: nothing but a one-tap win has ever had an empty
            // weekday list AND the untitled name, so the pair is exact rather
            // than a guess. A one-off task from the add sheet has the same shape
            // except for its title, which is what the title test keeps apart. A
            // win somebody RENAMED cannot be recognised at all from a version-1
            // file; it still draws on the tower, it just is not counted as a
            // win, and there is no honest way to do better.
            if exported.frequency.isEmpty, exported.title == QuickWinService.untitled {
                habit.isQuickWin = true
                habit.isTodo = true
                habit.scheduledDate = exported.scheduledDate ?? DateUtils.dateString(from: exported.createdAt)
            }
            // A version-1 win also lost its colour: `category` was `.unlabeled`
            // and the colour lived in `spontaneousCategoryRaw`, which was not
            // exported. `displayCategory` falls back to `.health`, so without
            // this every restored win would come back green and a tower would
            // lose the one thing it is made of. A colour is given back so the
            // tower is varied again; it is explicitly NOT a category, so no
            // filter, tone, Siri result or icon claims anything about it.
            if category == .unlabeled, habit.spontaneousCategoryRaw == nil {
                habit.spontaneousCategoryRaw = restoredColour(for: exported).rawValue
            }
        }
        return habit
    }

    /// A stable colour for a version-1 win, derived from its own fields rather
    /// than drawn at random, so restoring the same backup twice gives the same
    /// tower and a screenshot can be compared with one taken before.
    private static func restoredColour(for habit: BackupArchive.ExportHabit) -> HabitCategory {
        let palette = HabitCategory.selectable
        var hash = 5381
        for byte in (habit.title + String(habit.createdAt.timeIntervalSince1970)).utf8 {
            hash = (hash &* 33) &+ Int(byte)
        }
        return palette[abs(hash) % palette.count]
    }

    private static func makeLog(from exported: BackupArchive.ExportLog, habit: Habit,
                                photographRestored: Bool) -> HabitLog {
        let log = HabitLog(habit: habit, dateString: exported.dateString,
                           completed: exported.completed)
        if let id = exported.id { log.id = id }
        log.completedAt = exported.completedAt
        log.skipped = exported.skipped
        log.note = exported.note
        log.caption = exported.caption
        // **Only if the file is on disk.** A name pointing at a photograph that
        // is not there is a block with a hole in it and no explanation; the
        // failure is reported instead.
        log.imageFileName = photographRestored ? exported.imageFileName : nil
        log.cropPositionX = exported.cropPositionX
        log.cropPositionY = exported.cropPositionY
        log.towerOrder = exported.towerOrder
        log.latitude = exported.latitude
        log.longitude = exported.longitude
        log.locationAccuracy = exported.locationAccuracy
        log.createdAt = exported.createdAt ?? exported.completedAt ?? Date()
        log.updatedAt = exported.updatedAt ?? log.createdAt
        log.timeZoneIdentifier = exported.timeZoneIdentifier ?? ""
        log.isBonusBlock = exported.isBonusBlock ?? false
        log.subtasks = (exported.subtasks ?? []).map {
            SubTask(id: $0.id, title: $0.title, completed: $0.completed)
        }
        return log
    }

    // MARK: - Matching

    /// Which habit a log belongs to. See the note in `plan` about version 1.
    private static func resolveHabit(for log: BackupArchive.ExportLog,
                                     documentHabits: [BackupArchive.ExportHabit],
                                     resolved: [HabitTarget],
                                     byTitle: [String: [Int]],
                                     claimedOneOffs: inout Set<Int>,
                                     localHabits: [Habit]) -> HabitTarget? {
        // Version 2: the id, which is exact.
        if let habitID = log.habitID {
            if let index = documentHabits.firstIndex(where: { $0.id == habitID }), index < resolved.count {
                return resolved[index]
            }
            if let local = localHabits.first(where: { $0.id == habitID }) {
                return .existing(local.id)
            }
        }
        // Version 1: the title, nearest in time, one-offs claimed once.
        let candidates = byTitle[log.habitTitle] ?? []
        let when = log.completedAt ?? DateUtils.date(from: log.dateString) ?? .distantPast
        let available = candidates.filter { index in
            let isOneOff = documentHabits[index].frequency.isEmpty
            return !isOneOff || !claimedOneOffs.contains(index)
        }
        guard let best = available.min(by: {
            abs(documentHabits[$0].createdAt.timeIntervalSince(when))
                < abs(documentHabits[$1].createdAt.timeIntervalSince(when))
        }) else {
            // Nothing in the file. A habit already on the phone with that title
            // is the last resort; it is only reached for a log whose habit the
            // file does not contain.
            if let local = localHabits.first(where: { $0.title == log.habitTitle }) {
                return .existing(local.id)
            }
            return nil
        }
        if documentHabits[best].frequency.isEmpty { claimedOneOffs.insert(best) }
        return best < resolved.count ? resolved[best] : nil
    }

    /// The content key for a version-1 habit, on both sides of the comparison.
    /// Written twice against the same field list on purpose: one function over a
    /// protocol would need both types to agree on names they do not share.
    private static func contentKey(_ habit: Habit) -> String {
        [habit.title, habit.category.rawValue, habit.blockSize.rawValue,
         String(Int(habit.createdAt.timeIntervalSince1970))].joined(separator: "\u{1}")
    }

    private static func contentKey(_ habit: BackupArchive.ExportHabit) -> String {
        [habit.title, habit.category, habit.blockSize,
         String(Int(habit.createdAt.timeIntervalSince1970))].joined(separator: "\u{1}")
    }

    private static func contentKey(_ log: HabitLog) -> String {
        [log.habit?.title ?? "Unknown", log.dateString,
         log.completedAt.map { String(Int($0.timeIntervalSince1970)) } ?? "-",
         log.caption, log.note ?? "-",
         log.completed ? "1" : "0", log.skipped ? "1" : "0"].joined(separator: "\u{1}")
    }

    private static func contentKey(_ log: BackupArchive.ExportLog) -> String {
        [log.habitTitle, log.dateString,
         log.completedAt.map { String(Int($0.timeIntervalSince1970)) } ?? "-",
         log.caption, log.note ?? "-",
         log.completed ? "1" : "0", log.skipped ? "1" : "0"].joined(separator: "\u{1}")
    }
}
