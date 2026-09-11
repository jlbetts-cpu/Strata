import SwiftUI

/// The page, pulled up over the map.
///
/// Apple Maps' own anatomy: a full-bleed map with a card you drag up over it.
/// It is the only arrangement that lets the map be the whole screen and keeps
/// everything the tab used to be one gesture away.
///
/// **Not a system sheet.** A `.sheet` with `presentationDetents` presented from
/// inside a `Tab` sits on the window's presenting controller, and at a small
/// detent it occupies exactly the band the floating tab bar lives in — the bar
/// is neither resized nor raised, and `presentationBackgroundInteraction`
/// restores interaction with content BEHIND the sheet, not with chrome it is
/// sitting on top of. iOS 26's `tabViewBottomAccessory` is the native answer
/// and the deployment target is 18.0, so it could only ever be a gated
/// flourish rather than the mechanism.
///
/// **Not a block, either.** CLAUDE.md is explicit that a white rim, a frosted
/// band or a blurred edge is a block's claim — "you built this and it is
/// standing on something". This is the ground the app stands on, sliding up
/// over the map, so it is `WarmBackground` with the surface radius and a
/// shadow. A shadow is not a rim.
/// How far up the drawer is.
///
/// **Outside the drawer, deliberately.** Nested in a generic type it would be
/// `MemoriesDrawer<Content>.Detent`, so the `@State` holding it would have to
/// name a `Content` — pinning the drawer to whatever that guess was (`AnyView`)
/// and rejecting the real content type. The detent is also the screen's state
/// rather than the panel's: it is what the map reads to decide how much of
/// itself is worth showing.
enum DrawerDetent: CaseIterable {
    /// Gone, off the bottom of the screen. **The resting state.**
    ///
    /// It used to be a `peek` — a handle sitting above the tab bar at all
    /// times. The owner's call is that the map is the feature, and a strip of
    /// page permanently across the bottom is the map being 85% of the screen
    /// instead of all of it. The photographs are a button away instead, which
    /// is the same distance as a drag and leaves the ground undivided.
    case hidden
    /// Everything, stopping short of the status bar. **The only place it
    /// opens to.**
    ///
    /// There was a `half` between these two. The owner's call is that the page
    /// "should open to full screen pop up with a done button", and a middle
    /// stop was working against that: it is the state where the map is too
    /// covered to read and the page is too short to use, and every drag had to
    /// decide which of two places you meant.
    case full
}

struct MemoriesDrawer<Content: View>: View {
    @Binding var detent: DrawerDetent
    @ViewBuilder var content: () -> Content

    @State private var drag: CGFloat = 0
    @GestureState private var isDragging = false


    var body: some View {
        GeometryReader { geo in
            let stops = offsets(in: geo.size.height)
            let resting = stops[detent] ?? 0
            let y = resisted(resting + drag, within: stops, height: geo.size.height)

            VStack(spacing: 0) {
                handle
                content()
                    // Below `.full` there is nothing to scroll, so the whole
                    // panel takes the drag. At `.full` the content scrolls and
                    // the handle is the only thing that still moves the panel.
                    .scrollDisabled(detent != .full)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: GridConstants.radiusSurface,
                    topTrailingRadius: GridConstants.radiusSurface,
                    style: .continuous
                )
                .fill(Color.clear)
                .background {
                    WarmBackground()
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: GridConstants.radiusSurface,
                            topTrailingRadius: GridConstants.radiusSurface,
                            style: .continuous
                        ))
                }
                .shadow(color: .black.opacity(GridConstants.shadowOpacity),
                        radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
            }
            .offset(y: y)
            .animation(isDragging ? nil : GridConstants.naturalSettle, value: detent)
        }
    }

    /// The grab handle, and the only thing that drags the panel.
    ///
    /// Dragging anywhere on the card would fight the content's own scrolling,
    /// and `simultaneousGesture` gives you both moving at once. Keeping the
    /// drag on the handle is the version that cannot be ambiguous.
    private var handle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(GridConstants.fillTrack)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { drag = $0.translation.height }
                .onEnded { value in
                    // Momentum projected, then snapped to the nearest stop —
                    // `docs/apple-design.md` §6. The deceleration rate is the
                    // one already tuned for the tower's slot, which is the
                    // same problem: three stops a few dozen points apart, all
                    // of which have to be reachable by flick AND by drag.
                    let projected = value.translation.height
                        + GridConstants.project(velocity: value.predictedEndTranslation.height
                                                - value.translation.height)
                    drag = 0
                    detent = nearest(to: projected)
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Photographs")
        .accessibilityHint("Drag up for more")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { detent = detent == .full ? .hidden : .full }
    }

    // MARK: - Geometry

    /// Where the top of the panel sits at each stop, as an offset from the top
    /// of the screen. Resolved once per layout rather than per frame.
    private func offsets(in height: CGFloat) -> [DrawerDetent: CGFloat] {
        // `.hidden` is a whole screen down rather than exactly `height`, so
        // the shadow above the panel's top edge goes with it instead of
        // leaving a grey seam along the bottom of the map.
        [.hidden: height + 24,
         .full: 0]
    }

    /// Rubber-banded past the first and last stop, never hard-stopped —
    /// `apple-design.md` §9.
    private func resisted(_ y: CGFloat, within stops: [DrawerDetent: CGFloat],
                          height: CGFloat) -> CGFloat {
        let top = stops[.full] ?? 0
        let bottom = stops[.hidden] ?? height
        if y < top {
            return top - GridConstants.rubberband(overshoot: top - y, dimension: height)
        }
        if y > bottom {
            return bottom + GridConstants.rubberband(overshoot: y - bottom, dimension: height)
        }
        return y
    }

    private func nearest(to projected: CGFloat) -> DrawerDetent {
        // Projected in the drag's own space: negative is up.
        let current = detent
        if projected < -60 { return .full }
        if projected > 60 { return .hidden }
        return current
    }
}

/// Numbers the drawer needs, outside it because a generic type cannot hold
/// static stored properties.
enum DrawerMetrics {
    /// The tab bar's allowance, so the page's last row is not under it.
    ///
    /// Kept as a name here for the drawer's own call sites; the value lives in
    /// `GridConstants`, because three files need it and two of them were
    /// carrying the number 110 as a literal.
    static let tabBarClearance = GridConstants.tabBarClearance
}
