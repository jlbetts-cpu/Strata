import SwiftUI

/// **An environment behind the page, not a tint on it.**
///
/// The owner, 2026-09-29, after two attempts that were both tint: "it isn't
/// about the colour, you shouldn't be tweaking colour... the look should feel
/// like there is something behind the white screen, like an environment. This
/// isn't just adding light to the scene, it's about letting the light reflect
/// through."
///
/// **That is a different thing and the earlier versions could not have become
/// it.** They were radial gradients of the day's colour laid over a flat fill:
/// more colour, in the same plane, with no structure in it. Something uniform
/// has nothing to reflect, nothing to refract and nothing to magnify — which is
/// also exactly why the slot could not be made to look like glass by changing
/// its material. A magnifier over blank paper is invisible. The material was
/// never the problem; the emptiness behind it was.
///
/// So this is a field with real spatial structure. `MeshGradient` rather than a
/// stack of radials because a mesh has interior control points: the surface
/// bends and pools instead of falling off evenly from a centre, which is what
/// makes it read as a room with something in it rather than a spotlight aimed at
/// the page.
///
/// **AND IT CARRIES NO COLOUR FROM THE DAY, WHICH IS THE THIRD CORRECTION.**
///
/// Three versions of this borrowed the dominant block's hue, on the strength of
/// §4's "a tint is only ever borrowed from content". Every one of them was told
/// the same thing: "it just reads red." They did, and they always would have —
/// the dominant colour of a tower is whatever the biggest block happens to be,
/// so "borrowed from content" on a full-page surface means the entire app is
/// tinted by one win. The owner said it plainly and I kept not hearing it: "it
/// isn't about the colour, you shouldn't be tweaking colour... it should feel
/// like there is something behind the white screen."
///
/// Depth is not hue. The field is neutral now: light and dark a few levels
/// apart, cool at the top and a shade warmer at the foot, arranged so the eye
/// reads a surface with a direction to it. The colour in this app stays where §4
/// put it in the first place — in the blocks and the photographs.
struct DayGround: View {

    /// Kept in the signature and unused, so the call sites and the tests do not
    /// churn while this is being judged. If the field is still neutral when it
    /// ships, both of these go.
    let colours: [Color]
    let fill: Double

    /// Reduced transparency asks for less of exactly this. The field flattens to
    /// the plain ground and every lens over it goes quiet with it.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Dark mode gets the same structure at a different altitude. A field of
    /// light neutrals on a charcoal page would be fog; these are the warm
    /// charcoals `WarmBackground` already uses, varied by the same amounts.
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            WarmBackground()
            if !reduceTransparency {
                field.ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }

    /// A 3x3 mesh. Three is enough for a surface and few enough to stay calm:
    /// the interior point is the only one that can pool, and one pool reads as a
    /// room where four read as a pattern.
    private var field: some View {
        MeshGradient(width: 3, height: 3,
                     points: Self.points,
                     colors: meshColours,
                     smoothsColors: true)
    }

    /// **The interior point is off centre and low**, which is the whole trick.
    ///
    /// On a regular lattice a mesh is a smooth ramp and reads as a gradient.
    /// Pulling the middle point down and left makes the field pool there and
    /// stretch away above it, so there is a place the light comes from and a
    /// direction it falls off in. Low, because that is where the tower stands
    /// and where the colour in the room actually is.
    private static let points: [SIMD2<Float>] = [
        .init(0.0, 0.0), .init(0.5, 0.0),   .init(1.0, 0.0),
        .init(0.0, 0.5), .init(0.36, 0.62), .init(1.0, 0.5),
        .init(0.0, 1.0), .init(0.5, 1.0),   .init(1.0, 1.0),
    ]

    /// Nine neutrals. The structure is entirely in how they differ from each
    /// other, which is the point: a mesh of one colour is a flat fill with extra
    /// steps.
    private var meshColours: [Color] {
        (0..<9).map { Self.neutral(at: $0, dark: scheme == .dark) }
    }

    /// The field's own greys, before any day colour.
    ///
    /// **They are not all the same value, and that is the point.** A mesh of one
    /// colour is a flat fill with extra steps. These run a few levels apart, cool
    /// at the top and a shade warmer at the foot, so even a day with nothing
    /// logged has a surface rather than a blank.
    private static func neutral(at i: Int, dark: Bool) -> Color {
        let light: [Double] = [0.972, 0.968, 0.962,
                               0.966, 0.978, 0.958,
                               0.952, 0.962, 0.948]
        let night: [Double] = [0.118, 0.112, 0.106,
                               0.110, 0.126, 0.102,
                               0.098, 0.106, 0.094]
        let v = dark ? night[i] : light[i]
        // Blue at the top, warmth at the foot: the same two-ended light the
        // contact sheet picked, built into the surface rather than layered on it.
        let hue = i < 3 ? 0.58 : 0.08
        let sat = dark ? 0.06 : 0.035
        return Color(hue: hue, saturation: sat, brightness: v)
    }

}
