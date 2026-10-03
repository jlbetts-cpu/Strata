import SwiftUI

/// **Somewhere to put him when you want him to stay still.**
///
/// The owner, 2026-10-02: "I like that the head moves but I wish there was a
/// way to place it when you dont want it to move... when you are dragging it
/// around a little liquid glass button appears and if you drag it into the
/// bubble with a clean animation like its actually entering and then if you
/// tap on it it will actually pop. make it clean and look native", and then:
/// "make the glass button right next to the plan and be the same size on the
/// left of the plan right next to it".
///
/// So: while the head is being dragged, a glass circle the Plan button's size
/// grows in one gap to its left. Over it, it
/// swells to say "let go here". Let go, and the head flies into it, shrinking
/// as it goes, and the glass gives a little as he lands. He stays there, still,
/// blinking, until the bubble is tapped: it pops, and he is back in the air
/// where it was.
///
/// The state is shared between two views that cannot see each other: the head
/// is drawn by `TowerCompanionRunner` in an overlay on the tower's scroll view,
/// and the bubble sits in the tower's header beside the Plan button. Parked is
/// remembered across launches.
@MainActor
@Observable
final class CompanionParking {
    static let shared = CompanionParking()

    /// A finger is carrying the head. The bubble shows while this is true.
    var dragging = false
    /// The finger is over the bubble, so letting go parks him.
    var over = false
    /// He is in the bubble.
    var parked: Bool {
        didSet { UserDefaults.standard.set(parked, forKey: Self.key) }
    }
    /// The head is in the air between the finger and the bubble.
    var arriving = false
    /// The bubble is bursting and drawing him as it does. He is no longer
    /// parked (so the tower's clock is already running when it takes him) but
    /// the tower does not draw him yet.
    var releasing = false
    /// Bumped when he lands in the bubble, so the glass can give.
    var landed = 0
    /// Bumped when the bubble pops, so the head can come back out of it.
    var popped = 0
    #if DEBUG
    /// `-strataDockCycle`: asks the bubble to pop, as a tap would.
    var debugPop = 0
    #endif
    /// The bubble's frame in the window, reported by the bubble itself.
    var dockFrame: CGRect = .zero
    /// Where the finger let go of him, in the window, while he flies in. The
    /// BUBBLE draws the flight, not the tower overlay: the header sits over
    /// that overlay, so a flight drawn there went under the glass and arrived
    /// as a frosted silhouette before snapping sharp (filmed, 2026-10-02).
    var flightFrom: CGPoint?
    /// His drawn height out on the tower, so the flight starts at his size.
    var headSide: CGFloat = 60

    /// Let go over the bubble: the bubble takes him from here.
    func beginArrival(from global: CGPoint, side: CGFloat) {
        headSide = side
        arriving = true
        dragging = false
        flightFrom = global
    }

    private static let key = "strata.companionParked"

    private init() {
        parked = UserDefaults.standard.bool(forKey: Self.key)
    }

    /// Whether the bubble is on screen at all.
    var showsDock: Bool { dragging || arriving || parked || releasing }

    /// A finger at this window point is "in" the bubble: its own circle and a
    /// little more, because a head is bigger than a fingertip.
    func isOver(_ global: CGPoint) -> Bool {
        guard dockFrame.width > 0 else { return false }
        return dockFrame.insetBy(dx: -Self.catchSlop, dy: -Self.catchSlop).contains(global)
    }

    static let catchSlop: CGFloat = 18
    /// The head's height inside the bubble: the bubble's 44 less a margin, so
    /// glass shows all the way round him.
    static let parkedSide: CGFloat = GlassIconButton.defaultSide - 10
}

