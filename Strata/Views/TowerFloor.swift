import SwiftUI

/// The tower's floor: its content at least as tall as the scroll view
/// shows, standing at the bottom: the Wins tower and every crew's
/// (`towerContent`, `CrewTowerView`). See `towerContent` for why.
struct TowerFloor: ViewModifier {
    /// `-strataNoTowerFloor`: without it, for the floor walk's self-test.
    private static let off: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-strataNoTowerFloor")
        #else
        return false
        #endif
    }()

    @ViewBuilder
    func body(content: Content) -> some View {
        if Self.off {
            content
        } else {
            ZStack(alignment: .bottom) {
                Color.clear
                    .containerRelativeFrame(.vertical)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
        }
    }
}
