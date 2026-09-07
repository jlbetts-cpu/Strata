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

    /// Points of drag per size step. Short enough that a flick reaches Deep,
    /// long enough that a small block is what you get if you do not mean to
    /// draw at all.
    private static let stepDistance: CGFloat = 46

    /// The size the current drag has reached.
    ///
    /// Continuous, and reversible: dragging back shrinks it. A hold-timer
    /// version of this could only ever count upward, so overshooting meant
    /// letting go and starting again.
    private var drawnSize: BlockSize {
        switch Int(drawn / Self.stepDistance) {
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

    /// A stretch toward the NEXT size, not the size itself.
    ///
    /// The slot's real footprint comes from its frame, which the tower sets to
    /// wherever a block of the committed size would land — so the scale here
    /// only has to say "you are on your way to the next one". Doing both would
    /// double-count and the slot would leap to four times its size.
    ///
    /// It stretches in the axis that is about to change: a medium block is two
    /// columns wide, a deep one is two by two, so small-to-medium pulls
    /// sideways and medium-to-deep pulls down. Rubber band, then a click.
    private var growth: (x: CGFloat, y: CGFloat) {
        let step = drawn / Self.stepDistance
        guard step < 2 else { return (0, 0) }
        let hint = (step - floor(step)) * 0.22
        return Int(step) == 0 ? (x: hint, y: 0) : (x: 0, y: hint)
    }

    /// 0 at rest, 1 once drawing has clearly begun.
    private var drawProgress: Double {
        Double(min(drawn / (Self.stepDistance * 0.5), 1))
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
                    withAnimation(.spring(response: 0.16, dampingFraction: 0.72)) {
                        charge = -1
                    }
                }
                guard !reduceMotion else { return }
                let distance = hypot(value.translation.width, value.translation.height)
                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
                    drawn = distance
                }
                // A haptic on every crossing, in both directions — the only
                // unambiguous signal that a size actually committed, and the
                // thing that makes drawing back feel deliberate rather than
                // like losing progress.
                if drawnSize != lastSize {
                    lastSize = drawnSize
                    HapticsEngine.snap()
                    onSizeChanged(drawnSize)
                }
            }
            .onEnded { _ in
                isDown = false
                let size = reduceMotion ? .small : drawnSize
                fire(size: size)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.45)) { charge = 1 }
                withAnimation(.easeOut(duration: 0.10)) { glow = 1 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { charge = 0 }
                    withAnimation(.easeOut(duration: 0.45)) { glow = 0 }
                }
            }
    }

    private func fire(size: BlockSize) {
        HapticsEngine.snap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            drawn = 0
        }
        lastSize = .small
        onSizeChanged(.small)
        action(size)
    }
}
