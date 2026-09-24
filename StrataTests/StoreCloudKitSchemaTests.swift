import Testing
import Foundation
import SwiftData
import CoreData
@testable import Strata

/// **Sync is switched on, so the schema's rules are now load bearing.**
///
/// Until this change the CloudKit rules were an aspiration: the models had been
/// given defaults and optional relationships in anticipation, and the only
/// thing that could prove it was an opt in probe that needs an entitlement
/// (`CloudKitValidatorProbe`, in `SocialFieldsTests`). A rule nobody can check
/// on an ordinary test run is a rule that comes back.
///
/// These run everywhere, in seconds, with no iCloud account, no entitlement and
/// no network. They cover the two questions the change actually raises: is the
/// schema legal, and does the app still open when sync is not available.
@MainActor
@Suite("StoreCloudKitSchema")
struct StoreCloudKitSchemaTests {

    private var appTypes: [any PersistentModel.Type] {
        [Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanFolder.self, PlanItem.self]
    }

    // MARK: - The schema

    @Test("every model in the store satisfies every CloudKit rule")
    func schemaIsLegal() {
        let found = StoreSchemaRules.violations(in: appTypes)
        // Named, not counted: a failure here has to say which property, or the
        // next person goes looking through six files.
        #expect(found.isEmpty, "CloudKit would refuse: \(found.map(\.description).joined(separator: "; "))")
    }

    /// **A check that checked nothing would pass.** If
    /// `makeManagedObjectModel` ever came back with no entities, or its
    /// properties stopped being where `StoreSchemaRules` looks, every rule
    /// above would be satisfied by an empty walk.
    @Test("the check actually read the whole schema")
    func schemaWasReallyRead() {
        let seen = StoreSchemaRules.coverage(in: appTypes)
        #expect(seen.entities == 6)
        // Measured: 80 attributes across the six models. The floor is under
        // that rather than equal to it, because adding a field must not fail
        // this test, while the schema quietly emptying must. A model going
        // missing would take a dozen with it.
        #expect(seen.attributes >= 70)
        // Habit.logs, Habit.tower, Habit.planFolder, HabitLog.habit,
        // Tower.habits, PlanFolder.habits.
        #expect(seen.relationships == 6)
    }

    @Test("the schema the app opens and the schema that was checked are the same six models")
    func schemaMatchesTheContainer() {
        #expect(SharedModelContainer.schema == Schema(appTypes))
    }

