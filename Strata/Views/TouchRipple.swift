import SwiftUI

/// **Rings under your finger when you touch the page itself.**
///
/// The owner, 2026-09-30, with a neumorphism reference: "I would love a subtle
/// ripple effect when you tap an element of the screen that doesn't have a
/// button or anything, like this ripple effect."
///
/// **What it is for.** Most of this screen is not a control. Tapping the empty
/// part of a tower currently does nothing and gives nothing back, which is
/// correct behaviour and a dead surface. This makes the page feel like a
/// material: touch it and it answers, without claiming anything happened.
///
/// **It must never be mistaken for a button.** So it is rings on water, not a
/// highlight: no fill, no colour, no sound, no haptic, and it is gone in well
/// under a second. A control in this app responds by compressing — `charge`,
/// `tapSquashSpring` — and nothing here does that. If this ever grows a tint or
/// a tap-through, it has become an affordance and is lying.
///
/// **Why the rings are a white one and a grey one, offset.** Straight off the
/// reference: neumorphism is one light source, so every raised edge carries a
/// white highlight on the side facing the light and a grey shadow on the side
/// facing away. A single grey ring reads as a drawn circle; the pair reads as
/// the surface itself moving. The reference's own numbers are `#FFFFFF` against
/// `#AEAEC0` at 20%, which is where these come from.
struct TouchRipple: Identifiable, Equatable {
    let id = UUID()
    let at: CGPoint
    let born: Date

    /// **How long a ring lives.** `docs/design-system-future.md` §5 allows
    /// nothing over 0.7s and nothing that loops. This is one pass, and it ends.
    static let life: TimeInterval = 0.62

    /// How far the outermost ring travels, in points. Wide enough to read as
    /// the surface answering, short enough that it never reaches the edge of
    /// the screen and turns into an event.
    static let reach: CGFloat = 132

    /// Three rings, launched slightly apart, which is what makes it water
    /// rather than one expanding circle.
    static let rings = 3
    static let stagger: TimeInterval = 0.08
}

/// Draws every live ripple. One `TimelineView`, not one per ripple, so an
/// excited finger costs the same as a patient one.
struct TouchRippleLayer: View {
    let ripples: [TouchRipple]

    /// Reduced motion gets nothing at all. This is decoration by definition —
    /// it carries no information — so it is the first thing to go.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || ripples.isEmpty {
            Color.clear
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let now = timeline.date
                    for ripple in ripples {
                        for ring in 0..<TouchRipple.rings {
                            draw(ring, of: ripple, at: now, in: &context)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func draw(_ ring: Int, of ripple: TouchRipple,
                      at now: Date, in context: inout GraphicsContext) {
        let age = now.timeIntervalSince(ripple.born) - Double(ring) * TouchRipple.stagger
        guard age > 0, age < TouchRipple.life else { return }
        let t = age / TouchRipple.life

        // Out fast, then slowing: a ring on water loses speed as it widens.
        // `1 - (1 - t)^3` is that curve, and it is the one `--ease-out` means.
        let eased = 1 - pow(1 - t, 3)
        let radius = TouchRipple.reach * eased
        guard radius > 1 else { return }

        // Fades the whole way, and the later rings start fainter so the set
        // reads as one disturbance rather than three circles.
        let fade = (1 - t) * (1 - Double(ring) * 0.26)
        let rect = CGRect(x: ripple.at.x - radius, y: ripple.at.y - radius,
                          width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)

        // The pair. White a hair inside, grey a hair outside: one light source,
        // so the near edge catches it and the far edge shades.
        context.stroke(circle, with: .color(.white.opacity(0.55 * fade)), lineWidth: 1.6)
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -1.4, dy: -1.4)),
                       with: .color(Color(red: 0.68, green: 0.68, blue: 0.75)
                                        .opacity(0.20 * fade)),
                       lineWidth: 1.6)
    }
}

extension View {
    /// Answers a touch on the page itself with rings, and swallows nothing.
    ///
    /// `.simultaneousGesture` rather than `.onTapGesture`, deliberately: a tap
    /// that lands on a block, the slot or the tab bar must still reach it. This
    /// only ever adds a ripple; it never consumes the touch, so there is no way
    /// for it to break something by being attached in the wrong place.
    func touchRipples(_ ripples: Binding<[TouchRipple]>) -> some View {
        modifier(TouchRippleModifier(ripples: ripples))
    }
}

private struct TouchRippleModifier: ViewModifier {
    @Binding var ripples: [TouchRipple]

    func body(content: Content) -> some View {
        content
            .overlay { TouchRippleLayer(ripples: ripples) }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        ripples.append(TouchRipple(at: value.location, born: Date()))
                        // Swept rather than counted: a ring is dead after its
                        // own lifetime plus the last stagger, and holding more
                        // than that is holding rubbish.
                        let cutoff = Date().addingTimeInterval(
                            -(TouchRipple.life + TouchRipple.stagger * Double(TouchRipple.rings)))
                        ripples.removeAll { $0.born < cutoff }
                    }
            )
    }
}
