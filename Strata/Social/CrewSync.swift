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
/// **Wins drawn out of the slot wait for a yes before a crew sees them** (the
/// owner, 2026-10-05: "when dragging to create a block on the home i noticed
/// it instantly shows up on the crews I would prefer if it only showed up if
/// you clicked the check mark first"). A dragged block lands on your tower
/// only; opening it and confirming the sheet sends it, with the crews you
/// usually choose already ticked. Kept by log id, on this phone.
enum CrewHold {
    private static let key = "crews.heldWins"

    static func hold(_ id: UUID, defaults: UserDefaults = .standard) {
        var held = defaults.stringArray(forKey: key) ?? []
        held.append(id.uuidString)
        defaults.set(Array(held.suffix(60)), forKey: key)
    }

    static func isHeld(_ id: UUID, defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(id.uuidString)
    }

    static func release(_ id: UUID, defaults: UserDefaults = .standard) {
        let held = (defaults.stringArray(forKey: key) ?? []).filter { $0 != id.uuidString }
        defaults.set(held, forKey: key)
    }
}

enum CrewSync {
    private static let log = Logger(subsystem: "Strata", category: "crews.sync")
    private static var token: NSObjectProtocol?

    /// The store wins go to. `.shared` in the app; a test's own in a test.
    static var store: () -> SocialStore = { SocialStore.shared }

    static func observe(evenIfOff: Bool = false) {
        guard token == nil, CrewsFlag.isOn || evenIfOff else { return }
        token = NotificationCenter.default.addObserver(forName: ModelContext.willSave, object: nil, queue: nil) { note in
            guard Thread.isMainThread, let context = note.object as? ModelContext else { return }
            MainActor.assumeIsolated { saw(context) }
        }
    }

    /// Sends a win you just logged to the crews chosen for it, with the
    /// people chosen on Add Win's With row, if any. Who a win was with is
    /// never on the `HabitLog`: it exists only in the crews it went to.
    static func post(_ entry: HabitLog, to chosen: Set<CrewID>? = nil, with people: [UUID] = []) {
        guard CrewsFlag.isOn, var win = ownWin(entry) else { return }
        let crews = chosen ?? CrewChoice.load()
        guard !crews.isEmpty else { return }
        win.withPeople = people
        Task { await store().post(win, to: crews) }
    }

    /// The Edit screen's checkboxes. `people` only from Add Win finishing a
    /// win whose photo failed the first time.
    static func setCrews(for entry: HabitLog, to chosen: Set<CrewID>, with people: [UUID] = []) {
        guard CrewsFlag.isOn, var win = ownWin(entry) else { return }
        win.withPeople = people
        Task { await store().setCrews(for: win, to: chosen) }
    }

    private static func saw(_ context: ModelContext) {
        // **Not a save that only links a photograph's iCloud copy**
        // (2026-10-08). That changes the win's row and nothing about the win;
        // sending it would re-send every crew-held photograph the backfill
        // touches. See `StoreStamp.isQuiet`.
        guard !StoreStamp.isQuiet else { return }
        let store = store()
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
        guard !changed.isEmpty || !deleted.isEmpty else { return }
        if !deleted.isEmpty {
            Task { for id in deleted { await store.deleteEverywhere(winID: id) } }
        }
        // **Gathered, then read once, after the saves have settled.** One edit
        // is often two saves (the name, then the photo), and reading each
        // save's values into its own update let an older one land last and
        // put a removed photo back (the 2026-10-02 audit). The log is read
        // when the update is sent, so it carries the final values.
        for (id, entry) in changed where !deleted.contains(id) { waiting[id] = entry }
        scheduled?.cancel()
        scheduled = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let batch = waiting
            waiting.removeAll()
            for (_, entry) in batch where !entry.isDeleted && entry.modelContext != nil {
                if let win = ownWin(entry) { await store.update(win) }
            }
        }
    }

    private static var waiting: [UUID: HabitLog] = [:]
    private static var scheduled: Task<Void, Never>?

    /// A win as a crew is handed it: what it looks like, and its photograph
    /// as it is on disk. `ShareDerivative` makes what is actually sent.
    static func ownWin(_ entry: HabitLog) -> OwnWin? {
        guard let habit = entry.habit, entry.completed else { return nil }
        // A doodle with no photograph goes as a picture of the doodled block
        // (`BlockDoodles.crewPicture`), keyed by its file so a redraw is sent.
        let doodle = entry.imageFileName == nil ? entry.doodleFileName : nil
        let photo = entry.imageFileName.flatMap {
            try? Data(contentsOf: ImageManager.shared.imageDirectory.appendingPathComponent($0))
        } ?? doodle.flatMap { BlockDoodles.crewPicture($0, colour: habit.displayCategory) }
        return OwnWin(winID: entry.id,
                      // The placeholder name is not a name: an unnamed win
                      // shows no text on anyone's tower.
                      title: habit.title == QuickWinService.untitled ? "" : habit.title,
                      colour: habit.displayCategory,
                      icon: habit.category,
                      blockSize: habit.blockSize,
                      photoJPEG: photo,
                      // The colour is in a doodle's picture, so a recolour
                      // sends it again.
                      photoKey: entry.imageFileName ?? doodle.map { "\($0)-\(habit.displayCategory.rawValue)" },
                      cropX: entry.cropPositionX,
                      cropY: entry.cropPositionY,
                      createdAt: entry.createdAt,
                      updatedAt: entry.updatedAt)
    }
}
