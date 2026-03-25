import SwiftUI

struct TimelineHabitRow: View {
    let habit: Habit
    let rowHeight: CGFloat
    let cornerRadius: CGFloat
    let onComplete: (Habit) -> Void
    var onSkip: ((Habit) -> Void)? = nil
    var onUndo: ((Habit) -> Void)? = nil
    var onUndoSkip: ((Habit) -> Void)? = nil
    var isAlreadyCompleted: Bool = false
    var isAlreadySkipped: Bool = false
    var photoFileName: String? = nil
    var completionProgress: Double = 0  // 0.0→1.0, fraction of day's habits completed
    var currentStreak: Int = 0          // Current streak for milestone detection

    enum TaskState {
        case incomplete, filling, completed, skipped
    }

    @State private var state: TaskState = .incomplete
    @State private var fillProgress: CGFloat = 0
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwiped = false
    @State private var driftGlow: CGFloat = 0 // Drift Reward: subtle aesthetic surprise
    @State private var completionTask: Task<Void, Never>? // Cancellable completion sequence
    @State private var holdProgress: CGFloat = 0 // Fluid Fill: press-to-complete progress
    @State private var isHolding: Bool = false
    @State private var lastSwipeThreshold: Int = 0 // Progressive haptic chain tracking
    @State private var lastHoldThreshold: Int = 0  // Hold gesture ratchet tracking
    @State private var completionBounce: Bool = false
    @State private var streakBadgeVisible: Bool = false
    @State private var streakMilestone: Int = 0
    private let holdDuration: TimeInterval = 0.6 // Fogg's Tiny Habits: deliberate but not slow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: CategoryStyle { habit.category.style }

    private var isCompleted: Bool {
        isAlreadyCompleted || state == .completed
    }

    private var isSkipped: Bool {
        isAlreadySkipped || state == .skipped
    }

    private var isFilling: Bool { state == .filling }

    private var isInteractive: Bool {
        !isAlreadyCompleted && !isAlreadySkipped && state == .incomplete
    }

    private var ghostBackground: Color {
        colorScheme == .dark ? AppColors.ghostBaseDark : AppColors.ghostBase
    }

    /// Choose animation based on reduceMotion
    private func anim(_ animation: Animation) -> Animation {
        reduceMotion ? GridConstants.motionReduced : animation
    }

    // MARK: - Momentum Escalation (Hull's Goal Gradient)

    private var escalatedFillDuration: TimeInterval {
        switch completionProgress {
        case 0..<0.3:  return GridConstants.fillSweepDuration
        case 0.3..<0.6: return GridConstants.fillSweepEarly
        case 0.6..<0.9: return GridConstants.fillSweepMedium
        default:        return GridConstants.fillSweepFast
        }
    }

    private var escalatedBounceAmplitude: CGFloat {
        switch completionProgress {
        case 0..<0.3:  return 1.015
        case 0.3..<0.6: return 1.02
        case 0.6..<0.9: return 1.025
        default:        return 1.03
        }
    }

    private var escalatedPitchShift: Double {
        switch completionProgress {
        case 0..<0.3:  return 0
        case 0.3..<0.6: return 50
        case 0.6..<0.9: return 100
        default:        return 150
        }
    }

    var body: some View {
        content
            .onDisappear {
                completionTask?.cancel()
                completionTask = nil
            }
            .onChange(of: isAlreadyCompleted) { _, newValue in
                if newValue && state == .incomplete {
                    state = .completed
                    fillProgress = 1.0
                } else if !newValue && state != .incomplete && state != .filling {
                    // Undo — reverse the fill (T7: guard against gesture conflict)
                    withAnimation(anim(.easeInOut(duration: 0.3))) {
                        fillProgress = 0
                    }
                    withAnimation(anim(GridConstants.motionSmooth)) {
                        state = .incomplete
                        isSwiped = false
                    }
                }
            }
            .onChange(of: isAlreadySkipped) { _, newValue in
                if newValue && state == .incomplete {
                    withAnimation(anim(GridConstants.motionSmooth)) {
                        state = .skipped
                    }
                } else if !newValue && state == .skipped {
                    withAnimation(anim(GridConstants.motionSmooth)) {
                        state = .incomplete
                        isSwiped = false
                    }
                }
            }
    }

