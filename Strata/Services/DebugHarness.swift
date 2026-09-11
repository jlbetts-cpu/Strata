#if DEBUG
import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Launch-argument hooks so a screenshot can be taken of an exact state.
///
/// The simulator gives no way to tap a tab bar from a script, and the states
/// worth photographing (one block, a full grid, a tower long enough to scroll)
/// take a long time to reach by hand. This lets a build be launched straight
/// into one:
///
///     xcrun simctl launch <dev> JaydenBetts.Strata \
///         -strataStartTab tower -strataSeedWins 12
///
/// DEBUG only, so none of it can reach a shipped build. It writes through the
/// same `QuickWinService` and `Habit` initialisers the app uses, so a seeded
/// state is a state the app could actually have got itself into.
enum DebugHarness {

    static func argument(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// Tab to open on launch, from `-strataStartTab <raw value, lowercased>`.
    static var startTab: StrataTab? {
        guard let raw = argument("-strataStartTab") else { return nil }
        let wanted = raw.lowercased()
        // "tower" still works: the tab was called that for most of this
        // project's life and every script and note that mentions it says so.
        if wanted == "tower" { return .tower }
        // Likewise "insights" and "history": the tab is Memories now, and
        // every screenshot script and task note written before that says one
        // of the two older names.
        if wanted == "insights" || wanted == "history" { return .memories }
        return StrataTab.allCases.first { $0.rawValue.lowercased() == wanted }
    }

    /// A day to push straight into on launch, from `-strataOpenDay <n>`,
    /// where n is days back from today. The day screen is behind a tap on an
    /// album, and a tap is the one thing a screenshot script cannot do.
    static var openDayBack: Int? {
        guard let raw = argument("-strataOpenDay") else { return nil }
        return Int(raw)
    }

    /// Holds the front-camera ring light on so it can be photographed. The
    /// simulator has no camera, so this is the only way to see the light at
    /// all — what it looks like on a FACE is still unverifiable here.
    static var holdsRingLight: Bool {
        ProcessInfo.processInfo.arguments.contains("-strataRingLight")
    }

    /// Exercises the camera-roll write and prints the outcome.
    ///
    /// `CameraView.fire()` is the real call site, and it cannot be reached in
    /// the simulator — there is no camera, so `CameraService.capture` never
    /// produces an image. This drives `PhotoLibrarySaver.save` directly with a
    /// generated one, which covers the part most likely to be wrong: the
    /// add-only authorisation and the `PHAssetChangeRequest` write. What it
    /// does NOT cover is orientation and resolution of a real frame, which is
    /// a device check.
    static var testsPhotoSave: Bool {
        ProcessInfo.processInfo.arguments.contains("-strataTestPhotoSave")
    }

    /// Writes a generated image to the camera roll and prints the result to
    /// the device log, where `simctl spawn log stream` can read it.
    /// Asks for location, waits, and says what came back.
    ///
    /// Nothing in the app uses `LocationService` yet, so this is the only
    /// evidence that the usage-description key reached BOTH build
    /// configurations — a key added to one is a Release-only device crash
    /// found six weeks later — and that a fix actually arrives. Drive it with
    /// `xcrun simctl location <device> set <lat>,<lon>`.
    static func runLocationProbe(_ service: LocationService) {
        Task { @MainActor in
            NSLog("[strata-probe] location auth=\(service.authorization.rawValue) "
                  + "canAsk=\(service.canAsk) precise=\(service.isPrecise)")
            service.requestAccess()
            service.start()
            for attempt in 1...10 {
                try? await Task.sleep(for: .seconds(1))
                if let fix = service.fix() {
                    NSLog("[strata-probe] location fixed after \(attempt)s "
                          + "lat=\(fix.coordinate.latitude) lon=\(fix.coordinate.longitude) "
                          + "accuracy=\(fix.horizontalAccuracy)")
                    return
                }
            }
            NSLog("[strata-probe] location no usable fix in 10s "
                  + "auth=\(service.authorization.rawValue) latest=\(service.latest?.description ?? "nil")")
        }
    }

    static func runPhotoSaveProbe() {
        Task { @MainActor in
            let size = CGSize(width: 1200, height: 1600)
            let image = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.systemPink.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 100, y: 100, width: 400, height: 400))
            }
            let enabled = PhotoLibrarySaver.isEnabled
            let ok = await PhotoLibrarySaver.save(image)
            NSLog("[strata-probe] photoSave enabled=\(enabled) saved=\(ok)")
        }
    }

    /// Months back from the current one, from `-strataOpenMonth <n>`. The
    /// month picker is behind a tap, so this is the only way to photograph a
    /// month that is not the current one.
    static var openMonthBack: Int? {
        argument("-strataOpenMonth").flatMap(Int.init)
    }

    /// Which curated album to open, from `-strataOpenCurated <index>`.
    static var openCuratedIndex: Int? {
        argument("-strataOpenCurated").flatMap(Int.init)
    }

    /// Which gallery photograph to open the viewer on, from
    /// `-strataOpenPhoto <index>`.
    ///
    /// The viewer is behind a tap, so without this it can only be photographed
    /// by racing a UI test with a screenshot loop — which caught it in one
    /// frame out of thirty and missed it entirely on the first try. Both new
    /// Memories screens needed a flag of their own for the same reason.
    static var openPhotoIndex: Int? {
        argument("-strataOpenPhoto").flatMap(Int.init)
    }

    /// Which moment card to open, from `-strataOpenMoment <index>`.
    static var openMomentIndex: Int? {
        argument("-strataOpenMoment").flatMap(Int.init)
    }

    /// Seeds a few plan lines, from `-strataSeedPlan <n>`. The plan is behind
    /// a button, so without this there is nothing to photograph.
    static var seedPlan: Int? {
        argument("-strataSeedPlan").flatMap(Int.init)
    }

    /// Sheet to present on launch, from `-strataOpenSheet settings|profile|add|block`.
    /// These are modals with no other scriptable route in. `settings` opens
    /// Profile and pushes Settings, since Settings lives only inside Profile.
    static var openSheet: String? {
        argument("-strataOpenSheet")?.lowercased()
    }

    /// The creator's bundled faces as a made head, from `-strataSeedHead`.
    /// The simulator has no camera to make a real one with, so without this
    /// no head placement could ever be photographed here.
    static var seedsHead: Bool { argument("-strataSeedHead") != nil }

    /// Which chart Profile opens on, from `-strataProfileChart day|week|month`.
    static var profileChartUnit: String? { argument("-strataProfileChart")?.lowercased() }

    /// Puts your head on the photo review, from `-strataReviewSticker`, with
    /// `-strataOpenReview` and `-strataHeadOn camera`.
    /// A bare flag: `argument` reads the word after a key, and a flag given
    /// last has none.
    static var placesReviewSticker: Bool { ProcessInfo.processInfo.arguments.contains("-strataReviewSticker") }

    /// Opens the head maker in one state, from
    /// `-strataOpenHeadMaker outline|blink|smile|preview|failed`, on top of
    /// `-strataOpenSheet profile`. The simulator has no camera, so the maker's
    /// chrome can only be photographed by putting it into a state directly.
    static var headMakerState: String? { argument("-strataOpenHeadMaker")?.lowercased() }

    /// Turns head placements on for one launch, from
    /// `-strataHeadOn picture,map,camera,tower` (any subset).
    static var headSwitches: Set<String>? {
        argument("-strataHeadOn").map { raw in
            Set(raw.lowercased().split(separator: ",").map(String.init))
        }
    }

    /// Presses the next slot this many times a moment after launch, so the
    /// drop cascade can be watched without a tap.
    static var autoWins: Int {
        Int(argument("-strataAutoWin") ?? "0") ?? 0
    }

    /// A stand-in photograph, written straight to the image directory.
    ///
    /// Synchronous on purpose, and NOT through `ImageManager.save`, which is
    /// `async`. Seeding runs on the main actor during launch, and bridging an
    /// async save back with a semaphore deadlocks it instantly — the task
    /// cannot get the actor the semaphore is holding, so the app comes up as a
    /// blank white screen. Measured, once.
    ///
    /// The file name is the same shape `ImageManager` writes, and it lands in
    /// the same directory, so a seeded photo is loaded by exactly the code
    /// path a captured one is.
    ///
    /// A flat colour rather than anything photographic: the point of the
    /// fixture is to exercise the fan, the caching and the round trip, and a
    /// solid field makes it obvious which layer of the stack is which.
    /// Scrolls Memories to the bottom on appear, from `-strataScrollMemories`.
    ///
    /// A pinned header is only interesting once something has scrolled under
    /// it, and nothing on this machine can swipe. Without this the pinned
    /// state cannot be photographed at all, which is how an unreachable
    /// control stayed unexplained.
    static var scrollsMemories: Bool { argument("-strataScrollMemories") != nil }
    /// Where to scroll to: `shelf` stops just past the month, anything else
    /// goes to the bottom.
    static var scrollTarget: String { argument("-strataScrollMemories") ?? "" }

    /// Walks the map's camera through a zoom ladder, from `-strataMapSweep`.
    ///
    /// **Nothing on this machine can pinch a simulator**, so the one claim the
    /// map actually makes — that places merge as you pull back and split as
    /// you go in — cannot be seen the way a person sees it. This drives the
    /// camera itself and logs a classified count at every step, which is the
    /// same instrument the drop cascade was judged with: report the count per
    /// event, never an aggregate.
    static var sweepsMap: Bool { argument("-strataMapSweep") != nil }

    /// Opens the map, from `-strataOpenMap`. It is behind a tap, so without
    /// this it cannot be photographed at all.
    static var opensMap: Bool { argument("-strataOpenMap") != nil }

    /// Which map ground to draw, from `-strataMapStyle [quiet|satellite]`.
    ///
    /// MapKit cannot be recoloured, so these two are the whole space. Which
    /// one is right is a taste question, and this exists so it can be settled
    /// by rendering both at phone size rather than by argument.
    /// Whether a ground was asked for explicitly, so the app's own rule (dark
    /// map in dark mode) is not silently replaced by a default.
    static var hasMapStyleOverride: Bool { argument("-strataMapStyle") != nil }

    static var mapStyle: MemoriesMapView.Style {
        switch argument("-strataMapStyle") {
        case "satellite": return .satellite
        case "night": return .night
        default: return .quiet
        }
    }

    /// Whether seeded photographs also get coordinates, from
    /// `-strataSeedPlaces`.
    ///
    /// The map is empty on a real device for weeks — no photograph taken
    /// before location capture shipped has a place, and none ever will — so
    /// without this it cannot be looked at full, and the person judging it
    /// would be judging an empty rectangle.
    static var seedsPlaces: Bool { argument("-strataSeedPlaces") != nil }

    /// Shows onboarding, from `-strataShowOnboarding`.
    ///
    /// **Inverted on purpose.** Onboarding is skipped by default under the
    /// harness, because otherwise it covers every screenshot this project
    /// takes and every UI test starts by failing to find anything. Asking for
    /// it is the special case.
    static var showsOnboarding: Bool { argument("-strataShowOnboarding") != nil }

    /// Forgets that onboarding has been seen, from `-strataResetOnboarding`.
    ///
    /// So a test can exercise the REAL first-launch path — decided by
    /// `hasOnboarded` — rather than a harness shortcut that skips the very
    /// thing being tested.
    static var resetsOnboarding: Bool { argument("-strataResetOnboarding") != nil }

    /// Empties the store before anything else runs, from `-strataResetStore`.
    ///
    /// **This exists because the UI suite could not be trusted.** Every test
    /// runs against one simulator holding one SwiftData store, and several of
    /// them write to it — so a test that asserts a FIRST run is not repeatable
    /// once a previous test has left wins behind. Measured: the first-run test
    /// failed with "On screen: 3", three wins already on the tower, and the
    /// welcome block correctly skipped because it may only ever be created
    /// once. The feature was right and the harness was wrong.
    ///
    /// Wired to the same `resetTower()` the Settings button uses, rather than
    /// a second deletion path: CLAUDE.md is explicit that image files are real
    /// user photographs, and the fewer places that can delete them the better.
    static var resetsStore: Bool { argument("-strataResetStore") != nil }

    /// Which onboarding page to open on, from `-strataOnboardingStep 0...3`.
    static var onboardingStep: Int? { argument("-strataOnboardingStep").flatMap(Int.init) }


    /// Raises the photographs page, from `-strataOpenDrawer full`.
    ///
    /// The drawer rests hidden and opens on a button, so without this it
    /// cannot be photographed at all — nothing on this machine can tap the
    /// simulator.
    static var openDrawer: DrawerDetent? {
        argument("-strataOpenDrawer") == nil ? nil : .full
    }

    /// Puts a seeded win somewhere real.
    ///
    /// **60% into three tight clusters, 40% spread**, which is what exercises
    /// the thing that can actually be wrong: merging at one zoom and splitting
    /// at the next. An even scatter never merges and would make a broken
    /// clusterer look fine.
    private static func place(_ log: HabitLog, index n: Int) {
        // Three places a few hundred metres across, and a wider spread around
        // them. London, because the numbers are memorable when reading a log.
        let hubs = [(51.5074, -0.1278), (51.5155, -0.1410), (51.4975, -0.1357)]
        if n % 5 < 3 {
            let hub = hubs[n % hubs.count]
            log.latitude = hub.0 + Double((n % 7) - 3) * 0.0004
            log.longitude = hub.1 + Double((n % 5) - 2) * 0.0006
        } else {
            log.latitude = 51.50 + Double((n % 23) - 11) * 0.012
            log.longitude = -0.13 + Double((n % 19) - 9) * 0.020
        }
        log.locationAccuracy = 25
    }

    /// Says whether the store opened, from `-strataReportStore`.
    ///
    /// `SharedModelContainer` falls back to an in-memory store when the
    /// container cannot be created, which is the right thing to do and the
    /// worst thing to debug: a failed migration presents as an app with no
    /// data, not as a crash. After any schema change, launch with this on a
    /// build that already has data and read the line.
    static func runStoreProbe() {
        NSLog("[strata-probe] store inMemoryFallback=\(SharedModelContainer.isUsingInMemoryFallback)")
    }

    /// Times the image pipeline, from `-strataBenchImages <n>`.
    ///
    /// **Because "photos load a bit slow" is a feeling until it is a number.**
    /// Reports three things for the same N cold thumbnails: how long they take
    /// awaited one at a time, how long the identical work takes issued
    /// concurrently, and one full-resolution decode. If the concurrent figure
    /// is not meaningfully better than the serial one, the queue underneath is
    /// the bottleneck rather than the decoding.
    static func runImageBench(count: Int) {
        Task { @MainActor in
            let manager = ImageManager.shared
            let names = Array(manager.allStoredFileNamesForBenchmark().prefix(count))
            guard !names.isEmpty else {
                NSLog("[strata-bench] no photographs on disk; seed first")
                return
            }

            // **A small run cannot see the failure that matters.** This
            // benchmark measured 30 images and reported an 8x speedup for a
            // pipeline that STALLED in real use: starvation needs more work in
            // flight than the thread pool can hold, and thirty from a standing
            // start never got there. Say so rather than let the next person
            // read a green number the way I did.
            if names.count < 50 {
                NSLog("[strata-bench] only \(names.count) photographs — too few to"
                      + " show a pool stalling. Seed more and pass 80+.")
            }

            manager.emptyThumbnailCacheForBenchmark()
            var start = Date()
            for name in names {
                _ = await manager.loadThumbnail(fileName: name, maxWidth: 180)
            }
            let serial = Date().timeIntervalSince(start)

            manager.emptyThumbnailCacheForBenchmark()
            start = Date()
            await withTaskGroup(of: Void.self) { group in
                for name in names {
                    group.addTask { _ = await manager.loadThumbnail(fileName: name, maxWidth: 180) }
                }
            }
            let concurrent = Date().timeIntervalSince(start)

            manager.emptyThumbnailCacheForBenchmark()
            start = Date()
            _ = await manager.loadThumbnail(fileName: names[0], maxWidth: 180)
            let single = Date().timeIntervalSince(start)

            start = Date()
            _ = await manager.loadFullImage(fileName: names[0])
            let full = Date().timeIntervalSince(start)

            NSLog("[strata-bench] n=\(names.count) "
                  + "serial=\(Int(serial * 1000))ms "
                  + "concurrent=\(Int(concurrent * 1000))ms "
                  + "speedup=\(String(format: "%.2f", serial / max(concurrent, 0.0001)))x "
                  + "oneThumbnail=\(Int(single * 1000))ms "
                  + "oneFullDecode=\(Int(full * 1000))ms")
        }
    }

    /// How many photographs to time, from `-strataBenchImages <n>`.
    static var benchImages: Int? {
        argument("-strataBenchImages").flatMap(Int.init)
    }

    /// Photographs TODAY's seeded wins too, from `-strataSeedTodayPhotos`.
    ///
    /// The history fixture deliberately only photographs past days — the
    /// shelf's curation gate is tuned against that. But the widget draws
    /// TODAY, so with the normal fixture it can only ever show its empty
    /// state, and the photograph path could not be looked at at all.
    static var seedsTodayPhotos: Bool { argument("-strataSeedTodayPhotos") != nil }

    /// Runs the REAL photograph path end to end, from `-strataProbePhotos`.
    ///
    /// **Because the fixture does not use it.** Seeded photographs are written
    /// straight to the image directory by `seedPhoto`, so every check built on
    /// them passes whatever the save path does. A photograph a person adds
    /// goes somewhere else entirely: resize, HEIC encode, write, then read
    /// back through `loadThumbnail`. This exercises that, and reports each
    /// step separately so a failure names itself.
    ///
    /// Two shapes of image, because they fail differently: one backed by a
    /// CGImage, and one backed by a CIImage — `encodeHEIC` asks for
    /// `image.cgImage` and gets nil from the second, which is what a picker or
    /// a camera can hand you.
    static func runPhotoPipelineProbe() {
        Task { @MainActor in
            let size = CGSize(width: 3000, height: 4000)
            let drawn = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.systemTeal.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 200, y: 300, width: 900, height: 900))
            }
            let ciBacked = CIImage(image: drawn).map { UIImage(ciImage: $0) }

            for (label, image) in [("cgImage-backed", drawn),
                                   ("ciImage-backed", ciBacked)] {
                guard let image else {
                    NSLog("[strata-photos] \(label): could not build the image")
                    continue
                }
                NSLog("[strata-photos] \(label): cgImage=\(image.cgImage != nil) "
                      + "ciImage=\(image.ciImage != nil) size=\(Int(image.size.width))x\(Int(image.size.height))")
                do {
                    let name = try await ImageManager.shared.save(image: image, for: UUID())
                    let onDisk = ImageManager.shared.fileExists(fileName: name)
                    let back = await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: 360)
                    NSLog("[strata-photos] \(label): SAVED \(name) onDisk=\(onDisk) "
                          + "readBack=\(back != nil) \(back.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil")")
                } catch {
                    NSLog("[strata-photos] \(label): SAVE FAILED \(error)")
                }
            }
            NSLog("[strata-photos] done")
        }
    }

    static var probesPhotos: Bool { argument("-strataProbePhotos") != nil }

    static var reportsStore: Bool { argument("-strataReportStore") != nil }

    /// Reports what the location service can see, from `-strataTestLocation`.
    ///
    /// Nothing else uses `LocationService` yet, so this is the only way to
    /// tell whether the permission key is wired into BOTH build
    /// configurations and whether a fix ever arrives. Drive it with
    /// `xcrun simctl location <device> set <lat>,<lon>`.
    static var reportsLocation: Bool { argument("-strataTestLocation") != nil }

    /// Puts the camera straight into its review state, from
    /// `-strataOpenReview [size]`, where size is `small`, `medium` or `hard`.
    ///
    /// The simulator has no capture device, so the review screen cannot be
    /// reached the way a person reaches it — you have to take a photograph
    /// first. Without this it is unphotographable, which is the same reason
    /// `-strataOpenPhoto` exists.
    static var openReviewSize: BlockSize? {
        guard argument("-strataOpenReview") != nil else { return nil }
        switch argument("-strataOpenReview") {
        case "medium": return .medium
        case "hard", "large": return .hard
        default: return .small
        }
    }

    /// A stand-in photograph, for a screen that would otherwise need a lens.
    static func placeholderPhoto(_ category: HabitCategory = .creativity) -> UIImage {
        gradientImage(category)
    }

    /// The fixture's photograph: a soft diagonal wash, no hard edges anywhere.
    ///
    /// It used to be a flat field with a white bar across it, to make the
    /// layers of the album fan tell themselves apart. On an album cover that
    /// was fine; on a BLOCK it read as a line drawn through the middle, and a
    /// tower of them looked broken. A fixture is not allowed to look like a
    /// bug.
    private static func gradientImage(_ category: HabitCategory) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let base = UIColor(category.style.baseColor)
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        let top = UIColor(hue: h, saturation: max(sat - 0.18, 0),
                          brightness: min(b + 0.16, 1), alpha: 1)
        let bottom = UIColor(hue: h, saturation: min(sat + 0.10, 1),
                             brightness: max(b - 0.18, 0), alpha: 1)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space,
                                            colors: [top.cgColor, bottom.cgColor] as CFArray,
                                            locations: [0, 1]) else {
                base.setFill(); ctx.fill(CGRect(origin: .zero, size: size)); return
            }
            // `drawsBefore/AfterStartLocation`, or the corners outside the
            // gradient's own endpoints are never painted at all — they come
            // out transparent, and every fixture photograph in every
            // screenshot this project takes has a chamfered top-left and
            // bottom-right. It read as a photo with its corners cut off, which
            // is exactly the "a fixture is not allowed to look like a bug"
            // rule this comment block was already about.
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width * 0.2, y: 0),
                end: CGPoint(x: size.width * 0.8, y: size.height),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
    }

    private static func seedPhoto(for logID: UUID, category: HabitCategory) -> String? {
        // A soft vertical wash, and no hard edges anywhere.
        //
        // This used to be a flat field with a white bar across it, to make the
        // layers of the album fan tell themselves apart. On an album cover
        // that was fine; on a BLOCK it read as a line drawn through the middle
        // of the block, and a tower of them looked broken. A fixture is not
        // allowed to look like a bug.
        let image = gradientImage(category)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("strata-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "\(logID.uuidString)_seed.jpg"
        do {
            try data.write(to: dir.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    /// Renders the share card to a PNG in the app container and exits the
    /// need to tap anything. The card is an `ImageRenderer` output, so a
    /// screenshot of the share SHEET only ever shows a thumbnail of it — this
    /// is the only way to look at the thing that actually gets posted.
    static var dumpsShareCard: Bool {
        // Presence, not a value: `argument(_:)` returns the token AFTER the
        // flag, so a bare switch always reads as nil through it.
        ProcessInfo.processInfo.arguments.contains("-strataDumpShareCard")
    }

    /// Flips between two tabs on a timer, so the appearance swap between a
    /// light screen and the dark camera can be filmed. Nothing here can tap.
    static var tabFlips: Int {
        Int(argument("-strataFlipTabs") ?? "0") ?? 0
    }

    /// One-off tasks for today, so the "just today" path can be checked
    /// without tapping through the add sheet.
    static var seedTodos: Int {
        Int(argument("-strataSeedTodos") ?? "0") ?? 0
    }

    /// Ticks n rows on the checklist, so the tick-to-block loop can be filmed.
    /// Nothing on this machine can tap, and that loop is the whole point of
    /// the screen, so it needs a way to run without one.
    static var autoChecks: Int {
        Int(argument("-strataAutoCheck") ?? "0") ?? 0
    }

    /// Forces the colour a logged win wears, so a drop that MERGES can be
    /// filmed. The least-used picker deliberately avoids repeats, so a normal
    /// run never drops a block next to its own colour.
    static var forcedWinCategory: HabitCategory? {
        guard let raw = argument("-strataForceWinColor") else { return nil }
        return HabitCategory.selectable.first { $0.rawValue == raw.lowercased() }
    }

    /// True when this launch is a harness run at all. Used to suppress the
    /// HealthKit permission sheet, which is a system alert no script can
    /// dismiss and which covers whatever was being photographed.
    static var isActive: Bool {
        startTab != nil || wantsSeed || openSheet != nil
            // `-strataResetOnboarding` deliberately does NOT count: it wants
            // the real path, not the harness's answer.
            // The onboarding flags count too. Without them, asking for
            // onboarding alone left `isActive` false, so the app fell back to
            // the real `hasOnboarded` default and showed no onboarding at all
            // — the flag looked broken when it was simply never consulted.
            || showsOnboarding || onboardingStep != nil
    }

    /// True when the run asked for seeding, so `setup()` knows to wipe first.
    static var wantsSeed: Bool {
        argument("-strataSeedWins") != nil
            || argument("-strataSeedHistory") != nil
            || argument("-strataSeedHabits") != nil
            || argument("-strataSeedUnlabeled") != nil
            || argument("-strataAutoWin") != nil
            || argument("-strataAutoCheck") != nil
            || argument("-strataSeedTodos") != nil
            || argument("-strataFlipTabs") != nil

            || dumpsShareCard
            || argument("-strataSeedMono") != nil
    }

    /// Replaces all habits and logs with a deterministic fixture.
    ///
    /// `-strataSeedWins n`   completed blocks, so the tower has n tiles.
    /// `-strataSeedHabits n` scheduled habits for today, left incomplete, so
    ///                       Today and Plan have rows and the ghost tier shows.
    /// The titles the fixture treats as repeated interests, so the curated
    /// shelf has exactly two cards to show and the rule can be seen working.
    static let seededInterests: Set<String> = ["Ran 5k", "Read a chapter"]

    static func seed(context: ModelContext, tower: Tower?) {
        guard wantsSeed else { return }

        // Start from empty so a seeded run is reproducible across launches.
        // Deleted one at a time on purpose: `delete(model:)` issues a batch
        // delete, which CoreData refuses here because HabitLog.habit and
        // Habit.tower are mandatory inverses it cannot nullify.
        if let logs = try? context.fetch(FetchDescriptor<HabitLog>()) {
            for log in logs { context.delete(log) }
        }
        if let habits = try? context.fetch(FetchDescriptor<Habit>()) {
            for habit in habits { context.delete(habit) }
        }
        try? context.save()

        if let planned = seedPlan, planned > 0 {
            if let old = try? context.fetch(FetchDescriptor<PlanItem>()) {
                for item in old { context.delete(item) }
            }
            let lines = ["Run the loop", "Send the invoice", "Call the landlord",
                         "Read a chapter", "Stretch for ten"]
            let colours = HabitCategory.selectable
            for i in 0..<min(planned, lines.count) {
                context.insert(PlanItem(text: lines[i], order: i,
                                        category: colours[i % colours.count]))
            }
            try? context.save()
        }

        let wins = Int(argument("-strataSeedWins") ?? "0") ?? 0
        let categories = HabitCategory.selectable
        let sizes: [BlockSize] = [.small, .small, .medium, .small, .hard, .small]
        let titles = ["Walk", "Inbox zero", "Sketch", "Deep work", "Called Mum",
                      "Ten minutes", "Stretched", "Read a chapter", "Tidied desk",
                      "Ran 5k", "Wrote it down", "Cooked dinner"]

        for i in 0..<wins {
            _ = try? QuickWinService.logWin(
                title: titles[i % titles.count],
                category: categories[i % categories.count],
                size: sizes[i % sizes.count],
                context: context,
                tower: tower
            )
        }

        // Wins as the app actually logs them: untitled and uncategorised,
        // which is the only way an `unlabeled` habit ever exists.
        let untitled = Int(argument("-strataSeedUnlabeled") ?? "0") ?? 0
        for _ in 0..<untitled {
            _ = try? QuickWinService.logWin(context: context, tower: tower)
        }

        // All one colour, to exercise merging. The least-used picker
        // deliberately avoids clustering, so a normal seed rarely produces two
        // adjacent blocks of one colour to look at.
        let mono = Int(argument("-strataSeedMono") ?? "0") ?? 0
        // NAMED, since named blocks merge now. Unnamed ones only exercise the
        // old path, where a member had nothing to draw.
        for i in 0..<mono {
            _ = try? QuickWinService.logWin(
                title: titles[i % titles.count],
                category: .health,
                size: sizes[i % sizes.count],
                context: context, tower: tower
            )
        }

        // A record that spans weeks, so History has something real to be
        // looked at. Everything else here seeds today, which is all the app
        // can produce on its own — `QuickWinService.logWin` takes a date now
        // for exactly this reason.
        let historyDays = Int(argument("-strataSeedHistory") ?? "0") ?? 0
        if historyDays > 0 {
            let calendar = Calendar.current
            for back in 0..<historyDays {
                guard let day = calendar.date(byAdding: .day, value: -back, to: Date()) else { continue }
                // Not every day has wins. A history with no gaps in it is not
                // a history, and the empty days are half of what the chart
                // above the albums is for.
                if back % 7 == 3 || back % 11 == 5 { continue }
                let count = 2 + (back * 3) % 6
                for i in 0..<count {
                    let n = back * 7 + i
                    guard let win = try? QuickWinService.logWin(
                        title: titles[n % titles.count],
                        category: categories[n % categories.count],
                        size: sizes[n % sizes.count],
                        on: day,
                        context: context,
                        tower: tower
                    ) else { continue }
                    // Most PAST days carry photographs — some three or more,
                    // because an album cover fans up to three and a fixture
                    // that never reaches three leaves the fan unexercised.
                    //
                    // Today is deliberately left without any. Today is what
                    // the Wins tab shows, and a tower made entirely of blocks
                    // wearing stand-in photographs is not what the tower looks
                    // like — it made the fixture read as a bug in the app.
                    // Two titles are photographed every time; everything
                    // else only on alternate days, and only its first win.
                    //
                    // It used to photograph nearly everything, and the result
                    // was that all twelve titles cleared the curated gate —
                    // five photographs, across four days, spanning two weeks —
                    // so the shelf came back as twelve curated cards and read
                    // as the rule being broken when it was the fixture that
                    // was wrong. The alternate-day rule gives each other title
                    // two or three photographs over fifty days, comfortably
                    // under the gate, while still leaving most days with a
                    // photograph so there are day albums to look at.
                    let title = titles[n % titles.count]
                    let isInterest = Self.seededInterests.contains(title)
                    let photographed = isInterest || (i == 0 && back % 2 == 0)
                    if back > 0 || seedsTodayPhotos, photographed,
                       let log = win.habit.logs.first(where: { $0.id == win.logID }) {
                        log.imageFileName = seedPhoto(
                            for: win.logID,
                            category: categories[n % categories.count]
                        )
                        if seedsPlaces { place(log, index: n) }
                    }
                }
            }
            try? context.save()
        }

        let scheduled = Int(argument("-strataSeedHabits") ?? "0") ?? 0
        let times = ["07:00", "09:30", "12:00", "14:00", "17:30", "20:00"]
        for i in 0..<scheduled {
            let habit = Habit(
                title: titles[(i + 3) % titles.count],
                category: categories[i % categories.count],
                blockSize: sizes[i % sizes.count],
                scheduledTime: i < 4 ? times[i % times.count] : nil,
                timeOfDay: .anytime,
                sortOrder: i
            )
            habit.tower = tower
            context.insert(habit)
        }

        // One-off tasks, exactly as `AddThingSheet` creates them: today's date,
        // no weekday, and NOT a quick win.
        let todayStr = DateUtils.dateString(from: Date())
        let todoTitles = ["Book the dentist", "Reply to Sam", "Renew the pass"]
        for i in 0..<seedTodos {
            let habit = Habit(
                title: todoTitles[i % todoTitles.count],
                category: categories[(i + 2) % categories.count],
                blockSize: .small,
                frequency: [],
                isTodo: true,
                scheduledDate: todayStr,
                sortOrder: 100 + i
            )
            habit.tower = tower
            context.insert(habit)
        }
        try? context.save()
    }
}
#endif
