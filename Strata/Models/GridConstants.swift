import SwiftUI

enum GridConstants {
    static let columnCount = 4
    static let spacing: CGFloat = 8
    static let cornerRadius: CGFloat = 20
    static let horizontalPadding: CGFloat = 20
    static let timelineGutterWidth: CGFloat = 56

    // 1 block height = 3 meters for altimeter
    static let metersPerBlock: Double = 3.0

    // Minimum scaffold blocks for new users
    static let minimumScaffoldBlocks = 12

    // MARK: - Stroke
    static let strokeWidth: CGFloat = 2.5

    // MARK: - Animation Springs
    static let dropSquashSpring = Animation.spring(response: 0.06, dampingFraction: 0.45)
    static let dropStretchSpring = Animation.spring(response: 0.20, dampingFraction: 0.42)
    static let dropSettleSpring = Animation.spring(response: 0.35, dampingFraction: 0.60)
    static let rippleCompressSpring = Animation.spring(response: 0.06, dampingFraction: 0.55)
    static let rippleReleaseSpring = Animation.spring(response: 0.35, dampingFraction: 0.60)

    // MARK: - Squash & Stretch (energy-proportional: ½mv² → quadratic in mass)
    static func squashScaleY(mass: CGFloat) -> CGFloat { 0.02 * mass * mass }
    static func squashScaleX(mass: CGFloat) -> CGFloat { 0.015 * mass * mass }
    static func stretchScaleY(mass: CGFloat) -> CGFloat { 0.01 * mass * mass }
    static func stretchScaleX(mass: CGFloat) -> CGFloat { 0.007 * mass * mass }

    // MARK: - Shadow

    /// Single soft ambient shadow for depth
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
    static let shadowOpacity: Double = 0.10

    // MARK: - Tap Bounce
    static let tapSquashSpring = Animation.spring(duration: 0.08, bounce: 0.0)
    static let tapPopSpring = Animation.spring(duration: 0.30, bounce: 0.45)
    static let tapScaleX: CGFloat = 1.03
    static let tapScaleY: CGFloat = 0.96

    // MARK: - Wobble Settle
    static let wobbleSpring = Animation.spring(response: 0.18, dampingFraction: 0.3)
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
