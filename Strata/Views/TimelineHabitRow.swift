import SwiftUI

struct TimelineHabitRow: View {
    let habit: Habit
    let rowHeight: CGFloat
    let cornerRadius: CGFloat
    let onComplete: (Habit) -> Void
    var onSkip: ((Habit) -> Void)? = nil
    /// If true, render in completed/glazed state immediately (for already-completed habits)
    var isAlreadyCompleted: Bool = false

    enum TaskState {
        case incomplete, glazing, glazed
    }

    @State private var state: TaskState = .incomplete
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwiped = false
    @State private var breathePhase: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: CategoryStyle { habit.category.style }

    /// Has the ceramic glaze been applied?
    private var isGlazed: Bool {
        isAlreadyCompleted || state == .glazing || state == .glazed
    }

    /// Is this row interactive (swipeable, tappable)?
    private var isInteractive: Bool {
        !isAlreadyCompleted && state == .incomplete
    }

    var body: some View {
        content
            .onAppear {
                if isAlreadyCompleted && !reduceMotion {
                    // Start breathing shimmer for already-completed blocks
                    let delay = Double.random(in: 0...0.5)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                            breathePhase = true
                        }
                    }
                }
            }
            .onDisappear {
                breathePhase = false
            }
    }

    private var content: some View {
        ZStack {
            // Swipe reveal icons (only when incomplete and interactive)
            if isInteractive && !isSwiped {
                swipeRevealIcons
            }

            // Main block
            ZStack {
                // Background: full category gradient (always colored — matte and glazed same fill)
                LinearGradient(
                    stops: [
                        .init(color: style.lightTint, location: 0.0),
                        .init(color: style.baseColor, location: 0.3),
                        .init(color: style.baseColor, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Frosted overlay (matching HabitBlockView)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Border: thin outline when matte → progressive dual glow when glazed
                if isGlazed {
                    // Overlay 1: Crisp top glow
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(breathePhase ? 0.95 : 0.85), location: 0.0),
                                    .init(color: .white.opacity(0.4), location: 0.4),
                                    .init(color: .white.opacity(0.0), location: 0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2.5
                        )

                    // Overlay 2: Diffused bottom glow (ceramic finish)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.0), location: 0.0),
                                    .init(color: .white.opacity(0.35), location: 0.45),
                                    .init(color: .white.opacity(0.6), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .blur(radius: 6)
                        .compositingGroup()
                } else {
                    // Matte outline (incomplete — no glaze yet)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                }

                // Content: icon + text + check circle
                HStack(spacing: 10) {
                    Image(systemName: habit.category.iconName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.leading, 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.title)
                            .font(Typography.headerSmall)
                            .kerning(Typography.headerKerning)
                            .foregroundStyle(.white)

                        if let time = habit.scheduledTime {
                            let end = BlockTimeFormatter.endTime(time, durationMinutes: habit.blockSize.durationMinutes)
                            HStack(spacing: 4) {
                                Text("\(BlockTimeFormatter.format12Hour(time)) – \(BlockTimeFormatter.format12Hour(end))")
                                    .font(Typography.caption)
                                    .foregroundStyle(.white.opacity(0.7))

                                if habit.blockSize != .small {
                                    Text(habit.blockSize == .medium ? "30m" : "1h")
                                        .font(Typography.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }

                    Spacer()

                    // Check circle
                    if isInteractive {
                        Button {
                            beginCompletion()
                        } label: {
                            checkCircle
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 6)
                    } else {
                        checkCircle
                            .padding(.trailing, 12)
                    }
                }
            }
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(x: swipeOffset)
            .scaleEffect(
                x: swipeOffset > 0 ? 1.0 + min(swipeOffset / 800, 0.08) : 1.0,
                y: 1.0,
                anchor: .leading
            )
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Shadows: single ambient when matte, dual-layer when glazed
        .shadow(
            color: .black.opacity(GridConstants.adaptiveShadowOpacity(GridConstants.shadowOpacity, colorScheme: colorScheme)),
            radius: GridConstants.shadowRadius, x: 0, y: GridConstants.shadowY
        )
        .shadow(
            color: .black.opacity(GridConstants.adaptiveShadowOpacity(isGlazed ? 0.05 : 0, colorScheme: colorScheme)),
            radius: 3, x: 0, y: 1
        )
        .opacity(swipeOffset != 0 ? Double(1.0 - abs(swipeOffset) / 400.0) : 1.0)
        .accessibilityLabel(habit.title)
        .accessibilityHint(isInteractive ? "Swipe right to complete, swipe left to skip" : "Completed")
        .accessibilityAction(named: "Complete") { if isInteractive { beginCompletion() } }
        .accessibilityAction(named: "Skip") { if isInteractive { onSkip?(habit) } }
        .gesture(
            isInteractive
            ? DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        swipeOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 120 {
                        HapticsEngine.snap()
                        withAnimation(.easeIn(duration: 0.2)) { swipeOffset = 400 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSwiped = true
                            beginCompletion()
                        }
                    } else if value.translation.width < -120 {
                        HapticsEngine.snap()
                        withAnimation(.easeIn(duration: 0.2)) { swipeOffset = -400 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSwiped = true
                            onSkip?(habit)
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { swipeOffset = 0 }
                    }
                }
            : nil
        )
    }

    // MARK: - Swipe Reveal Icons

    private var swipeRevealIcons: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.healthGreen)
                .scaleEffect(swipeOffset > 30 ? min(CGFloat(swipeOffset - 30) / 90.0, 1.0) : 0.001)
                .opacity(swipeOffset > 30 ? 1.0 : 0)
                .padding(.leading, 16)

            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.3))
                .scaleEffect(swipeOffset < -30 ? min(CGFloat(-swipeOffset - 30) / 90.0, 1.0) : 0.001)
                .opacity(swipeOffset < -30 ? 1.0 : 0)
                .padding(.trailing, 16)
        }
        .frame(height: rowHeight)
    }

    // MARK: - Check Circle

    private var checkCircle: some View {
        let isChecked = isGlazed

        return ZStack {
            Circle()
                .stroke(.white.opacity(isChecked ? 0 : 0.5), lineWidth: 1.5)
                .frame(width: 28, height: 28)

            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .scaleEffect(isChecked ? 1.0 : 0.001)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(style.baseColor)
                .scaleEffect(isChecked ? 1.0 : 0.001)
                .rotationEffect(.degrees(isChecked ? 0 : -30))
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isGlazed)
    }

    // MARK: - Completion: Glazing

    private func beginCompletion() {
        HapticsEngine.snap()

        // Phase 1: Glaze — ceramic finish appears
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            state = .glazing
        }

        // Start breathing shimmer
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathePhase = true
            }
        }

        Task { @MainActor in
            // Phase 2: Settle as glazed
            try? await Task.sleep(nanoseconds: 500_000_000)

            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()

            state = .glazed

            // Notify parent — habit is complete, queue for tower
            onComplete(habit)
        }
    }
}
