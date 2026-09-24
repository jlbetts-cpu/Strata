import Testing
import Foundation
import SwiftData
import CoreData
@testable import Strata

/// **The fields added now so that a social version later is an addition, not
/// a migration.** Once the CloudKit schema is live it can only gain fields,
/// never rename or remove them, so `createdAt`, `updatedAt` and
/// `timeZoneIdentifier` went in with the CloudKit defaults. None of them is
/// used by a feature yet; these pin that they carry honest values.
@MainActor
@Suite("SocialFields", .serialized)
struct SocialFieldsTests {

    /// `cloudKitDatabase: .none` on every container below, and it is not
    /// decoration. The app carries the iCloud entitlement now, and
    /// `ModelConfiguration` defaults to `.automatic`, which reads the
    /// entitlement: left at the default these tests each stand up a real
    /// mirroring store inside the test host. Measured, they did, and the run
    /// filled with `CKAccountStatusNoAccount` recoveries and one real error
    /// ("There is another instance of this persistent store actively syncing
    /// with CloudKit in this process"). These tests are about the schema and the
    /// stamp, not about iCloud.
    private func context() throws -> ModelContext {
        StoreStamp.observe()
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none))
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
        // The stamp must be part of the save, not a change left pending after
        // it. Pending, autosave would save again, stamp again, forever, and
        // `updatedAt` would record the last autosave rather than the edit.
        #expect(context.hasChanges == false)
    }

    /// **Proved from disk, not from the object in memory.** A stamp written
    /// during `willSave` could sit on the object and never reach the store; a
    /// second container over the same file is the only reader that cannot be
    /// fooled by that.
    @Test("the stamped updatedAt is what a second container reads off disk")
    func stampReachesDisk() throws {
        StoreStamp.observe()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stamp-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        func open() throws -> ModelContainer {
            try ModelContainer(for: SharedModelContainer.schema,
                               configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                                                  url: url, cloudKitDatabase: .none))
        }
        let old = Date(timeIntervalSinceReferenceDate: 600_000_000)
        var logID = UUID()
        var stamped = old
        do {
            let context = ModelContext(try open())
            let log = try win(context)
            logID = log.id
            try StoreStamp.withoutStamping {
                log.updatedAt = old
                try context.save()
            }
            log.caption = "edited"
            try context.save()
            stamped = log.updatedAt
            #expect(stamped > old)
            #expect(context.hasChanges == false)
        }

        let reader = ModelContext(try open())
        let id = logID
        let onDisk = try #require(try reader.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.id == id })).first)
        #expect(onDisk.caption == "edited")
        #expect(onDisk.updatedAt == stamped)
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

    /// A file-backed store with one old win (no zone, as every win before
    /// this change has) and returns its url.
    private func storeWithAnOldWin(happened: Date) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("added-\(UUID().uuidString).store")
        let context = ModelContext(try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               url: url, cloudKitDatabase: .none)))
        let tower = Tower(name: "Home")
        context.insert(tower)
        let habit = Habit(title: "Ran", category: .health)
        habit.tower = tower
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2025-01-01", completed: true)
        context.insert(log)
        try StoreStamp.withoutStamping {
            try context.save()
            // What a migrated row looks like: no zone, and dates that are the
            // moment of migration rather than anything true.
            log.timeZoneIdentifier = ""
            log.completedAt = happened
            habit.createdAt = happened
            tower.createdAt = happened
            try context.save()
        }
        return url
    }

    private func remove(_ url: URL) {
        for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
    }

    private func open(_ url: URL) throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               url: url, cloudKitDatabase: .none)))
    }

    @Test("the added fields read back off disk identically, and hold backfilled dates, not launch time")
    func addedFieldsSurviveAReopen() throws {
        StoreStamp.observe()
        let happened = Date(timeIntervalSinceReferenceDate: 650_000_000)
        let url = try storeWithAnOldWin(happened: happened)
        defer { remove(url) }
        let defaults = try #require(UserDefaults(suiteName: "added-\(UUID().uuidString)"))

        let written: StoreAddedFieldsCheck.Reading
        do {
            let context = try open(url)
            #expect(SocialFieldsBackfill.runIfNeeded(context: context, defaults: defaults) == 1)
            written = StoreAddedFieldsCheck.read(context: context)
        }

        let reader = try open(url)
        let reread = StoreAddedFieldsCheck.read(context: reader)
        #expect(written.isComplete && reread.isComplete)
        #expect(reread == written)
        #expect(reread.createdFromCompleted == 1)
        #expect(reread.zoned == 0)

        // From disk: the habit and tower carry the backfilled dates. Launch
        // time would be years after `happened`.
        let habit = try #require(try reader.fetch(FetchDescriptor<Habit>()).first)
        let tower = try #require(try reader.fetch(FetchDescriptor<Tower>()).first)
        #expect(habit.updatedAt == happened)
        #expect(tower.updatedAt == happened)
    }

    @Test("the added-fields digest notices one changed value")
    func addedDigestCanFail() throws {
        StoreStamp.observe()
        let url = try storeWithAnOldWin(happened: Date(timeIntervalSinceReferenceDate: 650_000_000))
        defer { remove(url) }
        let context = try open(url)
        let before = StoreAddedFieldsCheck.read(context: context)
        let log = try #require(try context.fetch(FetchDescriptor<HabitLog>()).first)
        try StoreStamp.withoutStamping {
            log.timeZoneIdentifier = "Europe/London"
            try context.save()
        }
        #expect(StoreAddedFieldsCheck.read(context: context).digest != before.digest)
    }

    /// The backfill used to rewrite every log. If its first run failed and a
    /// back-dated win was logged before the next launch, that win's real
    /// `createdAt` would have been replaced.
    @Test("the backfill never touches a win logged by this build")
    func backfillLeavesNewWinsAlone() throws {
        let context = try context()
        let log = try win(context)
        let logged = log.createdAt
        try StoreStamp.withoutStamping {
            log.completedAt = Date(timeIntervalSinceReferenceDate: 500_000_000)
            try context.save()
        }
        let defaults = try #require(UserDefaults(suiteName: "new-win-\(UUID().uuidString)"))
        #expect(SocialFieldsBackfill.runIfNeeded(context: context, defaults: defaults) == 0)
        #expect(log.createdAt == logged)
    }

    @Test("reading the profile id for a report never creates one")
    func storedProfileIDDoesNotWrite() throws {
        // Its own suite: the test host's real id is never removed or rewritten.
        let suite = "profile-id-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(ProfileStore.storedProfileID(in: defaults) == nil)
        #expect(defaults.string(forKey: ProfileStore.profileIDKey) == nil)

        let made = ProfileStore.profileID(in: defaults)
        #expect(ProfileStore.storedProfileID(in: defaults) == made)
        #expect(ProfileStore.profileID(in: defaults) == made)
    }

    @Test("a habit with no wins is backfilled too, not left at launch time")
    func backfillCoversHabitsWithoutWins() throws {
        let context = try context()
        let habit = Habit(title: "Planned", category: .work)
        context.insert(habit)
        let made = Date(timeIntervalSinceReferenceDate: 640_000_000)
        try StoreStamp.withoutStamping {
            try context.save()
            habit.createdAt = made
            try context.save()
        }
        let defaults = try #require(UserDefaults(suiteName: "no-wins-\(UUID().uuidString)"))
        SocialFieldsBackfill.runIfNeeded(context: context, defaults: defaults)
        #expect(habit.updatedAt == made)
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

    /// Loads the schema through `NSPersistentCloudKitContainer` directly and
    /// returns the validator's own failure reason, or nil if it loaded.
    ///
    /// **Through Core Data, because SwiftData drops the reason.** Its error is
    /// `loadIssueModelContainer` with no explanation, so a test on "it threw"
    /// would pass for a missing entitlement or a bad path just as well as for
    /// the rule. Core Data's error carries the sentence.
    private func validatorReason(_ types: [any PersistentModel.Type]) throws -> String? {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: types))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ck-reason-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        let container = NSPersistentCloudKitContainer(name: "probe", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.JaydenBetts.Strata")
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var reason: String?
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                reason = (error.userInfo[NSLocalizedFailureReasonErrorKey] as? String) ?? error.localizedDescription
            }
        }
        return reason
    }

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

    /// Must be refused. If this opens, the validator is not running in this
    /// environment and the app schema passing below proves nothing.
    @Test("probe: a schema that breaks the rule is refused")
    func breaker() throws {
        let result = open(Schema([CloudKitRuleBreaker.self]))
        NSLog("[ck-probe] breaker -> \(result)")
        #expect(result.hasPrefix("THREW"))
        // The validator's own sentence, so an environment error cannot pass.
        let reason = try validatorReason([CloudKitRuleBreaker.self])
        NSLog("[ck-probe] breaker reason -> \(reason ?? "none")")
        #expect(reason?.contains("have a default value") == true)
        #expect(reason?.contains("CloudKitRuleBreaker: name") == true)
    }

    @Test("probe: the app's schema passes the validator")
    func app() throws {
        let result = open(SharedModelContainer.schema)
        NSLog("[ck-probe] app -> \(result)")
        #expect(result == "OPENED")
        let reason = try validatorReason([Habit.self, HabitLog.self, MoodLog.self,
                                           Tower.self, PlanFolder.self, PlanItem.self])
        NSLog("[ck-probe] app reason -> \(reason ?? "none")")
        #expect(reason == nil)
    }
}
