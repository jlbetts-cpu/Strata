import SwiftUI

/// The empty slot at the top of the tower, as a button.
///
/// Pressing it drops a block. That is the whole of logging a win — it replaces
/// a dedicated page whose entire job was to hold one button, and puts the
/// action in the place where its result appears.
///
/// It is drawn as an outline rather than a filled block on purpose: it is the
/// absence of a block, which is what makes it read as a slot waiting to be
/// filled rather than as a block that is somehow blank.
struct NextSlotButton: View {
    let reduceMotion: Bool
    let cornerRadius: CGFloat
    /// Hands back the size the hold reached.
    /// The colour the block will be, shown while drawing.
    let previewCategory: HabitCategory
    /// Reports the size being drawn, so the tower can show where it would land.
    let onSizeChanged: (BlockSize) -> Void
    let action: (BlockSize) -> Void
    /// A quick tap: open the menu rather than logging anything.
    let onOpenMenu: () -> Void


    /// -1 = compressing under the finger, +1 = released.
    @State private var charge: CGFloat = 0
    @State private var glow: Double = 0
    @State private var isDown = false
    /// How far the finger has been dragged from where it went down.
    @State private var drawn: CGFloat = 0
    @State private var lastSize: BlockSize = .small
    @State private var pressStarted = Date()

    /// Below this, a still press is a tap.
    private static let tapCeiling: Double = 0.28

    /// The gesture's maths lives in `BlockSizeDraw`.
    ///
    /// It used to be three private functions here, which made this the only
    /// control in the app that could express a size with a finger — the camera
    /// shutter, the other thing you press to make a win, could only ever
    /// produce a 1x1. Moving it out changes nothing about this view's
    /// behaviour and is why `TowerGestureTests` must still pass unedited.

    /// Press recoil only. The size itself comes from the frame the tower
    /// gives this view, which snaps between the three real sizes.
    /// **Uniform, and never above 1.** It used to squash one axis and stretch
    /// the other — 5% wider and 7% shorter under the finger, anchored top-left
    /// — so the one element whose entire job is to show which grid cell the
    /// block will occupy stopped lining up with that cell exactly while you
    /// were looking at it.
    private var scale: CGFloat { 1 - abs(charge) * 0.04 }

    /// 0 at rest, 1 once drawing has clearly begun.
    private var drawProgress: Double {
        Double(min(drawn / (GridConstants.slotStep * 0.5), 1))
    }

    /// How strongly the slot wears the colour it is about to become.
    ///
    /// This used to be `drawProgress` alone, which meant the colour only
    /// arrived if you dragged — so the commonest action in the app, a plain
    /// hold for a small block, showed no colour at all and the block's colour
    /// was a surprise that fell out of the sky. A finger down is already the
    /// commitment; `apple-design.md` §1 asks for the response on pointer-DOWN,
    /// not on release.
    ///
    /// It still tops out where it did. The slot must stay a GHOST — see the
    /// note on `body` — so this drives a tint and an outline, never a surface.
    private var colourStrength: Double {
        max(isDown ? 0.60 : 0, drawProgress)
    }

    /// Strong enough to be seen on an off-white page.
    ///
    /// This was 0.18, which on this background is very close to not being
    /// there — the slot is the only control on the screen and it read as a
    /// faint artefact rather than as the thing you press.
    @Environment(\.colorScheme) private var scheme

    private var outline: Color {
        // Heavier in the dark: a light dash on a dark ground reads thinner
        // than a dark dash on a light one at the same alpha, so matching the
        // numbers would not match the appearance.
        let base = scheme == .dark ? 0.42 : 0.26
        return AppColors.slotInk.opacity(isDown ? base + 0.10 : base)
    }

    /// A shallow recess, so the slot reads as somewhere a block goes.
    ///
    /// Still the absence of a block rather than a blank one — that distinction
    /// is deliberate and worth keeping — but an outline alone gives the eye no
    /// surface to land on. A socket does. It deepens the instant a finger goes
    /// down, which is the response apple-design.md §1 asks for on pointer-down
    /// rather than on release.
    private var recess: Color {
        let base = scheme == .dark ? 0.075 : 0.038
        return AppColors.slotInk.opacity(isDown ? base * 2 : base)
    }

