import SwiftUI

/// **Rings under your finger when you touch the page itself.**
///
/// The owner, 2026-09-30, with a neumorphism reference: "I would love a subtle
/// ripple effect when you tap an element of the screen that doesn't have a
/// button or anything, like this ripple effect." Then, after the first two
/// goes: "the ripple has to be a lot better... make sure it is behind the
/// blocks and it works all over the screen, in the header as well. Make sure it
/// also interacts with the lattice, like it looks like the lattice is also
/// participating in the moving."
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
/// `#AEAEC0` at 20%.
struct TouchRipple: Identifiable, Equatable {
    let id = UUID()
    let at: CGPoint
    let born: Date

    /// **The page's coordinate space**, named so that two things which are in
    /// very different parts of the view tree can agree on where a finger was:
    /// the ring, which is drawn in the page's background, and the lattice,
    /// which is deep inside the scrolling tower and has to swell in the right
    /// place. Everything that reads a touch point reads it in here.
    static let space = "strata.page"

    /// **How long a ring lives.** `docs/design-system-future.md` §5 allows
    /// nothing over 0.7s and nothing that loops. This is one pass, and it ends.
    static let life: TimeInterval = 0.58

    /// How far the outermost ring travels, in points. Wide enough to read as
    /// the surface answering, short enough that it never reaches the edge of
    /// the screen and turns into an event.
    /// **Condensed, at the owner's word.** It was 132 and read as an event
    /// crossing the page; a ripple from a fingertip is the size of a fingertip
    /// disturbing something, not a wave.
    static let reach: CGFloat = 76

    /// **Two rings, not three.**
    ///
    /// Three were drawn at a 0.26 step, which meant the third one opened at
    /// half the strength of a first ring that was already at the edge of
    /// visible. It did not read as a third ring; it read as the first two
    /// smearing. Premium is subtraction: two rings, both of which you can
    /// actually see, and the second far enough behind to be a second thing.
    static let rings = 2
    static let stagger: TimeInterval = 0.09

    /// The reference's own parameters: `-4px -4px 6px #FFFFFF` against
    /// `4px 4px 6px #AEAEC0 20%`, **scaled to a travelling ring.**
    ///
    /// Those numbers are for a big resting panel, and taken literally here they
    /// came to nothing — measured on the built screen, the whole ripple spanned
    /// NINE levels of grey against a background that varies by eleven on its
    /// own. That is not a subtle effect, it is an absent one.
    ///
    /// The reason is headroom, which is the same thing that has caught this
    /// page twice already. The ground is around 240, so a white band has about
    /// fifteen levels to work with however opaque it is, and the shadow colour
    /// is only sixty-six levels below the ground to begin with — at 20% alpha,
    /// blurred over a 5pt band, it moved four. A thin soft pair that works on a
    /// 200pt button does not survive being a 1pt-wide ring in motion.
    ///
    /// So the band is wide and the shadow carries it: at these numbers the dark
    /// side of the ring reads about twenty levels under the page at its peak
    /// and the light side about twelve over it, which is a surface moving
    /// rather than a line drawn on one.
    static let offset: CGFloat = 5
    static let shadowBlur: CGFloat = 9
    static let bandWidth: CGFloat = 16
    static let shadeStrength: Double = 0.62
    static let lightStrength: Double = 1.0
    /// #AEAEC0, the reference's shadow colour.
    static let shade = Color(red: 0.682, green: 0.682, blue: 0.753)

    /// Whether this ring is still worth drawing, so the layer that draws them
    /// can take itself down — and, more importantly, so the lattice's own
    /// `TimelineView` is only ever mounted while something is moving.
    func isAlive(at now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(born)
        return age > -0.01 && age < Self.life + Self.stagger * Double(Self.rings)
    }

