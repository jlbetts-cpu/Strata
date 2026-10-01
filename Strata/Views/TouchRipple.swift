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
/// highlight: no fill, no colour, and it is gone in well under a second. A
/// control in this app responds by compressing — `charge`, `tapSquashSpring` —
/// and nothing here does that. If this ever grows a tint or a tap-through, it
/// has become an affordance and is lying.
///
/// **It does have a haptic now, and the reason is the rule below it.** The
/// first version said "no haptic", on the argument that a haptic is what a
/// control gives you. That was right while the ripple fired on EVERY tap,
/// including taps that opened a sheet — a tick there would have been a second
/// voice answering the same touch as the button. Now that it only ever fires
/// where there is no control, the tick is the only thing saying anything at
/// all, and what it says is "that was a surface". `HapticsEngine.surface` is
/// the faintest rung in the engine, a third of a `lightTap`, and it is below
/// everything else on purpose: every other haptic in this app is telling you
/// about something you did.
///
/// **THE SHADOW IS GONE, AND THAT IS THE WHOLE OF THIS VERSION.**
///
/// It was neumorphic: a white highlight on the side facing the light and a grey
/// shadow on the side facing away, off the reference the owner sent. Built,
/// measured, tuned up until it read — and his verdict on the result is the one
/// that settles it: "make the ripple effect a lot more subtle, like a lot more
/// subtle, because right now it makes it look cheap... the shadow is too much."
///
/// He is right, and the fault is in the idea rather than in the number. The grey
/// ring is a SMUDGE: it is the only thing in the app that puts dirt on the page,
/// on a page that has just been taken to clean white precisely so nothing does.
/// Tuning it down does not fix that — it makes a fainter smudge — which is why
/// this is a different effect rather than a smaller one.
///
/// **One ring, made only of light.** The page brightens a hair where the ring
/// is and nothing anywhere goes darker. On a 247 page white has eight levels of
/// headroom, so the ceiling on how loud this can ever be is built into it: it
/// cannot shout, and it cannot look cheap, because there is nothing there to
/// look cheap WITH. It is the same material argument the rest of the app is
/// made of — every cue here is made of light, and the one that was not is the
/// one he kept objecting to.
///
/// If it is still too much, the next step is not another number. It is deleting
/// the file.
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
    /// Soft, and wide, and that is all there is to it now. There is no offset
    /// any more: an offset existed to separate a highlight from a shadow, and
    /// there is no shadow.
    static let shadowBlur: CGFloat = 11
    static let bandWidth: CGFloat = 18

    /// **How bright the ring gets, at its strongest.**
    ///
    /// This is the one number, and the arithmetic is the reason it is safe. The
    /// page is 247, so pure white at full alpha moves it eight levels; at 0.55,
    /// blurred over eleven points, the peak measures four. Four levels is at the
    /// edge of what anybody can see on a flat field and well under what reads as
    /// a mark on one, which is exactly the brief.
    static let lightStrength: Double = 0.55

    /// The lit side: the page, taken up. On the light page that lands on white;
    /// on the dark one it is a warm grey, because white would be a hole in it.
    static let light = Color(uiColor: UIColor { traits in
        let ground = UIColor(WarmBackground.top).resolvedColor(with: traits)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ground.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s * 0.5,
                       brightness: min(1, b + 0.22), alpha: 1)
    })

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

    /// One soft band of light, and nothing else drawn anywhere.
    ///
    /// See the type's own note for why the grey half is gone rather than
    /// quieter: a dark ring is dirt on a page that exists to have none, and a
    /// fainter one is fainter dirt.
    static func draw(_ ring: Int, of ripple: TouchRipple,
                     at now: Date, in context: inout GraphicsContext) {
        guard let front = ripple.front(ring, at: now) else { return }
        let radius = front.radius
        let rect = CGRect(x: ripple.at.x - radius, y: ripple.at.y - radius,
                          width: radius * 2, height: radius * 2)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: TouchRipple.shadowBlur))
            layer.stroke(Path(ellipseIn: rect),
                         with: .color(TouchRipple.light
                            .opacity(TouchRipple.lightStrength * front.fade)),
                         lineWidth: TouchRipple.bandWidth)
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
    /// The gesture lives on a plate BEHIND the content, not on the content, so
    /// a tap that any control claims never reaches it. See the modifier.
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
            // **AN ORDINARY TAP ON THE CONTAINER, AND THAT IS THE WHOLE
            // GATING MECHANISM.**
            //
            // The owner: "the ripple only shows up when you click on an area
            // with no button, not one with a button — right, that's the right
            // way to go about it." It is, and the gesture was doing the exact
            // opposite: a `.simultaneousGesture`, which is the one kind that
            // CANNOT be swallowed. Every tap rippled — opening a win, pressing
            // the slot, changing tab — so the page was answering touches
            // something else had already answered. Two voices for one event.
            //
            // SwiftUI gives a CHILD's gesture priority over its container's, so
            // a plain `.onTapGesture` here is exactly the rule he asked for and
            // needs nothing to know about anything else: a block, a button, the
            // slot and the tab bar each take their own tap, and only a tap that
            // nothing claimed reaches this. A control added tomorrow is excluded
            // the moment it is added.
            //
            // **A plate behind the content was tried first and does not work.**
            // The obvious shape — a transparent, hit-testable rectangle in the
            // background, so only unclaimed taps fall through to it — never
            // fired once. Built, tapped on a real simulator with the handler
            // logging, and the log stayed empty for taps on the page, on the
            // header and on empty grid alike.
            //
            // Verified the same way, which is the only way this could be
            // verified at all since nothing here can tap: a tap on the empty
            // page logs, and a tap on a block opens the edit sheet and logs
            // nothing.
            .onTapGesture(coordinateSpace: .named(TouchRipple.space)) { location in
                HapticsEngine.surface()
                ripples.append(TouchRipple(at: location, born: Date()))
                sweep()
            }
            .background { TouchRippleLayer(ripples: ripples).allowsHitTesting(false) }
            // One space for the whole page, so the lattice — which is inside a
            // scroll view, inside the tower, several frames deep — can work out
            // where the finger was relative to its own cells.
            .coordinateSpace(.named(TouchRipple.space))
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
