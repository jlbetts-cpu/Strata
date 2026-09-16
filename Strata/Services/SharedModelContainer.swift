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

enum SharedModelContainer {

    /// Every model the store holds, in one place so the ladder's rungs cannot
    /// drift apart from each other.
    static var schema: Schema {
        Schema([Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanFolder.self, PlanItem.self])
    }

    private(set) static var opening: StoreOpening = .onDisk

    /// True only in the state where nothing a person does is written down.
    /// `DebugHarness.runStoreProbe` reads it and the name is kept for that.
    static var isUsingInMemoryFallback: Bool { !opening.savesToDisk }

    private static var made: ModelContainer?

    static var shared: ModelContainer {
        if let made { return made }
        let result = climb(open: realOpen)
        made = result.container
        opening = result.opening
        logger.log("store opened: \(result.opening.summary, privacy: .public)")
        NSLog("[strata-store] opened: \(result.opening.summary)")
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
        guard !opening.savesToDisk else { return opening }
        made = nil
        _ = shared
        return opening
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
    /// 1. **primary** — the store the app uses. `cloudKitDatabase:` goes here
    ///    when sync is turned on, and not before.
    /// 2. **recovery** — the same schema and the same file on disk, local,
    ///    never asking for sync. The person keeps their app and keeps saving;
    ///    only sync is off. Until CloudKit is enabled this rung differs from
    ///    the first only in that it can never ask for it, which is exactly the
    ///    failure it is there to catch.
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
            logger.critical("the store did not open on the primary rung: \(String(describing: error), privacy: .public)")
            NSLog("[strata-store] rung primary failed: \(error)")

            do {
                let container = try open(.recovery, configuration(.recovery, schema))
                let reason = shortReason(error)
                logger.warning("the store opened local and on disk after the primary rung failed: \(reason, privacy: .public)")
                NSLog("[strata-store] rung recovery opened after: \(reason)")
                return (container, .recovered(reason: reason))
            } catch {
                logger.critical("the store did not open on the recovery rung either: \(String(describing: error), privacy: .public)")
                NSLog("[strata-store] rung recovery failed: \(error)")
                return (holdingContainer(schema), .unavailable(reason: shortReason(error)))
            }
        }
    }

    /// The configuration for a rung.
    ///
    /// **Both disk rungs point at the same file, deliberately.** A "recovery"
    /// that moved or rebuilt the store would be the data loss this whole
    /// change exists to prevent. The only thing that differs is whether sync
    /// is asked for, and today neither asks: CloudKit is turned on in a later
    /// phase, and when it is, that one line goes in the `.primary` branch here
    /// and nowhere else.
    ///
    /// The store also stays where it is rather than moving into the App Group.
    /// The widget does not read it (`Shared/WidgetSnapshot.swift` says why: it
    /// reads a JSON snapshot the app writes), so a relocation would be a
    /// migration of somebody's real wins and photographs bought for nothing.
    private static func configuration(_ rung: StoreRung, _ schema: Schema) -> ModelConfiguration {
        switch rung {
        case .primary, .recovery:
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        case .holding:
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        if let container = try? ModelContainer(
            for: empty, configurations: [ModelConfiguration(schema: empty, isStoredInMemoryOnly: true)]) {
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
