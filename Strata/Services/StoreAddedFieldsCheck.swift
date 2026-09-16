import Foundation
import SwiftData

/// A reading of the fields added for social readiness, kept apart from
/// `StoreRecordDigest`.
///
/// **Apart on purpose.** `StoreRecordDigest` has to compile against the models
/// as they were BEFORE this change, so a store written by that build and read
/// by this one can be compared value for value. These fields do not exist in
/// that build, so they cannot be in that reading. This one is taken on the new
/// build only, and says whether the new fields arrived with honest values:
/// backfilled from when each win happened, not stamped with the migration.
enum StoreAddedFieldsCheck {

    struct Reading: Equatable {
        var logs = 0
        /// Logs whose `createdAt` equals `completedAt`, which is what the
        /// backfill writes for a win that existed before the field did.
        var createdFromCompleted = 0
        /// Logs with a recorded zone. Zero for old wins is the honest answer.
        var zoned = 0
        var habits = 0
        var towers = 0
        var body = ""
        var failures: [String] = []

        var isComplete: Bool { failures.isEmpty }
        var digest: String { StableDigest.of(body) }

        var line: String {
            let head = "logs=\(logs) createdFromCompleted=\(createdFromCompleted) zoned=\(zoned) "
                + "habits=\(habits) towers=\(towers) digest=\(digest)"
            return isComplete ? head : head + " INCOMPLETE: " + failures.joined(separator: "; ")
        }
    }

    static func read(context: ModelContext) -> Reading {
        var reading = Reading()
        func fetch<Model: PersistentModel>(_ type: Model.Type) -> [Model] {
            do { return try context.fetch(FetchDescriptor<Model>()) } catch {
                reading.failures.append("\(Model.self): \(error)")
                return []
            }
        }
        let stamp = StoreRecordDigest.stamp
        let logs = fetch(HabitLog.self).sorted { $0.id.uuidString < $1.id.uuidString }
        let habits = fetch(Habit.self).sorted { $0.id.uuidString < $1.id.uuidString }
        let towers = fetch(Tower.self).sorted { $0.id.uuidString < $1.id.uuidString }

        reading.logs = logs.count
        reading.habits = habits.count
        reading.towers = towers.count
        reading.createdFromCompleted = logs.filter { $0.completedAt == $0.createdAt }.count
        reading.zoned = logs.filter { !$0.timeZoneIdentifier.isEmpty }.count

        let lines = logs.map { [$0.id.uuidString, stamp($0.createdAt), stamp($0.updatedAt), $0.timeZoneIdentifier].joined(separator: "|") }
            + habits.map { [$0.id.uuidString, stamp($0.updatedAt)].joined(separator: "|") }
            + towers.map { [$0.id.uuidString, stamp($0.updatedAt)].joined(separator: "|") }
            + ["profileID|" + ProfileStore.profileID.uuidString]
        reading.body = lines.joined(separator: "\n")
        return reading
    }
}
