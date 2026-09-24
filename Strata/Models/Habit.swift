import Foundation
import SwiftData

// MARK: - Enums

nonisolated enum HabitCategory: String, Codable, CaseIterable, Sendable {
    case health
    case work
    case creativity
    case focus
    case social
    case mindfulness
    /// A win logged before it was described. Neutral on purpose — the colour
    /// system is for categories you chose, and this one has not been chosen yet.
    /// Naming a win later moves it to a real category.
    case unlabeled

    /// Categories a person can pick. `unlabeled` is a state, not a choice, so it
    /// never appears in a picker.
    static var selectable: [HabitCategory] {
        allCases.filter { $0 != .unlabeled }
    }

    /// SF Symbol for the category, or nil when it has none.
    ///
    /// `unlabeled` has no icon on purpose. An icon here has one job — to say
    /// which of six categories this is — and an unlabeled win is not any of
    /// them. A grey `circle.fill` answered that question with a shrug, and put
    /// a mark on the block where a mark means something.
    ///
    /// Optional rather than a sentinel string so the compiler names every
    /// render site instead of leaving one quietly drawing a dot.
    var iconName: String? {
        switch self {
        case .health:      return "heart.fill"
        case .work:        return "briefcase.fill"
        case .creativity:  return "paintbrush.fill"
        case .focus:       return "eye.fill"
        case .social:      return "person.2.fill"
        case .mindfulness: return "leaf.fill"
        case .unlabeled:   return nil
        }
    }
}

