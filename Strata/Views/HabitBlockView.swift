import SwiftUI

// MARK: - Time Formatting Helpers

enum BlockTimeFormatter {
    /// Computes end time from a start "HH:mm" string + duration in minutes.
    static func endTime(_ startStr: String, durationMinutes: CGFloat) -> String {
        let parts = startStr.split(separator: ":")
        guard !parts.isEmpty, let h = Int(parts[0]) else { return startStr }
        let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let totalMinutes = h * 60 + m + Int(durationMinutes)
        let endH = (totalMinutes / 60) % 24
        let endM = totalMinutes % 60
        return String(format: "%02d:%02d", endH, endM)
    }

    /// Converts "14:00" → "2 PM", "14:30" → "2:30 PM"
    static func format12Hour(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard !parts.isEmpty, let h = Int(parts[0]) else { return timeStr }
        let m = parts.count > 1 ? String(parts[1]) : "00"
        let period = h < 12 ? "AM" : "PM"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return m == "00" ? "\(hour12) \(period)" : "\(hour12):\(m) \(period)"
    }

    private static let localeTimeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt
    }()

    /// Formats a Date using the user's locale (e.g. "3:30 PM" or "15:30")
    static func format12Hour(_ date: Date) -> String {
        localeTimeFormatter.string(from: date)
    }

    /// Returns a single timestamp for a block: completion time if available, otherwise scheduled start.
    static func timeRange(scheduledTime: String?, durationMinutes: CGFloat, completedAt: Date?) -> String? {
        if let completed = completedAt {
            return format12Hour(completed)
        } else if let time = scheduledTime {
            return format12Hour(time)
        }
        return nil
    }

    /// Converts "2026-03-19" → "3/19"
    static func dateLabel(from dateString: String) -> String {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return dateString }
        return "\(month)/\(day)"
    }

    /// Returns the appropriate display text based on filter mode.
    /// Day → time range, Week/Month → date label.
    static func displayText(
        filterMode: TowerFilterMode,
        dateString: String,
        scheduledTime: String?,
        durationMinutes: CGFloat,
        completedAt: Date?
    ) -> String? {
        switch filterMode {
        case .day:
            return timeRange(scheduledTime: scheduledTime, durationMinutes: durationMinutes, completedAt: completedAt)
        case .week, .month:
            return dateLabel(from: dateString)
        }
    }
}

// MARK: - Completed Block (Flat Squircle)

struct HabitBlockView: View {
    let block: PlacedBlock
    let cellSize: CGFloat
    let onTap: () -> Void

