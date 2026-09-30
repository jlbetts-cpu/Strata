import SwiftUI

/// **A sheet hung up against a bright sky.**
///
/// The owner, 2026-09-29, after three attempts that were all tint: "I want there
/// to feel like there is a subtle grassy field on a sunny day behind it, like
/// subtly, like it should feel like it's a sheet put up to the sky."
///
/// That is a scene, and it is why nothing before this worked. Every earlier
/// version tried to make a near-white surface *slightly interesting* — a wash, a
/// temperature ramp, a hue borrowed from the biggest block, which always came out
/// red because the biggest block is usually red. All of them were adjustments to
/// a blank page. None of them had anything behind them, so there was nothing for
/// glass to refract and nothing for the eye to read as depth.
///
/// **So this is built the way the thing it is imitating is built: a real scene,
/// and then cloth over it.**
///
/// ```
///   sky, sun, grass          ← saturated enough to actually be those things
///   ───────────────────
///   white veil at 86%        ← the sheet
/// ```
///
/// That order matters and is the whole technique. Trying to paint the *result*
/// directly means mixing nine nearly-white colours by eye and hoping they read
/// as a landscape, which is what failed three times. Painting a believable scene
/// and then diffusing it is what fabric actually does to light, so the hues that
/// survive are the ones that would survive, at the intensity they would survive
/// at. The sky stays faintly blue, the grass stays faintly green, the sun stays
/// warm, and none of it is nameable at a glance.
///
/// **It is fixed, not derived from the day.** §4 of
/// `docs/design-system-future.md` says a tint is only ever borrowed from
/// content, and this deliberately is not: it is a backdrop, the same on every
/// day of a person's life, the way the wall behind a shelf is the same wall. The
/// rule exists to stop chrome inventing a brand accent that competes with the
/// blocks — a green field at 14% behind a sheet is not competing with anything,
/// and the version that DID obey the rule is the one that made the whole app
/// look red.
struct DayGround: View {

    /// Kept in the signature and unused. The field is a fixed scene now, not
    /// anything borrowed from the day. Both go once that is settled.
    let colours: [Color]
    let fill: Double

    /// **How much cloth is between you and the field.**
    ///
    /// **It came down from 0.86 when the sheet moved into the lattice.**
    ///
    /// While this was the only translucent thing on the screen it had to do all
    /// the diffusing itself, so the scene was buried under it. Now the cells are
    /// the panes and this is only the haze between them, so the scene can be
    /// closer to the surface: what you see through a gap is nearly the scene,
    /// and what you see through a cell is the scene through cloth. That
    /// difference is the depth.
    static let veil: Double = 0.55

    /// Reduced transparency asks for less of exactly this: the sheet goes
    /// opaque and the page is the plain ground again.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if reduceTransparency {
                WarmBackground()
            } else {
                scene
                // The sheet. `WarmBackground.top` rather than pure white so the
                // page's own ground and this agree at the edges, and so dark
                // mode dims the scene instead of bleaching it.
                WarmBackground.top.opacity(Self.veil)
            }
        }
        .ignoresSafeArea()
    }

    /// Sky at the top, sun in it, grass along the bottom.
    ///
    /// A 3x3 `MeshGradient` because a mesh has interior control points: the
    /// horizon can bow and the sun can pool, where stacked gradients can only
    /// fall off evenly from a centre. The sun sits off to one side because light
    /// in a room comes from somewhere, and a centred one reads as a vignette.
    private var scene: some View {
        MeshGradient(width: 3, height: 3,
                     points: Self.points,
                     colors: scheme == .dark ? Self.night : Self.day,
                     smoothsColors: true)
    }

    /// The interior point is high and to the right — the sun — and the bottom
    /// row is pulled up slightly in the middle, which bows the horizon and stops
    /// the grass reading as a straight band across the page.
    private static let points: [SIMD2<Float>] = [
        .init(0.0, 0.0),  .init(0.5, 0.0),   .init(1.0, 0.0),
        // **The middle row sits high, which puts the horizon high.**
        //
        // It was at 0.46 and the green only arrived in the last few hundred
        // pixels — which are the pixels the tower covers, so the field was
        // measurably there and effectively invisible. Pulling this row up gives
        // the sky-to-grass interpolation the whole lower half to happen in, so
        // the ground shows in the empty part of the lattice where there is
        // actually something to see it against.
        .init(0.0, 0.30), .init(0.68, 0.22), .init(1.0, 0.27),
        .init(0.0, 1.0),  .init(0.5, 0.94),  .init(1.0, 1.0),
    ]

    /// **Saturated on purpose.** These are read through 86% cloth, so anything
    /// timid here arrives as nothing at all. Judged by what comes out, not by
    /// how they look written down.
    private static let day: [Color] = [
        sky(0.50), sky(0.34), sky(0.62),
        sky(0.26), sun,       sky(0.40),
        // **NO GREEN.** "I don't think I like the green, I think more blue and
        // just light." So the foot of the scene is a pale cool light rather
        // than a field: the sky comes all the way down and simply brightens.
        foot(0.16), foot(0.10), foot(0.20),
    ]

    /// Night is the same scene after dark: the sky deepens, the sun is gone, the
    /// field goes to almost nothing. The same shape, so the page does not become
    /// a different place when the lights go out.
    private static let night: [Color] = [
        Color(hue: 0.60, saturation: 0.45, brightness: 0.30),
        Color(hue: 0.60, saturation: 0.40, brightness: 0.34),
        Color(hue: 0.60, saturation: 0.48, brightness: 0.28),
        Color(hue: 0.60, saturation: 0.38, brightness: 0.26),
        Color(hue: 0.11, saturation: 0.30, brightness: 0.34),
        Color(hue: 0.60, saturation: 0.42, brightness: 0.24),
        Color(hue: 0.33, saturation: 0.35, brightness: 0.18),
        Color(hue: 0.33, saturation: 0.30, brightness: 0.20),
        Color(hue: 0.33, saturation: 0.38, brightness: 0.16),
    ]

    private static func sky(_ s: Double) -> Color {
        Color(hue: 0.575, saturation: s, brightness: 0.99)
    }

    /// The bottom of the scene: the same sky hue, barely saturated, bright.
    /// Light rather than ground.
    private static func foot(_ s: Double) -> Color {
        Color(hue: 0.575, saturation: s, brightness: 1.0)
    }

    /// Warm, barely coloured, very bright. A sun seen through cloth is a bright
    /// patch rather than a disc, which is also why it is a mesh point and not a
    /// circle drawn on top.
    private static let sun = Color(hue: 0.12, saturation: 0.22, brightness: 1.0)
}
