import SwiftUI
import SwiftData

// MARK: - Smart Brick View (Clay Cartridge)

struct FlippableBlockView: View {
    let block: PlacedBlock
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let modelContext: ModelContext
    /// Sides that continue into a same-colour neighbour.
    var merged: MergedEdges = .none
    /// Something is resting directly on this block.
    var isCovered: Bool = false
    var onTap: (() -> Void)? = nil
    var showOverlay: Bool = true

    @State private var tapTrigger: Int = 0

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.towerFilterMode) private var towerFilterMode
    @Environment(\.perfectDayDates) private var perfectDayDates

    // displayCategory, not category: an unchosen block still needs a colour.
    private var style: CategoryStyle { block.habit.displayCategory.style }
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
        BlockSurface(
            cornerRadius: cornerRadius,
            // A white overlay floors the composite's luminance at its own alpha,
            // so the full 0.20 wash under white text caps contrast below 4.5:1
            // however dark the scrim beneath it is. The source escapes this
            // because its text sits near the TOP of the band on a 565pt block.
            washOpacity: hasImage ? 0.06 : GridConstants.blockScrimOpacity,
            merged: merged
        ) {
            ZStack {
            if hasImage {
                CachedImageView(
                    fileName: block.log.imageFileName,
                    width: width,
                    height: height,
                    cornerRadius: 0
                )

                RadialGradient(
                    colors: [
                        .clear,
                        AppColors.warmBlack.opacity(0.12)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: min(width, height) * 0.25,
                    endRadius: max(width, height) * 0.85
                )

                // Anchored to where the TEXT starts, not to a fraction of
                // height. Title + time + spacing + padding is ~40pt, so text
                // begins around 54% of an 86pt row, while a proportional ramp
                // does not reach full dark until 81% — fine on Figma's 565pt
                // block, and it leaves the title over open photo detail here.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    // A veil, not a shade.
                    //
                    // This was warmBlack at 0.80 — near-opaque, so the bottom
                    // third of every photo was simply gone, and it read as a
                    // caption bar stuck on rather than as part of the block.
                    // A softer ramp holding a lighter floor keeps the photo
                    // visible under the title while still carrying it.
                    //
                    // The title above it gains its own shadow, which is what
                    // buys back the contrast the darkness used to force.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: AppColors.warmBlack.opacity(0.16), location: 0.35),
                            .init(color: AppColors.warmBlack.opacity(0.40), location: 0.72),
                            .init(color: AppColors.warmBlack.opacity(0.48), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(84, height * 0.95))
                }

            } else {
                // Flat colour.
                //
                // This was a gradient washing lightTint at 0.7 across the top
                // quarter. Measured off a screenshot it put ~30% white into the
                // top of every block, which with the frosted band's ~20% at the
                // bottom left the colour only actually reaching full saturation
                // across the middle third. The block read as lit from two
                // directions and washed out at both ends.
                //
                // The rim is what says "lit from above" now, and it says it
                // with one crisp edge rather than a quarter-block of haze.
                style.baseColor
            }

            }
        }
        .frame(width: width, height: height)
        // Text above the blurred band so it stays sharp
        .overlay {
            if showOverlay {
                BlockContentOverlay(
                    title: block.habit.title,
                    category: block.habit.category,
                    rowSpan: block.rowSpan,
                    timeText: timeText,
                    hasImage: hasImage
                )
            }
        }
        // CONTACT SHADE.
        //
        // Stacked objects darken where another one sits on them. Without it
        // every block is lit as if it were alone, and a tower of them reads as
        // tiles on a wall rather than as a structure carrying its own weight.
        // Top edge only, short, and never across a merged seam — inside one
        // piece there is nothing resting on anything.
        .overlay(alignment: .top) {
            if isCovered && !merged.contains(.top) {
                LinearGradient(
                    colors: [
                        AppColors.warmBlack.opacity(GridConstants.blockContactShade),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(14, height * 0.22))
                .allowsHitTesting(false)
            }
        }
        // Perfect-day patina — golden surface wash
        .overlay {
            if patinaOpacity > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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

        .contentShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
        // #495: Smart Invert — photos excluded from color inversion
        .accessibilityIgnoresInvertColors(hasImage)

        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    HapticsEngine.lightTap()
                    tapTrigger += 1
                    onTap?()
                }
        )
    }
}
