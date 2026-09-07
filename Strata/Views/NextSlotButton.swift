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

    /// The size the drag has committed to, with a deadband on the way back.
    ///
    /// **The direction you drag is the direction the block grows.** Sideways
    /// widens it; up makes it tall. That is not a mapping to learn, because the
    /// sizes are literally those shapes: `medium` is 2x1 and `hard` is 2x2, so
    /// pulling sideways makes the wide one and pulling up adds the height.
    ///
    /// It used to be pure distance in any direction — one step for medium, two
    /// for hard — so the same 92pt pull meant "tall" whether you went up, down,
    /// left or right, and reaching the biggest size meant dragging twice as far
    /// in a direction that said nothing about what you would get.
    ///
    /// It SNAPS. A block can only be one of three sizes, so a slot that
    /// stretches smoothly between them is showing a state the block can never
    /// be in — and then jumps anyway when you let go. It steps between the
    /// sizes that exist, which is also what makes the haptic honest: it fires
    /// at the moment the thing actually changes.
    ///
    /// Growing takes a full step; shrinking gives one back only after coming
    /// `slotStepHysteresis` further, so a finger resting on a threshold does
    /// not flicker between two sizes on the tremors of a real hand.
    private func size(lateral: CGFloat, up: CGFloat, from current: BlockSize) -> BlockSize {
        let step = GridConstants.slotStep
        let back = GridConstants.slotStepHysteresis
        // The direction has to be DECISIVE, not merely present. Reaching the
        // upward threshold while pulling mostly sideways used to give the tall
        // block, so a wide pull that drifted upward produced a shape you did
        // not ask for and could not predict. Past 45 degrees it is an upward
        // drag; below it, a sideways one.
        let goingUp = up > lateral

        switch current {
        case .small:
            if goingUp && up >= step { return .hard }
            return lateral >= step ? .medium : .small
        case .medium:
            if goingUp && up >= step { return .hard }
            return lateral >= step - back ? .medium : .small
        case .hard:
            // Holding it tall does not demand you keep winning the argument
            // about direction — only that the height is still being asked for.
            if up >= step - back { return .hard }
            return lateral >= step - back ? .medium : .small
        }
    }

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

    /// Strong enough to be seen on an off-white page.
    ///
    /// This was 0.18, which on this background is very close to not being
    /// there — the slot is the only control on the screen and it read as a
    /// faint artefact rather than as the thing you press.
    private var outline: Color {
        AppColors.warmBlack.opacity(isDown ? 0.34 : 0.26)
    }

    /// A shallow recess, so the slot reads as somewhere a block goes.
    ///
    /// Still the absence of a block rather than a blank one — that distinction
    /// is deliberate and worth keeping — but an outline alone gives the eye no
    /// surface to land on. A socket does. It deepens the instant a finger goes
    /// down, which is the response apple-design.md §1 asks for on pointer-down
    /// rather than on release.
    private var recess: Color {
        AppColors.warmBlack.opacity(isDown ? 0.075 : 0.038)
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
                .fill(previewCategory.style.baseColor.opacity(drawProgress * 0.14))

            // The outline stays dashed the whole way, and takes on the colour.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    drawProgress > 0
                        ? AnyShapeStyle(previewCategory.style.baseColor.opacity(0.30 + drawProgress * 0.55))
                        : AnyShapeStyle(outline),
                    style: StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength])
                )

            Image(systemName: "plus")
                .iconSize(GridConstants.iconCategory, relativeTo: .body, weight: .semibold)
                .foregroundStyle(
                    AppColors.warmBlack
                        .opacity((isDown ? 0.52 : 0.38) * (1 - drawProgress))
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
                let lateral = resisted(abs(value.translation.width))
                // Up is negative in this coordinate space. Dragging DOWN grows
                // nothing — there is no shorter block than one cell, and
                // pulling a block down out of the tower means nothing yet.
                let up = resisted(max(-value.translation.height, 0))
                drawn = max(lateral, up)
                let next = size(lateral: lateral, up: up, from: lastSize)
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

    /// Resistance past the last stop on an axis.
    ///
    /// Each axis now has exactly one meaningful step, so the limit is one step
    /// rather than two. Dragging beyond it has nowhere to go: stopping dead
    /// reads as the gesture breaking, while giving back progressively less
    /// reads as having reached the end of something real.
    private func resisted(_ distance: CGFloat) -> CGFloat {
        let limit = GridConstants.slotStep
        guard distance > limit else { return distance }
        return limit + GridConstants.rubberband(
            overshoot: distance - limit,
            dimension: GridConstants.slotStep
        )
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
        onSizeChanged(.small)
        action(size)
    }
}
