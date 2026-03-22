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

    var iconName: String {
        switch self {
        case .health:      return "heart.fill"
        case .work:        return "briefcase.fill"
        case .creativity:  return "paintbrush.fill"
        case .focus:       return "eye.fill"
        case .social:      return "person.2.fill"
        case .mindfulness: return "leaf.fill"
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

    var baseXP: Int {
        switch self {
        case .small: return 10
        case .medium: return 20
        case .hard: return 40
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
    @Attribute(.unique) var id: UUID
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
    var tower: Tower?

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

    var frequency: [DayCode] {
        get { frequencyRawValues.compactMap { DayCode(rawValue: $0) } }
        set { frequencyRawValues = newValue.map(\.rawValue) }
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
        graceDays: Int = 1,
        timeOfDay: TimeOfDay? = .anytime,
        parentHabitID: UUID? = nil,
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
        self.creationXP = Int.random(in: 1...10)
        self.graceDays = graceDays
        self.timeOfDay = timeOfDay
        self.parentHabitID = parentHabitID
        self.sortOrder = sortOrder
    }

    var isSubTask: Bool { parentHabitID != nil }
}
