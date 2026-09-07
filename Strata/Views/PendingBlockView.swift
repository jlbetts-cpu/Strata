import SwiftUI

/// Something you mean to do today, drawn as the block it will become.
///
/// This is the Today screen, folded into the tower. A checklist was a list of
/// rows describing blocks; this is the blocks, in the cells they will occupy.
///
/// **Colour is earned.** It is drawn in neutral until it is done, and the
/// category colour arrives as you complete it. Tinting it in advance meant six
/// saturated colours in the built tower and six pastel ones above it — the
/// palette doubled, and the page stopped being confident about what its colours
/// meant. Grey outline, then colour, is also the plainest possible statement of
/// what the tower is for.
///
/// **Its anatomy matches a real block exactly** — same title font, same
/// padding, and a reserved line where a finished block puts its time. Four
/// small mismatches (a `bodySmall` title, 10/9 padding instead of 12/12/8, no
/// second line, and a coloured rim where every real block has a white one)
/// were enough to make a row of them sit visibly wrong next to the tower
/// without it being obvious why.
struct PendingBlockView: View {
    let habit: Habit
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let onComplete: () -> Void
    let onOpen: () -> Void

    /// Long enough to be deliberate, short enough not to be a wait.
    private static let holdDuration: Double = 0.45

    @State private var fill: CGFloat = 0

    private var tint: Color { habit.displayCategory.style.baseColor }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColors.warmBlack.opacity(0.035))

            // The hold, filling from the floor up.
            //
            // It is the progress indicator and the reward in one: the block
            // takes on its colour as you earn it, so by the time it completes
            // you are already looking at what you are about to get.
            if fill > 0 {
                Rectangle()
                    .fill(tint.opacity(0.85))
                    .frame(height: height * fill)
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AppColors.warmBlack.opacity(0.16), lineWidth: 1.5)

            // Same structure a finished block uses, including the line its time
            // sits on, so titles line up across a row of mixed blocks.
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(habit.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(fill > 0.5 ? .white : .primary.opacity(0.45))
                    .lineLimit(height > width ? 2 : 1)
                    .minimumScaleFactor(0.65)
                Text(" ")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.leading, 12)
            .padding(.bottom, 12)
            .padding(.trailing, 8)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Tap opens it, hold completes it.
        //
        // The other way round put the irreversible action on the twitchiest
        // gesture: one stray tap while scrolling and something was marked done
        // that you had not done. Holding cannot happen by accident, it gives
        // you the whole duration to change your mind, and it is the gesture
        // with somewhere to put progress.
        .onTapGesture {
            HapticsEngine.lightTap()
            onOpen()
        }
        .onLongPressGesture(minimumDuration: Self.holdDuration) {
            HapticsEngine.success()
            onComplete()
        } onPressingChanged: { down in
            if down {
                withAnimation(.linear(duration: Self.holdDuration)) { fill = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.18)) { fill = 0 }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.title)
        .accessibilityValue("Not done")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Touch and hold to mark done. Double tap to edit.")
        .accessibilityAction(named: "Mark done") { onComplete() }
    }
}
