import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "ModelContainer")

/// How the store opened, and whether the app is allowed to behave as though it
/// is saving anything.
///
/// **This type exists because a boolean could not say the difference that
/// matters.** The old flag was `isUsingInMemoryFallback`, and the app read it,
/// put up an alert, and then carried on drawing a tower and accepting wins
/// into a store that evaporates on quit. There are three outcomes, not two: it
/// opened, it opened on the second try, or it did not open and the person has
/// to be told before they log anything.
enum StoreOpening: Equatable, Sendable {
    /// The store on disk, first attempt. The ordinary case.
    case onDisk
    /// The store on disk, after the first attempt failed. Everything works
    /// from here on; the reason is carried so the log and the probe can say
    /// what happened.
    case recovered(reason: String)
    /// Nothing opened on disk. The container the app is holding saves nothing,
    /// so the app must say so rather than draw an empty tower.
    case unavailable(reason: String)

    /// Whether what a person does next is written down.
    var savesToDisk: Bool {
        switch self {
        case .onDisk, .recovered: return true
        case .unavailable: return false
        }
    }

    /// For the log and `-strataReportStore`.
    var summary: String {
        switch self {
        case .onDisk: return "onDisk"
        case .recovered(let reason): return "recovered(\(reason))"
        case .unavailable(let reason): return "unavailable(\(reason))"
        }
    }
}

/// The three rungs of the ladder, named so that a log line and a forced
/// failure can both say which one they mean.
enum StoreRung: String, CaseIterable, Sendable {
    /// The store the app actually uses. CloudKit is configured here when it is
    /// turned on, which is what makes the recovery rung load bearing.
    case primary
    /// The same schema and the same file, local and on disk, never asking for
    /// sync. The rung that catches a schema the mirroring container refuses.
    case recovery
    /// Not a store. Something for SwiftUI to hold while the app tells the
    /// truth on screen.
    case holding
}

enum StoreOpenError: Error, CustomStringConvertible {
    case forcedByHarness(StoreRung)

    var description: String {
        switch self {
        case .forcedByHarness(let rung): return "forced failure on the \(rung.rawValue) rung"
        }
    }
}

/// Whether the store the app ended up holding is mirrored to iCloud.
///
/// **Derived from the rung, never stored beside it.** A second variable saying
/// "sync is on" is a variable that can disagree with the container that is
/// actually open, and the disagreement would show up as an app claiming to
/// back a person's wins up while it did not. Only the primary rung asks for
/// CloudKit, so the rung IS the answer.
///
/// Note what this does NOT say: that sync is working. The store opening
/// mirrored means the mirroring container loaded, which it does happily with
/// no iCloud account, no network and a full iCloud. `StoreSyncStatus` is the
/// thing that knows whether anything is moving.
enum StoreSyncPlan: Equatable, Sendable {
    /// Mirrored to the private database of the named container.
    case mirrored(container: String)
    /// On disk and local. Everything a person does is saved; nothing leaves
    /// the phone. The reason is the recovery rung's reason, which is the
    /// primary rung's error.
    case localOnly(reason: String)

    var isMirrored: Bool {
        if case .mirrored = self { return true }
        return false
    }

    var summary: String {
        switch self {
        case .mirrored(let container): return "mirrored(\(container))"
        case .localOnly(let reason): return "localOnly(\(reason))"
        }
    }
}

extension StoreOpening {
    /// Which of the two the app is actually doing.
    var syncPlan: StoreSyncPlan {
        switch self {
        case .onDisk:
            return .mirrored(container: SharedModelContainer.cloudKitContainerID)
        case .recovered(let reason):
            return .localOnly(reason: reason)
        case .unavailable(let reason):
            return .localOnly(reason: reason)
        }
    }
}

enum SharedModelContainer {

    /// Every model the store holds, in one place so the ladder's rungs cannot
    /// drift apart from each other.
    static var schema: Schema {
        Schema([Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanFolder.self, PlanItem.self])
    }

    /// The iCloud container whose PRIVATE database the store mirrors to.
    ///
    /// **Named here rather than left to `.automatic`, for two reasons.**
    /// `.automatic` reads the entitlement and takes the first container it
    /// finds, which means that the moment the entitlement exists every
    /// configuration in this file asks for CloudKit, including the recovery
    /// rung whose whole job is not to. And a container written down can be
    /// compared: this string, `Strata.entitlements` and
    /// `StrataDebug.entitlements` must all say the same word.
    /// `StoreCloudKitSchemaTests` pins that the primary rung asks for THIS
    /// string and that no other rung asks for anything; it cannot read the
    /// entitlement files, so the three staying in step is still checked by
    /// eye, and a mismatch shows up as the store opening on the recovery rung
    /// with `[strata-store] sync: localOnly(...)` in the log.
    ///
    /// The private database, not shared and not public: the person's Apple ID
    /// is the login, their wins are theirs, and nothing here is meant to be
    /// readable by anybody else.
    static let cloudKitContainerID = "iCloud.JaydenBetts.Strata"

