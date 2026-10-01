import SwiftUI

/// **Colour lit from inside, rather than painted on.**
///
/// The owner, 2026-09-30, with two reference images: "can we make the main
/// buttons like this... I want the blocks to have this kinda glass transparency
/// as well in them, for the inner colour instead of just flat. Like this
/// stunning feel in all the UI, real sense of ethereal glass aesthetic."
///
/// **The reference's trick is that the gradient is RADIAL and inside-out.** Look
/// at the blue pill: the middle is the most saturated part and the colour thins
/// toward the rim, where it goes pale and almost white. That is the whole
/// effect. A top-to-bottom gradient — which is what this app used everywhere —
/// reads as a surface with a light above it. An inside-out radial reads as a
/// body with a light INSIDE it, and that difference is the entire distance
/// between "a coloured rectangle" and "a piece of glass".
///
/// Three rules taken off the reference and applied everywhere this is used:
///
/// 1. **Saturated at the core, pale at the rim.** Not lighter at the top.
/// 2. **The core sits slightly above centre**, because the light is above. Dead
///    centre reads as a vignette, which is a photograph's flaw rather than an
///    object's property.
/// 3. **No dark edge anywhere.** The reference has no shading at the bottom of
///    the pill at all; it ends in light. A dark rim would make it a button with
///    a bevel, which is a different and much older idea.
enum EtherealFill {

    /// How much more saturated the core is than the colour handed in.
    ///
    /// **A QUARTER OF WHAT IT WAS.** The owner, 2026-09-30, looking at a whole
    /// tower rather than one block: "all the blocks have individual splotches
    /// and they are too strong."
    ///
    /// He is describing an arithmetic fact. At 0.12 over 0.82 this moved the
    /// green channel of a red block by FORTY-NINE levels between its core and
    /// its corner, which is more than the whole page varies across itself. One
    /// block of that is a lit object; nine of them in a stack is nine separate
    /// marks, and the eye counts marks.
    static let coreBoost: Double = 0.035

    /// **How far the rim is pulled toward white.**
    ///
    /// The reference pill's core reads hsb(0.552, 0.698, 0.988) and its rim
    /// reads hsb(0.560, 0.056, 0.980): the saturation is cut to about EIGHT
    /// PERCENT of the core's. It was taken to 0.16 — the reference's own ratio
    /// — and that WAS TOO FAR, for a reason the reference cannot tell you: **it
    /// is a button, and a block is not.** At 0.16 the blocks lost their edges,
    /// and a tower of glowing blurs is not a tower.
    ///
    /// Then 0.44, and the owner's verdict settles it: "I like when it's more
    /// full of colour, right now it looks really bad."
    ///
    /// **A BLOCK IS A COLOURED OBJECT FIRST AND A PIECE OF GLASS SECOND.** The
    /// tower's whole job is to be a wall of colour, and a rim that drains it is
    /// taking away the thing the screen is for in order to win an argument
    /// about material. 0.82 keeps the block full: the glow is a lift at the
    /// core rather than a drain at the rim.
    ///
    /// **A softer, off-centre, never-completing version of this was built and
    /// thrown away**, on the owner's "now the blocks look too flat". It was a
    /// smoothstep ramp from a bleached highlight at (0.33, 0.26) out past the
    /// corner, which is what `docs/reference-board.md` §1 describes. His next
    /// message was "wait, actually your last update cooked, I like it a lot" —
    /// about THIS one. Written down so nobody builds it a second time: the
    /// flatness he saw was the label scrim coming off, not the gradient, and
    /// what the blocks actually wanted was a stronger EDGE. See `BlockRim`.
    /// **And 0.94, not 0.82, for the same reason.** The direction of this
    /// number has never changed — every move has been toward keeping the block
    /// full — and this is simply the end of it. What survives is a lift you can
    /// see across a tower and cannot point at on one block, which is what
    /// "subtle" has to mean when there are forty of them.
    static let rimSaturation: Double = 0.94
    static let rimLift: Double = 0.03

    /// Where the light is, as a unit point. **Centred, near enough.** It was
    /// (0.42, 0.34) on the reasoning that light comes from above; measured
    /// against the reference, that is wrong — its most saturated point is at
    /// 50% vertically and about 40% across. The light from above is carried by
    /// the RIM, which is a separate thing and already brightest at the top.
    static let core = UnitPoint(x: 0.46, y: 0.5)

