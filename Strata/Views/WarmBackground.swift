import SwiftUI

/// The ground every page stands on.
///
/// **It is no longer warm, and the name is kept anyway** — renaming a type
/// used on twelve screens to say the same thing in a different word is churn,
/// and this comment is where the truth lives.
///
/// It was a warm off-white (250,249,246 → 249,247,244). Rendered against the
/// full block palette on six candidate grounds and looked at side by side, the
/// warmth was the problem: it is a yellow cast, and half the blocks are cool —
/// blue, purple, green — so the ground and the object on it pulled in opposite
/// directions and the pastels read as printed rather than lit.
///
/// Measured first, and the measurement said it did not matter: CIELAB
/// separation from the six block colours varied by barely two units across all
/// six candidates (53.3 to 55.0). Contrast was never the question. What
/// changes is the cast, and that is a thing to look at rather than compute.
///
/// This is the faintest possible cool lift — a blue-grey a couple of units off
/// neutral, nowhere near enough to read as "blue", but enough that the colours
/// on top of it look like they are catching light. The blocks are the app;
/// the ground's only job is to make them look clean and then disappear.
struct WarmBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.965, green: 0.970, blue: 0.978), location: 0.0),
                .init(color: Color(red: 0.947, green: 0.955, blue: 0.965), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}
