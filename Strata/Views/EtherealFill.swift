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
    static let coreBoost: Double = 0.12

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
    static let rimSaturation: Double = 0.82
    static let rimLift: Double = 0.05

    /// Where the light is, as a unit point. **Centred, near enough.** It was
    /// (0.42, 0.34) on the reasoning that light comes from above; measured
    /// against the reference, that is wrong — its most saturated point is at
    /// 50% vertically and about 40% across. The light from above is carried by
    /// the RIM, which is a separate thing and already brightest at the top.
    static let core = UnitPoint(x: 0.46, y: 0.5)

    /// `reachFraction` is relative to the half-size: 0.5 lands the rim colour
    /// exactly on the edge midpoints. A hair over that keeps a trace of the hue
    /// at the very corner, which is what stops the shape looking cut out.
    static let reachFraction: CGFloat = 0.52

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
        EllipticalGradient(
            colors: [core(of: colour), rim(of: colour)],
            center: aim.core,
            startRadiusFraction: 0,
            endRadiusFraction: Self.reachFraction
        )
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

/// The reference's button: a capsule of that fill, a light rim, a soft bloom
/// around it, and a white glyph.
///
/// **The lift is a bloom, not a shadow**, and that is deliberate. The reference
/// has no drop shadow at all — the pill sits in a soft halo of its own colour,
/// which is what a lit object does to the page around it. A shadow would say the
/// button is a solid thing casting darkness, and `docs/design-system-future.md`
/// §6 reserves shadow for things standing on something.
struct EtherealPill<Label: View>: View {
    var colour: Color
    var height: CGFloat = 56
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var isDown = false

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            label()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background {
                    Capsule(style: .continuous)
                        .fill(EtherealFill.fill(colour))
                }
                .overlay {
                    // The light rim. Brightest along the top, because that is
                    // where the light is; it never goes dark at the foot.
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.85),
                                                    .white.opacity(0.35)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
                }
                .background {
                    // The bloom. Sits behind everything, blurred, in the
                    // button's own colour, so the page around it is lit rather
                    // than shaded.
                    Capsule(style: .continuous)
                        .fill(colour.opacity(0.45))
                        .blur(radius: 18)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .scaleEffect(isDown ? 0.975 : 1)
                .animation(GridConstants.tapSquashSpring, value: isDown)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isDown = true }
                .onEnded { _ in isDown = false }
        )
    }
}
