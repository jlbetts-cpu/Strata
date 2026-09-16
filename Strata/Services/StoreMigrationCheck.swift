import Foundation
import SwiftData

/// A hash that means the same thing in two different launches.
///
/// **`hashValue` does not.** Swift seeds its hasher per process, so a digest
/// taken from the old build and a digest taken from the new one would differ
/// every time whether or not a single byte of the record had changed, and the
/// check would be worse than none: a test that cannot fail for the right
/// reason and cannot pass for it either. FNV-1a over UTF-8, which is fixed.
enum StableDigest {
    static func of(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

/// What the record says about itself, in one string.
///
/// **Thirty one properties were given default values so the schema fits
/// CloudKit's rules** (every attribute optional or defaulted). The whole
/// argument for that being safe is that nothing is renamed, removed or
/// retyped, so SwiftData adds the defaults in place and every existing row
/// keeps every value it already had. That is a claim, and this is how it is
/// measured: take the reading from a store written before the change, take it
/// again after, and the two strings are equal or they are not.
///
/// It reads every property that was given a default, plus the ones that would
/// be the loudest loss if one had been overwritten: the photograph a win
/// points at, where it was taken, and where it sits in the tower.
enum StoreRecordDigest {

    struct Reading: Equatable {
        var habits = 0
        var logs = 0
        var moods = 0
        var towers = 0
        var folders = 0
        var planItems = 0
        /// Every value that a default could have flattened, in a fixed order.
        var body = ""
        /// One entry per model that could not be read.
        ///
        /// **A failed fetch is not an empty table.** These were `try?`, so a
        /// fetch that failed the same way before and after the change produced
        /// two equal empty readings, and the check passed on a store it had
        /// not read at all.
        var failures: [String] = []

        /// Whether every model was read. A reading that is not complete never
        /// counts as a pass, whatever its digest says.
        var isComplete: Bool { failures.isEmpty }

        var digest: String { StableDigest.of(body) }

        var line: String {
            let head = "habits=\(habits) logs=\(logs) moods=\(moods) towers=\(towers) "
                + "folders=\(folders) planItems=\(planItems) digest=\(digest)"
            return isComplete ? head : head + " INCOMPLETE: " + failures.joined(separator: "; ")
        }
    }

    /// A date as the exact number the store holds, so a value flattened to
    /// launch time shows even when it lands in the same second.
    static func stamp(_ date: Date) -> String { String(date.timeIntervalSinceReferenceDate) }

    static func read(context: ModelContext) -> Reading {
        var reading = Reading()

        func fetch<Model: PersistentModel>(_ type: Model.Type) -> [Model] {
            do {
                return try context.fetch(FetchDescriptor<Model>())
            } catch {
                reading.failures.append("\(Model.self): \(error)")
                return []
            }
        }

        let logs = fetch(HabitLog.self)
        let habits = fetch(Habit.self)
        let moods = fetch(MoodLog.self)
        let towers = fetch(Tower.self)
        let folders = fetch(PlanFolder.self)
        let items = fetch(PlanItem.self)

        func counted<Model>(_ rows: [Model], _ type: Model.Type) -> Int {
            reading.failures.contains { $0.hasPrefix("\(type):") } ? -1 : rows.count
        }
        reading.logs = counted(logs, HabitLog.self)
        reading.habits = counted(habits, Habit.self)
        reading.moods = counted(moods, MoodLog.self)
        reading.towers = counted(towers, Tower.self)
        reading.folders = counted(folders, PlanFolder.self)
        reading.planItems = counted(items, PlanItem.self)

        // Sorted by id, because fetch order is not a promise and a digest that
        // depended on it would fail for a reason that is not a loss.
        let logLines = logs.sorted { $0.id.uuidString < $1.id.uuidString }.map { log in
            [log.id.uuidString, log.dateString, String(log.completed), log.caption,
             String(log.surgeMode), String(log.xpCollected), String(log.isBonusBlock),
             log.imageFileName ?? "-",
             log.towerOrder.map(String.init) ?? "-",
             log.latitude.map { String(format: "%.6f", $0) } ?? "-",
             log.longitude.map { String(format: "%.6f", $0) } ?? "-",
             log.note ?? "-",
             log.completedAt.map(stamp) ?? "-",
             log.habit?.id.uuidString ?? "-",
             log.subtasks.map { "\($0.title):\($0.completed)" }.joined(separator: ",")
            ].joined(separator: "|")
        }

        let habitLines = habits.sorted { $0.id.uuidString < $1.id.uuidString }.map { habit in
            [habit.id.uuidString, habit.title, habit.category.rawValue,
             habit.blockSize.rawValue, habit.frequencyRawValues.joined(separator: ","),
             stamp(habit.createdAt),
             String(habit.reminderEnabled), String(habit.isTodo),
             String(habit.creationXP), String(habit.graceDays),
             habit.spontaneousCategoryRaw ?? "-",
             // The tower's id, not its name: two towers can share a name, and
             // a habit moved between them must not read as unchanged.
             habit.tower?.id.uuidString ?? "-",
             habit.planFolder?.id.uuidString ?? "-"].joined(separator: "|")
        }

        let moodLines = moods.sorted { $0.id.uuidString < $1.id.uuidString }.map { mood in
            [mood.id.uuidString, mood.dateString, String(mood.mood),
             String(mood.motivation), mood.note ?? "-"].joined(separator: "|")
        }

        let towerLines = towers.sorted { $0.id.uuidString < $1.id.uuidString }.map { tower in
            [tower.id.uuidString, tower.name, tower.emoji, String(tower.order),
             stamp(tower.createdAt),
             // Counted from the habits' side, so this line compiles against the
             // model before and after `Tower.habits` became optional.
             String(habits.filter { $0.tower?.id == tower.id }.count)].joined(separator: "|")
        }

        let folderLines = folders.sorted { $0.id.uuidString < $1.id.uuidString }.map { folder in
            [folder.id.uuidString, folder.name, folder.icon, folder.colorHex,
             String(folder.sortOrder), stamp(folder.createdAt)].joined(separator: "|")
        }

        let itemLines = items.sorted { $0.id.uuidString < $1.id.uuidString }.map { item in
            [item.id.uuidString, item.text, String(item.order),
             item.categoryRaw, item.repeatDaysRaw, stamp(item.createdAt),
             item.completedAt.map(stamp) ?? "-"].joined(separator: "|")
        }

        reading.body = (logLines + habitLines + moodLines + towerLines + folderLines + itemLines)
            .joined(separator: "\n")
        return reading
    }
}
