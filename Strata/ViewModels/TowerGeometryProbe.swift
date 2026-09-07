import SwiftUI

/// Where the tower's grid actually is on screen.
///
/// The drop needs one thing the tower's own arithmetic cannot reliably give
/// it: the block's real position in the window, so the fall can start above
/// the top edge of the screen no matter how tall the tower is or where it is
/// scrolled. Three attempts to derive that from `gridH`, `towerScrollOffset`
/// and the layout paddings each got it wrong in a different way, because each
/// of those changes on its own schedule and at least one of them is stale
/// (`towerScrollOffset` is only republished in 8pt steps).
///
/// Measuring it removes the arithmetic entirely.
///
/// **Deliberately not `@Observable`.** It is written on every scroll frame and
/// every layout pass, and its only reader samples it once, when a drop is
/// queued. Publishing it would re-render the whole tower at 60Hz to deliver a
/// number that nothing on screen depends on.
@MainActor
final class TowerGeometryProbe {
    /// Top edge of the grid in global (window) coordinates.
    var gridTopOnScreen: CGFloat = 0
    /// The grid's laid-out height, matching `gridTopOnScreen`'s moment.
    var gridHeight: CGFloat = 0
    /// Cell size, so a block's frame can be recomputed without threading the
    /// column width through the drop path.
    var cellSize: CGFloat = 0

    /// True once a real layout pass has reported in. Before that the drop
    /// falls back to a fixed distance rather than trusting zeros.
    var hasMeasured: Bool { cellSize > 0 }
}
