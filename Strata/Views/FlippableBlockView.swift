import SwiftUI
import SwiftData

// MARK: - Smart Brick View (Clay Cartridge)

struct FlippableBlockView: View {
    let block: PlacedBlock
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let modelContext: ModelContext
    /// True when this block is part of a merged run.
    ///
    /// The run is drawn once, as one shape, by `MergedGroupView` — so a settled
    /// member draws nothing at all and exists only for its tap target. That is
    /// what makes a merge genuinely one object: there is no second outline, no
    /// second band and no second shadow to leak through a seam, because there
    /// is no second anything.
    ///
    /// A member still draws itself while FALLING, so a block descends as a
    /// block and joins the shape on landing.
    var isGroupMember: Bool = false
    /// Drop the rim, the frosted band and the shadow.
    ///
    /// Set the instant a merging block LANDS. In the air it is a separate
    /// object and looks like one; on the ground it is about to be part of a
    /// larger shape, and a rim is an outline drawn around something that is
    /// supposed to have no edge there. Filmed at 60fps, that white outline was
    /// the last thing still announcing the join.
    var chromeless: Bool = false
    /// Something is resting directly on this block.
    var isCovered: Bool = false
    var onTap: (() -> Void)? = nil
    var showOverlay: Bool = true
    /// True while this block is the one being carried.
    var isLifted: Bool = false
    /// True when releasing would land the carried block here.

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
        // A member hides instantly. No crossfade.
        //
        // Fading it out was meant to soften the handover, and filmed at 60fps
        // it did the opposite: for the fifth of a second it took, the block was
        // half-transparent over a group that did not yet include its cell, so
        // the page showed through as a pale square sitting in the middle of the
        // shape. That is the ghost.
        //
        // Both this flag and the group's cells come from the same set —
        // `activelyAnimatingIDs`, cleared in one transaction with `dropPhase` —
        // so the block disappears on exactly the frame the group takes over.
        // With the colours identical and the chrome already stripped, that swap
        // has nothing left to see.
        Group {
            if isGroupMember {
                // A member draws its LABEL and nothing else.
                //
                // The run's surface — the fill, the rim, the band, the shadow
                // — is drawn once by `MergedGroupView`, so a member drawing
                // its own would put a second outline through the middle of one
                // shape. But now that named blocks merge, it still has
                // something to say: the words sit on the merged surface the
                // way words sit on a wall, and the wall is still one wall.
                BlockContentOverlay(
                    title: block.habit.title,
                    category: block.habit.category,
                    rowSpan: block.rowSpan,
                    timeText: nil,
                    hasImage: false
                )
                .frame(width: width, height: height)
            } else {
                blockBody
            }
        }
            // The tap belongs to the BLOCK, not to its chrome.
            //
            // It used to be attached inside `chromedBody`, which a merged
            // block never reaches: merging makes it `chromeless`, and that
            // branch is a bare rounded rect. So every block that had joined a
            // group silently lost its tap target and there was no way to open
            // a merged block to edit it. A member is also drawn at zero
            // opacity, so the hit area has to be declared here, after that,
            // rather than inherited from something visible.
            // Picked up, or marked as where it would land.
            //
            // A lifted block scales UP and gains a shadow — the two things
            // that read as "off the surface" without moving it, so the finger
            // stays over what it grabbed. The target dims rather than growing:
            // if both changed size the whole tower would ripple while you
            // dragged, and only one of them is in your hand.
            .scaleEffect(isLifted ? 1.06 : 1)
            .shadow(
                color: .black.opacity(isLifted ? 0.22 : 0),
                radius: isLifted ? 16 : 0,
                y: isLifted ? 10 : 0
            )
            // No dimming of the other blocks.
            //
            // That was here to make the lift legible when a 6% scale was the
            // only signal. It is not needed now and it actively hurts: the
            // whole point of reflowing live is to show you the rearranged
            // TOWER, and dimming forty blocks to 0.4 hides the very thing you
            // are being shown.
            .animation(GridConstants.slotSnap, value: isLifted)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        HapticsEngine.lightTap()
                        tapTrigger += 1
                        onTap?()
                    }
            )
    }

    @ViewBuilder
    private var blockBody: some View {
        if chromeless {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(style.baseColor)
                .frame(width: width, height: height)
        } else {
            chromedBody
        }
    }

    private var chromedBody: some View {
        BlockSurface(
            cornerRadius: cornerRadius,
            // A white overlay floors the composite's luminance at its own alpha,
            // so the full 0.20 wash under white text caps contrast below 4.5:1
            // however dark the scrim beneath it is. The source escapes this
            // because its text sits near the TOP of the band on a 565pt block.
            washOpacity: hasImage ? 0.06 : GridConstants.blockScrimOpacity
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
                // Only when there is a title to protect.
                //
                // The veil exists for one reason: white text on a photograph
                // is unreadable without it. A block nobody named draws no text
                // at all, so on those it was darkening the bottom of the
                // picture to make nothing legible — which is just a dark
                // gradient across a block, and a block is meant to be one flat
                // colour.
                if !BlockContentOverlay.isUnnamed(block.habit.title) {
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
                    // Lighter again (2026-09-09). It went 0.80 -> 0.48 once
                    // already; at 0.48 it is still a dark bar across the
                    // bottom of a photograph, and a dark bar is the one thing
                    // a block never has. The block is a flat lit plane and
                    // everything on it should read as lit.
                    //
                    // The title's own shadow is what carries the contrast now,
                    // which is why this can be a veil rather than a scrim.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: AppColors.warmBlack.opacity(0.08), location: 0.40),
                            .init(color: AppColors.warmBlack.opacity(0.20), location: 0.75),
                            .init(color: AppColors.warmBlack.opacity(GridConstants.photoVeilOpacity), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(84, height * 0.95))
                }
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
        .overlay {
            if isCovered {
                // Clipped to the block's own shape.
                //
                // Unclipped, this filled the square corners OUTSIDE the rounded
                // rect — a hard grey wedge at each top corner that read as a
                // rendering glitch, which is exactly what it was. It also has
                // to sit inside a full-size container: a 14pt-tall view clipped
                // to a 12pt corner radius rounds the gradient itself instead of
                // following the block.
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            AppColors.warmBlack.opacity(GridConstants.blockContactShade),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(14, height * 0.22))
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

        // #495: Smart Invert — photos excluded from color inversion
        .accessibilityIgnoresInvertColors(hasImage)
    }
}
