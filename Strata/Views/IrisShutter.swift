import SwiftUI

/// **The blades closing: what a camera does that a phone never does.**
///
/// The owner: "a tasteful pressing of the shutter animation, like it meant
/// something to press it. Make it a satisfying ritual, not just another
/// pressing-a-camera animation."
///
/// Phones mark a photograph with a white flash, which is a picture of a
/// FLASHBULB and belongs to 1950s press cameras. What actually happens when a
/// camera takes a photograph is that the finder goes dark: the blades sweep
/// shut, the frame is exposed, and they sweep open again. It is the one
/// moment in photography with real mechanism in it, it is over in a fifth of
/// a second, and nobody on a phone has ever felt it.
///
/// So the viewfinder blinks. Six blades, closing fast and opening slower,
/// because that is how a spring-loaded mechanism behaves — it is driven shut
/// and it returns. The blades rotate as they close, which is the detail that
/// separates an iris from a hole getting smaller.
///
/// **Black, never white.** A white flash says "a light fired". Black says
/// "the shutter was open and now it is not", which is the true thing and also
/// the quiet one.
struct IrisShutter: Shape {
    /// 1 is wide open and draws nothing at all; 0 is shut and fills the frame.
    var openness: CGFloat
    /// Six, like most leaf shutters and most aperture diaphragms. Five reads
    /// as a star and eight is indistinguishable from a circle at this speed.
    var blades: Int = 6

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var shut = Path(rect)
        let clamped = min(max(openness, 0), 1)
        guard clamped > 0.001 else { return shut }

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        // **Sized by the polygon's INRADIUS, not its circumradius.** A hexagon
        // whose vertices reach the corners still leaves the corners covered,
        // because its edges cut inside them — so at full openness the blades
        // would show as dark wedges in all four corners of the viewfinder.
        // Dividing by cos(pi/n) pushes the flats out to the diagonal instead.
        let reach = hypot(rect.width, rect.height) / 2 / cos(.pi / CGFloat(blades))
        let radius = reach * clamped
        // A quarter turn over the whole close, so the blades sweep rather
        // than shrink. Less and it reads as a hole; more and it reads as a
        // pinwheel.
        let spin = (1 - clamped) * (.pi / 2) / CGFloat(blades) * 2

        var opening = Path()
        for blade in 0..<blades {
            let angle = spin + CGFloat(blade) * 2 * .pi / CGFloat(blades) - .pi / 2
            let point = CGPoint(x: centre.x + cos(angle) * radius,
                                y: centre.y + sin(angle) * radius)
            if blade == 0 { opening.move(to: point) } else { opening.addLine(to: point) }
        }
        opening.closeSubpath()
        shut.addPath(opening)
        return shut
    }
}

/// The blink itself: the blades over the picture, and nothing when it is not
/// happening.
///
/// **Over the photograph, under the controls.** A real blackout covers the
/// finder, not the camera's dials — and on a phone, blacking out the shutter
/// button at the instant you press it would look like the app had crashed.
struct ShutterBlink: View {
    /// 1 is open. Driven from the capture, not from a timer in here, so the
    /// blink and the exposure are the same event.
    var openness: CGFloat

    var body: some View {
        IrisShutter(openness: openness)
            .fill(.black, style: FillStyle(eoFill: true))
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Nothing to composite at all while the shutter is open, which is
            // almost always.
            .opacity(openness >= 1 ? 0 : 1)
    }

    /// **Fast shut, slower open, and that ordering is the whole feel.**
    ///
    /// A leaf shutter is driven closed by a spring and returns under lighter
    /// tension, so the close is a snap and the open is a release. Reversed —
    /// or matched — it reads as a crossfade rather than as a mechanism. The
    /// numbers are a real shutter's: about 1/12th of a second shut, which is
    /// slow for an exposure and right for something you are meant to notice.
    static let shutDuration: Double = 0.085
    static let darkDuration: Double = 0.030
    static let openDuration: Double = 0.145

    /// How long the whole blink takes, for anything that has to wait for it.
    static var total: Double { shutDuration + darkDuration + openDuration }
}
