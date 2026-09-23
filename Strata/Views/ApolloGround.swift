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
            Grey.g950
            ApolloSheet()
        }
        .ignoresSafeArea()
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
        .ignoresSafeArea()
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
