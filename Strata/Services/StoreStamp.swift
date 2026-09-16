import Foundation
import SwiftData

/// Keeps `updatedAt` current on every save, in one place.
///
/// **Not written at each edit site, because there are dozens and the next one
/// would forget.** A win's caption, size, colour, place, crop, tower position
/// and photograph are all edited from different views, and a tower drag
/// rewrites the order of every block at once. Instead this listens for
/// `ModelContext.willSave` and stamps whatever is about to be written, so an
/// edit path that does not exist yet is already covered.
///
/// Only main-thread saves are stamped, and that is every save this app makes:
/// the two background contexts (`SpotlightIndexer`, the widget streak fetch)
/// only read. A background save is logged in DEBUG so that stops being true
/// loudly rather than quietly.
enum StoreStamp {
    private static var token: NSObjectProtocol?
    /// While above zero, saves are not stamped. For `SocialFieldsBackfill`,
    /// which writes historical values that a stamp would overwrite with now.
    private static var suppressed = 0

    static func observe() {
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: ModelContext.willSave, object: nil, queue: nil
        ) { note in
            guard Thread.isMainThread else {
                #if DEBUG
                NSLog("[strata-stamp] a save off the main thread was not stamped")
                #endif
                return
            }
            guard let context = note.object as? ModelContext else { return }
            MainActor.assumeIsolated { stamp(context) }
        }
    }

    static func stamp(_ context: ModelContext, now: Date = Date()) {
        guard suppressed == 0 else { return }
        for model in context.changedModelsArray {
            switch model {
            case let log as HabitLog: log.updatedAt = now
            case let habit as Habit: habit.updatedAt = now
            case let tower as Tower: tower.updatedAt = now
            default: break
            }
        }
    }

    static func withoutStamping<T>(_ body: () throws -> T) rethrows -> T {
        suppressed += 1
        defer { suppressed -= 1 }
        return try body()
    }
}

/// Gives the rows that existed before `createdAt`/`updatedAt` did honest values,
/// once.
///
/// A defaulted `Date` column is filled with the moment of migration for every
/// existing row, which would say four years of wins were all logged and edited
/// this morning. The truest thing available is when each win happened.
/// `timeZoneIdentifier` is left empty on those rows: the zone they were logged
/// in was never recorded, and a guess would be a fabrication.
enum SocialFieldsBackfill {
    static let doneKey = "socialFieldsBackfilled"

    /// - Returns: how many logs were backfilled, or nil if it had already run.
    @discardableResult
    static func runIfNeeded(context: ModelContext,
                            defaults: UserDefaults = .standard) -> Int? {
        guard !defaults.bool(forKey: doneKey) else { return nil }
        do {
            let logs = try context.fetch(FetchDescriptor<HabitLog>())
            let habits = try context.fetch(FetchDescriptor<Habit>())
            let towers = try context.fetch(FetchDescriptor<Tower>())
            try StoreStamp.withoutStamping {
                try context.transaction {
                    for log in logs {
                        let happened = log.completedAt ?? log.habit?.createdAt ?? log.createdAt
                        log.createdAt = happened
                        log.updatedAt = happened
                    }
                    for habit in habits {
                        let latest = (habit.logs ?? []).compactMap(\.completedAt).max()
                        habit.updatedAt = max(habit.createdAt, latest ?? habit.createdAt)
                    }
                    for tower in towers { tower.updatedAt = tower.createdAt }
                }
            }
            defaults.set(true, forKey: doneKey)
            return logs.count
        } catch {
            NSLog("[strata-backfill] did not run, will try next launch: \(error)")
            return nil
        }
    }
}
