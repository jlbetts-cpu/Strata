import SwiftUI

struct WeekProgressStrip: View {
    let weekData: [DayProgressData]
    @Binding var selectedDate: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false

    private let healthGreen = AppColors.healthGreen

    /// Choose animation based on reduceMotion
    private func anim(_ animation: Animation) -> Animation {
        reduceMotion ? GridConstants.motionReduced : animation
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekData, id: \.id) { day in
                    DayCircleView(
                        day: day,
                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate),
                        reduceMotion: reduceMotion,
                        onTap: {
                            withAnimation(anim(GridConstants.motionSmooth)) {
                                selectedDate = day.date
                            }
                            HapticsEngine.tick()
                        }
                    )
                    .frame(maxWidth: .infinity)
                    // Cascade entrance — left to right
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .animation(
                        reduceMotion ? .none :
                        GridConstants.gentleReveal.delay(Double(weekData.firstIndex(where: { $0.id == day.id }) ?? 0) * 0.03),
                        value: appeared
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            guard !appeared else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                appeared = true
            }
        }
    }
}

// MARK: - Day Circle (Minimal Ceramic Ring)

private struct DayCircleView: View {
    let day: DayProgressData
    let isSelected: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var animatedRate: Double = 0
    @State private var tapScale: CGFloat = 1.0

    private let healthGreen = AppColors.healthGreen
    private let circleSize: CGFloat = 40   // 4/8 grid alignment
    private let ringStroke: CGFloat = 2.0  // Crisp on all displays

    /// Choose animation based on reduceMotion
    private func anim(_ animation: Animation) -> Animation {
        reduceMotion ? GridConstants.motionReduced : animation
    }

    private static let accessibilityDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private var dayAccessibilityLabel: String {
        let dateStr = Self.accessibilityDateFormatter.string(from: day.date)
        let completionPct = Int(day.completionRate * 100)
        if day.isToday {
            return "Today, \(dateStr), \(completionPct)% completed"
        } else if day.isFuture {
            return "\(dateStr), upcoming"
        } else {
            return "\(dateStr), \(completionPct)% completed"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Day label
                Text(day.dayLabel)
                    .font(Typography.caption2)
                    .foregroundStyle(
                        day.isFuture ? Color.primary.opacity(0.5) : Color.primary.opacity(0.55)
                    )

                ZStack {
                    // Honest Ring: hide track when 0 habits (Rule 1: no ring > empty ring)
                    if day.totalCount > 0 {
                        Circle()
                            .stroke(
                                day.isFuture ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08),
                                lineWidth: ringStroke
                            )
                            .frame(width: circleSize, height: circleSize)
                    }

                    // Completed ring (green ceramic)
                    if !day.isFuture && animatedRate > 0 {
                        Circle()
                            .trim(from: 0, to: animatedRate)
                            .stroke(
                                healthGreen,
                                style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                            )
                            .frame(width: circleSize, height: circleSize)
                            .rotationEffect(.degrees(-90))
                    }

                    // Skipped ring (grey — Rule 3: skipped is not missed)
                    if !day.isFuture && day.skippedCount > 0 && day.totalCount > 0 {
                        let skipStart = Double(day.completedCount) / Double(day.totalCount)
                        let skipEnd = Double(day.completedCount + day.skippedCount) / Double(day.totalCount)
                        Circle()
                            .trim(from: skipStart, to: skipEnd)
                            .stroke(
                                Color.primary.opacity(0.5),
                                style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                            )
                            .frame(width: circleSize, height: circleSize)
                            .rotationEffect(.degrees(-90))
                    }

                    // Today highlight — subtle fill, no animation loop
                    if day.isToday {
                        Circle()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: circleSize - ringStroke, height: circleSize - ringStroke)
                    }

                    // Day number
                    Text("\(day.dayNumber)")
                        .font(Typography.bodySmall.weight(day.isToday || isSelected ? .bold : .regular))
                        .foregroundStyle(
                            day.isFuture ? Color.primary.opacity(0.5) : Color.primary
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44) // ADA minimum touch target
        .contentShape(Circle())
        .scaleEffect(tapScale)
        .accessibilityLabel(dayAccessibilityLabel)
        .accessibilityHint("Tap to view this day's habits")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onAppear {
            if !day.isFuture && day.completionRate > 0 {
                if reduceMotion {
                    animatedRate = day.completionRate
                } else {
                    withAnimation(GridConstants.progressFill.delay(0.2)) {
                        animatedRate = day.completionRate
                    }
                }
            }
        }
        .onChange(of: day.completionRate) { _, newRate in
            if reduceMotion {
                animatedRate = newRate
            } else {
                withAnimation(anim(GridConstants.progressFill)) {
                    animatedRate = newRate
                }
            }
        }
        .onChange(of: isSelected) { _, selected in
            guard !reduceMotion else { return }
            if selected {
                withAnimation(anim(GridConstants.motionSnappy)) {
                    tapScale = 1.03
                }
                withAnimation(anim(GridConstants.motionSmooth).delay(0.1)) {
                    tapScale = 1.0
                }
            }
        }
    }
}
