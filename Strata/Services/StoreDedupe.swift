import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "StoreDedupe")

/// Puts every win back on one tower after a sync.
///
/// **The one bug that sync creates all by itself, and it looks exactly like
/// sync not working.**
///
/// `TowerManager.ensureDefaultTower` makes a tower called "My Tower" whenever
/// the store has none. On a second device that is a fresh install, it runs at
/// launch, before the first import has landed, so that device makes its OWN
/// tower. The import then brings the first device's tower down as well, and
/// there are two. Nothing in the app lists towers, so nobody sees them. What
/// they see is this, at `MainAppView.swift:230`:
///
///     cachedFilteredLogs.filter { $0.habit?.tower?.id == activeTowerID }
///
/// The Wins tab shows the active tower's blocks only. So the second device
/// holds every win the first one ever logged, in its store, exported and
/// imported correctly, and draws an empty tower. There is no error, no alert
/// and nothing in the log. It is the most expensive possible failure: the
/// person concludes sync is broken and reinstalls, which is how the data was
/// lost the first time.
///
/// CloudKit cannot prevent it, because the fix Core Data would normally use is
/// `@Attribute(.unique)` and mirroring refuses unique constraints outright. So
/// it is fixed here, after the fact, which is what Apple's own guidance says to
/// do.
///
/// **The survivor is chosen the same way on every device, or the devices fight.**
/// Oldest `createdAt` wins, and the lower `id` breaks a tie. Both are synced
/// values, so each device reaches the same answer independently: device one
/// moves its habits onto tower A, device two moves its habits onto tower A, and
/// the next import finds nothing to do. Choosing "whichever tower this device
/// was already using" would have each device moving everything to its own and
/// exporting, forever.
///
/// **Nothing is deleted.** The loser is left as an empty row, and that is
/// deliberate rather than lazy: `TowerManager` holds its tower in memory for
/// the life of the screen, and deleting the object it is holding leaves a view
/// reading a deleted row, which is a fault and a crash rather than a blank. An
/// empty `Tower` is six small fields that nothing reads, nothing lists and
/// nothing draws. A crash on the launch after the first sync would be a far
/// worse trade.
enum StoreDedupe {

    /// - Returns: how many habits were moved. Zero is the ordinary answer and
    ///   means nothing was written.
    @discardableResult
    @MainActor
    static func mergeDuplicateTowers(in context: ModelContext) -> Int {
        let towers: [Tower]
        do {
            towers = try context.fetch(FetchDescriptor<Tower>())
        } catch {
            // Logged, never swallowed: without this the app silently keeps
            // drawing an empty tower on a device that has every win.
            logger.error("could not read the towers to merge them: \(String(describing: error), privacy: .private)")
            return 0
        }

        // The single-device case, which is every install today. Strictly
        // nothing happens: no write, no save, no export.
        guard towers.count > 1, let survivor = chosen(from: towers) else { return 0 }

        let habits: [Habit]
        do {
            habits = try context.fetch(FetchDescriptor<Habit>())
        } catch {
            logger.error("could not read the wins to move them: \(String(describing: error), privacy: .private)")
            return 0
        }

        // A habit with no tower at all is moved too. An import can land a habit
        // before the relationship that connects it, and an untowered habit is
        // invisible on the Wins tab for the same reason a wrongly towered one
        // is. Running on every import is what makes that self healing.
        let strays = habits.filter { $0.tower?.id != survivor.id }
        guard !strays.isEmpty else {
            // Still point the app at the survivor. Two towers with nothing to
            // move can still mean this device is looking at the empty one.
            pointAppAt(survivor)
            return 0
        }

        for habit in strays { habit.tower = survivor }
        // Written BEFORE the save, so that a save which fails still leaves the
        // app looking at the tower the wins are being gathered onto.
        pointAppAt(survivor)

        do {
            try context.save()
        } catch {
            logger.error("could not save the merged tower: \(String(describing: error), privacy: .private)")
            return 0
        }

        logger.log("merged \(towers.count, privacy: .public) towers into one, moving \(strays.count, privacy: .public) wins")
        #if DEBUG
        NSLog("[strata-dedupe] towers=\(towers.count) moved=\(strays.count) survivor=\(survivor.id)")
        #endif
        return strays.count
    }

    /// The tower every device agrees on: the oldest, with the lower id breaking
    /// a tie.
    ///
    /// The tie matters more than it looks. Two fresh installs set up minutes
    /// apart have different `createdAt`s, but a restored device and a seeded
    /// one can land on the same instant, and `Date` equality then decides
    /// nothing. The id is the only value guaranteed to differ.
    static func chosen(from towers: [Tower]) -> Tower? {
        towers.min {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    /// The key `TowerManager` and `LogWinIntent` both read to decide which
    /// tower is open. Written here rather than through `TowerManager` so that
    /// this runs from a notification without a view model in reach.
    static let activeTowerKey = "activeTowerID"

    private static func pointAppAt(_ tower: Tower) {
        let wanted = tower.id.uuidString
        guard UserDefaults.standard.string(forKey: activeTowerKey) != wanted else { return }
        UserDefaults.standard.set(wanted, forKey: activeTowerKey)
    }
}
