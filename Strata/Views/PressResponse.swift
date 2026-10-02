import SwiftUI

/// **Every button acknowledges the press, in one place.**
///
/// The owner: "I truly want it to feel like premium UI in your hand, like
/// every button with a clean animation... everything needs to feel easy to
/// touch."
///
/// **There was no `ButtonStyle` anywhere in this app.** Every button was
/// `.plain`, which means SwiftUI draws the label and nothing else: no scale,
/// no dim, no response of any kind while a finger is on it. Three things were
/// hiding that. The shutter hand-rolls its own press, so the one control
/// somebody presses most did feel right. Liquid Glass buttons respond by
/// themselves, because `.interactive()` is on both `glassCircle` and
/// `photoOverlay`, so the tray and the corner button did too. And every
/// button in the app fires a haptic, so a press was always ANSWERED — just
/// not on screen.
///
/// What was left with nothing was the plain-glyph row: the grid, the flash,
/// the flip and the timer, and the size chips beside the shutter. Those are
/// the controls on a photograph, where there is no background to shift and
/// the glyph is the whole of the button.
///
/// **AND FOR A WHILE THAT PARAGRAPH WAS THE ONLY PLACE ANY OF IT HAPPENED**
/// (fixed 2026-10-01, `docs/consistency-audit.md` §1.8). The style was written,
/// the controls were named by name in this comment, and `.press` was given
/// **zero call sites**: the app counted 25 `.buttonStyle(.plain)` against 8
/// press styles, and all four controls above were still `.plain`. Every
/// non-glass `.plain` in `Strata/Views` is gone now, and
/// `ConsistencyTests.everyPlainButtonIsGlass` is the gate — a `.plain` label is
/// only correct when it is already Liquid Glass, which answers a press itself,
/// or when it is the shutter, which hand-rolls one.
///
/// **The size chips are `.pressWord`, not `.press`.** They sit in the glyph row
/// and they are words, and the rule is about what a control is made of rather
/// than where it stands: `.press` on the glyphs, `.pressWord` on the words,
/// `.pressSurface` on the cards.
///
/// **The numbers are the shutter's**, so the screen presses as one thing: in
/// on `shutterPress`, back on `shutterRelease`. A press that leaves on an
/// ease and returns on a spring is the shape of something being let go of,
/// which is what it is.
///
/// **Scale AND dim, not one of them.** A 6% scale alone is nearly invisible
/// on a 21pt glyph, and a dim alone reads as the control disabling itself.
/// Together they read as depression. The glyph already carries a drop shadow
/// for legibility over a photograph, and shrinking it moves that too, which
/// is the part that sells it.
/// **Reduce Motion keeps the dim and drops the scale** (2026-10-01).
///
/// `docs/motion-audit.md` found this style was the one place in the app that
/// told other code to honour the setting and did not honour it itself: the
/// private copy of it on the Memories shelf, which this file exists to make
/// unnecessary, had a Reduce Motion path and the original did not.
///
/// It is not gated to nothing, because a press that answers with nothing is
/// the defect this whole file was written to fix, and Reduce Motion asks for
/// less MOTION rather than less feedback. A scale is motion; a dim is not. So
/// with the setting on the glyph still goes to `dim`, on `crossFade` rather
/// than on a spring, and does not move.
struct PressResponse: ButtonStyle {
    /// How far in. Smaller controls need more, because the same percentage of
    /// a smaller thing is fewer pixels.
    var scale: CGFloat = 0.92
    var dim: Double = 0.72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? dim : 1)
            .animation(reduceMotion
                       ? GridConstants.crossFade
                       : (configuration.isPressed
                          ? GridConstants.shutterPress
                          : GridConstants.shutterRelease),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressResponse {
    /// The app's press. Use this rather than `.plain` on anything that is not
    /// already Liquid Glass, which responds on its own.
    static var press: PressResponse { PressResponse() }

    /// For a control whose label is a word rather than a glyph: a word at 6%
    /// reads as a wobble, so it moves less and dims more.
    static var pressWord: PressResponse { PressResponse(scale: 0.96, dim: 0.62) }

    /// For a SURFACE: a card, a poster, a row with a picture in it.
    ///
    /// **It gives, and it does not dim** (2026-10-01). A glyph over a
    /// photograph needs both, because there is no background to shift and the
    /// scale alone is nearly invisible on 21pt of ink. A card is the thing that
    /// moves, so the scale reads on its own — and dimming a photograph by 28%
    /// reads as the picture dulling rather than the card being pressed.
    ///
    /// `tapScaleY`'s 0.97 is the amount every other pressable surface in the
    /// app gives by, so a card does not get a number of its own. **Uniform, not
    /// the block's squash**: `tapScaleX`/`tapScaleY` together are a thing
    /// landing on a floor, and this is a card pressed into the page.
    ///
    /// This replaces `PosterPress`, which was `MemoriesShelf`'s private copy of
    /// exactly this and the reason `docs/motion-audit.md` found a press with
    /// four different answers. The copy was the MORE accessible of the two: it
    /// honoured Reduce Motion and the original did not. Both do now.
    static var pressSurface: PressResponse {
        PressResponse(scale: GridConstants.tapScaleY, dim: 1)
    }
}
