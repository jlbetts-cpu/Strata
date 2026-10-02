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
    /// Bumped when he lands in the bubble, so the glass can give.
    var landed = 0
    /// Bumped when the bubble pops, so the head can come back out of it.
    var popped = 0
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
    var showsDock: Bool { dragging || arriving || parked }

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
        return ZStack {
            if parking.parked && !bursting {
                LivingHeadView(rig: rig, side: CompanionParking.parkedSide, liveliness: .calm)
                    .frame(width: side, height: side)
                    .transition(.identity)
            }
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .glassCircle(onPage: true)
        // On top of the glass, so he is sharp all the way in.
        .overlay { arrivingHead(rig: rig) }
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
        // The pop: the glass grows and is gone, faster than it arrived.
        .scaleEffect(bursting && !reduceMotion ? 1.6 : 1)
        .opacity(bursting ? 0 : 1)
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
        }
        .companionObstacle("dock")
        .accessibilityElement()
        .accessibilityLabel("Your head, parked")
        .accessibilityHint("Pops the bubble and lets him float again.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(!parking.parked)
    }

    /// **Him, on his way in.** Drawn at his tower size and shrunk, rather than
    /// at bubble size and enlarged, so he is never a scaled-up small picture.
    @ViewBuilder
    private func arrivingHead(rig: HeadRig) -> some View {
        if let from = parking.flightFrom {
            let full = parking.headSide
            let fit = CompanionParking.parkedSide / max(full, 1)
            let dx = from.x - parking.dockFrame.midX
            let dy = from.y - parking.dockFrame.midY
            LivingHeadView(rig: rig, side: full, liveliness: .calm)
                .frame(width: full, height: full)
                .scaleEffect(1 + (fit - 1) * flight)
                .offset(x: dx * (1 - flight), y: dy * (1 - flight))
                .allowsHitTesting(false)
                // Handed over from the tower in one frame. Without this the
                // bubble's own swell animation faded him in, and the first
                // frame of the flight was a half-transparent grey head
                // (filmed, 2026-10-02).
                .transition(.identity)
                .animation(nil, value: parking.over)
        }
    }

    private func pop() {
        guard parking.parked, !bursting else { return }
        HapticsEngine.snap()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.popBurst) {
            bursting = true
        } completion: {
            bursting = false
        }
        parking.parked = false
        parking.popped += 1
    }
}
