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

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.towerFilterMode) private var towerFilterMode
    @Environment(\.perfectDayDates) private var perfectDayDates

    private var style: CategoryStyle {
        block.habit.category.style
    }

    private var borderHighlight: Color { style.lightTint }

    private var blockFrame: CGRect {
        block.frame(cellSize: cellSize)
    }

    private var patinaOpacity: Double {
        guard towerFilterMode != .day else { return 0 }
        guard perfectDayDates.contains(block.log.dateString) else { return 0 }
        guard let blockDate = BlockTimeFormatter.dateFormatter.date(from: block.log.dateString) else {
            return GridConstants.patinaMaxOpacity
        }
        let daysAgo = max(0, Calendar.current.dateComponents([.day], from: blockDate, to: Date()).day ?? 0)
        return min(GridConstants.patinaMaxOpacity, 0.05 + Double(daysAgo) * GridConstants.patinaGrowthRate)
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
                    .init(color: colorScheme == .dark ? style.darkShade : style.baseColor, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))

            // Frosted gradient overlay — subtle white mist at the bottom (light mode only)
            if colorScheme == .light {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Text content: title + time + category icon
            BlockContentOverlay(
                title: block.habit.title,
                category: block.habit.category,
                rowSpan: block.rowSpan,
                timeText: timeText,
                hasDrawerContent: block.log.hasDrawerContent
            )
        }
        .frame(width: blockFrame.width, height: blockFrame.height)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        // Overlay 1: Crisp border — visible at top, fades toward bottom
        .overlay(
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: borderHighlight.opacity(0.55), location: 0.0),
                            .init(color: borderHighlight.opacity(0.20), location: 0.4),
                            .init(color: borderHighlight.opacity(0.0), location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
        )
        // Overlay 2: Diffused border — invisible at top, soft glow at bottom
        .overlay(
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: borderHighlight.opacity(0.0), location: 0.0),
                            .init(color: borderHighlight.opacity(0.20), location: 0.45),
                            .init(color: borderHighlight.opacity(0.35), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )
                .blur(radius: 6)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
                .drawingGroup()
        )
        // Single soft ambient shadow
        .shadow(
            color: colorScheme == .dark
                ? style.glow
                : .black.opacity(GridConstants.shadowOpacity),
            radius: colorScheme == .dark ? 8 : GridConstants.shadowRadius,
            x: 0,
            y: colorScheme == .dark ? 0 : GridConstants.shadowY
        )
        // Perfect-day golden patina (week/month views only)
        .overlay {
            if patinaOpacity > 0 {
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .stroke(GridConstants.patinaGold.opacity(patinaOpacity), lineWidth: 2)
            }
        }
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
        .accessibilityLabel("\(block.habit.title), \(block.habit.category.rawValue)")
        .accessibilityHint("Tap to expand")
        .onTapGesture {
            HapticsEngine.lightTap()
            tapTrigger += 1
            onTap()
        }
    }

}

// MARK: - Shared Block Content Overlay

struct BlockContentOverlay: View {
    let title: String
    let category: HabitCategory
    let rowSpan: Int
    let timeText: String?
    var hasImage: Bool = false
    var hasDrawerContent: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Category icon — top-left badge
            Image(systemName: category.iconName)
                .font(.system(size: GridConstants.iconCategory, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
                .shadow(color: .black.opacity(hasImage ? 0.3 : 0), radius: 2, x: 0, y: 1)
                .padding(.leading, 8)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Title + time — bottom-left
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(title)
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .lineLimit(rowSpan > 1 ? 2 : 1)
                    .minimumScaleFactor(0.65)

                if let time = timeText {
                    Text(time)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white.opacity(0.8))
                        .contentTransition(.interpolate)
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.leading, 8)
            .padding(.bottom, 8)
            .padding(.trailing, 8)

            // Conditional chevron — bottom-center
            if hasDrawerContent {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: GridConstants.iconSmall))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 4)
                    .accessibilityLabel("Has additional content")
            }

            // Photo indicator badge — top-right (Recognition over Recall)
            if hasImage {
                Image(systemName: "photo.fill")
                    .font(.system(size: GridConstants.iconSmall))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    .accessibilityLabel("Has photo")
            }
        }
    }
}
