import Foundation
import CloudKit
import CoreData
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "StoreSync")

/// What iCloud sync is actually DOING, as opposed to whether it was asked for.
///
/// **The two are different and the difference is the whole reason this file
/// exists.** `SharedModelContainer.opening.syncPlan` says the mirroring
/// container loaded. It loads when the person is signed out of iCloud, when
/// there is no network, and when their iCloud is full: the store opens, every
/// win saves to disk, and the failure arrives later and asynchronously on
/// CloudKit's own schedule. So "the store opened mirrored" is not a promise
/// that anything has left the phone, and an app that showed it as one would be
/// telling the same lie that lost the owner his data in the first place: he
/// reinstalled believing his wins were in iCloud, and there was no CloudKit in
/// this app at all.
///
/// Everything here is REPORTING. Nothing in this file blocks a launch, fails a
/// save, throws into a view, or gates a feature. The rule from
/// `SharedModelContainer`'s ladder carries straight through: an app that will
/// not open because sync failed is far worse than an app that does not sync.
@MainActor
@Observable
final class StoreSyncStatus {

    static let shared = StoreSyncStatus()

    /// Whether the store the app is holding asked for CloudKit at all.
    private(set) var plan: StoreSyncPlan = .localOnly(reason: "the store has not opened yet")

    /// The iCloud account, as CloudKit reports it.
    ///
    /// A separate fact from `plan`: a mirrored store with no account is the
    /// ordinary state of a phone that has been signed out, and it is the one
    /// the person can do something about.
    enum Account: Equatable, Sendable {
        /// Not asked yet, or CloudKit would not say.
        case unknown
        /// Signed in. Sync can happen.
        case signedIn
        /// Signed out. Everything still saves to this phone.
        case signedOut
        /// Restricted by parental controls or a device policy.
        case restricted
        /// iCloud said "ask again later", which is a real answer and not an
        /// error: it happens on a phone that has just been restored.
        case temporarilyUnavailable
        /// CloudKit refused the question, which is what a missing entitlement
        /// looks like from here.
        case refused(reason: String)

        var summary: String {
            switch self {
            case .unknown: return "unknown"
            case .signedIn: return "signedIn"
            case .signedOut: return "signedOut"
            case .restricted: return "restricted"
            case .temporarilyUnavailable: return "temporarilyUnavailable"
            case .refused(let reason): return "refused(\(reason))"
            }
        }
    }

    private(set) var account: Account = .unknown

    /// One of CloudKit's own events, kept so the log and any screen that ever
    /// reports sync read the same thing.
    struct Moment: Equatable, Sendable {
        var at: Date
        var succeeded: Bool
        /// Nil when it succeeded. The short form, because a CloudKit error's
        /// full text runs to hundreds of characters of record names.
        var failure: String?
    }

    /// The last of each kind of event CloudKit reported. Setup happens once per
    /// launch; import brings other devices' wins in; export sends this
    /// device's out.
    private(set) var lastSetup: Moment?
    private(set) var lastImport: Moment?
    private(set) var lastExport: Moment?

    /// True once an export has succeeded this launch, which is the only
    /// evidence in the app that a win has actually reached iCloud.
    var hasExported: Bool { lastExport?.succeeded == true }
    /// True once an import has succeeded, which is the evidence that this
    /// device has heard from the other one.
    var hasImported: Bool { lastImport?.succeeded == true }

    /// One line, for the log and for `-strataReportStore`-shaped debugging.
    var summary: String {
        var parts = ["plan=\(plan.summary)", "account=\(account.summary)"]
        for (name, moment) in [("setup", lastSetup), ("import", lastImport), ("export", lastExport)] {
            guard let moment else { continue }
            parts.append("\(name)=\(moment.succeeded ? "ok" : "failed(\(moment.failure ?? "no reason"))")")
        }
        return parts.joined(separator: " ")
    }

    private var token: NSObjectProtocol?

    // MARK: - Starting

