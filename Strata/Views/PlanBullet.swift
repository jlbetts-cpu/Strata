import SwiftUI

/// A plan line's bullet: an empty slot that becomes a block.
///
/// **Unchecked it carries no colour at all.** It is the same shape a block
/// is, drawn as an outline — the tower's own language for "nothing here yet",
/// which is what an unfinished line is. Colour is what the app spends on
/// things that happened; spending it on things that have not yet would make
/// the plan look like a record.
///
/// Checked, it becomes a real `BlockSurface` in its category's colour with a
/// tick on it — the same object the tower is built from. So the plan is
/// literally a picture of the tower you are about to build, filling in one
/// block at a time.
///
/// Motion follows `docs/apple-design.md`: the fill and the tick arrive on a
/// critically-damped spring, with one small overshoot on the scale — earned,
/// because something landed.
struct PlanBullet: View {
    let category: HabitCategory
    let isDone: Bool
    var side: CGFloat = 24

    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: side) }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        ZStack {
            // The empty slot. Neutral: the outline says "a block goes here",
            // and says nothing about which one.
            shape
                .strokeBorder(AppColors.warmBlack.opacity(0.22),
                              lineWidth: 1.4 * (side / GridConstants.blockReferenceCell) * 3.4)
                .opacity(isDone ? 0 : 1)

            // The block, once it is real.
            BlockSurface(cornerRadius: radius,
                         scale: side / GridConstants.blockReferenceCell) {
                category.style.baseColor
            }
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.52, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(isDone ? 1 : 0.4)
                    .opacity(isDone ? 1 : 0)
            }
            .opacity(isDone ? 1 : 0)
            .scaleEffect(isDone ? 1 : 0.72)
        }
        .frame(width: side, height: side)
        .animation(GridConstants.motionSnappy, value: isDone)
    }
}
