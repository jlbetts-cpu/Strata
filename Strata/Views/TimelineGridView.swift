import SwiftUI

/// Google Calendar-style hourly timeline for the Today screen.
/// Architecture: VStack per hour (not global ZStack) — each hour gets REAL layout space.
/// Research: Barkley 2015 (now line), Tufte 2001 (linear time scale), MDPI 2024 (visual cues for ADHD).
struct TimelineGridView: View {
    let scheduledHabits: [Habit]
    let calendarEvents: [CalendarAnchor]
    let completedHabitIDs: Set<UUID>
    let skippedHabitIDs: Set<UUID>
    let cachedNowFraction: Double
    let onComplete: (Habit) -> Void
    let onSkip: (Habit) -> Void
    let onUndo: (Habit) -> Void
    let onUndoSkip: (Habit) -> Void
    var cachedStreaks: [UUID: Int] = [:]
    var healthKitProgress: [UUID: Double] = [:]
    var verifiedHabitIDs: Set<UUID> = []

    @Environment(\.colorScheme) private var colorScheme

    private let startHour = 5
    private let endHour = 23
    private let hourHeight: CGFloat = 60  // 1pt per minute (Tufte 2001: linear scale)
    private let gutterWidth: CGFloat = 56

    // Group habits by their start hour for efficient lookup
    private var habitsByHour: [Int: [Habit]] {
        var result: [Int: [Habit]] = [:]
        for habit in scheduledHabits {
            if let h = TimelineViewModel.effectiveHour(for: habit) {
                let hourKey = Int(h)
                result[hourKey, default: []].append(habit)
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                ZStack(alignment: .topLeading) {
                    // Hour label + grid line (background layer)
                    HStack(spacing: 0) {
                        Text(hourLabel(hour))
                            .font(Typography.caption2)
                            .foregroundStyle(Color.primary.opacity(0.35))
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 8)

                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.primary.opacity(GridConstants.opacityGhost))
                                .frame(height: 0.5)
                            Spacer()
                        }
                    }

                    // Habit blocks starting in this hour
                    if let habits = habitsByHour[hour] {
                        ForEach(habits, id: \.id) { habit in
                            if let effectiveH = TimelineViewModel.effectiveHour(for: habit) {
                                let minuteOffset = CGFloat(effectiveH - Double(hour)) * hourHeight
                                let blockHeight = max(CGFloat(habit.blockSize.durationMinutes), 44)

                                TimelineHabitRow(
                                    habit: habit,
                                    rowHeight: blockHeight,
                                    cornerRadius: GridConstants.cornerRadiusSmall,
                                    onComplete: onComplete,
                                    onSkip: onSkip,
                                    onUndo: onUndo,
                                    onUndoSkip: onUndoSkip,
                                    isAlreadyCompleted: completedHabitIDs.contains(habit.id),
                                    isAlreadySkipped: skippedHabitIDs.contains(habit.id),
                                    currentStreak: cachedStreaks[habit.id] ?? 0,
                                    healthKitProgress: healthKitProgress[habit.id] ?? 0,
                                    isHealthKitVerified: verifiedHabitIDs.contains(habit.id)
                                )
                                .padding(.leading, gutterWidth + 12)
                                .padding(.trailing, GridConstants.horizontalPadding)
                                .offset(y: minuteOffset) // Small offset WITHIN hour (0-59pt max)
                            }
                        }
                    }

                    // Now line — only in the hour that contains current time
                    let currentHour = Int(cachedNowFraction)
                    if currentHour == hour && cachedNowFraction >= Double(startHour) {
                        let minuteOffset = CGFloat(cachedNowFraction - Double(hour)) * hourHeight
                        HStack(spacing: 0) {
                            Circle()
                                .fill(AppColors.warmRed)
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(AppColors.warmRed)
                                .frame(height: 2)
                        }
                        .padding(.leading, gutterWidth)
                        .offset(y: minuteOffset)
                        .accessibilityLabel("Current time")
                    }
                }
                .frame(height: hourHeight) // Each hour gets REAL 60pt layout space
                .clipped() // Prevent overflow into adjacent hours
                .id("hour-\(hour)") // For outer ScrollViewReader
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h) \(period)"
    }
}