/// The bubble, beside the Plan button. Draws nothing until it has a reason to.
struct CompanionDock: View {
    @State private var parking = CompanionParking.shared
    /// The glass bursting outward as it pops, for one beat.
    @State private var bursting = false
    /// The finger's press, the beat before the burst.
    @State private var pressing = false
    /// 0 to 1, the droplets flying out of the burst.
    @State private var spray: CGFloat = 0
    /// 0 to 1, him growing out of the burst to his own size.
    @State private var grow: CGFloat = 0
    /// 0 where the finger let go, 1 in the bubble.
    @State private var flight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Only when the tower head is switched on: the bubble is his.
        if let rig = HeadStore.shared.headForTower, parking.showsDock || bursting {
            bubble(rig: rig)
                // Its own glass, beside the Plan button's rather than joined to
                // it: in one glass group the two blended into a single peanut
                // at rest, and the owner asked for a button next to the Plan,
                // not part of it.
                .transition(reduceMotion ? .opacity
                            : .scale(scale: 0.4).combined(with: .opacity))
        }
    }

    private func bubble(rig: HeadRig) -> some View {
        let side = GlassIconButton.defaultSide
        return Color.clear
        .frame(width: side, height: side)
        .contentShape(Circle())
        // Still glass: the bubble answers the press itself (the dip below),
        // and the system's interactive glow hid him for the length of it.
        .stillGlassCircle()
        // "Let go here": the glass swells under the head before the finger
        // lifts, the way a drop target answers in the system.
        .scaleEffect(parking.over && !reduceMotion ? 1.18 : 1)
        .animation(GridConstants.motionSnappy, value: parking.over)
        // He lands: the glass gives and comes back.
        .phaseAnimator([false, true], trigger: parking.landed) { content, phase in
            content.scaleEffect(phase && !reduceMotion ? 1.12 : 1)
        } animation: { phase in
            phase ? GridConstants.tapSquashSpring : GridConstants.elasticPop
        }
        // The press: the glass dips under the finger before it goes.
        .scaleEffect(pressing && !reduceMotion ? 0.86 : 1)
        // The pop: the glass grows and is gone, faster than it arrived.
        .scaleEffect(bursting && !reduceMotion ? 1.6 : 1)
        .opacity(bursting ? 0 : 1)
        // And what it was made of flies off.
        .background { droplets }
        // Him, over the glass and outside its fade, in this layer the whole
        // time he is the bubble's. See `head(rig:)`.
        .overlay { head(rig: rig) }
        .onTapGesture { pop() }
        .onChange(of: parking.flightFrom) { _, from in
            guard from != nil else { return }
            flight = 0
            withAnimation(GridConstants.parkFlight) {
                flight = 1
            } completion: {
                parking.parked = true
                parking.arriving = false
                parking.flightFrom = nil
                parking.landed += 1
                HapticsEngine.success()
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
            parking.dockFrame = $0
            registerObstacle()
        }
        // **Something he floats around, except while you are putting him in
        // it.** As an obstacle all the time, it held a carried head beside it
        // and he could never be dragged INTO the bubble (filmed, 2026-10-02).
        .onChange(of: parking.dragging) { registerObstacle() }
        #if DEBUG
        .onChange(of: parking.debugPop) { pop() }
        #endif
        .onDisappear { CompanionObstacles.shared.remove("dock") }
        .accessibilityElement()
        .accessibilityLabel("Your head, parked")
        .accessibilityHint("Double-tap to pop the bubble and let him float again.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pop() }
        .accessibilityHidden(!parking.parked)
    }

    /// **Him, for as long as he is the bubble's: one view, start to finish.**
    ///
    /// Flying in he shrinks from his tower size to fit the glass, parked he
    /// sits in it, pressed he dips with it, and bursting he grows back to his
    /// own size on its spot, where the tower takes him. It was three views,
    /// one per state, and each new one had to load his face: filmed, the
    /// flight's first frame was a grey head and the pop showed an empty
    /// bubble for 100ms before he faded in (2026-10-02). One view loads once.
    /// Drawn at his full size and scaled down, so he is never a small picture
    /// enlarged. Over the glass, so he is sharp; outside its fade, so the
    /// burst does not take him with it.
    @ViewBuilder
    private func head(rig: HeadRig) -> some View {
        if parking.flightFrom != nil || parking.parked || bursting {
            let full = parking.headSide
            let fit = CompanionParking.parkedSide / max(full, 1)
            let place = headPlacement(fit: fit)
            LivingHeadView(rig: rig, side: full, liveliness: .calm)
                .frame(width: full, height: full)
                .scaleEffect(place.scale * (pressing && !reduceMotion ? 0.86 : 1))
                .offset(place.offset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                // Taken over in one frame, never faded in.
                .transition(.identity)
                .animation(nil, value: parking.over)
        }
    }

    /// Where `head(rig:)` draws him and how big, for the state he is in.
    private func headPlacement(fit: CGFloat) -> (scale: CGFloat, offset: CGSize) {
        if bursting {
            return (fit + (1 - fit) * grow, .zero)
        }
        if let from = parking.flightFrom {
            let dx = from.x - parking.dockFrame.midX
            let dy = from.y - parking.dockFrame.midY
            return (1 + (fit - 1) * flight,
                    CGSize(width: dx * (1 - flight), height: dy * (1 - flight)))
        }
        return (fit, .zero)
    }

    /// **Eight drops of the bubble's glass**, flung out of the burst and gone.
    /// Small, quick and evenly spread, turned a little so none sits on the
    /// Plan button's line. Drawn only while the bubble pops.
    @ViewBuilder
    private var droplets: some View {
        if bursting && !reduceMotion {
            ZStack {
                ForEach(0..<Self.dropCount, id: \.self) { i in
                    let angle = Double(i) / Double(Self.dropCount) * 2 * .pi + 0.35
                    let size = (i.isMultiple(of: 2) ? 9 : 6) * (1 - spray * 0.5)
                    // A soap-bubble drop: a fine ink rim round a little
                    // material. Glass alone on a white page is white, and
                    // filmed, the drops could barely be seen.
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(AppColors.inkTertiary.opacity(0.55),
                                                       lineWidth: 1))
                        .frame(width: size, height: size)
                        .offset(x: cos(angle) * (dropStart + (dropReach - dropStart) * spray),
                                y: sin(angle) * (dropStart + (dropReach - dropStart) * spray))
                        // Bright for most of the throw, gone at the end.
                        .opacity(Double(1 - spray * spray))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private static let dropCount = 8
    /// Out past his own edge, because he grows to full size in the same beat:
    /// at a fixed 40pt the drops flew out from underneath a 76pt head and
    /// were never seen (filmed, 2026-10-02).
    private var dropReach: CGFloat { parking.headSide / 2 + 22 }
    /// They leave from his edge, so none of the throw is spent under him.
    private var dropStart: CGFloat { parking.headSide * 0.4 }

    /// **The pop, in two beats**: the glass dips under the finger, then
    /// bursts outward and throws its drops while he springs out. Under Reduce
    /// Motion it is a fade and nothing flies.
    private func registerObstacle() {
        if parking.dragging || parking.dockFrame.width == 0 {
            CompanionObstacles.shared.remove("dock")
        } else {
            CompanionObstacles.shared.set("dock", parking.dockFrame)
        }
    }

    private func pop() {
        guard parking.parked, !bursting, !pressing else { return }
        HapticsEngine.lightTap()
        if reduceMotion {
            burst()
            return
        }
        withAnimation(GridConstants.tapSquashSpring) {
            pressing = true
        } completion: {
            pressing = false
            burst()
        }
    }

    private func burst() {
        HapticsEngine.snap()
        spray = 0
        grow = 0
        // **The burst first, then let go of "parked".** In the other order
        // SwiftUI rendered between the two lines: for one frame the bubble
        // had no reason to exist, was removed, and came back with its own
        // appear transition, so the pop showed an empty header and then a
        // faded head growing in (filmed, 2026-10-02). `releasing` also keeps
        // `showsDock` true on its own, so the order is belt and braces.
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.popBurst) {
            bursting = true
            grow = 1
        } completion: {
            // He is at his own size on the bubble's spot: the tower takes him
            // from here, at exactly this size and place, and he drifts off.
            //
            // **Placed first, handed over a beat later.** Both in one update,
            // the tower drew him for one frame at the simulation's old spot,
            // 107pt below the bubble, before it moved him onto it (filmed at
            // 60fps, 2026-10-02). `popped` first lets the tower put him on the
            // bubble's centre while the bubble still draws him; then the
            // bubble lets go.
            parking.popped += 1
            Task { @MainActor in
                await Task.yield()
                parking.releasing = false
                bursting = false
                spray = 0
                grow = 0
            }
        }
        withAnimation(GridConstants.popSpray) { spray = 1 }
        // Wake the tower's clock now, so it is running when it takes him.
        parking.releasing = true
        parking.parked = false
    }
}
