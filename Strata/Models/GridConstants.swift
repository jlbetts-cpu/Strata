import SwiftUI

enum GridConstants {
    static let columnCount = 4
    static let spacing: CGFloat = 8
    /// Figma Apollo (248:14) uses a constant 40px radius at every block size —
    /// not a proportional one. Against its 272px 1x1 block that is 14.7% of the
    /// side, which is 12.7pt at an 86.5pt cell; 12 keeps it on the 4pt grid.
    /// Was 16pt (18.5%), which read noticeably rounder than the source.
    static let cornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let headerTopPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 8
    static let headerDividerOpacity: Double = 0.06
    static let headerDividerHeight: CGFloat = 0.5
    static let timelineGutterWidth: CGFloat = 56

    // 1 block height = 3 meters for altimeter
    static let metersPerBlock: Double = 3.0

    // Minimum scaffold blocks for new users
    static let minimumScaffoldBlocks = 12

    // MARK: - Stroke
    static let strokeWidth: CGFloat = 2.5

    // MARK: - Animation Springs
    static let dropSquashSpring = Animation.spring(response: 0.12, dampingFraction: 0.60)
    static let dropStretchSpring = Animation.spring(response: 0.18, dampingFraction: 0.65)
    static let dropSettleSpring = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let rippleCompressSpring = Animation.spring(response: 0.12, dampingFraction: 0.55)
    static let rippleReleaseSpring = Animation.spring(response: 0.35, dampingFraction: 0.60)

    // MARK: - Squash & Stretch (linear in mass — rigid material)
    static func squashScaleY(mass: CGFloat) -> CGFloat { 0.025 * mass }
    static func squashScaleX(mass: CGFloat) -> CGFloat { 0.015 * mass }
    static func stretchScaleY(mass: CGFloat) -> CGFloat { 0.012 * mass }
    static func stretchScaleX(mass: CGFloat) -> CGFloat { 0.008 * mass }

    // MARK: - Shadow

    /// Single soft ambient shadow for depth
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
    static let shadowOpacity: Double = 0.10

    // MARK: - Tap Bounce
    static let tapSquashSpring = Animation.spring(duration: 0.06, bounce: 0.0)
    static let tapPopSpring = Animation.spring(duration: 0.22, bounce: 0.20)
    static let tapScaleX: CGFloat = 1.02
    static let tapScaleY: CGFloat = 0.97

    // MARK: - Wobble Settle
    static let wobbleSpring = Animation.spring(response: 0.18, dampingFraction: 0.65)
    static let wobbleDegreesLight: Double = 0.8
    static let wobbleDegreesHeavy: Double = 1.5

    // Compute the cell size (1x1 square side) from the available grid width
    static func cellSize(forGridWidth gridWidth: CGFloat) -> CGFloat {
        // gridWidth = (columnCount * cellSize) + ((columnCount - 1) * spacing)
        // cellSize = (gridWidth - (columnCount - 1) * spacing) / columnCount
        let totalSpacing = CGFloat(columnCount - 1) * spacing
        return floor((gridWidth - totalSpacing) / CGFloat(columnCount))
    }

