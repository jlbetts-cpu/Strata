import SwiftUI
import UIKit

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

    /// The ground's colour at the top of the screen.
    ///
    /// Named because more than one thing needs it now: anything that fades
    /// INTO the page — a header's wash, a scroll edge — has to start from
    /// exactly this and not from a second copy of it typed nearby. A wash that
    /// is one shade off the ground it sits on draws a band you cannot quite
    /// see and cannot stop seeing.
    /// **Dynamic**, so every consumer adapts without knowing it did.
    ///
    /// Making these two adaptive is what gives the whole app dark mode: the
    /// page, the drawer, the pinned headings, the badge on a map block and
    /// every scroll-edge wash all fade into one of these, so they follow the
    /// system together or not at all.
    ///
    /// The dark values are a warm charcoal, not black. `AppColors.warmBlack`
    /// is 0x403D39 — the app's black has always had brown in it — and the
    /// ground goes a little under it so a block still reads as lit FROM
    /// somewhere. Pure black would be the ethereal thing this app is going
    /// for turning into a void: there would be no ground for a block to stand
    /// on, only an absence behind it.
    static let top = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.129, green: 0.125, blue: 0.118, alpha: 1)
            : UIColor(red: 0.965, green: 0.970, blue: 0.978, alpha: 1)
    })
    /// And at the bottom. The gradient runs the same direction in both: the
    /// light ground gets very slightly cooler and darker downwards, the dark
    /// ground very slightly deeper, so "lit from above" survives the flip.
    static let bottom = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.094, green: 0.090, blue: 0.086, alpha: 1)
            : UIColor(red: 0.947, green: 0.955, blue: 0.965, alpha: 1)
    })

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Self.top, location: 0.0),
                .init(color: Self.bottom, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}
