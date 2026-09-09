#if DEBUG
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

    private static func argument(_ key: String) -> String? {
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

    /// Pushes the full paged grid, which is otherwise behind the shelf's tail
    /// card.
    static var opensAllAlbums: Bool {
        ProcessInfo.processInfo.arguments.contains("-strataOpenAllAlbums")
    }

    /// Sheet to present on launch, from `-strataOpenSheet settings|add`.
    /// Settings and the add sheet are modals with no other scriptable route in.
    static var openSheet: String? {
        argument("-strataOpenSheet")?.lowercased()
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
    private static func seedPhoto(for logID: UUID, category: HabitCategory) -> String? {
        // A soft vertical wash, and no hard edges anywhere.
        //
        // This used to be a flat field with a white bar across it, to make the
        // layers of the album fan tell themselves apart. On an album cover
        // that was fine; on a BLOCK it read as a line drawn through the middle
        // of the block, and a tower of them looked broken. A fixture is not
        // allowed to look like a bug.
        let size = CGSize(width: 900, height: 1200)
        let base = UIColor(category.style.baseColor)
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        let top = UIColor(hue: h, saturation: max(sat - 0.18, 0),
                          brightness: min(b + 0.16, 1), alpha: 1)
        let bottom = UIColor(hue: h, saturation: min(sat + 0.10, 1),
                             brightness: max(b - 0.18, 0), alpha: 1)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space,
                                            colors: [top.cgColor, bottom.cgColor] as CFArray,
                                            locations: [0, 1]) else {
                base.setFill(); ctx.fill(CGRect(origin: .zero, size: size)); return
            }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width * 0.2, y: 0),
                end: CGPoint(x: size.width * 0.8, y: size.height),
                options: []
            )
        }
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

        let wins = Int(argument("-strataSeedWins") ?? "0") ?? 0
        let categories = HabitCategory.selectable
        let sizes: [BlockSize] = [.small, .small, .medium, .small, .hard, .small]
        let titles = ["Walk", "Inbox zero", "Sketch", "Deep work", "Called Mum",
                      "Ten minutes", "Stretched", "Read a chapter", "Tidied desk",
                      "Ran 5k", "Wrote it down", "Cooked dinner"]

        for i in 0..<wins {
            try? QuickWinService.logWin(
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
            try? QuickWinService.logWin(context: context, tower: tower)
        }

        // All one colour, to exercise merging. The least-used picker
        // deliberately avoids clustering, so a normal seed rarely produces two
        // adjacent blocks of one colour to look at.
        let mono = Int(argument("-strataSeedMono") ?? "0") ?? 0
        // NAMED, since named blocks merge now. Unnamed ones only exercise the
        // old path, where a member had nothing to draw.
        for i in 0..<mono {
            try? QuickWinService.logWin(
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
                    if back > 0, i != 1, let log = win.habit.logs.first(where: { $0.id == win.logID }) {
                        log.imageFileName = seedPhoto(
                            for: win.logID,
                            category: categories[n % categories.count]
                        )
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
