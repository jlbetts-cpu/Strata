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

    /// **A header pinned over a scroll view, as a bar.** On iOS 26 a custom
    /// bar (`safeAreaBar`) is what the system draws its scroll edge under;
    /// under a plain `safeAreaInset` the edge drew nothing at all, and the
    /// calendar's weekdays ran straight through the month's name (looked at
    /// on Memories, 2026-10-13). Before 26 it is the inset it always was.
    ///
    /// **What hangs under the header goes in `below`, never inside the
    /// bar.** A tip, or a crew's plan card, used to be an overlay on the
    /// header that overflowed it. Inside a bar that overflow is drawn and
    /// takes no touch: I'm In did nothing (tried, 2026-10-13, before it
    /// reached anyone). `below` is laid just under the bar, over the page,
    /// and takes no room, so nothing moves when it comes or goes.
    func pinnedBar<Bar: View>(@ViewBuilder _ bar: @escaping () -> Bar) -> some View {
        modifier(PinnedBar(bar: bar, below: { EmptyView() }))
    }

    func pinnedBar<Bar: View, Below: View>(@ViewBuilder _ bar: @escaping () -> Bar,
                                           @ViewBuilder below: @escaping () -> Below) -> some View {
        modifier(PinnedBar(bar: bar, below: below))
    }

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

    /// **A sideways row fades where it runs on past the margin** (the owner,
    /// 2026-10-14: "there should be a little fade when it gets to the margin
    /// apple does this ... adding that throughout the app would add a more
    /// premium polish"). Only on a side with more to scroll to: at the start
    /// of a row its leading edge is crisp, mid-row both sides soften, at the
    /// end the trailing edge is crisp again. Apply it to the SCROLL VIEW.
    func edgeFade(_ length: CGFloat = GridConstants.gapWide) -> some View {
        modifier(EdgeFade(length: length))
    }
}

private struct EdgeFade: ViewModifier {
    let length: CGFloat
    @State private var leading = false
    @State private var trailing = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: [Bool].self) { geo in
                let x = geo.contentOffset.x + geo.contentInsets.leading
                return [x > 1, x + geo.containerSize.width < geo.contentSize.width + geo.contentInsets.leading + geo.contentInsets.trailing - 1]
            } action: { _, now in
                leading = now[0]
                trailing = now[1]
            }
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(leading ? 0 : 1), .black],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: length)
                    Rectangle()
                    LinearGradient(colors: [.black, .black.opacity(trailing ? 0 : 1)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: length)
                }
                // Past the row above and below: several rows draw outside
                // their bounds on purpose (`scrollClipDisabled`), a press
                // growing or a rim, and only the sides are this mask's job.
                .padding(.vertical, -60)
            }
            .animation(GridConstants.crossFade, value: leading)
            .animation(GridConstants.crossFade, value: trailing)
    }
}

private struct PinnedBar<Bar: View, Below: View>: ViewModifier {
    @ViewBuilder let bar: () -> Bar
    @ViewBuilder let below: () -> Below
    /// Where the bar ends, in this view's own space: where `below` begins.
    @State private var barFoot: CGFloat = 0
    private static var space: String { "pinnedBar" }

    func body(content: Content) -> some View {
        barred(content)
            .overlay(alignment: .top) {
                below().padding(.top, barFoot)
            }
            .coordinateSpace(.named(Self.space))
    }

    @ViewBuilder
    private func barred(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .top, spacing: 0) { measured }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) { measured }
        }
    }

    private var measured: some View {
        bar().onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).maxY } action: { barFoot = $0 }
    }
}
