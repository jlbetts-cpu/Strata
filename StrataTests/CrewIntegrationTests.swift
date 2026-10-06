import Testing
import Foundation
import SwiftData
@testable import Strata

/// **The app's own paths, not the store's.** The 2026-10-02 audit found new
/// wins never reached a crew: every store test passed, because the store was
/// fine and the screens never called it. These hold the calls themselves.
@MainActor
@Suite("Crew integration", .serialized)
struct CrewIntegrationTests {
    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    @Test func everyPlaceAPersonLogsAWinSendsIt() throws {
        // "with: withPeople" since 2026-10-05: Add Win sends who the win was
        // with (shared wins). Still the one call that posts a new win.
        #expect(try Self.source("Strata/Views/AddWinSheet.swift")
            .contains("CrewSync.post(log, to: crewChoice, with: withPeople)"))
        #expect(try Self.source("Strata/Views/MainAppView.swift").contains("CrewSync.post(log)"))
        #expect(try Self.source("Strata/Intents/LogWinIntent.swift").contains("CrewSync.post(log)"))
    }

    @Test func restoringABackupNeverSendsAnything() throws {
        // A kept copy of a friend's tagged win is yours alone: it is logged,
        // never sent (shared wins, spec 1).
        for file in ["Strata/Services/BackupRestore.swift", "Strata/Services/BackupArchive.swift",
                     "Strata/Services/QuickWinService.swift", "Strata/Services/TaggedWinKeeper.swift"] {
            #expect(try !Self.source(file).contains("CrewSync"), "\(file) must never post to a crew")
        }
    }

    @Test func theRealCloudIsChosenWhenCrewsAreOn() throws {
        #expect(try Self.source("Strata/StrataApp.swift").contains("SocialStore.makeCloud = { CloudKitCrewCloud() }"))
    }

    @Test func aRealSaveKeepsEveryCopyInStep() async throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let world = FakeCrewWorld()
        let suite = "integration-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.derive = { $0 }
        let previous = CrewSync.store
        CrewSync.store = { store }
        defer { CrewSync.store = previous }
        CrewSync.observe(evenIfOff: true)

        let (crew, _) = try await store.createCrew(name: "One")
        let win = try QuickWinService.logWin(title: "Gym", category: .health, context: context, tower: nil)
        let log = try #require((win.habit.logs ?? []).first)
        await store.post(try #require(CrewSync.ownWin(log)), to: [crew.id])
        #expect(world.records(of: .sharedWin, in: crew.id).values.first?["title"] == .string("Gym"))

        // Two saves, as the Edit sheet makes them: the name, then something
        // else. The crew gets the final values once.
        win.habit.title = "Gym, legs"
        try context.save()
        win.habit.category = .focus
        try context.save()
        try await Task.sleep(for: .milliseconds(800))
        let record = try #require(world.records(of: .sharedWin, in: crew.id).values.first)
        #expect(record["title"] == .string("Gym, legs"))
        #expect(record["colour"] == .string(HabitCategory.focus.rawValue))

        // Deleting the win deletes every copy, through the save alone.
        context.delete(log)
        try context.save()
        try await Task.sleep(for: .milliseconds(300))
        #expect(world.records(of: .sharedWin, in: crew.id).isEmpty)
    }

    @Test func anEditBeforeTheFirstFetchStillReachesTheCrew() async throws {
        let world = FakeCrewWorld()
        let suite = "ledger-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let dir = FileManager.default.temporaryDirectory.appending(path: suite)
        let first = SocialStore(cloud: FakeCrewCloud(world: world, me: UUID()), defaults: defaults, directory: dir)
        first.isEnabled = { true }
        first.derive = { $0 }
        let (crew, _) = try await first.createCrew(name: "One")
        let id = UUID()
        await first.post(OwnWin(winID: id, title: "Run", colour: .health, icon: .health, blockSize: .small,
                                photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now), to: [crew.id])
        // A relaunch, offline: a new store on the same disk, nothing fetched.
        let cloud = FakeCrewCloud(world: world, me: first.me)
        let again = SocialStore(cloud: cloud, defaults: defaults, directory: dir)
        again.isEnabled = { true }
        #expect(again.crews(holding: id) == [crew.id], "the ledger knows before any fetch")
    }
}
