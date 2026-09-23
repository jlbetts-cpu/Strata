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
            VStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: 0,
                                       bottomLeadingRadius: Self.radius,
                                       bottomTrailingRadius: Self.radius,
                                       topTrailingRadius: 0,
                                       style: .continuous)
                    .fill(HomeGround.top)
                Color.clear.frame(height: GridConstants.bottomStrip)
            }
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
