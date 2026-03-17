import SwiftUI

struct TimelineHabitRow: View {
    let habit: Habit
    let rowHeight: CGFloat
    let cornerRadius: CGFloat
    let onComplete: (Habit) -> Void
    var onSkip: ((Habit) -> Void)? = nil

    enum TaskState {
        case incomplete, checking, morphingAndDropping, hidden
    }

    @State private var state: TaskState = .incomplete
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwiped = false

    private var style: CategoryStyle { habit.category.style }

    // Target block dimensions for the morph
    private var morphWidth: CGFloat {
        switch habit.blockSize {
        case .small:  80
        case .medium: 164
        case .hard:   164
        }
    }

    private var morphHeight: CGFloat {
        switch habit.blockSize {
        case .small:  80
        case .medium: 80
        case .hard:   164
        }
    }

    var body: some View {
        if state == .hidden || isSwiped {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        let isMorphing = state == .morphingAndDropping

        return ZStack {
            // Swipe reveal icons behind the block
            if !isMorphing {
                HStack {
                    // Complete icon (revealed on right swipe)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.green)
                        .opacity(swipeOffset > 30 ? min(Double(swipeOffset - 30) / 90.0, 1.0) : 0)
                        .padding(.leading, 16)

                    Spacer()

                    // Skip icon (revealed on left swipe)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.gray)
                        .opacity(swipeOffset < -30 ? min(Double(-swipeOffset - 30) / 90.0, 1.0) : 0)
                        .padding(.trailing, 16)
                }
                .frame(height: rowHeight)
            }

            // Main block content
            ZStack {
                // Background shape
                RoundedRectangle(cornerRadius: isMorphing ? 20 : cornerRadius, style: .continuous)
                    .fill(style.gradient)

                // Gloss overlay — fades out during morph
                if !isMorphing {
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(height: rowHeight * 0.5)
                        Spacer(minLength: 0)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .transition(.opacity)
                }

                // Text + checkbox content — fades out during morph
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.title)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(.white)

                        if let time = habit.scheduledTime {
                            let end = Self.endTime(time, durationMinutes: habit.blockSize.durationMinutes)
                            Text("\(Self.format12Hour(time)) – \(Self.format12Hour(end))")
                                .font(Typography.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 14)

                    Spacer()

                    // Completion toggle
                    Button {
                        guard state == .incomplete else { return }
                        beginCompletion()
                    } label: {
                        checkCircle
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, 6)
                }
                .opacity(isMorphing ? 0 : 1)

                // Block title that appears during morph (mimics tower block label)
                if isMorphing {
                    Text(habit.title)
                        .font(habit.blockSize == .small ? .caption2 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .padding(6)
                        .transition(.opacity)
                }
            }
            .frame(
                width: isMorphing ? morphWidth : nil,
                height: isMorphing ? morphHeight : rowHeight
            )
            .frame(maxWidth: isMorphing ? nil : .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: isMorphing ? 20 : cornerRadius, style: .continuous))
            .offset(x: swipeOffset, y: isMorphing ? 800 : 0)
            // Rubber-band stretch on right swipe
            .scaleEffect(
                x: swipeOffset > 0 ? 1.0 + min(swipeOffset / 800, 0.08) : 1.0,
                y: 1.0,
                anchor: .leading
            )
        }
        .frame(
            width: isMorphing ? morphWidth : nil,
            height: isMorphing ? morphHeight : rowHeight
        )
        .frame(maxWidth: isMorphing ? nil : .infinity, alignment: .leading)
        .shadow(color: style.glow, radius: isMorphing ? 10 : 4, x: 0, y: isMorphing ? 6 : 2)
        .opacity(swipeOffset != 0 ? Double(1.0 - abs(swipeOffset) / 400.0) : 1.0)
        .scaleEffect(isMorphing ? 0.9 : 1.0)
        .gesture(
            state == .incomplete
            ? DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Only allow horizontal swipes (not vertical drags)
                    if abs(value.translation.width) > abs(value.translation.height) {
                        swipeOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 120 {
                        // Swipe RIGHT = complete
                        HapticsEngine.snap()
                        withAnimation(.easeIn(duration: 0.2)) {
                            swipeOffset = 400
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSwiped = true
                            beginCompletion()
                        }
                    } else if value.translation.width < -120 {
                        // Swipe LEFT = skip
                        HapticsEngine.snap()
                        withAnimation(.easeIn(duration: 0.2)) {
                            swipeOffset = -400
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSwiped = true
                            onSkip?(habit)
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = 0
                        }
                    }
                }
            : nil
        )
    }

    // MARK: - Check Circle

    private var checkCircle: some View {
        let isChecked = state == .checking || state == .morphingAndDropping

        return ZStack {
            Circle()
                .stroke(.white.opacity(isChecked ? 0 : 0.6), lineWidth: 1.5)
                .frame(width: 26, height: 26)

            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .scaleEffect(isChecked ? 1.0 : 0.001)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(style.gradientTop)
                .scaleEffect(isChecked ? 1.0 : 0.001)
        }
    }

    // MARK: - Animation Sequence

    private func beginCompletion() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()

        // Phase 1: Fill & Check
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            state = .checking
        }

        // Hold for 0.5s, then Phase 2: Morph & Drop
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)

            let gen2 = UIImpactFeedbackGenerator(style: .medium)
            gen2.impactOccurred()

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                state = .morphingAndDropping
            }

            // Phase 3: Handoff after drop clears
            try? await Task.sleep(nanoseconds: 400_000_000)

            state = .hidden
            onComplete(habit)
        }
    }

    // MARK: - Time Formatting

    /// Computes end time from a start "HH:mm" string + duration in minutes.
    static func endTime(_ startStr: String, durationMinutes: CGFloat) -> String {
        let parts = startStr.split(separator: ":")
        guard let h = Int(parts[0]) else { return startStr }
        let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let totalMinutes = h * 60 + m + Int(durationMinutes)
        let endH = (totalMinutes / 60) % 24
        let endM = totalMinutes % 60
        return String(format: "%02d:%02d", endH, endM)
    }

    /// Converts "14:00" → "2:00 PM"
    static func format12Hour(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard let h = Int(parts[0]) else { return timeStr }
        let m = parts.count > 1 ? String(parts[1]) : "00"
        let period = h < 12 ? "AM" : "PM"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return m == "00" ? "\(hour12) \(period)" : "\(hour12):\(m) \(period)"
    }
}
