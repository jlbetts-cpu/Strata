import SwiftUI

enum GridConstants {
    static let columnCount = 4
    static let spacing: CGFloat = 8
    static let cornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 16
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

    // MARK: - Breathing
    static let breatheDuration: TimeInterval = 3.0

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
}
