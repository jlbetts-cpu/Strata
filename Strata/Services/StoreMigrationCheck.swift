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

        var digest: String { StableDigest.of(body) }

        var line: String {
            "habits=\(habits) logs=\(logs) moods=\(moods) towers=\(towers) "
            + "folders=\(folders) planItems=\(planItems) digest=\(digest)"
        }
    }

    static func read(context: ModelContext) -> Reading {
        var reading = Reading()
        func count<Model: PersistentModel>(_ type: Model.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<Model>())) ?? -1
        }
        reading.habits = count(Habit.self)
        reading.moods = count(MoodLog.self)
        reading.towers = count(Tower.self)
        reading.folders = count(PlanFolder.self)
        reading.planItems = count(PlanItem.self)

        let logs = (try? context.fetch(FetchDescriptor<HabitLog>())) ?? []
        reading.logs = logs.count

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
             log.subtasks.map { "\($0.title):\($0.completed)" }.joined(separator: ",")
            ].joined(separator: "|")
        }

        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let habitLines = habits.sorted { $0.id.uuidString < $1.id.uuidString }.map { habit in
            [habit.id.uuidString, habit.title, habit.category.rawValue,
             habit.blockSize.rawValue, habit.frequencyRawValues.joined(separator: ","),
             String(habit.reminderEnabled), String(habit.isTodo),
             String(habit.creationXP), String(habit.graceDays),
             habit.spontaneousCategoryRaw ?? "-",
             habit.tower?.name ?? "-"].joined(separator: "|")
        }

        let moods = (try? context.fetch(FetchDescriptor<MoodLog>())) ?? []
        let moodLines = moods.sorted { $0.id.uuidString < $1.id.uuidString }.map { mood in
            [mood.id.uuidString, mood.dateString, String(mood.mood),
             String(mood.motivation), mood.note ?? "-"].joined(separator: "|")
        }

        let towers = (try? context.fetch(FetchDescriptor<Tower>())) ?? []
        let towerLines = towers.sorted { $0.id.uuidString < $1.id.uuidString }.map { tower in
            [tower.id.uuidString, tower.name, tower.emoji, String(tower.order),
             String(tower.habits.count)].joined(separator: "|")
        }

        let folders = (try? context.fetch(FetchDescriptor<PlanFolder>())) ?? []
        let folderLines = folders.sorted { $0.id.uuidString < $1.id.uuidString }.map { folder in
            [folder.id.uuidString, folder.name, folder.icon, folder.colorHex,
             String(folder.sortOrder)].joined(separator: "|")
        }

        let items = (try? context.fetch(FetchDescriptor<PlanItem>())) ?? []
        let itemLines = items.sorted { $0.id.uuidString < $1.id.uuidString }.map { item in
            [item.id.uuidString, item.text, String(item.order),
             item.categoryRaw, item.repeatDaysRaw].joined(separator: "|")
        }

        reading.body = (logLines + habitLines + moodLines + towerLines + folderLines + itemLines)
            .joined(separator: "\n")
        return reading
    }
}
