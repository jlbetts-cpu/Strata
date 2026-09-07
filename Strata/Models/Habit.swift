import Foundation
import SwiftData

// MARK: - Enums

enum HabitCategory: String, Codable, CaseIterable {
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

enum BlockSize: String, Codable, CaseIterable {
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

enum DayCode: String, Codable, CaseIterable {
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
    var id: UUID
    var title: String
    var category: HabitCategory
    var blockSize: BlockSize
    var frequencyRawValues: [String]
    var createdAt: Date
    var scheduledTime: String?
    var reminderEnabled: Bool
    var isTodo: Bool
    var scheduledDate: String?
    var todoOrder: Int?
    var creationXP: Int
    var graceDays: Int
    var timeOfDay: TimeOfDay?
    var anchorHabitID: UUID?
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

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

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
        let recentLogs = logs.filter { $0.completed }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
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
