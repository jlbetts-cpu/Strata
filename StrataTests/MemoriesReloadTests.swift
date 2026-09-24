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
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
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

    /// Fix round 2: the cards are drawn behind the map's quiet gate while the
    /// drawer is down, which is a reload that finds the periods first and
    /// draws nothing, then one that draws what is missing. The second must not
    /// be skipped as "unchanged" just because the first saw the same store.
    @Test("a reload that draws nothing still leaves the missing cards for the next one to draw")
    func missingCardsDrawnLater() async throws {
        let context = try context()
        let lastWeek = try #require(Calendar.current.date(byAdding: .day, value: -7, to: Date()))
        _ = try QuickWinService.logWin(title: "Walk", category: .health, on: lastWeek, context: context, tower: nil)
        let shelf = ReplayShelfModel()
        await shelf.reload(context: context, colorScheme: .light, displayScale: 1, now: Date(),
                           redrawsStale: false, drawsMissing: false)
        #expect(!shelf.weeks.isEmpty, "the periods were not found")
        #expect(shelf.cards.isEmpty, "a card was drawn by a reload told not to")
        await shelf.reload(context: context, colorScheme: .light, displayScale: 1, now: Date(),
                           redrawsStale: false, drawsMissing: true)
        #expect(!shelf.cards.isEmpty, "the missing card was never drawn")
    }
}

/// The date formatters are made once now. Made per call they followed a change
/// of zone, calendar or locale for free; cached they must be dropped when one
/// changes, and made again from what the phone says then.
///
/// **It does not change `NSTimeZone.default`.** An earlier version did, which
/// is process-wide and can flake any suite running beside it; this checks the
/// two halves that can actually break — the cache is dropped on the
/// notification, and a formatter is made with the zone in force.
@Suite("Album formats")
struct AlbumFormatsTests {
    @Test("the cache is dropped when the system says the zone changed")
    func dropsOnZoneChange() {
        let before = Album.Formats.formatter("d MMMM HH:mm")
        #expect(Album.Formats.formatter("d MMMM HH:mm") === before, "a formatter is made once")
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        let after = Album.Formats.formatter("d MMMM HH:mm")
        #expect(after !== before, "the zone changed and the old formatter was handed back")
    }

    @Test("the cache is dropped when the locale or the day changes")
    func dropsOnLocaleAndDay() {
        let localeBefore = Album.Formats.formatter("EEEE")
        NotificationCenter.default.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        #expect(Album.Formats.formatter("EEEE") !== localeBefore)
        let dayBefore = Album.Formats.formatter("EEEE")
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        #expect(Album.Formats.formatter("EEEE") !== dayBefore)
    }

    @Test("a formatter is made with the zone, calendar and locale in force")
    func madeFromWhatThePhoneSays() {
        Album.Formats.refresh()
        let display = Album.Formats.formatter("d MMMM")
        #expect(display.timeZone == NSTimeZone.default)
        #expect(display.calendar == NSCalendar.current)
        #expect(display.locale == NSLocale.current)
        let key = Album.Formats.formatter("yyyy-MM", posix: true)
        #expect(key.locale?.identifier == "en_US_POSIX")
        #expect(key.timeZone == NSTimeZone.default)
    }
}

/// The Memories page builds its drawer off screen only once the map has come
/// to rest, so the build never takes a frame out of a pan. The waiting rule is
/// `MapMotion.waitUntilStill(for:)`; here it is driven by a camera that keeps
/// moving, with the sleeping stubbed so the test is deterministic.
@MainActor
@Suite("MapMotion")
struct MapMotionTests {
    /// A camera moving every 100ms keeps the wait going; once it stops, the
    /// wait ends after the delay and not before.
    @Test("the wait restarts every time the camera moves")
    func waitsForTheCameraToRest() async {
        let motion = MapMotion()
        let delay = Duration.milliseconds(500)
        var slept = Duration.zero
        var moves = 0
        // A clock the test drives: sleeping moves it on, and the camera moves
        // again for the first five hops.
        await motion.waitUntilStill(for: delay) { asked in
            slept += asked
            if moves < 5 {
                moves += 1
                motion.movedAt = .now   // moved again: the wait must restart
            }
        }
        #expect(moves == 5, "the wait gave up while the camera was still moving")
        #expect(slept >= delay, "it returned without waiting out the delay")
    }

    @Test("a still camera is waited out once")
    func stillCameraReturns() async {
        let motion = MapMotion()
        motion.movedAt = .now
        var hops = 0
        await motion.waitUntilStill(for: .milliseconds(50)) { asked in
            hops += 1
            try? await Task.sleep(for: asked)
        }
        #expect(hops == 1)
        #expect(motion.stillFor >= .milliseconds(50))
    }
}
