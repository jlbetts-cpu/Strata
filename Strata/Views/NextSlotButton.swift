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
    let action: (BlockSize) -> Void


    /// -1 = compressing under the finger, +1 = released.
    @State private var charge: CGFloat = 0
    @State private var glow: Double = 0
    @State private var isDown = false
    /// How long the finger has been down, in size steps. Fractional, so the
    /// slot can grow continuously toward the next size rather than snapping at
    /// the moment it changes.
    @State private var held: Double = 0
    @State private var holdTask: Task<Void, Never>?

    /// Seconds of holding per size step.
    private static let stepSeconds: Double = 1.1
    private static let tick: Double = 1.0 / 60.0

    /// The size the current hold has reached.
    private var heldSize: BlockSize {
        switch Int(held) {
        case 0: .small
        case 1: .medium
        default: .hard
        }
    }

    /// Press recoil and hold growth, combined once so the view body stays
    /// inside the type-checker's budget.
    private var scale: CGSize {
        let g = growth
        return CGSize(width: (1 - charge * 0.05) * (1 + g.x),
                      height: (1 + charge * 0.07) * (1 + g.y))
    }

    /// How far the slot has grown, 0...1 per axis.
    ///
    /// A medium block is two columns wide and a hard one is two by two, so the
    /// preview grows sideways first and then downward — the same order the real
    /// block's footprint changes in, so what you see while holding is what you
    /// get when you let go.
    private var growth: (x: CGFloat, y: CGFloat) {
        let t = min(held, 2)
        return (x: min(t, 1), y: max(0, min(t - 1, 1)))
    }

    private var outline: Color { AppColors.warmBlack.opacity(0.18) }

    var body: some View {
        // The press has three beats, not one.
        //
        // It used to squash and pop in 60ms, which is a button acknowledging a
        // tap. This is meant to feel like releasing something: it compresses
        // and dims while your finger is down (anticipation), springs past its
        // own size on release (recoil), and leaves a brief bloom behind, so the
        // block that then falls reads as having come from here.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                outline,
                style: StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength])
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(glow * 0.9))
                    .blur(radius: 6 * glow)
            )
            .overlay {
                Image(systemName: "plus")
                    .iconSize(GridConstants.iconCategory, relativeTo: .body, weight: .medium)
                    .foregroundStyle(outline)
                    .scaleEffect(1 + charge * 0.18)
            }
            // Grows from its own top-left, which is where the block will be
            // anchored, so the preview occupies exactly the cells the block
            // will take.
            .scaleEffect(x: scale.width, y: scale.height, anchor: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 40) {
                // Empty: the press/release work happens in `onPressingChanged`,
                // so the recoil starts the instant the finger lifts rather than
                // after the gesture resolves.
            } onPressingChanged: { pressing($0) }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire(size: .small) }
        .accessibilityLabel("Log a win")
        .accessibilityHint("Drops a block onto your tower")
    }

    private func pressing(_ down: Bool) {
        isDown = down
        guard !reduceMotion else {
            if !down { fire(size: .small) }
            return
        }
        if down {
            HapticsEngine.tick()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.72)) { charge = -1 }
            startHold()
        } else {
            holdTask?.cancel()
            fire(size: heldSize)
            withAnimation(.spring(response: 0.30, dampingFraction: 0.45)) { charge = 1 }
            withAnimation(.easeOut(duration: 0.10)) { glow = 1 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { charge = 0 }
                withAnimation(.easeOut(duration: 0.45)) { glow = 0 }
            }
        }
    }

    /// Grows the slot while the finger stays down.
    ///
    /// A 60Hz tick rather than a step timer, so the slot expands continuously
    /// toward the next size instead of jumping at the moment it changes — you
    /// can see the size you are heading for and stop short of it. Each whole
    /// step lands a haptic, which is the only unambiguous signal that the size
    /// actually committed.
    private func startHold() {
        holdTask?.cancel()
        held = 0
        holdTask = Task { @MainActor in
            var elapsed: Double = 0
            var lastStep = 0
            while !Task.isCancelled, elapsed < Self.stepSeconds * 2 {
                try? await Task.sleep(for: .seconds(Self.tick))
                guard !Task.isCancelled else { return }
                elapsed += Self.tick
                let progress = min(elapsed / Self.stepSeconds, 2)
                withAnimation(.linear(duration: Self.tick)) { held = progress }
                let step = Int(progress)
                if step != lastStep {
                    lastStep = step
                    HapticsEngine.snap()
                }
            }
        }
    }

    private func fire(size: BlockSize) {
        HapticsEngine.snap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { held = 0 }
        action(size)
    }
}