    // Frame for a block given its grid position and computed cell size
    static func blockFrame(column: Int, row: Int, columnSpan: Int, rowSpan: Int, cellSize: CGFloat) -> CGRect {
        let x = CGFloat(column) * (cellSize + spacing)
        let y = CGFloat(row) * (cellSize + spacing)
        let w = CGFloat(columnSpan) * cellSize + CGFloat(columnSpan - 1) * spacing
        let h = CGFloat(rowSpan) * cellSize + CGFloat(rowSpan - 1) * spacing
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // Total grid height for N rows
    static func gridHeight(rows: Int, cellSize: CGFloat) -> CGFloat {
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * cellSize + CGFloat(rows - 1) * spacing
    }

    // Total grid width for the column count
    static func gridWidth(cellSize: CGFloat) -> CGFloat {
        CGFloat(columnCount) * cellSize + CGFloat(columnCount - 1) * spacing
    }

    // MARK: - Semantic Springs (reusable motion vocabulary)

    /// Taps, toggles — matches tapSquashSpring
    static let microResponse = Animation.spring(duration: 0.06, bounce: 0.0)
    /// Pop-back — matches tapPopSpring
    static let snapBack = Animation.spring(duration: 0.22, bounce: 0.20)
    /// Content appearing
    static let gentleReveal = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Settling — matches dropSettleSpring, reusable
    static let naturalSettle = Animation.spring(response: 0.28, dampingFraction: 0.78)
    /// Large elements settling
    static let heavySettle = Animation.spring(response: 0.40, dampingFraction: 0.80)
    /// Small celebratory bounces
    static let elasticPop = Animation.spring(response: 0.25, dampingFraction: 0.50)
    /// Bars, rings filling
    static let progressFill = Animation.spring(response: 0.60, dampingFraction: 0.70)
    /// Major layout changes (filter transitions, block expansion)
    static let layoutReflow = Animation.spring(response: 0.55, dampingFraction: 0.90)
    /// Non-spatial transitions (cross-fades)
    static let crossFade = Animation.easeInOut(duration: 0.2)
    /// Cascade reveal — new blocks dropping into tower
    static let cascadeReveal = Animation.spring(response: 0.50, dampingFraction: 0.65)

    // MARK: - Today Screen Motion (Timeline Claude)

    /// Tap feedback, check circles — fast, clean
    static let motionSnappy = Animation.spring(response: 0.25, dampingFraction: 0.82)
    /// Content transitions, schedule confirm, row state changes
    static let motionSmooth = Animation.spring(response: 0.30, dampingFraction: 0.78)
    /// Container changes, collapse/expand
    static let motionGentle = Animation.spring(response: 0.40, dampingFraction: 0.85)
    /// Completion settle, end-of-sequence
    static let motionSettle = Animation.spring(response: 0.50, dampingFraction: 0.90)
    /// Reduced motion fallback
    static let motionReduced = Animation.easeOut(duration: 0.05)
    /// Fill sweep duration
    static let fillSweepDuration: TimeInterval = 0.4

    /// Toggle/picker transitions (NewHabitMenu, HabitEditView, AllItemsView)
    static let toggleSwitch = Animation.spring(response: 0.30, dampingFraction: 0.80)
    /// Skeleton pop-in during loading
    static let skeletonPop = Animation.spring(response: 0.35, dampingFraction: 0.65)

    // MARK: - Filmstrip
    static let filmstripThumbnailSize: CGFloat = 56
    static let filmstripSpacing: CGFloat = 8

    // MARK: - Icon Sizes
    static let iconSmall: CGFloat = 8      // badges, chevrons, photo indicators
    static let iconMedium: CGFloat = 12    // next-up pill icons
    static let iconCategory: CGFloat = 13  // category icons on blocks
    static let iconAction: CGFloat = 14    // action buttons (close X, replace photo)
    static let iconToolbar: CGFloat = 17   // toolbar icons (gear)
    static let iconEmptyState: CGFloat = 36 // empty state hero icons
    static let iconHero: CGFloat = 40      // large hero elements
    static let iconChevron: CGFloat = 10   // next-up pill chevron

    // MARK: - Block Rim (Apollo block style — Figma 248:14)
    // The signature "sticker on paper" look: a crisp white rim separating the
    // block from the warm ground, over a stronger drop shadow. Figma draws the
    // rim at 5px on a 562px block (0.9%); at an ~86pt cell that lands near 2pt.
    /// White rim on the block edge.
    ///
    /// Figma draws 5px on a 562pt block — 0.89% — which is 0.77pt at an 86.5pt
    /// cell. Earlier revisions fattened this to 1.5pt on the assumption that
    /// sub-point strokes would not hold up; at 3x, 0.8pt is 2.4 device px and
    /// renders crisp. The heavier rim was visibly wrong against the source.
    static let blockRimWidth: CGFloat = 0.8
    /// Blur applied to the rim inside the band.
    ///
    /// Figma blurs 10px on a 562pt block — 1.78% of width — which is 1.54pt at
    /// an 86.5pt cell.
    ///
    /// This was 4pt (4.6%) for several revisions, chosen back when a blurred
    /// RING was being composited over a sharp block and needed to be strong
    /// enough to soften the boundary. Rebuilt against the source side by side at
    /// its native size, that reads as a haze washing up the bottom half — the
    /// cast Jayden spotted. At the source's own ratio there is no cast.
    static let blockRimBlur: CGFloat = 1.5
    /// Where the blurred copy has finished ramping in underneath, and the sharp
    /// copy starts fading out on top of it.
    ///
    /// The two masks deliberately do NOT mirror each other. Two masked opaque
    /// layers at 50% each composite to 75% alpha, not 100% — a symmetric
    /// crossfade makes the block genuinely translucent through the transition
    /// and the page shows through as a milky cast. Proved by rendering the block
    /// over pure blue: a purple band appeared across the handover.
    ///
    /// So the blurred copy sits underneath and reaches FULL opacity before the
    /// sharp copy above it begins to fade. Alpha is 1 everywhere; only focus
    /// changes. The band still needs to be a blend rather than a hard cut,
    /// because blurring softens a surface's alpha at its edges and a hard cut
    /// makes the silhouette visibly pinch in.
    /// The blurred copy is fully in by bandStart, so nothing softens above the
    /// band — the sides stay crisp to 74% exactly as the source's hard-edged
    /// backdrop-blur does. It ramps in underneath before that only to keep total
    /// alpha at 1; it is invisible there, covered by the opaque sharp copy.
    static let blockBandBlurRampStart: Double = 0.66
    static let blockBandFeatherStart: Double = 0.74
    static let blockBandFeatherEnd: Double = 0.86
    /// Frosted white wash over the lower portion of a block
    static let blockScrimOpacity: Double = 0.20
    /// Photo scrim band, anchored to the bottom edge rather than a proportion of
    /// height. Tall blocks and short ones need the SAME absolute cover under the
    /// title; a percentage ramp puts a 2x1's title in the transition instead.
    /// Capped against block height for 1x1s.
    static let blockPhotoScrimHeight: CGFloat = 72
    /// Drop shadow — Figma 0 10px 20px rgba(0,0,0,0.15), scaled to a ~86pt cell
    static let blockShadowRadius: CGFloat = 6
    static let blockShadowY: CGFloat = 3
    static let blockShadowOpacity: Double = 0.15

    // MARK: - Block Patina (Perfect-Day Gold Tint)
    static let patinaMaxOpacity: Double = 0.15
    static let patinaGrowthRate: Double = 0.02
    static let patinaGold = Color(red: 0.95, green: 0.80, blue: 0.40)
}
