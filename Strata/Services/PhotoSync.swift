import Foundation
import CoreData
import SwiftData
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "PhotoSync")

/// When the photographs move between the image directory and the store, and
/// when the one function that deletes photographs is allowed to run.
///
/// **The wins sync on their own; the photographs need three moments of
/// help** (2026-10-08). A copy arriving from iCloud is a row, and a row is not
/// a file the app can draw, so `WinPhotoStore.materialise` writes it out: at
/// launch, whenever the store says another device changed something
/// (`NSPersistentStoreRemoteChange`, and a finished CloudKit import), and on
/// every return to the foreground. Photographs that were on the phone before
/// sync existed have no copy, so `WinPhotoStore.backfill` makes them, once a
/// launch, late, slowly and newest first. And the orphan sweep is held back
/// until neither of those can be mid-delivery (`pruneAllowed`).
///
/// Everything here is best effort and none of it blocks anything. A pass that
/// fails is logged and the next trigger tries again.
@MainActor
final class PhotoSync {

    static let shared = PhotoSync()

    // MARK: - Tuning

    /// How long after launch the backfill waits before it starts. The launch
    /// is the most contended moment the app has (the drop, the derivative
    /// migration, the first decodes), and the backfill is the least urgent
    /// thing that wants the disk.
    static let backfillDelay: Duration = .seconds(20)
    /// The pause between backfill batches. Each batch is a handful of
    /// photographs decoded and re-encoded one at a time at utility priority,
    /// then one quiet save; this keeps it to a trickle under anything a person
    /// is doing.
    static let batchPause: Duration = .milliseconds(1500)
    /// How long a burst of remote changes is gathered before one pass runs.
    /// An import posts a change per batch of records.
    static let remoteChangeSettle: Duration = .seconds(1)

    // MARK: - What is remembered between launches

    /// **Set when CloudKit refuses a save because the person's iCloud is
    /// full**, cleared by the next export that succeeds. While it is set the
    /// backfill does not start or stops at its next batch, so the app is not
    /// queueing a thousand old photographs behind a full account. Photographs
    /// attached from now on still get their copy, so they go up the moment
    /// there is room, and the wins keep their place in the queue.
    static let pausedForQuotaKey = "photoSyncPausedForQuota"
    /// Set the first time an import from iCloud finishes on this install. The
    /// orphan sweep waits for it on a mirrored store; see `pruneAllowed`.
    static let hasImportedKey = "photoSyncHasImported"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isPausedForQuota: Bool { defaults.bool(forKey: Self.pausedForQuotaKey) }

    // MARK: - State for this launch

    private var container: ModelContainer?
    private var imageDirectory: URL?
    private var tokens: [NSObjectProtocol] = []

    private var materialiseTask: Task<Void, Never>?
    private var materialiseAgain = false
    private var remoteChangeTask: Task<Void, Never>?

    private var backfillTask: Task<Void, Never>?
    /// The backfill has run to the end this launch, so nothing asks for it
    /// again until the next one, except a restore.
    private var backfillFinished = false

    /// The sweep the app asked for and did not yet get, held until it is safe.
    private var pendingPrune: ModelContext?
    private var prunedThisLaunch = false

    var isMaterialising: Bool { materialiseTask != nil }

    // MARK: - Starting

    /// Called once from `MainAppView.setup()`, after the store is settled.
    func start(container: ModelContainer, imageDirectory: URL? = nil) {
        guard self.container == nil else { return }
        self.container = container
        self.imageDirectory = imageDirectory ?? ImageManager.shared.imageDirectory
        observe()
        materialise(reason: "launch")
        startBackfill(after: Self.backfillDelay)
    }