    private var content: some View {
        ZStack {
            if isInteractive && !isSwiped {
                swipeRevealIcons
            }

            GeometryReader { geo in
                ZStack {
                    // PROTO-BLOCK BASE — muted tower gradient (Lakoff 1980: visual metaphor continuity)
                    LinearGradient(
                        stops: [
                            .init(color: style.lightTint, location: 0.0),
                            .init(color: style.baseColor, location: 0.3),
                            .init(color: colorScheme == .dark ? style.darkShade : style.baseColor, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.15)

                    // Frosted overlay (light mode)
                    if colorScheme == .light {
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.0), .init(color: .white.opacity(0.10), location: 1.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }

                    // Crisp top-lit border (matches tower blocks)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: style.lightTint.opacity(0.35), location: 0.0),
                                    .init(color: style.lightTint.opacity(0.15), location: 0.4),
                                    .init(color: style.lightTint.opacity(0.0), location: 0.75)
                                ],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )

                    // HOLD FILL (press-to-complete: fills during hold gesture)
                    if holdProgress > 0 && !isCompleted {
                        LinearGradient(
                            stops: [
                                .init(color: style.lightTint, location: 0.0),
                                .init(color: style.baseColor, location: 0.3),
                                .init(color: style.baseColor, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(0.85)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: geo.size.width * holdProgress)
                        }
                    }

                    // COLOR FILL (sweeps left-to-right on completion)
                    if fillProgress > 0 || isAlreadyCompleted {
                        ZStack {
                            LinearGradient(
                                stops: [
                                    .init(color: style.lightTint, location: 0.0),
                                    .init(color: style.baseColor, location: 0.3),
                                    .init(color: style.baseColor, location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .white.opacity(0.20), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(.white.opacity(colorScheme == .dark ? 0.15 : 0.3), lineWidth: 1.5)
                        }
                        .opacity(isCompleted ? 0.70 : 1.0) // Dim background only, text stays crisp
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: isAlreadyCompleted ? geo.size.width : geo.size.width * fillProgress)
                        }
                    }

                    // Drift Reward: subtle iridescent glow (appears stochastically after completion)
                    if driftGlow > 0 {
                        LinearGradient(
                            colors: [
                                style.lightTint.opacity(driftGlow * 0.15),
                                .white.opacity(driftGlow * 0.08),
                                style.baseColor.opacity(driftGlow * 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(colorScheme == .dark ? .screen : .colorDodge)
                    }

                    // Skipped hash overlay (diagonal lines — universal "crossed out" metaphor)
                    if isSkipped {
                        Canvas { context, size in
                            let step: CGFloat = 10
                            let opacity = colorScheme == .dark ? 0.18 : 0.14
                            var x: CGFloat = -size.height
                            while x < size.width + size.height {
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: size.height))
                                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                                context.stroke(path, with: .color(.primary.opacity(opacity)), lineWidth: 1)
                                x += step
                            }
                        }
                    }

                    // CONTENT — dual-layer "slice" during fill
                    sliceContent(geo: geo)

                    // Check circle (outside slice — always interactive)
                    HStack {
                        Spacer()
                        Button {
                            if isCompleted {
                                withAnimation(anim(GridConstants.motionSmooth)) {
                                    state = .incomplete
                                    fillProgress = 0
                                    isSwiped = false
                                }
                                HapticsEngine.lightTap()
                                onUndo?(habit)
                            } else if isSkipped {
                                withAnimation(anim(GridConstants.motionSmooth)) {
                                    state = .incomplete
                                    isSwiped = false
                                }
                                HapticsEngine.lightTap()
                                onUndoSkip?(habit)
                            } else if state == .incomplete {
                                beginCompletion()
                            }
                        } label: {
                            checkCircle
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 6)
                    }
                }
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                // Fluid Fill: press-to-complete on the entire block
                .onLongPressGesture(minimumDuration: holdDuration, pressing: { isPressing in
                    guard isInteractive else { return }
                    if isPressing {
                        isHolding = true
                        lastHoldThreshold = 0
                        HapticsEngine.lightTap()
                        withAnimation(.linear(duration: holdDuration)) {
                            holdProgress = 1.0
                        }
                        // Ratcheting haptic chain — tick every 15% of hold progress
                        completionTask = Task { @MainActor in
                            let stepMs = Int(holdDuration * 150) // 15% interval in ms
                            for step in 1...6 { // 15%, 30%, 45%, 60%, 75%, 90%
                                try? await Task.sleep(for: .milliseconds(stepMs))
                                guard !Task.isCancelled, isHolding else { return }
                                lastHoldThreshold = step
                                HapticsEngine.tick()
                            }
                        }
                    } else {
                        // Released early — snap back
                        completionTask?.cancel()
                        isHolding = false
                        lastHoldThreshold = 0
                        withAnimation(anim(GridConstants.motionSnappy)) {
                            holdProgress = 0
                        }
                    }
                }, perform: {
                    // Hold completed — trigger full completion
                    isHolding = false
                    holdProgress = 0
                    lastHoldThreshold = 0
                    beginCompletion()
                })
            }
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: swipeOffset)
            .scaleEffect(
                x: swipeOffset > 0 ? 1.0 + min(swipeOffset / 800, 0.08) : 1.0,
                y: 1.0,
                anchor: .leading
            )
            // Completion settle bounce — escalates with momentum (Hull 1932)
            .scaleEffect(x: 1.0, y: completionBounce ? escalatedBounceAmplitude : 1.0, anchor: .bottom)
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Streak milestone badge overlay
        .overlay(alignment: .trailing) {
            if streakBadgeVisible {
                Text(streakMilestone == 66 ? "Habit Formed!" : "\(streakMilestone)")
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(GridConstants.patinaGold, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .padding(.trailing, 12)
            }
        }
        .shadow(
            color: .black.opacity(GridConstants.adaptiveShadowOpacity(
                isCompleted ? GridConstants.shadowOpacity : GridConstants.shadowOpacity * 0.7,
                colorScheme: colorScheme)),
            radius: isCompleted ? GridConstants.shadowRadius : GridConstants.shadowRadius * 0.7,
            x: 0,
            y: isCompleted ? GridConstants.shadowY : GridConstants.shadowY * 0.7
        )
        // Completed: dim background layers only (text stays crisp at full opacity for WCAG AA)
        .opacity(swipeOffset != 0 ? Double(1.0 - abs(swipeOffset) / 400.0) : 1.0)
        .accessibilityLabel(habit.title)
        .accessibilityHint(isCompleted ? "Completed. Tap checkmark to undo." : (isSkipped ? "Skipped. Tap to undo skip." : "Swipe right to complete, swipe left to skip"))
        .accessibilityAction(named: "Complete") { if isInteractive { beginCompletion() } }
        .accessibilityAction(named: "Skip") { if isInteractive { onSkip?(habit) } }
        .accessibilityAction(named: "Undo Skip") { if isSkipped { onUndoSkip?(habit) } }
        .gesture(
            isInteractive
            ? DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        swipeOffset = value.translation.width

                        // Progressive haptic chain — escalating feedback as threshold approaches
                        let threshold = max(90, rowHeight * 1.3)
                        let progress = abs(value.translation.width) / threshold
                        let tier = Int(progress * 4) // 0=0%, 1=25%, 2=50%, 3=75%
                        if tier > lastSwipeThreshold && tier <= 3 {
                            lastSwipeThreshold = tier
                            if tier <= 2 {
                                HapticsEngine.tick()
                            } else {
                                HapticsEngine.lightTap()
                            }
                        }
                    }
                }
                .onEnded { value in
                    lastSwipeThreshold = 0 // Reset progressive chain
                    let threshold = max(90, rowHeight * 1.3) // Fitts' Law: consistent across block sizes
                    if value.translation.width > threshold {
                        HapticsEngine.snap()
                        withAnimation(anim(.easeOut(duration: 0.25))) { swipeOffset = 400 }
                        completionTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            guard !Task.isCancelled else { return }
                            isSwiped = true
                            beginCompletion()
                        }
                    } else if value.translation.width < -threshold {
                        HapticsEngine.tick()
                        // Skip: stay in place with skipped visual (not vanish)
                        withAnimation(anim(GridConstants.motionSmooth)) {
                            swipeOffset = 0
                            state = .skipped
                        }
                        onSkip?(habit)
                    } else {
                        // Snap back
                        HapticsEngine.tick()
                        withAnimation(anim(GridConstants.motionSmooth)) { swipeOffset = 0 }
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
                .accessibilityHidden(true)

            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.3))
                .scaleEffect(swipeOffset < -30 ? min(CGFloat(-swipeOffset - 30) / 90.0, 1.0) : 0.001)
                .opacity(swipeOffset < -30 ? 1.0 : 0)
                .padding(.trailing, 16)
                .accessibilityHidden(true)
        }
        .frame(height: rowHeight)
    }

    // MARK: - Check Circle

    private var checkCircle: some View {
        let isChecked = isCompleted || isFilling
        let isSkippedState = isSkipped

        return ZStack {
            // Unfilled ring: white glass circle (visible on any category color)
            Circle()
                .stroke(
                    isChecked ? Color.clear : (isSkippedState ? Color.primary.opacity(0.2) : Color.white.opacity(0.6)),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            // Filled state: solid white circle
            Circle()
                .fill(isChecked ? Color.white : (isSkippedState ? Color.primary.opacity(0.15) : Color.white))
                .frame(width: 24, height: 24)
                .scaleEffect(isChecked || isSkippedState ? 1.0 : 0.001)

            Image(systemName: isSkippedState ? "xmark" : "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    isChecked ? style.baseColor : (isSkippedState ? Color.primary.opacity(0.3) : .white)
                )
                .scaleEffect(isChecked || isSkippedState ? 1.0 : 0.001)
                .rotationEffect(.degrees(isChecked || isSkippedState ? 0 : -30))
        }
        .animation(anim(GridConstants.motionSnappy), value: isChecked)
        .animation(anim(GridConstants.motionSnappy), value: isSkippedState)
    }

    // MARK: - Slice Content (dual-mask progressive reveal)

    private enum SliceStyle { case pending, completed }

    /// Computes the current fill fraction from holdProgress or fillProgress
    private var fillFraction: CGFloat {
        if isAlreadyCompleted { return 1.0 }
        if holdProgress > 0 { return holdProgress }
        if fillProgress > 0 { return fillProgress }
        return 0
    }

    /// Dual-mask content: "completed" layer (white) behind fill line, "pending" layer (grey) ahead
    @ViewBuilder
    private func sliceContent(geo: GeometryProxy) -> some View {
        let fraction = fillFraction
        let isSlicing = fraction > 0 && fraction < 1.0 && !isSkipped

        if isSlicing {
            // Completed layer (behind fill line)
            habitContentLayer(sliceStyle: .completed)
                .mask(alignment: .leading) {
                    Rectangle().frame(width: geo.size.width * fraction)
                }
            // Pending layer (ahead of fill line)
            habitContentLayer(sliceStyle: .pending)
                .mask(alignment: .trailing) {
                    Rectangle().frame(width: geo.size.width * (1.0 - fraction))
                }
        } else {
            // Static: fully pending, fully completed, or skipped
            let resolvedStyle: SliceStyle = isCompleted || isFilling ? .completed : .pending
            habitContentLayer(sliceStyle: isSkipped ? .pending : resolvedStyle)
        }
    }

    /// Single content layer with consistent layout (anti-jitter: identical spacing, kerning, alignment)
    private func habitContentLayer(sliceStyle: SliceStyle) -> some View {
        let isComp = sliceStyle == .completed

        return HStack(spacing: 10) {
            Image(systemName: habit.category.iconName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(isComp ? .white.opacity(0.6) : (isSkipped ? Color.primary.opacity(0.3) : style.baseColor))
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(rowHeight <= 56 ? Typography.bodySmall : (rowHeight >= 88 ? Typography.bodyLarge : Typography.headerSmall))
                    .kerning(0) // Anti-jitter: consistent kerning across both mask layers
                    .foregroundStyle(isComp ? .white : (isSkipped ? Color.primary.opacity(0.4) : Color.primary))
                    .strikethrough(isComp || isSkipped, pattern: .solid, color: isComp ? .white.opacity(0.7) : Color.primary.opacity(0.3))
                    .shadow(color: isComp ? .black.opacity(0.15) : .clear, radius: 1, y: 1)

                if let time = habit.scheduledTime {
                    let end = BlockTimeFormatter.endTime(time, durationMinutes: habit.blockSize.durationMinutes)
                    HStack(spacing: 4) {
                        Text("\(BlockTimeFormatter.format12Hour(time)) – \(BlockTimeFormatter.format12Hour(end))")
                            .font(Typography.caption)
                            .kerning(0)
                            .foregroundStyle(isComp ? .white.opacity(0.7) : Color.primary.opacity(0.5))

                        if habit.blockSize != .small {
                            Text(habit.blockSize == .medium ? "30m" : "1h")
                                .font(Typography.caption2)
                                .kerning(0)
                                .foregroundStyle(isComp ? .white.opacity(0.5) : style.baseColor.opacity(0.5))
                        }
                    }
                }
            }

            Spacer()

            // Photo thumbnail (if photo exists and not skipped)
            if let photo = photoFileName, !isSkipped {
                CachedImageView(
                    fileName: photo,
                    width: rowHeight - 16,
                    height: rowHeight - 16,
                    cornerRadius: cornerRadius - 4
                )
                .opacity(isComp ? 0.8 : 1.0)
                .padding(.trailing, 4)
            }

            // Reserve space for check circle (44pt) to match layout with the actual button
            Color.clear.frame(width: 50, height: 44)
        }
    }

    // MARK: - Completion (3 clear phases, one physical world)

    private func beginCompletion() {
        completionTask?.cancel()

        // Phase 1: Check circle fills — escalated haptic (Hull's Goal Gradient)
        withAnimation(anim(GridConstants.motionSnappy)) {
            state = .filling
        }
        switch completionProgress {
        case 0..<0.3:  HapticsEngine.lightTap()
        case 0.3..<0.6: HapticsEngine.lightTap()
        case 0.6..<0.9: HapticsEngine.snap()
        default:        HapticsEngine.success()
        }

        // Phases 2-4 in a cancellable Task
        completionTask = Task { @MainActor in
            // Phase 2: Color sweeps — escalated duration
            let sweepDelay: Int = reduceMotion ? 50 : 250
            try? await Task.sleep(for: .milliseconds(sweepDelay))
            guard !Task.isCancelled else { return }

            withAnimation(anim(.easeInOut(duration: escalatedFillDuration))) {
                fillProgress = 1.0
            }

            // Phase 3: Settle into completed state
            let settleDelay: Int = reduceMotion ? 100 : Int(escalatedFillDuration * 1000 + 50)
            try? await Task.sleep(for: .milliseconds(settleDelay))
            guard !Task.isCancelled else { return }

            HapticsEngine.lightTap()

            withAnimation(anim(GridConstants.motionSettle)) {
                state = .completed
            }

            onComplete(habit)

            // Completion sound — category-tuned, pitch-escalated
            SoundEngine.completionTone(category: habit.category, pitchShift: escalatedPitchShift)

            // Phase 4: Completion settle bounce (mirrors tower squash-stretch)
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    completionBounce = true
                }
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    completionBounce = false
                }
            }

            // Phase 5: Streak milestone celebration (Lally et al. 2010)
            let milestone = [66, 30, 14, 7].first { currentStreak >= $0 && currentStreak < $0 + 1 }
            if let milestone {
                streakMilestone = milestone
                if milestone == 66 {
                    HapticsEngine.reward()
                    SoundEngine.allClearChime()
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    HapticsEngine.reward()
                } else {
                    HapticsEngine.reward()
                    SoundEngine.completionTone(category: habit.category, pitchShift: 200)
                }
                withAnimation(GridConstants.celebrationBurst) {
                    streakBadgeVisible = true
                }
                let badgeDuration = milestone == 66 ? 3000 : 2000
                try? await Task.sleep(for: .milliseconds(badgeDuration))
                guard !Task.isCancelled else { return }
                withAnimation(GridConstants.crossFade) {
                    streakBadgeVisible = false
                }
            }

            // Drift Reward: ~25% chance of delayed aesthetic surprise (Skinner variable ratio)
            guard !Task.isCancelled, !reduceMotion, Double.random(in: 0...1) < 0.25 else { return }
            let driftDelay = Int(Double.random(in: 1500...4000))
            try? await Task.sleep(for: .milliseconds(driftDelay))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 1.2)) {
                driftGlow = 1.0
            }
            HapticsEngine.tick()
        }
    }
}
