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
    /// Making it adaptive is what gives the whole app dark mode: the page,
    /// the drawer, the pinned headings, the badge on a map block and every
    /// scroll-edge wash all fade into it, so they follow the system together
    /// or not at all.
    ///
    /// The dark values are a warm charcoal, not black. `AppColors.warmBlack`
    /// is 0x403D39 — the app's black has always had brown in it — and the
    /// ground goes a little under it so a block still reads as lit FROM
    /// somewhere. Pure black would be the ethereal thing this app is going
    /// for turning into a void: there would be no ground for a block to stand
    /// on, only an absence behind it.
    static let top = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.112, green: 0.108, blue: 0.102, alpha: 1)
            : UIColor(red: 0.956, green: 0.962, blue: 0.972, alpha: 1)
    })

    /// **One colour, not a gradient.** It was a top-to-bottom gradient
    /// (light 0.965 to 0.947, dark 0.129 to 0.094), which is two to nine
    /// 8-bit levels spread over the whole screen: too shallow to read as
    /// light from above and exactly shallow enough to show as faint
    /// horizontal steps. The owner saw lines. The value here is the old
    /// gradient's midpoint, so the page is the same brightness to the eye,
    /// and because it is `top` everywhere, every wash that fades into `top`
    /// meets the ground at every height.
    var body: some View {
        Self.top
            .accessibilityHidden(true)
    }
}

/// **The Home screen's ground: a warm premium white.**
///
/// The owner: "I think we go light mode, like for the top a warm premium
/// white."
///
/// **Why this is not `WarmBackground`.** That token's own comment says it
/// deliberately is NOT warm: it was a warm off-white and got a faint COOL
/// lift, because the block palette is half cool and a yellow ground pulled
/// against the blues and greens. That reasoning is about *blocks on a page*.
/// Home has no blocks on it — it has photographs and coloured folders, and a
/// photograph sits on warm paper the way a print does. Rebinding the shared
/// ground would change twelve screens to fix one, which is the mistake
/// CLAUDE.md's accent rule is about.
///
/// So it is a second, named ground with a job description, and as the light
/// redesign works down the app the screens that join Home move onto this one
/// rather than each inventing a white.
///
/// The value: 2.4 points of warmth (R−B) at 98% brightness. Enough that a
/// white card laid on it reads as cooler, which is the test for whether a
/// ground is warm at all; far short of cream, which would make the folders
/// look grubby.
///
/// It does not go dark. Home is a light screen in both appearances for now —
/// the honest state of the redesign, and the alternative is a dark variant
/// nobody has looked at.
struct HomeGround: View {
    static let top = Color(red: 0.980, green: 0.972, blue: 0.956)

    var body: some View {
        Self.top
            .accessibilityHidden(true)
    }
}