    /// Called once, by `SharedModelContainer.shared`, the moment the store has
    /// opened.
    ///
    /// **Idempotent, because the ladder can be climbed twice.** "Try Again" on
    /// the blocking screen calls `SharedModelContainer.retry()`, which walks
    /// the ladder again; a second observer on the same notification would
    /// double every log line and run the dedupe twice for one import.
    func begin(plan: StoreSyncPlan) {
        self.plan = plan
        logger.log("sync plan: \(plan.summary, privacy: .private)")
        #if DEBUG
        NSLog("[strata-sync] plan: \(plan.summary)")
        #endif

        guard token == nil else { return }

        // Watched even when the plan is local. If a build ever ends up on the
        // recovery rung and CloudKit events arrive anyway, that is a
        // contradiction worth seeing in the log rather than a silence.
        token = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: nil
        ) { note in
            // The notification can arrive on CloudKit's own queue. Everything
            // this class holds is main-actor state, and the dedupe writes to
            // the main context, so hop rather than assume.
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let moment = Moment(at: event.endDate ?? event.startDate,
                                succeeded: event.succeeded,
                                failure: event.error.map(Self.shortReason))
            let type = event.type
            Task { @MainActor in StoreSyncStatus.shared.record(type, moment, ended: event.endDate != nil) }
        }

        guard plan.isMirrored else { return }
        // Asked for, never waited on. The answer takes a round trip to Apple
        // and the app is mid launch.
        Task { await self.readAccount() }
    }

    // MARK: - What CloudKit said

    private func record(_ type: NSPersistentCloudKitContainer.EventType,
                        _ moment: Moment, ended: Bool) {
        // An event is posted when it starts and again when it finishes. Only
        // the finished one carries a verdict; recording the start would report
        // every import as having failed for as long as it was running.
        guard ended else { return }

        switch type {
        case .setup: lastSetup = moment
        case .import: lastImport = moment
        case .export: lastExport = moment
        @unknown default: break
        }

        let name = Self.name(of: type)
        if moment.succeeded {
            logger.log("\(name, privacy: .public) finished")
        } else {
            // `.private`: a CloudKit error names record ids and zone names.
            logger.warning("\(name, privacy: .public) failed: \(moment.failure ?? "no reason", privacy: .private)")
        }
        #if DEBUG
        NSLog("[strata-sync] \(name) \(moment.succeeded ? "ok" : "failed: \(moment.failure ?? "no reason")")")
        #endif

        // **The one thing this file does besides report.** A fresh install on a
        // second device makes its own default tower before the first import
        // lands, so after the import there are two. See `StoreDedupe`.
        if type == .import, moment.succeeded {
            StoreDedupe.mergeDuplicateTowers(in: SharedModelContainer.shared.mainContext)
        }
    }

    private static func name(of type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: return "setup"
        case .import: return "import"
        case .export: return "export"
        @unknown default: return "unknown event"
        }
    }

    private static func shortReason(_ error: Error) -> String {
        let text = String(describing: error).replacingOccurrences(of: "\n", with: " ")
        return text.count > 160 ? String(text.prefix(160)) + "..." : text
    }

    // MARK: - The account

    /// Reads the iCloud account status, and keeps reading it when it changes.
    ///
    /// Signing in or out while the app is running posts
    /// `CKAccountChangedNotification`, and a person who has just been told
    /// "sign in to sync" is about to do exactly that, so the answer has to be
    /// able to change without a relaunch.
    private func readAccount() async {
        await refreshAccount()
        // The stream ends when the app does. `for await` on a notification
        // sequence holds no strong reference to anything but this object, which
        // is a singleton that lives as long as the process.
        let changes = NotificationCenter.default.notifications(named: .CKAccountChanged)
        for await _ in changes {
            await refreshAccount()
        }
    }

    private func refreshAccount() async {
        let container = CKContainer(identifier: SharedModelContainer.cloudKitContainerID)
        let answer: Account
        do {
            switch try await container.accountStatus() {
            case .available: answer = .signedIn
            case .noAccount: answer = .signedOut
            case .restricted: answer = .restricted
            case .temporarilyUnavailable: answer = .temporarilyUnavailable
            case .couldNotDetermine: answer = .unknown
            @unknown default: answer = .unknown
            }
        } catch {
            // Asking CloudKit anything without the entitlement fails here
            // rather than crashing, and that is worth saying out loud: it is
            // what a build signed with the old profile looks like.
            answer = .refused(reason: Self.shortReason(error))
        }
        guard answer != account else { return }
        account = answer
        logger.log("icloud account: \(answer.summary, privacy: .public)")
        #if DEBUG
        NSLog("[strata-sync] account: \(answer.summary)")
        #endif
    }
}
