#if DEBUG
import Foundation
import SwiftData

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
        return StrataTab.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
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

    /// True when this launch is a harness run at all. Used to suppress the
    /// HealthKit permission sheet, which is a system alert no script can
    /// dismiss and which covers whatever was being photographed.
    static var isActive: Bool {
        startTab != nil || wantsSeed || openSheet != nil
    }

    /// True when the run asked for seeding, so `setup()` knows to wipe first.
    static var wantsSeed: Bool {
        argument("-strataSeedWins") != nil
            || argument("-strataSeedHabits") != nil
            || argument("-strataSeedUnlabeled") != nil
            || argument("-strataAutoWin") != nil
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
        for i in 0..<mono {
            try? QuickWinService.logWin(
                title: "", category: .health,
                size: sizes[i % sizes.count],
                context: context, tower: tower
            )
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
        try? context.save()
    }
}
#endif
