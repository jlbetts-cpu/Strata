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
struct PressResponse: ButtonStyle {
    /// How far in. Smaller controls need more, because the same percentage of
    /// a smaller thing is fewer pixels.
    var scale: CGFloat = 0.92
    var dim: Double = 0.72

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? dim : 1)
            .animation(configuration.isPressed
                       ? GridConstants.shutterPress
                       : GridConstants.shutterRelease,
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
}
