import SwiftUI

enum GridConstants {
    static let columnCount = 4
    static let spacing: CGFloat = 8
    static let cornerRadius: CGFloat = 16
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

    // MARK: - Adaptive Shadow
    static func adaptiveShadowOpacity(_ base: Double, colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? min(base * 3.5, 0.60) : base
    }

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

    // MARK: - Block Patina (Perfect-Day Gold Tint)
    static let patinaMaxOpacity: Double = 0.15
    static let patinaGrowthRate: Double = 0.02
    static let patinaGold = Color(red: 0.95, green: 0.80, blue: 0.40)
}