    @State private var tapTrigger: Int = 0
    @State private var breathePhase: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.towerFilterMode) private var towerFilterMode

    private var style: CategoryStyle {
        block.habit.category.style
    }

    private var blockFrame: CGRect {
        block.frame(cellSize: cellSize)
    }

    private var pendingXPString: String? {
        if let pendingXP = block.log.pendingXP, !block.log.xpCollected {
            return "+\(pendingXP) XP"
        }
        return nil
    }

    private var timeText: String? {
        BlockTimeFormatter.displayText(
            filterMode: towerFilterMode,
            dateString: block.log.dateString,
            scheduledTime: block.habit.scheduledTime,
            durationMinutes: block.habit.blockSize.durationMinutes,
            completedAt: block.log.completedAt
        )
    }

    var body: some View {
        ZStack {
            // Color fill — gradient from light tint at top to base color
            LinearGradient(
                stops: [
                    .init(color: style.lightTint, location: 0.0),
                    .init(color: style.baseColor, location: 0.3),
                    .init(color: style.baseColor, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))

            // Frosted gradient overlay — subtle white mist at the bottom
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.20), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Text content: title + time + category icon
            BlockContentOverlay(
                title: block.habit.title,
                category: block.habit.category,
                rowSpan: block.rowSpan,
                timeText: timeText,
                pendingXPText: pendingXPString
            )
        }
        .frame(width: blockFrame.width, height: blockFrame.height)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        // Overlay 1: Crisp white border — visible at top, fades toward bottom (breathing shimmer)
        .overlay(
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(breathePhase ? 0.95 : 0.85), location: 0.0),
                            .init(color: .white.opacity(0.4), location: 0.4),
                            .init(color: .white.opacity(0.0), location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
        )
        // Overlay 2: Diffused white border — invisible at top, soft glow at bottom
        .overlay(
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.35), location: 0.45),
                            .init(color: .white.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )
                .blur(radius: 6)
                .compositingGroup()
        )
        // Single soft ambient shadow
        .shadow(
            color: .black.opacity(GridConstants.adaptiveShadowOpacity(GridConstants.shadowOpacity, colorScheme: colorScheme)),
            radius: GridConstants.shadowRadius,
            x: 0,
            y: GridConstants.shadowY
        )
        // Tap bounce: fast squash → bouncy pop-back
        .phaseAnimator([false, true], trigger: tapTrigger) { content, phase in
            content
                .scaleEffect(
                    x: phase ? GridConstants.tapScaleX : 1.0,
                    y: phase ? GridConstants.tapScaleY : 1.0
                )
                .brightness(phase ? -0.03 : 0)
        } animation: { phase in
            phase ? GridConstants.tapSquashSpring : GridConstants.tapPopSpring
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: tapTrigger)
        .accessibilityLabel("\(block.habit.title), \(block.habit.category.rawValue)")
        .accessibilityHint("Tap to expand")
        .onTapGesture {
            tapTrigger += 1
            onTap()
        }
        .onAppear {
            if !reduceMotion {
                let delay = Double.random(in: 0...0.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let breatheDuration = Double.random(in: 2.7...3.3)
                    withAnimation(.easeInOut(duration: breatheDuration).repeatForever(autoreverses: true)) {
                        breathePhase = true
                    }
                }
            }
        }
        .onDisappear {
            breathePhase = false
        }
    }

}

// MARK: - Incomplete Block (Muted/Outlined)

struct IncompleteBlockView: View {
    let habit: Habit
    let frame: CGRect
    let onComplete: () -> Void

    @State private var holdProgress: Double = 0

    private let holdDuration: Double = 0.6

    private var style: CategoryStyle {
        habit.category.style
    }

    var body: some View {
        ZStack {
            // Muted background
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .fill(style.darkShade.opacity(0.08))

            // Hold progress fill
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .fill(style.baseColor.opacity(0.4))
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: frame.height * holdProgress)
                }

            // Border
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(style.darkShade.opacity(0.2), lineWidth: 1.5)

            // Label
            VStack(alignment: .leading) {
                Spacer()
                Text(habit.title)
                    .font(blockFont)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .lineLimit(habit.blockSize.rowSpan > 1 ? 2 : 1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.leading, 12)
            .padding(.bottom, 8)
            .padding(.trailing, 8)
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: holdDuration, perform: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onComplete()
            withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
        }, onPressingChanged: { pressing in
            if pressing {
                withAnimation(.linear(duration: holdDuration)) { holdProgress = 1.0 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
            }
        })
    }

    private var blockFont: Font {
        switch habit.blockSize {
        case .small: return Typography.caption2
        case .medium: return Typography.caption
        case .hard: return Typography.bodyMedium
        }
    }
}

// MARK: - Shared Block Content Overlay

struct BlockContentOverlay: View {
    let title: String
    let category: HabitCategory
    let rowSpan: Int
    let timeText: String?
    let pendingXPText: String?
    var hasImage: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Category icon — top-left badge
            Image(systemName: category.iconName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
                .shadow(color: .black.opacity(hasImage ? 0.3 : 0), radius: 2, x: 0, y: 1)
                .padding(.leading, 8)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Title + time — bottom-left
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(rowSpan > 1 ? 2 : 1)
                    .minimumScaleFactor(0.65)

                if let time = timeText {
                    Text(time)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .contentTransition(.interpolate)
                } else if let xp = pendingXPText {
                    Text(xp)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .contentTransition(.interpolate)
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.leading, 8)
            .padding(.bottom, 8)
            .padding(.trailing, 8)
        }
    }
}
