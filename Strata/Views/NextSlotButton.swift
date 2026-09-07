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

    @State private var pressed = false

    private var outline: Color { AppColors.warmBlack.opacity(0.18) }

    var body: some View {
        Button {
            HapticsEngine.snap()
            if !reduceMotion {
                withAnimation(GridConstants.tapSquashSpring) { pressed = true }
                withAnimation(GridConstants.tapPopSpring.delay(0.06)) { pressed = false }
            }
            action()
        } label: {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    outline,
                    style: StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength])
                )
                .overlay {
                    Image(systemName: "plus")
                        .iconSize(GridConstants.iconCategory, relativeTo: .body, weight: .medium)
                        .foregroundStyle(outline)
                }
                .scaleEffect(pressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a win")
        .accessibilityHint("Drops a block onto your tower")
    }
}
