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
    static let coreBoost: Double = 0.06

    /// How far the rim is pulled toward white: saturation cut to this share,
    /// brightness raised toward 1.
    static let rimSaturation: Double = 0.62
    static let rimLift: Double = 0.10

    /// Where the light is, as a unit point. Above centre, slightly left, which
    /// is where every highlight in this app already comes from.
    static let core = UnitPoint(x: 0.42, y: 0.34)

    /// The fill itself.
    ///
    /// `endRadiusFactor` is relative to the shape's larger side: past about 0.95
    /// the rim colour never fully arrives and the object looks flat again, and
    /// under about 0.6 the core becomes a visible disc rather than a glow.
    static func gradient(_ colour: Color, size: CGSize) -> RadialGradient {
        // **The DIAGONAL, not the longer side.** At 0.86 of the longer side the
        // gradient finished well inside a square block and the core read as a
        // visible disc with an edge — a spot, not a glow. Reaching past the
        // corners is what makes it a wash across the whole face.
        let reach = hypot(size.width, size.height) * 1.05
        return RadialGradient(
            colors: [core(of: colour), rim(of: colour)],
            center: Self.core,
            startRadius: 0,
            endRadius: max(reach, 1)
        )
    }

    /// A version for callers that do not know their size — a capsule button, a
    /// chip — expressed in unit space so it scales with whatever it fills.
    static func gradient(_ colour: Color) -> RadialGradient {
        RadialGradient(colors: [core(of: colour), rim(of: colour)],
                       center: Self.core, startRadius: 0, endRadius: 190)
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
                        .fill(EtherealFill.gradient(colour))
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
