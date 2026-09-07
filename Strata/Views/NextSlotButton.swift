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
    let blocksToday: Int
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
        // The count sits with the slot rather than in the badge under the
        // tower: it is the number this button makes go up, so it belongs next
        // to the button that moves it.
        //
        // Above rather than beside: the slot is at the top of the stack, so
        // there is always empty space above it, while beside it runs off the
        // screen whenever the slot lands in the last column.
        .overlay(alignment: .top) {
            if blocksToday > 0 {
                Text("^[\(blocksToday) today](inflect: true)")
                    .font(Typography.caption)
                    .foregroundStyle(.primary.opacity(0.35))
                    .contentTransition(.numericText())
                    .fixedSize()
                    .offset(y: -20)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Log a win")
        .accessibilityValue("^[\(blocksToday) block](inflect: true) today")
        .accessibilityHint("Drops a block onto your tower")
    }
}