    /// `reachFraction` is relative to the half-size, so 0.5 lands the far colour
    /// exactly on the edge midpoints.
    ///
    /// **Carried well past the corner on purpose.** A gradient that ARRIVES
    /// inside the shape has an edge in it: a ring where the change stops, with
    /// flat colour outside it. That ring is half of what reads as a splotch —
    /// the other half is the hotspot at the middle. At 0.78 the falloff is still
    /// going when it runs off the block, so there is no ring anywhere and the
    /// whole face is one continuous slope.
    static let reachFraction: CGFloat = 0.78

    /// **SMOOTHSTEP, NOT A STRAIGHT RAMP, AND THIS IS THE OTHER HALF OF IT.**
    ///
    /// A two-stop gradient interpolates linearly in radius, so its derivative
    /// has a corner at both ends: the eye finds the centre of the bright patch
    /// and the place it stops, and on a large field it bands — visible as faint
    /// concentric rings across a merged run.
    ///
    /// These stops sample `3t² - 2t³`, which leaves at zero slope and arrives at
    /// zero slope. Nowhere on the block does the rate of change jump, so there
    /// is nothing to catch: it reads as a surface that is lit rather than as a
    /// gradient that has been applied to one.
    private static let ramp: [Double] = [0, 0.12, 0.28, 0.5, 0.72, 0.88, 1]

    /// **An ELLIPSE, so it is the shape of whatever it fills.**
    ///
    /// This took two sized `RadialGradient` overloads and a `GeometryReader` at
    /// every call site, and a circle has one radius — so on anything that is not
    /// square the falloff completed on the long axis and barely started on the
    /// short one. Invisible on a single block, which is square; ruinous on a
    /// merged run three rows tall, which came out saturated through its middle
    /// and drained at both ends. An ellipse's radii are fractions of the view's
    /// own width and height, so it completes at every edge of whatever it is in,
    /// and it sizes itself.
    ///
    /// `aim` is where the light is. See `BlockLight`: in a tower the glow sits
    /// toward one lamp hanging over the whole stack rather than in the middle of
    /// each block, so two blocks either side of centre are lit from opposite
    /// sides. `.overhead` is the lone-object case and is what everything outside
    /// the tower uses.
    static func fill(_ colour: Color, aim: BlockAim = .overhead) -> EllipticalGradient {
        let a = core(of: colour), b = rim(of: colour)
        return EllipticalGradient(
            stops: ramp.map { t in
                Gradient.Stop(color: mix(a, b, by: t * t * (3 - 2 * t)), location: t)
            },
            center: aim.core,
            startRadiusFraction: 0,
            endRadiusFraction: Self.reachFraction
        )
    }

    private static func mix(_ a: Color, _ b: Color, by t: Double) -> Color {
        let (h1, s1, b1) = hsb(a), (h2, s2, b2) = hsb(b)
        return Color(hue: h1 + (h2 - h1) * t,
                     saturation: s1 + (s2 - s1) * t,
                     brightness: b1 + (b2 - b1) * t)
    }

    static func core(of colour: Color) -> Color {
        let (h, s, b) = hsb(colour)
        return Color(hue: h, saturation: min(1, s + coreBoost), brightness: b)
    }

    static func rim(of colour: Color) -> Color {
        let (h, s, b) = hsb(colour)
        return Color(hue: h, saturation: s * rimSaturation,
                     brightness: min(1, b + rimLift))
    }

    private static func hsb(_ colour: Color) -> (Double, Double, Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(colour).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }
}

// **`EtherealPill` is deleted** (2026-09-30). It was the reference's button
// built as a reusable view — the fill, a light rim, and a soft bloom behind
// rather than a shadow beneath — and it never gained a caller: onboarding's
// action was already assembled inline by the time this existed.
//
// It goes now rather than later because its bloom is a mistake the owner has
// since named: "why is there light coming off of it." The reference is a button
// floating in a render with nothing around it to light; this app's buttons stand
// on a page that is already clean white, where a halo in the button's own colour
// is not light but a stain. Leaving an unused view carrying that recipe is
// leaving a trap for whoever reaches for it next.
