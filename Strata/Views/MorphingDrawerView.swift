import SwiftUI

struct MorphingDrawerView: View {
    let incompleteHabits: [Habit]
    let completedToday: [HabitLog]
    let onComplete: (Habit) -> Void
    let onUndo: (Habit) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var currentSnap: SnapPoint = .dock
    @State private var isDragging = false

    enum SnapPoint: CGFloat {
        case dock = 76
        case expanded = 260
        case full = 520

        static let all: [SnapPoint] = [.dock, .expanded, .full]
    }

    private var currentHeight: CGFloat {
        let base = currentSnap.rawValue
        let clamped = max(SnapPoint.dock.rawValue, min(SnapPoint.full.rawValue, base - dragOffset))
        return clamped
    }

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            grabHandle

            // Content
            if currentHeight > SnapPoint.dock.rawValue + 20 {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Incomplete habits - "Floating Pool"
                        if !incompleteHabits.isEmpty {
                            floatingPoolSection
                        }

                        // Completed today - Timeline
                        if !completedToday.isEmpty {
                            completedSection
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(height: currentHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                topTrailingRadius: 20,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        .gesture(dragGesture)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: currentSnap)
        .animation(.interactiveSpring(response: 0.3), value: dragOffset)
    }

    // MARK: - Grab Handle

    private var grabHandle: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.primary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack {
                Text("\(incompleteHabits.count) remaining")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                if !completedToday.isEmpty {
                    Text("\(completedToday.count) done")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(hex: 0x648BF2))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Floating Pool

    private var floatingPoolSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UP NEXT")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.tertiary)
                .tracking(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            ForEach(incompleteHabits, id: \.id) { habit in
                IncompleteHabitRow(habit: habit) {
                    onComplete(habit)
                }

                if habit.id != incompleteHabits.last?.id {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 4)

            Text("COMPLETED")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.tertiary)
                .tracking(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            ForEach(completedToday, id: \.id) { log in
                if let habit = log.habit {
                    CompletedHabitRow(habit: habit, log: log) {
                        onUndo(habit)
                    }

                    if log.id != completedToday.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.height
            }
            .onEnded { value in
                isDragging = false
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let projected = currentHeight - value.translation.height

                // Find nearest snap point considering velocity
                let target: SnapPoint
                if abs(velocity) > 300 {
                    // Fast swipe — snap in direction of velocity
                    if velocity > 0 {
                        // Swiping down = shrink
                        target = SnapPoint.all
                            .filter { $0.rawValue < currentSnap.rawValue }
                            .last ?? .dock
                    } else {
                        // Swiping up = expand
                        target = SnapPoint.all
                            .filter { $0.rawValue > currentSnap.rawValue }
                            .first ?? .full
                    }
                } else {
                    // Slow drag — snap to nearest
                    target = SnapPoint.all
                        .min(by: { abs($0.rawValue - projected) < abs($1.rawValue - projected) })
                        ?? .dock
                }

                dragOffset = 0
                currentSnap = target

                // Haptic at snap
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
    }
}
