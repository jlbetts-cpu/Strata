import SwiftUI

/// **The ground every Apollo screen stands on: a warm white sheet over the
/// camera's black, with the dark showing as a strip at the bottom.**
///
/// The owner: "keep the dark bottom, I like that look for the app, it's kinda
/// like our look, so keep it even when going to sub screens."
///
/// It was built once, inline, inside `HomeView`, which meant the inside of a
/// folder and a print both landed on a plain light page and lost the strip —
/// the one piece of chrome that is the same on every screen including the
/// camera. Extracted so there is one definition and the sub screens get it by
/// asking rather than by reimplementing it.
///
/// **The dark is not shaped and the light is.** That is the whole trick and
/// it is the camera's, where the viewfinder has rounded bottom corners and
/// the black is a plain rectangle showing around them. A dark panel with its
/// own rounded TOP corners curves the dark down and away at the edges, which
/// is the wrong way and is what the owner caught the first time: "it's curved
/// the wrong way."
///
/// The strip is `GridConstants.bottomStrip`, shared with `CameraView` rather
/// than copied, and the radius is the camera's 40.
struct ApolloGround: View {
    /// The camera's own corner. See `CameraView.cornerRadius`.
    static let radius: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            // Only the DARK goes to the edges of the glass. The sheet has to
            // keep the bottom safe area, because that is where the tab bar
            // is and the strip is measured from the bar, not from the
            // screen. See `ApolloSheet`.
            Grey.g950.ignoresSafeArea()
            ApolloSheet()
        }
        .accessibilityHidden(true)
    }
}

/// **The warm white sheet on its own**, without the dark behind it.
///
/// Separate because Home drags it: the sheet and the page's content lift
/// together to uncover the feed, while the black stays where it is. A ground
/// that draws both cannot do that, and `ApolloGround` is still the right
/// thing for every screen that does not move.
struct ApolloSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: 0,
                                   bottomLeadingRadius: ApolloGround.radius,
                                   bottomTrailingRadius: ApolloGround.radius,
                                   topTrailingRadius: 0,
                                   style: .continuous)
                .fill(HomeGround.top)
            Color.clear.frame(height: GridConstants.bottomStrip)
        }
        // **The top and the sides, and NOT the bottom.**
        //
        // The owner, 2026-09-23: "the pulley is now too low."
        //
        // Measured, and he is right by 84 points. This ignored the safe area
        // on every edge, so the 20pt strip was 20pt from the bottom of the
        // GLASS — under the floating tab bar, which is the one place a thumb
        // cannot reach. The camera's viewfinder stops 20pt above the BAR,
        // which is 104 off the bottom once the bar and the home indicator
        // are counted, and `CameraView.stripBreathing` says so in as many
        // words: "the strip becomes 104, with 20 above the bar and the
        // system's own 23 below it."
        //
        // Keeping the bottom inset is what makes the same constant mean the
        // same thing on both screens: 20 points of air above the tab bar.
        .ignoresSafeArea(edges: [.top, .horizontal])
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts the app's ground behind a screen, and keeps its content clear of
    /// the dark strip. See `ApolloGround`.
    func apolloGround() -> some View {
        background { ApolloGround() }
            .safeAreaPadding(.bottom, GridConstants.bottomStrip)
    }

    /// **Keeps a screen's content ON the paper.**
    ///
    /// A `ScrollView` takes the safe area and gives its content an inset
    /// instead, which is the right behaviour under a floating tab bar and
    /// the wrong one here: once the sheet stopped 104pt short of the bottom,
    /// cards carried on scrolling past its lip and floated on the black with
    /// the bar over them. Photographed inside Today — a green card lying
    /// half on the paper and half on the strip.
    ///
    /// The mask is `ApolloSheet` itself rather than a second copy of its
    /// shape, so the edge content is cut at is the same edge the sheet is
    /// drawn to, by construction, and a change to one cannot leave the other
    /// behind.
    func clippedToSheet() -> some View {
        mask { ApolloSheet() }
    }
}

/// **How far Home's page has been lifted, for the one view that is not in it.**
///
/// The header is a `safeAreaInset` on the tab rather than part of `HomeView`,
/// so it cannot simply take the same `.offset`. A binding would work and
/// would be wrong: the value changes every frame of a drag, and a binding
/// writes into the TAB's state, so the whole tab — the folders, the shelf,
/// the grid — would re-evaluate sixty times a second to move one row of
/// chrome.
///
/// An `@Observable` read only by `LiftedHeader` invalidates only
/// `LiftedHeader`.
@Observable
final class HomeLift {
    var offset: CGFloat = 0
    /// **Whether enough of the feed is showing that the screen is now dark.**
    ///
    /// Separate from `offset` on purpose, and it is the difference between a
    /// value that changes sixty times a second and one that changes twice per
    /// interaction. The window's appearance is driven off THIS: anything
    /// reading `offset` re-evaluates on every frame of a drag, and the window
    /// scheme is the last thing that should.
    var feedShown: Bool = false
}

/// Applies `HomeLift` to a header without the rest of the screen having to
/// know about it. See `HomeLift` for why this is its own view.
struct LiftedHeader<Content: View>: View {
    var lift: HomeLift
    @ViewBuilder var content: Content

    var body: some View {
        content
            .offset(y: -lift.offset)
            // Gone well before it reaches the top, so it does not slide up
            // under the clock and out through the notch.
            .opacity(lift.offset > 0 ? max(0, 1 - Double(lift.offset / 120)) : 1)
    }
}
