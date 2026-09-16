import Testing
import Foundation
import SwiftData
@testable import Strata

/// **The fields added now so that a social version later is an addition, not
/// a migration.** Once the CloudKit schema is live it can only gain fields,
/// never rename or remove them, so `createdAt`, `updatedAt` and
/// `timeZoneIdentifier` went in with the CloudKit defaults. None of them is
/// used by a feature yet; these pin that they carry honest values.
@MainActor
@Suite("SocialFields", .serialized)
struct SocialFieldsTests {

    private func context() throws -> ModelContext {
        StoreStamp.observe()
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func win(_ context: ModelContext) throws -> HabitLog {
        let habit = Habit(title: "Ran", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-09-01", completed: true)
        context.insert(log)
        try context.save()
        return log
    }

    @Test("an edit moves updatedAt, on the win and on its habit")
    func editStamps() throws {
        let context = try context()
        let log = try win(context)
        let old = Date(timeIntervalSinceReferenceDate: 600_000_000)
        try StoreStamp.withoutStamping {
            log.updatedAt = old
            log.habit?.updatedAt = old
            try context.save()
        }
        #expect(log.updatedAt == old)

        log.caption = "a caption"
        log.habit?.title = "Ran further"
        try context.save()

        #expect(log.updatedAt > old)
        #expect((log.habit?.updatedAt ?? old) > old)
    }

    /// A stamp that marked the row dirty again would make every autosave
    /// write, forever.
    @Test("a save with nothing in it leaves updatedAt and the context alone")
    func quietSaveDoesNotStamp() throws {
        let context = try context()
        let log = try win(context)
        let stamped = log.updatedAt
        #expect(context.hasChanges == false)
        try context.save()
        #expect(log.updatedAt == stamped)
        #expect(context.hasChanges == false)
    }

    @Test("a new win records the zone it was logged in")
    func newWinIsZoned() throws {
        let log = try win(try context())
        #expect(log.timeZoneIdentifier == TimeZone.current.identifier)
        #expect(!log.timeZoneIdentifier.isEmpty)
    }

    @Test("the backfill dates old wins from when they happened, once, and is not stamped over")
    func backfillIsHonestAndOnce() throws {
        let context = try context()
        let log = try win(context)
        let happened = Date(timeIntervalSinceReferenceDate: 650_000_000)
        try StoreStamp.withoutStamping {
            log.completedAt = happened
            log.timeZoneIdentifier = ""
            try context.save()
        }
        let defaults = try #require(UserDefaults(suiteName: "social-fields-\(UUID().uuidString)"))

        #expect(SocialFieldsBackfill.runIfNeeded(context: context, defaults: defaults) == 1)
        #expect(log.createdAt == happened)
        #expect(log.updatedAt == happened)
        // The zone of an old win was never recorded; a guess would be made up.
        #expect(log.timeZoneIdentifier.isEmpty)
        #expect(SocialFieldsBackfill.runIfNeeded(context: context, defaults: defaults) == nil)
    }

    @Test("the stored schedule default is the initialiser's: every day")
    func frequencyDefaultMatchesInitialiser() {
        let habit = Habit(title: "Ran", category: .health)
        #expect(habit.frequencyRawValues == DayCode.allCases.map(\.rawValue))
        #expect(habit.frequencyRawValues == ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"])
    }

    @Test("the profile id is made once and then stays")
    func profileIDIsStable() {
        #expect(ProfileStore.profileID == ProfileStore.profileID)
    }

    @Test("what Siri says when the store did not open is the screen's own sentence, with no long dash")
    func unavailableCopy() {
        #expect(StoreUnavailableCopy.spoken.hasPrefix(StoreUnavailableCopy.title))
        for text in [StoreUnavailableCopy.title, StoreUnavailableCopy.body,
                     StoreUnavailableCopy.stillFailing, StoreUnavailableCopy.spoken] {
            #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"))
        }
        let error = StoreUnavailableIntentError()
        #expect(String(localized: error.localizedStringResource) == StoreUnavailableCopy.spoken)
    }
}

/// A model that breaks CloudKit's rule on purpose, so the validator is proven
/// to run before anything is concluded from the app's schema passing it.
@Model
final class CloudKitRuleBreaker {
    var name: String
    init(name: String) { self.name = name }
}

/// **The CloudKit validator, run rather than asserted.** Opt-in
/// (`TEST_RUNNER_STRATA_CK_PROBE=1`), because it opens a CloudKit-mirrored
/// container in a test host with no iCloud entitlement, and what that does is
/// the question, not something the ordinary suite should depend on.
@MainActor
@Suite("CloudKitValidator", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["STRATA_CK_PROBE"] != nil))
struct CloudKitValidatorProbe {

    private func open(_ schema: Schema) -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ck-validate-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        do {
            let config = ModelConfiguration(schema: schema, url: url,
                                            cloudKitDatabase: .private("iCloud.JaydenBetts.Strata"))
            _ = try ModelContainer(for: schema, configurations: [config])
            return "OPENED"
        } catch {
            return "THREW: \(error)"
        }
    }

    @Test("probe: a schema that breaks the rule")
    func breaker() { NSLog("[ck-probe] breaker -> \(open(Schema([CloudKitRuleBreaker.self])))") }

    @Test("probe: the app's schema")
    func app() { NSLog("[ck-probe] app -> \(open(SharedModelContainer.schema))") }
}
