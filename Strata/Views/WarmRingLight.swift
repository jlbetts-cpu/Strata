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
    /// At the moment of capture nothing matters but light on the face.
    static let captureFill: Double = 0.72

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
                        .init(color: .clear, location: 0.30),
                        .init(color: Self.ring.opacity(0.30), location: 0.55),
                        .init(color: Self.ring.opacity(0.90), location: 0.82),
                        .init(color: Self.ring, location: 1.00)
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.62
                )
                .blur(radius: 28)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
