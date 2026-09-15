import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Strata

/// **Memories reloads only when something changed — and always when it did.**
///
/// Every visit to the tab used to refetch four years of photographs on the
/// main actor. `StoreSignature` now decides whether a reload has anything to
/// do. Skipping is only safe if every change a person can make moves the
/// signature, so each of those is pinned here: logging a win, renaming one
/// (which changes no count), and removing a photograph.
@MainActor
@Suite("MemoriesReload", .serialized)
struct MemoriesReloadTests {

    private func context() throws -> ModelContext {
        StoreSaves.observe()
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func photographedWin(_ title: String, file: String, context: ModelContext) throws -> HabitLog {
        let win = try QuickWinService.logWin(title: title, category: .health, context: context, tower: nil)
        let id = win.logID
        let log = try #require(try context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.id == id })).first)
        log.imageFileName = file
        try context.save()
        return log
    }

    @Test("nothing happening leaves the signature alone")
    func quietStoreMatches() throws {
        let context = try context()
        _ = try photographedWin("Ran", file: "sig-a.heic", context: context)
        #expect(StoreSignature.current(context: context) == StoreSignature.current(context: context))
    }

    @Test("logging a win changes the signature")
    func loggingChanges() throws {
        let context = try context()
        let before = StoreSignature.current(context: context)
        _ = try QuickWinService.logWin(title: "Walk", category: .health, context: context, tower: nil)
        #expect(StoreSignature.current(context: context) != before)
    }

    @Test("renaming a win changes the signature, though no count moves")
    func editingChanges() async throws {
        let context = try context()
        let log = try photographedWin("Ran", file: "sig-b.heic", context: context)
        let before = StoreSignature.current(context: context)
        log.habit?.title = "Ran 10k"
        try context.save()
        await Task.yield()
        let after = StoreSignature.current(context: context)
        #expect(after.logs == before.logs && after.photographs == before.photographs)
        #expect(after != before, "an edit would be skipped and Memories would show the old title")
    }

    @Test("an unsaved change never matches")
    func pendingNeverMatches() throws {
        let context = try context()
        let log = try photographedWin("Ran", file: "sig-c.heic", context: context)
        log.habit?.title = "Unsaved"
        let a = StoreSignature.current(context: context)
        #expect(a != a)
    }

    @Test("removing a photograph changes the signature")
    func removingAPhotoChanges() throws {
        let context = try context()
        _ = try photographedWin("Ran", file: "sig-d.heic", context: context)
        let before = StoreSignature.current(context: context)
        PhotoRemoval.removePhoto(fileName: "sig-d.heic", context: context)
        #expect(StoreSignature.current(context: context) != before)
    }

    @Test("the page picks up a new photograph, an edit and a removal after a skipped reload")
    func reloadFollowsChanges() async throws {
        let context = try context()
        let first = try photographedWin("Ran", file: "sig-e.heic", context: context)
        let vm = MemoriesViewModel()
        await vm.reload(context: context)
        #expect(vm.gallery.flatMap(\.photos).map(\.fileName) == ["sig-e.heic"])

        // Nothing changed: skipped, and still right.
        await vm.reload(context: context)
        #expect(vm.gallery.flatMap(\.photos).count == 1)

        _ = try photographedWin("Walk", file: "sig-f.heic", context: context)
        await vm.reload(context: context)
        #expect(Set(vm.gallery.flatMap(\.photos).map(\.fileName)) == ["sig-e.heic", "sig-f.heic"])

        first.habit?.title = "Ran far"
        try context.save()
        await vm.reload(context: context)
        #expect(vm.gallery.flatMap(\.photos).contains { $0.title == "Ran far" })

        PhotoRemoval.removePhoto(fileName: "sig-f.heic", context: context)
        await vm.reload(context: context)
        #expect(vm.gallery.flatMap(\.photos).map(\.fileName) == ["sig-e.heic"])
    }

    /// The replay shelf skips its period queries on the same signature; a new
    /// win must still bring its week onto the shelf.
    @Test("the replay shelf finds a new win after a skipped reload")
    func replayShelfFollowsANewWin() async throws {
        let context = try context()
        let shelf = ReplayShelfModel()
        await shelf.reload(context: context, colorScheme: .light, displayScale: 1, now: Date(), redrawsStale: false)
        #expect(shelf.weeks.isEmpty && shelf.months.isEmpty)
        await shelf.reload(context: context, colorScheme: .light, displayScale: 1, now: Date(), redrawsStale: false)
        #expect(shelf.weeks.isEmpty)
        // Last week: a finished week is always on the shelf, where this week
        // only is inside its own window.
        let lastWeek = try #require(Calendar.current.date(byAdding: .day, value: -7, to: Date()))
        _ = try QuickWinService.logWin(title: "Walk", category: .health, on: lastWeek, context: context, tower: nil)
        await shelf.reload(context: context, colorScheme: .light, displayScale: 1, now: Date(), redrawsStale: false)
        #expect(!shelf.weeks.isEmpty, "a new win was hidden by a skipped reload")
    }
}

/// The date formatters are made once now. Made per call they followed a change
/// of time zone for free; made once they must still follow it.
@Suite("Album formats", .serialized)
struct AlbumFormatsTests {
    @Test("a cached formatter follows a change of time zone once the system says so")
    func followsTimeZone() {
        let original = NSTimeZone.default
        defer {
            NSTimeZone.default = original
            NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        }
        let instant = Date(timeIntervalSince1970: 1_789_000_000)
        func fresh() -> String {
            let f = DateFormatter()
            f.dateFormat = "d MMMM HH:mm"
            return f.string(from: instant)
        }

        NSTimeZone.default = TimeZone(identifier: "Pacific/Auckland")!
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        let auckland = Album.Formats.formatter("d MMMM HH:mm").string(from: instant)
        #expect(auckland == fresh())

        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        let angeles = Album.Formats.formatter("d MMMM HH:mm").string(from: instant)
        #expect(angeles == fresh())
        #expect(auckland != angeles, "the zone change did not reach the cached formatter")
    }
}
