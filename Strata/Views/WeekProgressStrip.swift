import SwiftUI

struct WeekProgressStrip: View {
    let weekData: [DayProgressData]
    @Binding var selectedDate: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let healthGreen = AppColors.healthGreen

    /// Count of completed days (completionRate == 1.0)
    private var completedCount: Int {
        weekData.filter { !$0.isFuture && $0.completionRate >= 1.0 }.count
    }

    /// Total non-future days
    private var totalCount: Int {
        weekData.filter { !$0.isFuture }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Day circles with completion rings
            HStack(spacing: 0) {
                ForEach(Array(weekData.enumerated()), id: \.element.id) { index, day in
                    DayCircleView(
                        day: day,
                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate),
                        isStreakEnd: isStreakEnd(at: index),
                        isStreakStart: isStreakStart(at: index),
                        reduceMotion: reduceMotion,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = day.date
                            }
                            HapticsEngine.tick()
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }

            // Progress summary
            if totalCount > 0 {
                Text("\(completedCount) of \(totalCount) completed")
                    .font(Typography.caption)
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Streak Detection

    private func isStreakStart(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let current = weekData[index]
        let prev = weekData[index - 1]
        return current.completionRate >= 1.0 && prev.completionRate >= 1.0
            && !current.isFuture && !prev.isFuture
    }

    private func isStreakEnd(at index: Int) -> Bool {
        guard index < weekData.count - 1 else { return false }
        let current = weekData[index]
        let next = weekData[index + 1]
        return current.completionRate >= 1.0 && next.completionRate >= 1.0
            && !current.isFuture && !next.isFuture
    }
}

// MARK: - Day Circle

private struct DayCircleView: View {
    let day: DayProgressData
    let isSelected: Bool
    let isStreakEnd: Bool
    let isStreakStart: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var animatedRate: Double = 0
    @State private var todayPulse: Bool = false
    @State private var tapScale: CGFloat = 1.0

    private let healthGreen = AppColors.healthGreen

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(day.dayLabel)
                    .font(Typography.caption2)
                    .foregroundStyle(
                        day.isFuture ? Color.primary.opacity(0.4) : Color.primary.opacity(0.55)
                    )

                ZStack {
                    // Track ring
                    Circle()
                        .stroke(
                            day.isFuture ? Color.primary.opacity(0.06) : Color.primary.opacity(0.08),
                            lineWidth: 2.5
                        )
                        .frame(width: 36, height: 36)

                    // Completion ring (animated trim)
                    if !day.isFuture && animatedRate > 0 {
                        Circle()
                            .trim(from: 0, to: animatedRate)
                            .stroke(
                                healthGreen,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                    }

                    // Today highlight (green pulse)
                    if day.isToday {
                        Circle()
                            .fill(healthGreen.opacity(0.12))
                            .frame(width: 32, height: 32)
                            .scaleEffect(todayPulse ? 1.05 : 1.0)
                    }

                    // Selected (non-today) highlight — warm accent fill
                    if isSelected && !day.isToday {
                        Circle()
                            .fill(AppColors.accentWarm.opacity(0.15))
                            .frame(width: 32, height: 32)
                    }

                    // Day number
                    Text("\(day.dayNumber)")
                        .font(Typography.headerSmall)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundStyle(
                            day.isFuture ? Color.primary.opacity(0.4) : Color.primary
                        )

                    // Streak connector (leading line to previous day)
                    if isStreakStart {
                        Rectangle()
                            .fill(healthGreen.opacity(0.3))
                            .frame(width: 20, height: 2)
                            .offset(x: -28)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(tapScale)
        .onAppear {
            if !day.isFuture && day.completionRate > 0 {
                if reduceMotion {
                    animatedRate = day.completionRate
                } else {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                        animatedRate = day.completionRate
                    }
                }
            }
            if day.isToday && !reduceMotion {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    todayPulse = true
                }
            }
        }
        .onChange(of: day.completionRate) { _, newRate in
            if reduceMotion {
                animatedRate = newRate
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animatedRate = newRate
                }
            }
        }
        .onChange(of: isSelected) { _, selected in
            guard !reduceMotion else { return }
            if selected {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    tapScale = 1.05
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6).delay(0.1)) {
                    tapScale = 1.0
                }
            }
        }
    }
}
