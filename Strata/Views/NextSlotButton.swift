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
    let action: () -> Void


    /// -1 = compressing under the finger, +1 = released.
    @State private var charge: CGFloat = 0
    @State private var glow: Double = 0
    @State private var isDown = false

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
            .scaleEffect(x: 1 - charge * 0.05, y: 1 + charge * 0.07)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 40) {
                // Empty: the press/release work happens in `onPressingChanged`,
                // so the recoil starts the instant the finger lifts rather than
                // after the gesture resolves.
            } onPressingChanged: { down in
                isDown = down
                guard !reduceMotion else {
                    if !down { fire() }
                    return
                }
                if down {
                    HapticsEngine.tick()
                    withAnimation(.spring(response: 0.16, dampingFraction: 0.72)) {
                        charge = -1
                    }
                } else {
                    fire()
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.45)) {
                        charge = 1
                    }
                    withAnimation(.easeOut(duration: 0.10)) { glow = 1 }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(90))
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { charge = 0 }
                        withAnimation(.easeOut(duration: 0.45)) { glow = 0 }
                    }
                }
            }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire() }
        .accessibilityLabel("Log a win")
        .accessibilityHint("Drops a block onto your tower")
    }

    private func fire() {
        HapticsEngine.snap()
        action()
    }
}
