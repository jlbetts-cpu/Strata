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
    @Environment(\.towerFilterMode) private var towerFilterMode
    @Environment(\.perfectDayDates) private var perfectDayDates

    // displayCategory, not category: an unchosen block still needs a colour.
    private var style: CategoryStyle {
        block.habit.displayCategory.style
    }

    private var borderHighlight: Color { style.lightTint }
    private var massTier: CGFloat { CGFloat(block.habit.blockSize.massTier) }
    private var tapSquashX: CGFloat { 1.02 - (massTier - 1) * 0.004 }
    private var tapSquashY: CGFloat { 0.97 + (massTier - 1) * 0.006 }

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
        BlockSurface {
            style.baseColor
        }
        .frame(width: blockFrame.width, height: blockFrame.height)
        // Text sits ABOVE the blurred band, as in Figma — the title and time
        // nodes (255:107/108) are drawn after the band node, so they stay sharp
        // on a softened ground.
        .overlay(
            BlockContentOverlay(
                title: block.habit.title,
                category: block.habit.category,
                rowSpan: block.rowSpan,
                timeText: timeText
            )
        )
        // Perfect-day patina — golden surface wash (not stroke)
        .overlay {
            if patinaOpacity > 0 {
                RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
                    .fill(GridConstants.patinaGold.opacity(patinaOpacity * 0.5))
                    .blendMode(.overlay)
            }
        }
        // Tap bounce: fast squash → bouncy pop-back
        .phaseAnimator([false, true], trigger: tapTrigger) { content, phase in
            content
                .scaleEffect(
                    x: phase ? tapSquashX : 1.0,
                    y: phase ? tapSquashY : 1.0
                )
                .brightness(phase ? -0.03 : 0)
        } animation: { phase in
            phase ? GridConstants.tapSquashSpring : GridConstants.tapPopSpring
        }
        .accessibilityLabel("\(block.habit.title), \(block.habit.category.rawValue)")
        .accessibilityHint("Tap to expand")
        .contentShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
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

    /// A block nobody has named carries no text at all — no title, no time.
    ///
    /// "Win" is not a name, it is the absence of one, and a block that says it
    /// is louder than the thing it describes. Its presence already says "this
    /// happened"; a label repeating that is the only part of it that could be
    /// wrong. Naming it in the card gives it its text.
    private var isUnnamed: Bool {
        title == QuickWinService.untitled || title.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // An unlabeled win draws no icon: the corner mark says which of
            // six categories a block is, and this block is none of them.
            if let icon = category.iconName {
                Image(systemName: icon)
                    .font(.system(size: GridConstants.iconCategory, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .shadow(color: .black.opacity(hasImage ? 0.3 : 0), radius: 2, x: 0, y: 1)
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                if !isUnnamed {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(rowSpan > 1 ? 2 : 1)
                        .minimumScaleFactor(0.65)
                        // On a photo the scrim is a light veil now, so the type
                        // carries its own contrast instead of the block being
                        // darkened until anything would be legible on it.
                        .shadow(color: .black.opacity(hasImage ? 0.55 : 0), radius: 3, x: 0, y: 1)

                    if let time = timeText {
                        Text(time)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(hasImage ? 0.85 : 0.6))
                            .shadow(color: .black.opacity(hasImage ? 0.5 : 0), radius: 2, x: 0, y: 1)
                            .contentTransition(.interpolate)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.leading, 12)
            .padding(.bottom, 12)
            .padding(.trailing, 8)
        }
    }
}
