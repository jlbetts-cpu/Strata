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
    /// the drawer, a pinned heading's wash (`pinnedHeaderWash()`), the badge on
    /// a map block and every scroll-edge wash all fade into it, so they follow
    /// the system together or not at all.
    ///
    /// The dark values are a warm charcoal, not black. `AppColors.warmBlack`
    /// is 0x403D39 — the app's black has always had brown in it — and the
    /// ground goes a little under it so a block still reads as lit FROM
    /// somewhere. Pure black would be the ethereal thing this app is going
    /// for turning into a void: there would be no ground for a block to stand
    /// on, only an absence behind it.
    /// **AND IT IS WARM, WHICH IT WAS NOT.**
    ///
    /// The owner, 2026-09-30: "I don't like how much the buttons stick out like
    /// a sore thumb, like there is no continuity. I think it's because the
    /// background is greyish so it doesn't really mesh well."
    ///
    /// He is right and the measurement is sharper than the word "greyish".
    /// Sampled beside the header's pill, the page read (230, 232, 234) — blue
    /// four levels ABOVE red — while the pill read (249, 249, 248) and the tab
    /// bar (232, 228, 223), both neutral-to-warm. And the page did not even
    /// agree with itself: at mid-height it read (237, 236, 232), warm. So the
    /// ground flipped temperature down its own height, and it was at its
    /// coolest exactly where both buttons live.
    ///
    /// That is what reads as "doesn't mesh". A nineteen-level value gap is
    /// ordinary — chrome is meant to be lighter than its page — but a value gap
    /// ACROSS a temperature reversal makes the button a different material
    /// rather than a brighter piece of the same one.
    ///
    /// **AND THEN NEITHER: CLEAN WHITE.**
    ///
    /// The ground went warm to close that gap, and the gap closed — and the
    /// owner's verdict on the result settles the direction for good: "I don't
    /// like this warm style we are going for. I liked it more when it was
    /// premium clean. The clean white fits the brand so much more, especially
    /// the Hey Tea look when we add illustrations."
    ///
    /// **Both of the previous versions were wrong in the same way**, which is
    /// the thing worth keeping: they each had a TEMPERATURE. Cool read as grey,
    /// warm read as beige, and a page with an opinion about its own colour is a
    /// page the illustrations and the photographs then have to argue with. The
    /// blocks and the pictures carry every colour in this app — that is section
    /// 4 — and the ground's colour is no colour at all.
    ///
    /// So: neutral, and high. Red, green and blue within a level of each other,
    /// where the cool version was four apart and the warm one ten.
    ///
    /// **The buttons were never a temperature problem, and that is why this
    /// does not undo the fix.** What made them stick out was that `.regular`
    /// glass over a smooth field has nothing to refract and collapses to an
    /// opaque white capsule. `GlassRecipe.onPage` cancels that lift, and it is
    /// a value move, not a hue one — it holds on a white page exactly as it
    /// held on a warm one.
    static let top = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.112, green: 0.110, blue: 0.108, alpha: 1)
            : UIColor(red: 0.992, green: 0.992, blue: 0.991, alpha: 1)
    })

    /// **One colour, not a gradient.** It was a top-to-bottom gradient
    /// (light 0.965 to 0.947, dark 0.129 to 0.094), which is two to nine
    /// 8-bit levels spread over the whole screen: too shallow to read as
    /// light from above and exactly shallow enough to show as faint
    /// horizontal steps. The owner saw lines. The value here is the old
    /// gradient's midpoint, so the page is the same brightness to the eye,
    /// and because it is `top` everywhere, every wash that fades into `top`
    /// meets the ground at every height.
    /// **THE FIELD LIVES HERE NOW, SO EVERY SCREEN HAS IT.** (2026-09-30)
    ///
    /// The owner: "I don't want to not see that glass and pretty style
    /// throughout the screens, focus on the background too — we made a lot of
    /// updates with it on the Wins screen, make sure that transfers over."
    ///
    /// It was `DayGround`, mounted on the tower tab alone and behind a debug
    /// flag, which is why the rest of the app still looked like the old one. It
    /// is folded into `WarmBackground` instead of being added to fourteen call
    /// sites, because this type ALREADY is the app's ground: Memories, the
    /// sheets, Settings, the replay, onboarding and the rest all draw it. One
    /// change, and the style is everywhere the ground is.
    ///
    /// `Self.top` stays exactly what it was — a flat colour — because a dozen
    /// washes, fades and scroll edges fade INTO it and would tear if it became
    /// a gradient. The field is what `WarmBackground()` draws; `top` is the
    /// colour it settles to.
    var body: some View {
        ZStack {
            Self.top
            if !reduceTransparency {
                GroundField()
            }
        }
        .accessibilityHidden(true)
    }

    /// Reduced transparency asks for less of exactly this, and the flat colour
    /// above is already a complete answer.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
}