    var body: some View {
        // It stays a GHOST the whole way. The block arrives by falling.
        //
        // This used to fill in with the block's colour and swap its dashes for
        // a white rim, so by the end of a drag you were holding what looked
        // like a finished block — and then it vanished and a different block
        // fell from the top into the same place. Two blocks for one win.
        //
        // The ghost only ever says WHERE and HOW BIG, which is all a
        // placeholder should claim. It still previews the colour, because the
        // tower's next colour is worth deciding in front of you rather than
        // revealing after — but as a tint on the outline and a wash inside it,
        // never as the block's own surface.
        ZStack {
            // The recess, which tints toward the block's colour as you draw.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(recess)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(previewCategory.style.baseColor.opacity(colourStrength * 0.14))

            // The outline stays dashed the whole way, and takes on the colour.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    colourStrength > 0
                        ? AnyShapeStyle(previewCategory.style.baseColor.opacity(0.30 + colourStrength * 0.55))
                        : AnyShapeStyle(outline),
                    style: StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength])
                )

            Image(systemName: "plus")
                .iconSize(GridConstants.iconCategory, relativeTo: .body, weight: .medium)
                .foregroundStyle(
                    AppColors.slotInk
                        .opacity((isDown ? 0.72 : 0.55) * (1 - colourStrength))
                )
                .scaleEffect(1 + charge * 0.18)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(glow * 0.9))
                .blur(radius: 6 * glow)
        )
        // Scaled down from the centre, so the ghost stays inside the cell it
        // is pointing at.
        .animation(GridConstants.tapSquashSpring, value: isDown)
        .scaleEffect(scale)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // One rule, both kinds of block: **tap opens it, hold does it.**
        //
        // A tap on an outlined block opens its details; a tap here opens the
        // menu, which is also the only route to adding a habit now that the
        // screen which owned that lives inside the tower. Holding an outlined
        // block completes it; holding this one draws a win out of the slot and
        // drops it.
        //
        // The irreversible action is the one that cannot happen by accident,
        // and it is the one with somewhere to put progress.
        .gesture(draw)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire(size: .small, velocity: 0) }
        .accessibilityLabel("Log a win")
        .accessibilityHint("Drops a block onto your tower. Drag out to make it bigger.")
    }

    /// Drawing the block out of the slot.
    ///
    /// One gesture does the whole thing: put a finger down and let go for a
    /// small block, or drag away and the block is drawn bigger the further you
    /// go — and smaller again if you come back, which a hold timer could never
    /// do. Distance, not time, so the size is something you aim at rather than
    /// wait for.
    private var draw: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDown {
                    isDown = true
                    pressStarted = Date()
                    HapticsEngine.tick()
                    withAnimation(GridConstants.tapSquashSpring) { charge = -1 }
                }
                guard !reduceMotion else { return }
                // Up is negative in this coordinate space. Dragging DOWN grows
                // nothing — there is no shorter block than one cell, and
                // pulling a block down out of the tower means nothing yet.
                // `BlockSizeDraw.axes` is the one place that knows it.
                let (lateral, up) = BlockSizeDraw.axes(translation: value.translation)
                drawn = max(lateral, up)
                let next = BlockSizeDraw.size(lateral: lateral, up: up, from: lastSize)
                guard next != lastSize else { return }
                lastSize = next
                // A haptic on every crossing, in both directions — the only
                // unambiguous signal that a size actually committed, and the
                // thing that makes drawing back feel deliberate rather than
                // like losing progress.
                HapticsEngine.snap()
                withAnimation(GridConstants.slotSnap) { onSizeChanged(next) }
            }
            .onEnded { value in
                // A gesture that never began cannot end in a block.
                //
                // `DragGesture(minimumDistance: 0)` can deliver `onEnded`
                // without a matching `onChanged` when the view is rebuilt under
                // a touch — and the tower rebuilds constantly. A logged win is
                // not reversible enough to be produced by a gesture nobody
                // made, so a run that never set `isDown` is discarded.
                guard isDown else { return }
                isDown = false
                // A quick, still press is a tap: open the menu instead.
                //
                // A tap is a drag of zero distance, so this gesture sees both
                // and has to tell them apart. Held long enough, or moved at
                // all, and you meant to draw a block out.
                let held = Date().timeIntervalSince(pressStarted)
                let moved = hypot(value.translation.width, value.translation.height) > 6
                guard moved || held >= Self.tapCeiling else {
                    withAnimation(GridConstants.snapBack) { charge = 0 }
                    drawn = 0
                    lastSize = .small
                    onSizeChanged(.small)
                    onOpenMenu()
                    return
                }
                let size: BlockSize = reduceMotion ? .small : released(value)
                fire(size: size, velocity: releaseSpeed(value))
                withAnimation(GridConstants.elasticPop) { charge = 1 }
                withAnimation(GridConstants.slotBloomIn) { glow = 1 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(GridConstants.snapBack) { charge = 0 }
                    withAnimation(GridConstants.slotBloomOut) { glow = 0 }
                }
            }
    }

    /// The component of the release velocity along the direction of the drag,
    /// in points per second. Sideways wobble at the end of a pull outward
    /// should not read as slowing down, so only motion along the drag counts.
    private func releaseSpeed(_ value: DragGesture.Value) -> CGFloat {
        let d = hypot(value.translation.width, value.translation.height)
        guard d > 1 else { return 0 }
        let ux = value.translation.width / d
        let uy = value.translation.height / d
        return value.velocity.width * ux + value.velocity.height * uy
    }

    /// What you let go of is what you saw.
    ///
    /// This used to recompute the size from the raw translation plus a
    /// momentum projection, which is apple-design.md §6 — and it was wrong
    /// here, because it recomputed WITHOUT the hysteresis the ghost had been
    /// tracking with. The two could disagree, in both directions:
    ///
    ///  - Drag up to Deep and drift back a little: hysteresis holds the ghost
    ///    on Deep at `up >= step - back`, but the release demanded
    ///    `up >= step`. Showed large, dropped Regular.
    ///  - Ghost on Regular, a small upward flick at release: projection made
    ///    `up > lateral` and returned Deep. Showed medium, dropped large.
    ///
    /// Momentum projection belongs on a control whose position is continuous
    /// and whose release point is arbitrary. This one has already SNAPPED —
    /// the size is decided, shown, and confirmed by a haptic while your finger
    /// is still down. Overriding what somebody watched themselves choose is
    /// worse than not predicting where they were heading.
    private func released(_ value: DragGesture.Value) -> BlockSize {
        lastSize
    }

    private func fire(size: BlockSize, velocity: CGFloat) {
        HapticsEngine.snap()
        // Velocity handoff (docs/apple-design.md §5): the settle continues at
        // the speed the finger was moving, so there is no seam between dragging
        // and animating. Normalised by the distance left to travel, which is
        // what a spring's initialVelocity expects.
        let remaining = max(drawn, 1)
        withAnimation(.interpolatingSpring(duration: 0.34, bounce: 0.18,
                                           initialVelocity: Double(velocity / remaining))) {
            drawn = 0
        }
        lastSize = .small
        // NOT `onSizeChanged(.small)` here.
        //
        // That call reset the parent's `drawingSize`, which is what sizes the
        // slot's own frame — so the moment you let go, the slot you had just
        // drawn at 2x2 snapped back to a single square. And it stayed there,
        // visibly, because the slot is only hidden once `animCoord.isCascading`
        // flips, which happens after `logWin` queues the drop and the cascade
        // waits out a 300ms scroll settle. That gap is the "it shrinks before
        // the block drops" — a third of a second of the wrong-sized slot
        // sitting where the right-sized block is about to land.
        //
        // Resetting to `.small` is bookkeeping for the NEXT win. It belongs
        // after this one has landed, and the parent does it there.
        action(size)
    }
}