    /// How the store opened. Read under `lock`, like the container itself.
    static var opening: StoreOpening {
        lock.lock(); defer { lock.unlock() }
        return _opening
    }
    private static var _opening: StoreOpening = .onDisk

    /// True only in the state where nothing a person does is written down.
    /// `DebugHarness.runStoreProbe` reads it and the name is kept for that.
    static var isUsingInMemoryFallback: Bool { !opening.savesToDisk }

    private static var made: ModelContainer?

    /// **Once only, by a lock, not by luck.** This was a `static let`, which
    /// Swift initialises exactly once. It became a cached computed property so
    /// "Try Again" could replace a failed container, and a cache checked and
    /// filled without a lock is two containers over one store file if two
    /// callers ever arrive together. The enum is main-actor isolated today, so
    /// that cannot happen yet; the lock makes it not depend on that.
    private static let lock = NSRecursiveLock()

    static var shared: ModelContainer {
        lock.lock(); defer { lock.unlock() }
        if let made { return made }
        let result = climb(open: realOpen)
        made = result.container
        _opening = result.opening
        if result.opening.savesToDisk { StoreStamp.observe() }
        logger.log("store opened: \(result.opening.summary, privacy: .private)")
        logger.log("store sync: \(result.opening.syncPlan.summary, privacy: .private)")
        #if DEBUG
        NSLog("[strata-store] opened: \(result.opening.summary)")
        NSLog("[strata-store] sync: \(result.opening.syncPlan.summary)")
        #endif
        // Started from here because this is the moment sync begins: the
        // mirroring container is now loaded and about to talk to iCloud on its
        // own. Watching starts even when the plan is local, so that the log
        // says which of the two it is rather than going quiet either way.
        StoreSyncStatus.shared.begin(plan: result.opening.syncPlan)
        return result.container
    }

    /// Walk the ladder again, for the "Try Again" button on the blocking
    /// screen.
    ///
    /// **It refuses when the store is already open**, because re-opening a
    /// working container would drop whatever the person is holding unsaved,
    /// for no reason at all. There is exactly one state this is for.
    @discardableResult
    static func retry() -> StoreOpening {
        lock.lock(); defer { lock.unlock() }
        guard !_opening.savesToDisk else { return _opening }
        made = nil
        _ = shared
        return _opening
    }

    // MARK: - The ladder

    /// Try each rung in turn, and never silently discard a person's data.
    ///
    /// **The old code had two rungs and the second one was a lie.** When the
    /// container failed it returned an IN-MEMORY store, set a flag, and let
    /// the app run. Every win logged from then on was thrown away on quit, and
    /// what the person saw was an app that worked. Adding CloudKit adds a
    /// whole new class of init failure (schema validation), so this has to be
    /// fixed before sync is switched on, not after.
    ///
    /// 1. **primary** — the store the app uses, mirrored to the private
    ///    CloudKit database. This is where `cloudKitDatabase:` lives and the
    ///    only place it does.
    /// 2. **recovery** — the same schema and the same file on disk, local,
    ///    mirroring explicitly refused. The person keeps their app and keeps
    ///    saving; only sync is off. **This is the rung that answers "the
    ///    container does not exist yet".** Automatic signing has not made
    ///    `iCloud.JaydenBetts.Strata`, or the entitlement is missing from this
    ///    build, or the mirroring validator refuses the schema: all three are
    ///    an error thrown out of `ModelContainer.init`, and all three land
    ///    here, with the store opening in place and every win still readable.
    ///
    ///    Being signed out of iCloud, having no network and having a full
    ///    iCloud are NOT this rung. The mirroring container loads happily in
    ///    all three and reports the trouble asynchronously, which is the
    ///    behaviour to want: the app opens, saves locally, and exports when it
    ///    can. `StoreSyncStatus` is what notices, and it never blocks
    ///    anything.
    /// 3. **holding** — nothing opened. The app puts `StoreUnavailableView` on
    ///    screen and does not pretend. The container returned here exists only
    ///    because `.modelContainer(_:)` needs one; nothing that reads or
    ///    writes a win is ever put in front of it.
    ///
    /// `open` is a parameter so a test can force a rung to fail without launch
    /// arguments. The holding rung is **not** routed through it: a test that
    /// forced all three would be asking for a crash, and the point of this
    /// function is that the third outcome is a screen, not a crash.
    static func climb(
        open: (StoreRung, ModelConfiguration) throws -> ModelContainer
    ) -> (container: ModelContainer, opening: StoreOpening) {
        let schema = self.schema

        do {
            return (try open(.primary, configuration(.primary, schema)), .onDisk)
        } catch {
            // `.private`, and the NSLog only in DEBUG: an error from the store
            // carries its file path, which has no business in a release
            // console.
            logger.critical("the store did not open on the primary rung: \(String(describing: error), privacy: .private)")
            #if DEBUG
            NSLog("[strata-store] rung primary failed: \(error)")
            #endif

            do {
                let container = try open(.recovery, configuration(.recovery, schema))
                let reason = shortReason(error)
                logger.warning("the store opened local and on disk after the primary rung failed: \(reason, privacy: .private)")
                #if DEBUG
                NSLog("[strata-store] rung recovery opened after: \(reason)")
                #endif
                return (container, .recovered(reason: reason))
            } catch {
                logger.critical("the store did not open on the recovery rung either: \(String(describing: error), privacy: .private)")
                #if DEBUG
                NSLog("[strata-store] rung recovery failed: \(error)")
                #endif
                return (holdingContainer(schema), .unavailable(reason: shortReason(error)))
            }
        }
    }

