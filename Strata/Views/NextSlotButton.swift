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


    /// -1 = compressing under the finger, +1 = released.
    @State private var charge: CGFloat = 0
    @State private var glow: Double = 0
    @State private var isDown = false
    /// How far the finger has been dragged from where it went down.
    @State private var drawn: CGFloat = 0
    @State private var lastSize: BlockSize = .small

    /// The size the drag has committed to, with a deadband on the way back.
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
    private func size(for distance: CGFloat, from current: BlockSize) -> BlockSize {
        let step = GridConstants.slotStep
        let back = GridConstants.slotStepHysteresis
        switch current {
        case .small:
            return distance >= step * 2 ? .hard : (distance >= step ? .medium : .small)
        case .medium:
            if distance >= step * 2 { return .hard }
            return distance < step - back ? .small : .medium
        case .hard:
            return distance < step * 2 - back ? .medium : .hard
        }
    }

    /// Press recoil only. The size itself comes from the frame the tower
    /// gives this view, which snaps between the three real sizes.
    private var scale: CGSize {
        CGSize(width: 1 - charge * 0.05, height: 1 + charge * 0.07)
    }

    /// 0 at rest, 1 once drawing has clearly begun.
    private var drawProgress: Double {
        Double(min(drawn / (GridConstants.slotStep * 0.5), 1))
    }

    private var outline: Color { AppColors.warmBlack.opacity(0.18) }

    var body: some View {
        // At rest it is an empty slot. While you draw, it becomes the block.
        //
        // A dashed outline that merely got bigger did not say a block was being
        // made — it said a placeholder was being stretched. The colour fills
        // in, the dashes fade to a solid rim and the plus gives way, so what
        // you let go of is the thing you have been looking at. The colour is
        // the one the block will actually be, so the tower's next colour is
        // decided in front of you rather than revealed after.
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(previewCategory.style.baseColor.opacity(drawProgress * 0.92))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    outline.opacity(1 - drawProgress),
                    style: StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength])
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(drawProgress), lineWidth: GridConstants.blockRimWidth)

            Image(systemName: "plus")
                .iconSize(GridConstants.iconCategory, relativeTo: .body, weight: .medium)
                .foregroundStyle(outline.opacity(1 - drawProgress))
                .scaleEffect(1 + charge * 0.18)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(glow * 0.9))
                .blur(radius: 6 * glow)
        )
        // Grows from its own top-left, which is where the block will be
        // anchored, so the preview occupies exactly the cells the block
        // will take.
        .scaleEffect(x: scale.width, y: scale.height, anchor: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .gesture(draw)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire(size: .small) }
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
                    HapticsEngine.tick()
                    withAnimation(GridConstants.tapSquashSpring) { charge = -1 }
                }
                guard !reduceMotion else { return }
                drawn = hypot(value.translation.width, value.translation.height)
                let next = size(for: drawn, from: lastSize)
                guard next != lastSize else { return }
                lastSize = next
                // A haptic on every crossing, in both directions — the only
                // unambiguous signal that a size actually committed, and the
                // thing that makes drawing back feel deliberate rather than
                // like losing progress.
                HapticsEngine.snap()
                withAnimation(GridConstants.slotSnap) { onSizeChanged(next) }
            }
            .onEnded { _ in
                isDown = false
                let size: BlockSize = reduceMotion ? .small : lastSize
                fire(size: size)
                withAnimation(GridConstants.elasticPop) { charge = 1 }
                withAnimation(GridConstants.slotBloomIn) { glow = 1 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(GridConstants.snapBack) { charge = 0 }
                    withAnimation(GridConstants.slotBloomOut) { glow = 0 }
                }
            }
    }

    private func fire(size: BlockSize) {
        HapticsEngine.snap()
        withAnimation(GridConstants.naturalSettle) { drawn = 0 }
        lastSize = .small
        onSizeChanged(.small)
        action(size)
    }
}
