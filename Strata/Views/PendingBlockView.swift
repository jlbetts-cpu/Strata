import SwiftUI

/// Something you mean to do today, drawn as the block it will become.
///
/// This is the Today tab, folded into the tower. A checklist was a list of
/// rows on another screen that described blocks; this is the blocks. The cell
/// it occupies is the cell it will occupy when it is done, so the tower shows
/// the whole day at once — what is standing, and what is still outlined above
/// it.
///
/// Outlined, not filled: it is the ABSENCE of a block, the same claim the next
/// slot makes, and for the same reason. The colour is there but held back to a
/// wash, so you can see what the tower is going to look like without it
/// pretending to already look that way.
struct PendingBlockView: View {
    let habit: Habit
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let onCheck: () -> Void
    let onOpen: () -> Void

    @State private var isDown = false

    private var tint: Color { habit.displayCategory.style.baseColor }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(isDown ? 0.22 : 0.13))

            // A solid rim, not dashes.
            //
            // Dashes are the next slot's language — "nothing here yet, press
            // to fill it". A pending block is not nothing: it is a named thing
            // you intend to do. Giving both the same dashed edge made five
            // outlined boxes that all looked like empty slots, and turned a
            // calm page busy. The rim is the block's own colour, held back.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tint.opacity(isDown ? 0.85 : 0.55), lineWidth: 1.5)

            // The name, positioned exactly where a finished block puts its
            // title, so completing one does not move the text.
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                Text(habit.title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: width, height: height)
        .animation(GridConstants.tapSquashSpring, value: isDown)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Tap checks it off. Nothing else on this screen is a single tap, so
        // there is nothing to disambiguate against — and the whole point is
        // that finishing something is the fastest thing in the app.
        .onTapGesture {
            HapticsEngine.lightTap()
            onCheck()
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            HapticsEngine.tick()
            onOpen()
        } onPressingChanged: { down in
            isDown = down
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.title)
        .accessibilityValue("Not done")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to mark done. Touch and hold to edit.")
    }
}
