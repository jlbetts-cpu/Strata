import SwiftUI

/// The front camera's flash: a warm ring light drawn on the screen.
///
/// Lifted out of `CameraView` so the head maker lights a face with the same
/// light — one definition, rather than a second copy that drifts.
///
/// A ring light, not a flashbulb. The front camera has no lamp, so its flash
/// is the screen — and what you put on the screen decides what the photo
/// looks like. Two decisions, both of which have a reason:
///
/// **Warm, not white.** A phone screen at full white is around 6500K, which
/// on skin reads clinical and blue and is why front-flash selfies look washed
/// out. This is roughly 3400K — the warm end of a ring light, and the same
/// choice Snapchat makes.
///
/// **A ring, not a wash.** The brightness sits at the perimeter and falls off
/// toward the middle, which is what a ring light physically is: light
/// arriving from around the lens rather than through it. Flat light from dead
/// centre removes every shadow that gives a face shape; light from the rim
/// keeps the modelling and puts the catchlight in the eye.
struct WarmRingLight: View {
    /// The base wash's strength. The CAPTURE flash wants the full fill,
    /// because at that moment nothing matters except photons on the face. The
    /// MODELLING ring is held on while the flash is armed so you can see
    /// yourself — and there the fill has to stay low, or the overlay whites
    /// out the very preview it exists to light.
    let fillOpacity: Double

    /// Held on, the fill has to stay low or the overlay hides your face
    /// instead of lighting it. The ring itself does the work.
    static let modellingFill: Double = 0.10
    static let modellingLevel: Double = 0.92

    /// ~3400K.
    static let fill = Color(red: 1.00, green: 0.90, blue: 0.78)
    /// A touch brighter and a touch less saturated than the fill, so the rim
    /// reads as the source and the middle as what it lights.
    static let ring = Color(red: 1.00, green: 0.95, blue: 0.88)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Fill. A base wash so the whole face is lifted out of the
                //    dark rather than only its edges — without this a pure
                //    ring carves the face into a bright outline and a dim
                //    middle, which is a horror-film key, not a beauty light.
                // 0.72, not 0.42. On a phone every photon comes from the same
                // plane a foot from the face, so a dark middle does not
                // "shape" anything the way a physical ring does — it just
                // throws away light. Measured at 0.42 the centre sat at
                // luminance 96 against edges of 164-243, which is a dim flash
                // with a bright border. The ring still does its real job on
                // top of this: the catchlight in the eye.
                Self.fill
                    .opacity(fillOpacity)

                // 2. The ring. Brightest in a band near the screen's edge and
                //    genuinely absent through the middle third.
                // ELLIPTICAL, not radial.
                //
                // A circular gradient on a 402x874 screen never reaches the
                // left and right edges: measured, a point 10% in from the side
                // was pixel-identical to the centre, so the "ring" was lighting
                // the top and bottom only. An elliptical gradient takes its
                // radii from the view's own proportions, so the bright band
                // lands on all four edges of whatever shape the screen is.
                EllipticalGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        // **The band sits further out than it used to, and
                        // that is about the PREVIEW rather than about the
                        // light.**
                        //
                        // Measured on `apollo-rename` over a selfie with the
                        // ring held on, against the same frame unlit: the old
                        // stops lifted the centre by 12 but the edges by 75 to
                        // 105, and a face at the lower middle by 35 to 54. The
                        // owner: "for the front flash I think it might be too
                        // bright... the person still needs to be visible
                        // enough to admire themselves."
                        //
                        // Dimming the whole thing is the wrong answer now that
                        // this is the ONLY light, because less screen emission
                        // is less light on the face. What can move instead is
                        // WHERE the emission sits: light at the extreme
                        // perimeter still reaches a face a foot away, it just
                        // does not sit on top of it in the preview. So the ramp
                        // starts at half the radius rather than a third.
                        //
                        // After: face lower middle +35 to +11, lower left +54
                        // to +25, edges +75/+105 to +35/+55, centre +12 either
                        // way. About a seventh of the emission given up for two
                        // thirds of the wash coming off the face.
                        .init(color: .clear, location: 0.52),
                        .init(color: Self.ring.opacity(0.22), location: 0.72),
                        .init(color: Self.ring.opacity(0.80), location: 0.88),
                        .init(color: Self.ring, location: 1.00)
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.62
                )
                // Tightened with the band, so it bleeds less of it inward.
                .blur(radius: 22)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
