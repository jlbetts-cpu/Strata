import SwiftUI
import SwiftData

// MARK: - Smart Brick View (Clay Cartridge)

struct FlippableBlockView: View {
    let block: PlacedBlock
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let modelContext: ModelContext
    var onTap: (() -> Void)? = nil

    @State private var tapTrigger: Int = 0
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.towerFilterMode) private var towerFilterMode
    @Environment(\.perfectDayDates) private var perfectDayDates

    private var style: CategoryStyle { block.habit.category.style }
    private var borderHighlight: Color { style.lightTint }
    private var isBig: Bool { block.columnSpan > 1 || block.rowSpan > 1 }
    private var hasImage: Bool { block.log.imageFileName != nil }
    private var massTier: CGFloat { CGFloat(block.habit.blockSize.massTier) }
    private var tapSquashX: CGFloat { 1.02 - (massTier - 1) * 0.004 }
    private var tapSquashY: CGFloat { 0.97 + (massTier - 1) * 0.006 }

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
            if hasImage {
                // Photo block — loaded via CachedImageView
                CachedImageView(
                    fileName: block.log.imageFileName,
                    width: width,
                    height: height,
                    cornerRadius: 0
                )

                // Subtle warm vignette — safety net for icon on bright photos
                RadialGradient(
                    colors: [
                        .clear,
                        AppColors.warmBlack.opacity(0.12)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: min(width, height) * 0.25,
                    endRadius: max(width, height) * 0.85
                )

                // Warm dark scrim — gentle fade for text readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: AppColors.warmBlack.opacity(0.45), location: 0.70),
                        .init(color: AppColors.warmBlack.opacity(0.65), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

            } else {
                // Vertical gradient — top light, natural (Apple HIG)
                LinearGradient(
                    stops: [
                        .init(color: style.lightTint.opacity(0.7), location: 0.0),
                        .init(color: style.baseColor, location: 0.25),
                        .init(color: style.baseColor, location: 0.7),
                        .init(color: colorScheme == .dark ? style.darkShade : style.baseColor, location: 1.0)
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
                hasImage: hasImage,
                hasDrawerContent: block.log.hasDrawerContent
            )
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // No border — iOS 17-18: shadow alone carries depth
        .shadow(
            color: .black.opacity(colorScheme == .dark
                ? GridConstants.blockShadowOpacityDark
                : GridConstants.blockShadowOpacity),
            radius: GridConstants.blockShadowRadius,
            x: 0,
            y: GridConstants.blockShadowY
        )
        // Perfect-day patina — golden surface wash
        .overlay {
            if patinaOpacity > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GridConstants.patinaGold.opacity(patinaOpacity * 0.5))
                    .blendMode(.overlay)
            }
        }
        .drawingGroup()
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
        .contentShape(Rectangle())
        .onTapGesture {
            HapticsEngine.lightTap()
            tapTrigger += 1
            onTap?()
        }
    }
}
