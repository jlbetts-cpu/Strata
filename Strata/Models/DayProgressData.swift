import Foundation

/// Per-habit status summary for Week Matrix visualization
struct HabitSummary: Identifiable {
    let id: UUID
    let category: HabitCategory
    let isCompleted: Bool
    let isSkipped: Bool
    let effectiveHour: Double?  // For chronological sorting (nil = unscheduled)
}

struct DayProgressData: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let dayNumber: Int
    let completionRate: Double
    let completedCount: Int
    let skippedCount: Int
    let totalCount: Int
    let isToday: Bool
    let isFuture: Bool
    let habits: [HabitSummary]

    /// Fraction of habits "handled" (completed + skipped)
    var handledRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount + skippedCount) / Double(totalCount)
    }

    /// Remaining habits (neither completed nor skipped)
    var remainingCount: Int {
        max(0, totalCount - completedCount - skippedCount)
    }
}