    /// The configuration for a rung.
    ///
    /// **Both disk rungs point at the same file, deliberately.** A "recovery"
    /// that moved or rebuilt the store would be the data loss this whole
    /// change exists to prevent. The one thing that differs between them is
    /// whether sync is asked for, and that is now the difference that matters:
    /// `.primary` mirrors to CloudKit, `.recovery` is the same file with
    /// mirroring explicitly refused.
    ///
    /// **`.none` on the recovery and holding rungs is load bearing, not
    /// tidiness.** `ModelConfiguration`'s default is `cloudKitDatabase:
    /// .automatic`, which reads the entitlement and takes the container it
    /// finds there. The entitlement now has one. So left at the default, the
    /// rung that exists to open the store WITHOUT sync would ask for sync
    /// straight after the primary rung failed asking for sync, fail for the
    /// same reason, and drop the app onto the blocking screen. The same goes
    /// for the holding container, which must not touch the network at all.
    ///
    /// `groupContainer` is left at `.automatic`, which is how the store came to
    /// live in the App Group, and it stays there. The widget does not read it
    /// (`Shared/WidgetSnapshot.swift` says why: it reads a JSON snapshot the
    /// app writes), so moving it now would be a migration of somebody's real
    /// wins and photographs bought for nothing. An App Group store mirrors to
    /// CloudKit exactly like any other.
    private static func configuration(_ rung: StoreRung, _ schema: Schema) -> ModelConfiguration {
        switch rung {
        case .primary:
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                      cloudKitDatabase: .private(cloudKitContainerID))
        case .recovery:
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                      cloudKitDatabase: .none)
        case .holding:
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                      cloudKitDatabase: .none)
        }
    }

    /// Something for SwiftUI to hold while the app says it could not open the
    /// store. Never shown anything that reads or writes a win.
    ///
    /// The app's own schema first, so previews and the harness behave. If the
    /// schema itself is what is broken, an empty one, which cannot be.
    private static func holdingContainer(_ schema: Schema) -> ModelContainer {
        if let container = try? ModelContainer(for: schema, configurations: [configuration(.holding, schema)]) {
            return container
        }
        let empty = Schema([])
        // `.none` here too. This container exists so that SwiftUI has something
        // to hold on the screen that says the store did not open; asking iCloud
        // for anything from it would be the app going to the network on the one
        // path where it has already failed.
        if let container = try? ModelContainer(
            for: empty,
            configurations: [ModelConfiguration(schema: empty, isStoredInMemoryOnly: true,
                                                cloudKitDatabase: .none)]) {
            return container
        }
        fatalError("SwiftData could not make an empty in-memory container")
    }

    private static func realOpen(_ rung: StoreRung, _ config: ModelConfiguration) throws -> ModelContainer {
        #if DEBUG
        if DebugHarness.forcesStoreFailure(rung) { throw StoreOpenError.forcedByHarness(rung) }
        #endif
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// One line, so a log and a probe stay readable. The whole error goes to
    /// the logger above; this is the part a person reads at a glance.
    private static func shortReason(_ error: Error) -> String {
        let text = String(describing: error).replacingOccurrences(of: "\n", with: " ")
        return text.count > 160 ? String(text.prefix(160)) + "..." : text
    }
}

/// The words the app uses when the store did not open, in one place, so the
/// blocking screen and Siri cannot say different things.
enum StoreUnavailableCopy {
    static let title = "Strata could not open your wins"
    static let body = "Nothing has been deleted. Your wins are on this phone and Strata cannot read them right now, so it is showing you this instead of an empty tower."
    static let stillFailing = "Still not opening. Close Strata from the app switcher, then open it again."
    /// What Siri and Shortcuts say. The screen's title and its first sentence,
    /// because a spoken answer has no room for the rest.
    static let spoken = "Strata could not open your wins. Nothing has been deleted."
}

/// Thrown by every App Intent that touches the store when the store did not
/// open.
///
/// **Siri never sees the blocking screen.** `LogWinIntent`,
/// `ShowTodaysWinsIntent` and `HabitEntityQuery` all run with
/// `openAppWhenRun = false`, so without this Siri would answer "Logged. That's
/// 1 today." into a container that evaporates, or "No wins yet today." over a
/// real store full of them.
struct StoreUnavailableIntentError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: StoreUnavailableCopy.spoken)
    }

    /// Opens the store if nothing has yet, and throws unless it saves to disk.
    /// Call before touching the `@Dependency` container.
    @MainActor
    static func check() throws {
        _ = SharedModelContainer.shared
        guard SharedModelContainer.opening.savesToDisk else { throw StoreUnavailableIntentError() }
    }
}