    /// The other half of "a gate must be able to fail": each rule, injected.
    @Test("an attribute with no default is caught, and named")
    func attributeRuleCanFail() {
        let found = StoreSchemaRules.violations(in: [SchemaBreakerUndefaulted.self])
        #expect(found.contains(Violation(entity: "SchemaBreakerUndefaulted", property: "name",
                                         rule: StoreSchemaRules.Rule.attributeNeedsDefault.rawValue)))
    }

    @Test("a to-many that is not optional and has no inverse is caught twice, once for each rule")
    func relationshipRulesCanFail() {
        let found = StoreSchemaRules.violations(in: [SchemaBreakerParent.self, SchemaBreakerChild.self])
        #expect(found.contains(Violation(entity: "SchemaBreakerParent", property: "kids",
                                         rule: StoreSchemaRules.Rule.relationshipMustBeOptional.rawValue)))
        #expect(found.contains(Violation(entity: "SchemaBreakerParent", property: "kids",
                                         rule: StoreSchemaRules.Rule.relationshipNeedsInverse.rawValue)))
    }

    private typealias Violation = StoreSchemaRules.Violation

    // MARK: - The rungs

    private func stand(_ config: ModelConfiguration) throws -> ModelContainer {
        // In memory, so no rung in these tests touches the real store file.
        try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none))
    }

    @Test("the primary rung asks for the named CloudKit container and no other rung does")
    func onlyThePrimaryRungAsksForCloudKit() throws {
        var asked: [StoreRung: String?] = [:]
        _ = SharedModelContainer.climb { rung, config in
            asked[rung] = config.cloudKitContainerIdentifier
            if rung == .primary { throw StoreOpenError.forcedByHarness(rung) }
            return try stand(config)
        }
        #expect(asked[.primary] == SharedModelContainer.cloudKitContainerID)
        // The assertion that matters. `ModelConfiguration` defaults to
        // `cloudKitDatabase: .automatic`, which reads the entitlement, so the
        // recovery rung left at the default would ask iCloud for the same thing
        // that has just failed and the app would land on the blocking screen
        // with a perfectly readable store on disk.
        #expect(asked[.recovery] == String?.none)
    }

    @Test("the store still opens, on disk, when CloudKit refuses it")
    func openWithoutSync() throws {
        var openedOnDisk = false
        let result = SharedModelContainer.climb { rung, config in
            // What a missing entitlement, an uncreated container and a schema
            // the mirroring validator refuses all look like from here.
            if rung == .primary { throw StoreOpenError.forcedByHarness(rung) }
            openedOnDisk = !config.isStoredInMemoryOnly
            return try stand(config)
        }
        #expect(openedOnDisk)
        #expect(result.opening.savesToDisk)
        #expect(result.opening.syncPlan.isMirrored == false)
    }

    @Test("nothing that failed to open ever claims to be syncing")
    func aFailedOpenNeverClaimsToSync() {
        #expect(StoreOpening.onDisk.syncPlan
                == .mirrored(container: SharedModelContainer.cloudKitContainerID))
        #expect(StoreOpening.recovered(reason: "no entitlement").syncPlan.isMirrored == false)
        #expect(StoreOpening.unavailable(reason: "the disk is full").syncPlan.isMirrored == false)
        // The reason a person would be shown is the reason the store gave, not
        // a sentence about iCloud invented here.
        #expect(StoreOpening.recovered(reason: "no entitlement").syncPlan.summary.contains("no entitlement"))
    }

    @Test("the holding container asks iCloud for nothing at all")
    func holdingRungIsOffline() {
        let result = SharedModelContainer.climb { rung, _ in throw StoreOpenError.forcedByHarness(rung) }
        let config = result.container.configurations.first
        #expect(config?.isStoredInMemoryOnly == true)
        #expect(config?.cloudKitContainerIdentifier == nil)
    }

    // MARK: - The store that is already on the phone

    /// **What happens to somebody who updates, and to the owner if he rolls
    /// back.** Both rungs open the same file, and the only difference is
    /// whether mirroring is asked for, so a store written without CloudKit has
    /// to open with it and a store written with it has to open without. The
    /// half a test can prove is that the file, the schema and the values are
    /// untouched by the configuration around them.
    @Test("a store written by one configuration opens under another with every win intact")
    func localStoreSurvivesTheChange() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ck-local-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        func open() throws -> ModelContainer {
            try ModelContainer(for: SharedModelContainer.schema,
                               configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                                                  url: url, cloudKitDatabase: .none))
        }

        var winID = UUID()
        do {
            let context = ModelContext(try open())
            let tower = Tower(name: "My Tower")
            context.insert(tower)
            let habit = Habit(title: "Walked the long way", category: .health)
            habit.tower = tower
            context.insert(habit)
            let log = HabitLog(habit: habit, dateString: "2026-09-20", completed: true)
            log.imageFileName = "photo.heic"
            context.insert(log)
            try context.save()
            winID = log.id
        }

        let reader = ModelContext(try open())
        let id = winID
        let log = try #require(try reader.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.id == id })).first)
        #expect(log.completed)
        #expect(log.imageFileName == "photo.heic")
        #expect(log.habit?.title == "Walked the long way")
        #expect(log.habit?.tower?.name == "My Tower")
    }

    // MARK: - The duplicate tower

    private func memoryContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true, cloudKitDatabase: .none)))
    }

    private func tower(_ name: String, made: Date, in context: ModelContext) -> Tower {
        let tower = Tower(name: name)
        tower.createdAt = made
        context.insert(tower)
        return tower
    }

    private func win(_ title: String, on tower: Tower, in context: ModelContext) -> Habit {
        let habit = Habit(title: title, category: .health)
        habit.tower = tower
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-09-20", completed: true)
        context.insert(log)
        return habit
    }

    /// The bug: `MainAppView` draws only the active tower's wins, so a second
    /// device that made its own tower before the first import shows an empty
    /// tower over a full store.
    @Test("two towers after a sync become one, and every win is on it")
    func duplicateTowersMerge() throws {
        let context = try memoryContext()
        let first = tower("My Tower", made: Date(timeIntervalSinceReferenceDate: 700_000_000), in: context)
        let second = tower("My Tower", made: Date(timeIntervalSinceReferenceDate: 800_000_000), in: context)
        _ = win("Ran", on: first, in: context)
        _ = win("Read", on: second, in: context)
        let stray = win("Unplaced", on: first, in: context)
        stray.tower = nil
        try context.save()

        #expect(StoreDedupe.mergeDuplicateTowers(in: context) == 2)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        #expect(habits.count == 3)
        // The older tower wins, on every device, which is what stops two
        // devices moving everything onto their own and exporting for ever.
        #expect(habits.allSatisfy { $0.tower?.id == first.id })
        #expect(UserDefaults.standard.string(forKey: StoreDedupe.activeTowerKey) == first.id.uuidString)
        #expect(second.habits?.isEmpty != false)
    }

    @Test("the survivor is the same tower whichever order the towers arrive in")
    func survivorIsDeterministic() throws {
        let context = try memoryContext()
        let old = tower("A", made: Date(timeIntervalSinceReferenceDate: 700_000_000), in: context)
        let new = tower("B", made: Date(timeIntervalSinceReferenceDate: 800_000_000), in: context)
        #expect(StoreDedupe.chosen(from: [old, new])?.id == old.id)
        #expect(StoreDedupe.chosen(from: [new, old])?.id == old.id)
    }

    /// Two devices set up from a restore can hold the same instant, and `Date`
    /// equality then decides nothing. The id is the only value guaranteed to
    /// differ, and both devices can see it.
    @Test("towers made at the same instant are broken by id, not by luck")
    func sameInstantIsBrokenByID() throws {
        let context = try memoryContext()
        let moment = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let a = tower("A", made: moment, in: context)
        let b = tower("B", made: moment, in: context)
        let expected = a.id.uuidString < b.id.uuidString ? a.id : b.id
        #expect(StoreDedupe.chosen(from: [a, b])?.id == expected)
        #expect(StoreDedupe.chosen(from: [b, a])?.id == expected)
    }

    /// Every install that exists today has one tower, and the merge must be
    /// strictly nothing there: no write, no save, and so no export.
    @Test("one tower is left completely alone")
    func oneTowerIsUntouched() throws {
        let context = try memoryContext()
        let only = tower("My Tower", made: Date(), in: context)
        _ = win("Ran", on: only, in: context)
        try context.save()
        #expect(StoreDedupe.mergeDuplicateTowers(in: context) == 0)
        #expect(context.hasChanges == false)
    }
}

// MARK: - Models that break the rules on purpose

/// A non optional attribute with no default. Core Data's own validator says
/// "have a default value" about exactly this.
@Model
final class SchemaBreakerUndefaulted {
    var name: String
    init(name: String) { self.name = name }
}

/// A to-many that is not optional and has no inverse. It reads as perfectly
/// ordinary Swift, which is the point: this is the shape four relationships in
/// this app had, and the shape a human review passed.
@Model
final class SchemaBreakerParent {
    var name: String = ""
    var kids: [SchemaBreakerChild] = []
    init() {}
}

@Model
final class SchemaBreakerChild {
    var name: String = ""
    init() {}
}
