import Foundation
import SwiftData

/// Making the backup file.
///
/// **Extracted from the Settings screen so the restore can be tested against a
/// real one.** The round-trip test — export a store, empty it, restore, and
/// check the same wins and photographs came back — is the only test that proves
/// a backup is a backup, and it cannot be written against a private function
/// inside a `View` that raises an alert. The export's behaviour is unchanged:
/// same file name, same zip layout, same JSON keys, plus the version-2 fields
/// listed in `BackupArchive`.
@MainActor
enum BackupExport {

    /// `Strata Backup 2026-09-23`. The name is also the zip's one wrapping
    /// folder, which is why the reader finds `wins.json` by suffix rather than
    /// by rebuilding this string.
    static func name(on date: Date) -> String {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        return "Strata Backup \(stamp.string(from: date))"
    }

    /// The index, from the store.
    ///
    /// **Version 2 writes down the identifiers and the photograph file names.**
    /// Version 1 wrote neither, which is what made its `photos/` folder
    /// unrestorable: the file name holds the log's UUID and nothing in the JSON
    /// ever said which win that was. Everything version 1 wrote is still
    /// written, so a version-2 file also decodes against a version-1 reader.
    static func document(habits: [Habit], logs: [HabitLog],
                        appVersion: String, exportDate: Date = Date()) -> BackupArchive.Document {
        BackupArchive.Document(
            formatVersion: BackupArchive.currentFormatVersion,
            exportDate: exportDate,
            appVersion: appVersion,
            habits: habits.map { habit in
                BackupArchive.ExportHabit(
                    title: habit.title,
                    category: habit.category.rawValue,
                    blockSize: habit.blockSize.rawValue,
                    frequency: habit.frequency.map(\.rawValue),
                    scheduledTime: habit.scheduledTime,
                    createdAt: habit.createdAt,
                    id: habit.id,
                    isTodo: habit.isTodo,
                    scheduledDate: habit.scheduledDate,
                    isQuickWin: habit.isQuickWin,
                    spontaneousCategoryRaw: habit.spontaneousCategoryRaw,
                    timeOfDay: habit.timeOfDay?.rawValue,
                    customDurationMinutes: habit.customDurationMinutes,
                    graceDays: habit.graceDays,
                    sortOrder: habit.sortOrder,
                    reminderEnabled: habit.reminderEnabled,
                    updatedAt: habit.updatedAt)
            },
            logs: logs.map { log in
                BackupArchive.ExportLog(
                    // "Unknown" is what version 1 wrote for a log whose habit
                    // is nil. Such a log never draws on the tower anyway
                    // (`TowerViewModel` skips it), and the restore reports it
                    // rather than inventing a win to hang it on.
                    habitTitle: log.habit?.title ?? "Unknown",
                    dateString: log.dateString,
                    completed: log.completed,
                    completedAt: log.completedAt,
                    skipped: log.skipped,
                    note: log.note,
                    caption: log.caption,
                    id: log.id,
                    habitID: log.habit?.id,
                    imageFileName: log.imageFileName,
                    cropPositionX: log.cropPositionX,
                    cropPositionY: log.cropPositionY,
                    towerOrder: log.towerOrder,
                    latitude: log.latitude,
                    longitude: log.longitude,
                    locationAccuracy: log.locationAccuracy,
                    createdAt: log.createdAt,
                    updatedAt: log.updatedAt,
                    timeZoneIdentifier: log.timeZoneIdentifier,
                    isBonusBlock: log.isBonusBlock,
                    subtasks: log.subtasks.map {
                        BackupArchive.ExportSubTask(id: $0.id, title: $0.title, completed: $0.completed)
                    })
            })
    }

    /// Every original photograph on disk.
    ///
    /// Originals only: `derived/` is a cache of copies the app remakes itself,
    /// and a backup of it is dead weight in somebody's mail. Every original is
    /// taken, not only the ones a win names — a file nothing points at is about
    /// to be collected by the launch sweep, and a backup is the last chance to
    /// keep it.
    static func photographs(in directory: URL = ImageManager.shared.imageDirectory) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
            .filter(ImageDerivatives.isOriginal)
    }

    /// Builds the whole backup and returns the zip to share.
    static func makeZip(habits: [Habit], logs: [HabitLog], appVersion: String,
                        now: Date = Date(),
                        photographs: [URL]? = nil,
                        temporaryDirectory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        try BackupArchive.writeZip(
            document: document(habits: habits, logs: logs, appVersion: appVersion, exportDate: now),
            photographs: photographs ?? Self.photographs(),
            named: name(on: now),
            in: temporaryDirectory)
    }
}
