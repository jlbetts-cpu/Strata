import Foundation
import SwiftData
import os

/// Your wins, kept in step with the crews they were sent to.
///
/// **Two doors, on purpose.**
///
/// - A NEW win is sent from the two places a person logs one (Add Win, and
///   the slot and the camera through `MainAppView.logWin`), with the crews
///   ticked there, or the ones ticked last time. Never from a save in
///   general: restoring a backup inserts hundreds of wins, and not one of
///   them should reach a friend.
/// - A win ALREADY sent is kept current by one save observer: any save that
///   changes it, or its habit, updates every copy; any save that deletes it
///   deletes every copy. So an edit, a new photo, a removed photo or a delete
///   cannot be missed by some path that forgot to call this.
@MainActor
enum CrewSync {
    private static let log = Logger(subsystem: "Strata", category: "crews.sync")
    private static var token: NSObjectProtocol?

    static func observe() {
        guard token == nil, CrewsFlag.isOn else { return }
        token = NotificationCenter.default.addObserver(forName: ModelContext.willSave, object: nil, queue: nil) { note in
            guard Thread.isMainThread, let context = note.object as? ModelContext else { return }
            MainActor.assumeIsolated { saw(context) }
        }
    }

    /// Sends a win you just logged to the crews chosen for it.
    static func post(_ entry: HabitLog, to chosen: Set<CrewID>? = nil) {
        guard CrewsFlag.isOn, let win = ownWin(entry) else { return }
        let crews = chosen ?? CrewChoice.load()
        guard !crews.isEmpty else { return }
        Task { await SocialStore.shared.post(win, to: crews) }
    }

    /// The Edit screen's checkboxes.
    static func setCrews(for entry: HabitLog, to chosen: Set<CrewID>) {
        guard CrewsFlag.isOn, let win = ownWin(entry) else { return }
        Task { await SocialStore.shared.setCrews(for: win, to: chosen) }
    }

    private static func saw(_ context: ModelContext) {
        let store = SocialStore.shared
        var changed: [UUID: HabitLog] = [:]
        for model in context.changedModelsArray {
            switch model {
            case let entry as HabitLog where !store.crews(holding: entry.id).isEmpty:
                changed[entry.id] = entry
            case let habit as Habit:
                for entry in habit.logs ?? [] where !store.crews(holding: entry.id).isEmpty {
                    changed[entry.id] = entry
                }
            default: break
            }
        }
        let deleted = context.deletedModelsArray.compactMap { ($0 as? HabitLog)?.id }
            .filter { !store.crews(holding: $0).isEmpty }
        // The save has not happened yet: read the values now, send after.
        let updates = changed.values.compactMap(ownWin)
        guard !updates.isEmpty || !deleted.isEmpty else { return }
        Task {
            for id in deleted { await store.deleteEverywhere(winID: id) }
            for win in updates where !deleted.contains(win.winID) { await store.update(win) }
        }
    }

    /// A win as a crew is handed it: what it looks like, and its photograph
    /// as it is on disk. `ShareDerivative` makes what is actually sent.
    static func ownWin(_ entry: HabitLog) -> OwnWin? {
        guard let habit = entry.habit, entry.completed else { return nil }
        let photo = entry.imageFileName.flatMap {
            try? Data(contentsOf: ImageManager.shared.imageDirectory.appendingPathComponent($0))
        }
        return OwnWin(winID: entry.id,
                      // The placeholder name is not a name: an unnamed win
                      // shows no text on anyone's tower.
                      title: habit.title == QuickWinService.untitled ? "" : habit.title,
                      colour: habit.displayCategory,
                      icon: habit.category,
                      blockSize: habit.blockSize,
                      photoJPEG: photo,
                      cropX: entry.cropPositionX,
                      cropY: entry.cropPositionY,
                      createdAt: entry.createdAt,
                      updatedAt: entry.updatedAt)
    }
}
