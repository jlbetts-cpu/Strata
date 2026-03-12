import SwiftUI

// MARK: - Completed Block (Vivid)

struct HabitBlockView: View {
    let block: PlacedBlock
    let cellSize: CGFloat
    let onTap: () -> Void

    private var style: CategoryStyle {
        block.habit.category.style
    }

    private var blockFrame: CGRect {
        block.frame(cellSize: cellSize)
    }

    var body: some View {
        ZStack {
            // Solid base color — pure category hex
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(style.baseColor)

            // Content
            VStack(spacing: 2) {
                Text(block.habit.title)
                    .font(blockFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.text)
                    .lineLimit(block.rowSpan > 1 ? 2 : 1)
                    .minimumScaleFactor(0.7)

                if let pendingXP = block.log.pendingXP, !block.log.xpCollected {
                    Text("+\(pendingXP) XP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(style.text.opacity(0.9))
                }
            }
            .padding(6)
        }
        .frame(width: blockFrame.width, height: blockFrame.height)
        // 1. Subtle volume gradient
        .overlay(
            LinearGradient(
                colors: [.white.opacity(0.1), .clear, .black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        // 2. Top highlight
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 6),
            alignment: .top
        )
        // 3. Specular gradient border
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .white.opacity(0.1), .black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // 4. Master clip
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        // 5. Soft drop shadow
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture(perform: onTap)
    }

    private var blockFont: Font {
        switch block.habit.blockSize {
        case .small: return .caption2
        case .medium: return .caption
        case .hard: return .subheadline
        }
    }
}

// MARK: - Incomplete Block (Muted/Outlined)

struct IncompleteBlockView: View {
    let habit: Habit
    let frame: CGRect
    let onComplete: () -> Void

    @State private var holdProgress: Double = 0

    private let holdDuration: Double = 0.6

    private var style: CategoryStyle {
        habit.category.style
    }

    var body: some View {
        ZStack {
            // Muted background
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .fill(style.gradientBottom.opacity(0.08))

            // Hold progress fill
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .fill(style.gradient.opacity(0.4))
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: frame.height * holdProgress)
                }

            // Border
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(style.gradientBottom.opacity(0.2), lineWidth: 1.5)

            // Label
            Text(habit.title)
                .font(blockFont)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary.opacity(0.6))
                .lineLimit(habit.blockSize.rowSpan > 1 ? 2 : 1)
                .minimumScaleFactor(0.7)
                .padding(6)
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: holdDuration, perform: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onComplete()
            withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
        }, onPressingChanged: { pressing in
            if pressing {
                withAnimation(.linear(duration: holdDuration)) { holdProgress = 1.0 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
            }
        })
    }

    private var blockFont: Font {
        switch habit.blockSize {
        case .small: return .caption2
        case .medium: return .caption
        case .hard: return .subheadline
        }
    }
}