    /// **Where this ring's front is, and how strongly it is drawn**, for a
    /// given ring index at a given moment — or `nil` when that ring is not in
    /// the air.
    ///
    /// Out here rather than inside the drawing code because the lattice needs
    /// exactly the same answer: if the panes swelled on a second curve, the
    /// surface and the ring on it would be moving at two different speeds, and
    /// the one thing this has to look like is one disturbance.
    func front(_ ring: Int, at now: Date) -> (radius: CGFloat, fade: Double)? {
        let age = now.timeIntervalSince(born) - Double(ring) * Self.stagger
        guard age > 0, age < Self.life else { return nil }
        let t = age / Self.life
        // Out fast, then slowing: a ring on water loses speed as it widens.
        // `1 - (1 - t)^3` is that curve, and it is the one `--ease-out` means.
        let radius: CGFloat = Self.reach * CGFloat(1 - pow(1 - t, 3))
        guard radius > 1 else { return nil }
        let fade = (1 - t) * (ring == 0 ? 1 : 0.55)
        return (radius, fade)
    }
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
            // **IT MEASURES WHERE IT IS, RATHER THAN ASSUMING.**
            //
            // The owner: "the ripple doesn't go all the way to the battery and
            // time, it gets cut off." It was a plain background, so it was laid
            // out INSIDE the safe area and ended at the status bar — a ring
            // started near the top of the page ran into a straight horizontal
            // edge, which is the one thing a ring on water cannot do.
            //
            // `.ignoresSafeArea()` on its own would fix the clipping and break
            // the aim: the canvas would start 60-odd points higher than the
            // space the finger was measured in, and every ring would be drawn
            // that far down the page. So the canvas asks where its own origin
            // sits in the page's space and shifts the drawing by it. That is
            // self-correcting — it holds whatever insets, orientation or chrome
            // the page ends up with, and it is the same trick `TowerLattice`
            // uses to find a finger from inside a scrolled tower.
            GeometryReader { geo in
                let origin = geo.frame(in: .named(TouchRipple.space)).origin
                TimelineView(.animation) { timeline in
                    Canvas { context, _ in
                        context.translateBy(x: -origin.x, y: -origin.y)
                        let now = timeline.date
                        for ripple in ripples {
                            for ring in 0..<TouchRipple.rings {
                                TouchRippleLayer.draw(ring, of: ripple,
                                                      at: now, in: &context)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    /// **EMBOSSED, TO THE REFERENCE'S OWN IDEA IF NOT ITS OWN NUMBERS.**
    ///
    /// The first cut drew two 1.6pt strokes and the owner was right that it was
    /// not the effect: the tutorial was in the screenshot he sent and I did not
    /// follow it. Neumorphism is not a pair of lines, it is a pair of SHADOWS —
    /// one light source up and to the left, so every raised edge takes a white
    /// glow on the near side and a grey one on the far side, both blurred. That
    /// is what makes a surface look pressed rather than drawn on.
    ///
    /// So each ring is a thick soft band drawn twice, offset each way and
    /// blurred, in its two colours. See `bandWidth` for why the weights are not
    /// the reference's.
    static func draw(_ ring: Int, of ripple: TouchRipple,
                     at now: Date, in context: inout GraphicsContext) {
        guard let front = ripple.front(ring, at: now) else { return }
        let radius = front.radius
        let rect = CGRect(x: ripple.at.x - radius, y: ripple.at.y - radius,
                          width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)
        let band = TouchRipple.bandWidth

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: TouchRipple.shadowBlur))
            layer.translateBy(x: -TouchRipple.offset, y: -TouchRipple.offset)
            layer.stroke(circle,
                         with: .color(.white.opacity(TouchRipple.lightStrength * front.fade)),
                         lineWidth: band)
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: TouchRipple.shadowBlur))
            layer.translateBy(x: TouchRipple.offset, y: TouchRipple.offset)
            layer.stroke(circle,
                         with: .color(TouchRipple.shade.opacity(TouchRipple.shadeStrength * front.fade)),
                         lineWidth: band)
        }
    }
}

extension View {
    /// Answers a touch on the page itself with rings, and swallows nothing.
    ///
    /// **Attach this to the whole page, not to the scrolling part of it.** The
    /// owner asked for it "all over the screen, in the header as well", and the
    /// header is a `safeAreaInset`, which is outside the content it insets.
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
            // **BEHIND, NOT OVER.**
            //
            // It was an `.overlay`, so the rings crossed the blocks — and a
            // block is an opaque object standing on this surface. A ripple that
            // runs over the top of one says the rings are a film laid on the
            // screen; a ripple that disappears under one says the page is a
            // material and the blocks are sitting on it. The owner asked for
            // the second, and it is also the only version that can be true.
            //
            // This is why it is worth the ring being quite strong: most of what
            // it crosses on a full tower is hidden, and what shows is the part
            // of the page nothing is standing on.
            .background { TouchRippleLayer(ripples: ripples) }
            // One space for the whole page, so the lattice — which is inside a
            // scroll view, inside the tower, several frames deep — can work out
            // where the finger was relative to its own cells.
            .coordinateSpace(.named(TouchRipple.space))
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named(TouchRipple.space))
                    .onEnded { value in
                        ripples.append(TouchRipple(at: value.location, born: Date()))
                        sweep()
                    }
            )
    }

    /// **Dead rings are dropped on a timer, not on the next tap.**
    ///
    /// They used to be swept only when a new one arrived, which left the array
    /// non-empty for as long as nobody touched anything — and `TowerLattice`
    /// mounts a `TimelineView` while this is non-empty. A timeline that never
    /// goes away is the exact cost that kept the lattice's landing animation
    /// off one, measured at a 50ms frame gap per mount. So the last ripple
    /// clears itself.
    private func sweep() {
        let wait = TouchRipple.life + TouchRipple.stagger * Double(TouchRipple.rings)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait + 0.05))
            let now = Date()
            ripples.removeAll { !$0.isAlive(at: now) }
        }
    }
}
