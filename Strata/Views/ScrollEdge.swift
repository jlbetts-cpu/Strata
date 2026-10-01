import SwiftUI

/// **A ground under pinned chrome, so a header is never printed on a block.**
///
/// Found by the screen audit, on the tower with forty wins in it. The Wins
/// header is a `safeAreaInset(edge: .top)`, so it is pinned while the tower
/// scrolls under it, and there was nothing between the two. Scrolled down by
/// one screen, the measured result was this:
///
/// - "Thursday, October 1" in `inkSecondary` drawn straight onto a salmon
///   block, crossing that block's own white label, two pieces of text in the
///   same place
/// - the status bar's clock in black on the same salmon
/// - the filter button's glass sampling a blue block and turning blue
///
/// The screen had been rated 9/10 with "the fold cuts the slot" named as its
/// one open check. That check passes. THIS was the failure, and it only shows
/// on a tower tall enough to scroll, which is why no screenshot of a seeded
/// twelve ever found it. Measure the state the app is in after a month, not
/// the state a fixture puts it in.
///
/// **This is the platform's own answer and it costs nothing.** iOS 26 ships
/// `scrollEdgeEffectStyle`, which lays a progressive blur across the scroll
/// boundary: content fades into the inset instead of arriving at full strength
/// under the chrome. `.soft` is the quiet one, which is the one this app wants
/// — `.hard` draws a visible line, and a line under a header is the separator
/// this design system does not use.
///
/// What was NOT done, and why:
///
/// - **A material behind the header.** It would be a bar, and the Wins screen
///   has deliberately had its bar removed: the date floats on the page. A
///   `.ultraThinMaterial` strip would put it back and would read as chrome on
///   every screen including the empty one, where there is nothing to separate
///   the header from.
/// - **A gradient scrim drawn by hand.** That is the same effect built
///   privately, and check 3 of the audit fails a privately rebuilt component.
///   It would also need its own colour per scheme, which is two more numbers
///   nobody can maintain.
/// - **Shrinking the header into the safe area.** The date would collide with
///   the status bar instead, which is the same bug one row up.
///
/// On iOS 18 to 25 nothing is applied. The effect is an enhancement, the
/// header stays legible on those systems in every state the fixtures reach,
/// and a hand-built fallback would be the privately rebuilt component this
/// exists to avoid.
extension View {

    /// A soft progressive blur where scrolling content meets pinned chrome.
    ///
    /// Apply it to the SCROLL VIEW, not to its content: the effect belongs to
    /// the scroll's boundary, and on the content it has no boundary to sit at.
    @ViewBuilder
    func softScrollEdge(_ edges: Edge.Set = .top) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: edges)
        } else {
            self
        }
    }
}