nonisolated enum BlockSize: String, Codable, CaseIterable, Sendable {
    case small    // 1x1
    case medium   // 2x1
    case hard     // 2x2

    var columnSpan: Int {
        switch self {
        case .small: return 1
        case .medium, .hard: return 2
        }
    }

    var rowSpan: Int {
        switch self {
        case .small, .medium: return 1
        case .hard: return 2
        }
    }

    /// Mass tier for physics: 1 (light), 2 (medium), 3 (heavy)
    var massTier: Int {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    /// Default duration in minutes for timeline sizing
    var durationMinutes: CGFloat {
        switch self {
        case .small: return 15
        case .medium: return 30
        case .hard: return 60
        }
    }

    /// Aspect ratio for photo crop overlay — matches real block proportions
    var cropAspectRatio: CGFloat {
        let cell: CGFloat = 85 // representative cellSize; ratio varies <1% across devices
        let s = GridConstants.spacing
        let w = CGFloat(columnSpan) * cell + CGFloat(columnSpan - 1) * s
        let h = CGFloat(rowSpan) * cell + CGFloat(rowSpan - 1) * s
        return w / h
    }

    /// Premium effort label — effort ≠ time (Kahneman 2011)
    var effortLabel: String {
        switch self {
        case .small: return "Quick"
        case .medium: return "Regular"
        case .hard: return "Deep"
        }
    }
}

enum TimeOfDay: String, Codable, CaseIterable {
    case morning
    case afternoon
    case evening
    case anytime
}

/// `nonisolated`: `HabitEntityQuery` reads `DayCode.today()` from an App
/// Intent, which runs off the main actor. Default main-actor isolation would
/// otherwise make that a Swift 6 error.
nonisolated enum DayCode: String, Codable, CaseIterable {
    case su = "Su"
    case mo = "Mo"
    case tu = "Tu"
    case we = "We"
    case th = "Th"
    case fr = "Fr"
    case sa = "Sa"

    static func from(weekday: Int) -> DayCode {
        switch weekday {
        case 1: return .su
        case 2: return .mo
        case 3: return .tu
        case 4: return .we
        case 5: return .th
        case 6: return .fr
        case 7: return .sa
        default: return .su
        }
    }

    static func today() -> DayCode {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return from(weekday: weekday)
    }
}

// MARK: - Habit Model

@Model
final class Habit {
    // **Every attribute below is optional or carries a default, and that is a
    // rule now rather than a habit.** CloudKit's mirroring refuses a schema in
    // which a non-optional attribute has no default, because there is nothing
    // for it to put in the field when a record arrives without one. Ten
    // properties on this model broke that rule.
    //
    // Nothing changed type, changed name or went away, and the initialiser
    // below still assigns every one of them, so no value anybody has is
    // touched and no behaviour moves. A default is not part of Core Data's
    // version hash, so the store opens in place with no migration plan, which
    // is the same shape `planItemID`, `sortOrder` and `isQuickWin` already use
    // further down this file. Each default is the value the initialiser would
    // have produced anyway, so the two cannot disagree.
    //
    // MARK: The dead fields, and the decision not to remove them
    //
    // **Nothing was deleted when CloudKit went on, and that was a decision
    // rather than an oversight.** The moment looked like the cheap one:
    // `tasks/backlog.md` lists fourteen dead fields and a "kept for migration"
    // convention, the owner's own store was empty, and a CloudKit schema can
    // only gain fields once it is deployed to production, never lose them.
    //
    // Measured by counting reads outside the model files, the dead list is
    // longer than the backlog says. Never read anywhere: `healthKitType`,
    // `healthKitThreshold`, `anchorHabitID`, `parentHabitID`,
    // `isStepCompleted`, `isInProgress`, `isSaved`, `todoOrder` and
    // `customDurationMinutes` (with `effectiveDurationMinutes`, the only thing
    // that reads it, which has no callers either); on `HabitLog`, `imageURL`,
    // `videoURL`, `imageFlipped`, `pendingXP` and `verifiedByHealthKit`; on
    // `MoodLog`, `imageURL` and `videoURL`. Read only by `StoreRecordDigest`,
    // which exists to notice values going missing: `creationXP`, `surgeMode`,
    // `xpCollected`, `isBonusBlock`. Still alive: `imageData`, which
    // `ImageMigrationRunner` reads to turn an old blob into a photograph on
    // disk, and `subtasks`, which the backup export writes.
    //
    // They were kept, for three reasons in order of weight:
    //
    // 1. **Not one of them blocks CloudKit.** Every one is already optional or
    //    defaulted, so removing them buys the mirroring validator nothing. The
    //    work would be a tidy paid for with risk.
    // 2. **A deleted field is somebody's data.** The owner's store is empty;
    //    the build already out is not the only copy of this app. `imageData` is
    //    the loud one, and it would have to go in the same pass for the pass to
    //    be worth doing: a phone whose migration has never finished still has
    //    its photographs in there and nowhere else.
    // 3. **A column costs nothing to carry.** CloudKit charges for bytes, not
    //    for fields, and a nil field is no bytes. The real cost is that the
    //    production schema keeps their names for good, and that is a cost in
    //    tidiness.
    //
    // The condition for removing them, if it is ever wanted: one pass, with a
    // `VersionedSchema` and a `SchemaMigrationPlan` (this app has neither),
    // after `imageData` has been proven empty on a real store, and BEFORE the
    // CloudKit schema is deployed to production. After that deployment it stops
    // being possible.
    var id: UUID = UUID()
    var title: String = ""
    /// `.unlabeled` because that is this app's word for "nobody has chosen
    /// one", which is the honest reading of a field with nothing in it.
    var category: HabitCategory = HabitCategory.unlabeled
    var blockSize: BlockSize = BlockSize.small
    /// Every day, the same as the initialiser's own default
    /// (`DayCode.allCases`). It was `[]`, which disagreed with the initialiser:
    /// a synced record arriving without the field would have been scheduled on
    /// no days at all. Written as a literal in `DayCode.allCases` order so the
    /// default does not depend on evaluating an enum inside the model macro.
    var frequencyRawValues: [String] = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    var createdAt: Date = Date()
    var scheduledTime: String?
    var reminderEnabled: Bool = false
    var isTodo: Bool = false
    var scheduledDate: String?
    var todoOrder: Int?
    var creationXP: Int = 0
    /// 2, the same number the initialiser defaults to.
    var graceDays: Int = 2
    /// When this was last changed by an edit, as opposed to when it was made.
    ///
    /// **Added now because it can only be added now for free.** Once the
    /// CloudKit schema is live it is add-only, and a shared copy of a win
    /// (never the private row itself) has to know whether it is stale.
    /// CloudKit's own modification date belongs to the record, not to the
    /// edit, and SwiftData does not expose it. Stamped on every save by
    /// `StoreStamp`, never by hand at a call site, so a new edit path cannot
    /// forget it. Existing rows are backfilled once by `SocialFieldsBackfill`.
    var updatedAt: Date = Date()
    var timeOfDay: TimeOfDay?
    var anchorHabitID: UUID?

    /// The plan line this win was created from, if it came from one.
    ///
    /// **So a tick can be taken back.** Completing a plan line drops a block
    /// and checks the line, but nothing pointed the other way — delete the
    /// block and the line stayed checked, claiming something that no longer
    /// existed. Optional with a nil default, which is the shape SwiftData
    /// migrates without a plan (the same as `towerOrder`).
    var planItemID: UUID?
    var parentHabitID: UUID?
    var sortOrder: Int = 0
    var isStepCompleted: Bool = false
    var isInProgress: Bool = false
    var isSaved: Bool = false
    /// True for a win logged straight onto the tower.
    ///
    /// A win and a one-off task are the same shape in the schema — both are
    /// `isTodo` with today's date and no weekday — so nothing could tell them
    /// apart after the task was ticked. The checklist needs to: a win is
    /// something you already did and it lives on the tower, so listing it among
    /// things to accomplish is noise.
    ///
    /// Defaulted rather than optional, which SwiftData migrates in place.
    /// Existing wins keep `false` and fall back to the shape test in
    /// `QuickWinService.isWin`.
    var isQuickWin: Bool = false
    /// A colour for a block whose category nobody has chosen yet.
    ///
    /// A win logged in one tap has no category — that is the point of one tap —
    /// but a colourless block does not belong on a page made of colour. So the
    /// two facts are stored separately: `category` stays `.unlabeled`, which is
    /// what suppresses the icon, and this carries a colour picked at random so
    /// the block still looks like part of the tower.
    ///
    /// Choosing a category sets `category` and this stops mattering.
    var spontaneousCategoryRaw: String?

    var healthKitType: String?        // "stepCount", "workout.running", "mindfulSession"
    var healthKitThreshold: Double?   // 10000 (steps), 30 (minutes), 0 (presence-only)
    var customDurationMinutes: Int?   // nil = use BlockSize default. Decoupled: effort ≠ duration (Kahneman 2011)
    var tower: Tower?
    var planFolder: PlanFolder?

    /// **Optional, and that is CloudKit's rule, not a style.** Run against
    /// this schema on 2026-09-16, the mirroring validator refused it with
    /// "CloudKit integration requires that all relationships be optional, the
    /// following are not: Habit: logs, PlanFolder: habits, Tower: habits".
    /// The research audit had passed these because a Swift array with a
    /// default looks optional; to Core Data a to-many that is not `?` is a
    /// mandatory relationship. Read it as `logs ?? []`.
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]? = []

    var frequency: [DayCode] {
        get { frequencyRawValues.compactMap { DayCode(rawValue: $0) } }
        set { frequencyRawValues = newValue.map(\.rawValue) }
    }

    /// The category to DRAW this block in.
    ///
    /// Never use this for the icon. An icon names a category, so a block whose
    /// category was never chosen must not have one — that is `category`'s job,
    /// and `HabitCategory.unlabeled.iconName` is nil precisely so the compiler
    /// makes every render site handle it.
    var displayCategory: HabitCategory {
        guard category == .unlabeled else { return category }
        if let raw = spontaneousCategoryRaw, let c = HabitCategory(rawValue: raw) {
            return c
        }
        return .health
    }

    /// Effective duration — custom if set, otherwise BlockSize default
    var effectiveDurationMinutes: Int {
        customDurationMinutes ?? Int(blockSize.durationMinutes)
    }

    /// #99: Shame-free consistency label — "Active"/"On fire"/"Legendary" (not streak count)
    /// Uses positive language without exposing raw numbers (Fhynix ADHD research)
    var currentConsistencyLabel: String? {
        let recentLogs = (logs ?? []).filter { $0.completed }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        guard !recentLogs.isEmpty else { return nil }

        // Count consecutive days from today
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        for _ in 0..<365 {
            let dateStr = {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: checkDate)
            }()
            if recentLogs.contains(where: { $0.dateString == dateStr }) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        switch streak {
        case 0: return nil
        case 1...3: return "Active"
        case 4...13: return "On a roll"
        case 14...29: return "On fire"
        case 30...65: return "Unstoppable"
        default: return "Legendary"
        }
    }

    init(
        title: String,
        category: HabitCategory,
        blockSize: BlockSize = .small,
        frequency: [DayCode] = DayCode.allCases,
        scheduledTime: String? = nil,
        reminderEnabled: Bool = false,
        isTodo: Bool = false,
        scheduledDate: String? = nil,
        todoOrder: Int? = nil,
        graceDays: Int = 2,
        timeOfDay: TimeOfDay? = .anytime,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.blockSize = blockSize
        self.frequencyRawValues = frequency.map(\.rawValue)
        self.createdAt = Date()
        self.scheduledTime = scheduledTime
        self.reminderEnabled = reminderEnabled
        self.isTodo = isTodo
        self.scheduledDate = scheduledDate
        self.todoOrder = todoOrder
        self.creationXP = 0
        self.graceDays = graceDays
        self.timeOfDay = timeOfDay
        self.sortOrder = sortOrder
    }
}