    private func observe() {
        let center = NotificationCenter.default
        // Posted on whatever queue the store used. Hop, then gather.
        tokens.append(center.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { _ in
            Task { @MainActor in PhotoSync.shared.remoteChange() }
        })
        tokens.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                         object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PhotoSync.shared.materialise(reason: "foreground") }
        })
    }

    private func remoteChange() {
        guard container != nil else { return }
        remoteChangeTask?.cancel()
        remoteChangeTask = Task { @MainActor in
            try? await Task.sleep(for: Self.remoteChangeSettle)
            guard !Task.isCancelled else { return }
            self.materialise(reason: "remote change")
        }
    }

    // MARK: - What StoreSyncStatus hears

    /// An import from iCloud finished. Copies may have arrived.
    func storeImported() {
        defaults.set(true, forKey: Self.hasImportedKey)
        materialise(reason: "import")
    }

    /// An export to iCloud finished. The one place the quota flag changes.
    func exportFinished(succeeded: Bool, quotaExceeded: Bool) {
        if succeeded {
            guard isPausedForQuota else { return }
            defaults.set(false, forKey: Self.pausedForQuotaKey)
            logger.log("iCloud has room again; the photo backfill resumes")
            if !backfillFinished { startBackfill(after: Self.batchPause) }
        } else if quotaExceeded, !isPausedForQuota {
            defaults.set(true, forKey: Self.pausedForQuotaKey)
            logger.log("iCloud is full; the photo backfill pauses")
        }
    }

    // MARK: - Materialising

    /// Writes out any copy whose photograph is not on disk. A pass already
    /// running is asked to go round once more rather than being doubled.
    func materialise(reason: String) {
        guard let container, let imageDirectory else { return }
        if materialiseTask != nil {
            materialiseAgain = true
            return
        }
        materialiseTask = Task { @MainActor in
            repeat {
                self.materialiseAgain = false
                // Reset cancels this task; the flag carries that into the
                // detached pass, which stops at its next chunk.
                let stop = OSAllocatedUnfairLock(initialState: false)
                let result = await withTaskCancellationHandler {
                    await Task.detached(priority: .utility) {
                        WinPhotoStore.materialise(container: container, imageDirectory: imageDirectory,
                                                  isCancelled: { stop.withLock { $0 } })
                    }.value
                } onCancel: {
                    stop.withLock { $0 = true }
                }
                // Each file that appeared, announced, so a block that drew its
                // colour while the picture was missing asks again.
                for name in result.written { ThumbnailStore.shared.fileArrived(name) }
                if !result.written.isEmpty || !result.failed.isEmpty || result.unreadable {
                    logger.log("materialised \(result.written.count, privacy: .public) photographs (\(reason, privacy: .public)), \(result.failed.count, privacy: .public) failed")
                }
                #if DEBUG
                NSLog("[strata-photosync] materialise (\(reason)): written=\(result.written.count) present=\(result.present) failed=\(result.failed.count) unreadable=\(result.unreadable)")
                #endif
            } while self.materialiseAgain && !Task.isCancelled
            self.materialiseTask = nil
            self.runPendingPrune()
        }
    }

    // MARK: - The backfill

    /// Asks for one more backfill pass, for a restore that has just put
    /// photographs on disk and pointed wins at them. Nothing when the app has
    /// not started syncing photographs, which is every test.
    func backfillSoon() {
        guard container != nil else { return }
        backfillFinished = false
        startBackfill(after: Self.batchPause)
    }

    private func startBackfill(after delay: Duration) {
        guard let container, let imageDirectory, backfillTask == nil else { return }
        backfillTask = Task { @MainActor in
            defer { self.backfillTask = nil }
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, !self.isPausedForQuota else { return }
            let report = await WinPhotoStore.backfill(
                context: container.mainContext, imageDirectory: imageDirectory,
                proceed: { await self.mayContinueBackfill() })
            if !report.stoppedEarly { self.backfillFinished = true }
            if report.created > 0 || report.stoppedEarly {
                logger.log("photo backfill: created \(report.created, privacy: .public), missing \(report.missingFile, privacy: .public), stopped early \(report.stoppedEarly, privacy: .public)")
            }
            #if DEBUG
            NSLog("[strata-photosync] backfill: created=\(report.created) had=\(report.alreadyHad) missing=\(report.missingFile) unreadable=\(report.unreadable) stoppedEarly=\(report.stoppedEarly)")
            #endif
        }
    }

    /// Between batches: a pause, then wait out anything a person is doing.
    /// The same signals the derivative migration yields to (a picture being
    /// read for the screen, Low Power Mode, heat, the app in the background).
    /// No when iCloud is full or the pass was cancelled.
    private func mayContinueBackfill() async -> Bool {
        try? await Task.sleep(for: Self.batchPause)
        while !Task.isCancelled, ImageManager.shared.migrationPauseReason() != nil {
            try? await Task.sleep(for: .seconds(2))
        }
        return !Task.isCancelled && !isPausedForQuota
    }

    // MARK: - The orphan sweep

    /// Whether `ImageManager.pruneOrphans` may run now.
    ///
    /// **`docs/research/icloud-backup.md` section 5.5.** The sweep deletes any
    /// photograph no row names. Under sync that reading has a window in which
    /// it is false for photographs that are perfectly fine: a copy written out
    /// moments ago whose row the sweep's fetch did not see, or a phone whose
    /// rows have not finished arriving. So:
    ///
    /// - never while a materialise pass is writing files, and
    /// - on a store that mirrors, not until this install has finished at least
    ///   one import from iCloud, unless there is no iCloud account to import
    ///   from (signed out, or restricted), in which case nothing can arrive.
    ///
    /// The names it is handed include every copy's name as well as every
    /// win's (`WinPhotoStore.referencedNames`), which covers a copy that
    /// arrived before its win.
    static func pruneAllowed(mirrored: Bool, account: StoreSyncStatus.Account,
                              hasEverImported: Bool, materialising: Bool) -> Bool {
        guard !materialising else { return false }
        guard mirrored else { return true }
        switch account {
        case .signedOut, .restricted: return true
        default: return hasEverImported
        }
    }

    /// Runs the launch's orphan sweep now if it is safe, otherwise as soon as
    /// it is (after a materialise pass, which every import and foreground
    /// starts). Once a launch, as before.
    func pruneWhenSafe(context: ModelContext) {
        guard !prunedThisLaunch else { return }
        pendingPrune = context
        runPendingPrune()
    }

    private func runPendingPrune() {
        guard let context = pendingPrune, !prunedThisLaunch else { return }
        let status = StoreSyncStatus.shared
        guard Self.pruneAllowed(mirrored: status.plan.isMirrored, account: status.account,
                                hasEverImported: defaults.bool(forKey: Self.hasImportedKey),
                                materialising: isMaterialising) else {
            #if DEBUG
            NSLog("[strata-photosync] orphan sweep held: \(status.summary) materialising=\(isMaterialising)")
            #endif
            return
        }
        pendingPrune = nil
        prunedThisLaunch = true
        let referenced: Set<String>
        do {
            referenced = try WinPhotoStore.referencedNames(context: context)
        } catch {
            // A fetch that threw tells us nothing about what is referenced,
            // and acting on nothing here deletes everything.
            NSLog("[strata] orphan sweep skipped: \(error)")
            return
        }
        let removed = ImageManager.shared.pruneOrphans(referenced: referenced)
        if removed > 0 {
            NSLog("[strata] orphan sweep removed \(removed) unreferenced photographs")
        }
    }

    // MARK: - Reset

    /// Reset All Data: stop writing photographs out and making copies, now.
    /// A pass still running would write files for rows that have just gone.
    func stopForReset() {
        materialiseTask?.cancel()
        materialiseAgain = false
        backfillTask?.cancel()
        remoteChangeTask?.cancel()
        backfillFinished = true
    }
}
