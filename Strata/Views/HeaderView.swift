import SwiftUI

// MARK: - Data Model for Week Progress

struct DayProgressData: Identifiable {
    let id = UUID()
    let dayLabel: String
    let dayNumber: Int
    let completionRate: Double
    let isToday: Bool
    let isFuture: Bool
}

// MARK: - Morphing Date Pill (collapses to capsule, expands to tall glass panel)

struct MorphingDatePill<Content: View>: View {
    let dateLabel: String
    @Binding var isExpanded: Bool
    let screenHeight: CGFloat
    let expandedWidth: CGFloat
    let weekData: [DayProgressData]
    @ViewBuilder let timelineContent: () -> Content

    @State private var isPressed = false
    @State private var dragOffset: CGFloat = 0

    private let collapsedHeight: CGFloat = 40
    private let brandMint = Color(hex: 0x10B77F)

    private var expandedHeight: CGFloat {
        screenHeight - 8
    }

    private var currentCornerRadius: CGFloat {
        isExpanded ? 24 : collapsedHeight / 2
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Date label (always visible, anchored at top)
            headerRow
                .padding(.top, isExpanded ? 16 : 0)
                .padding(.horizontal, isExpanded ? 20 : 16)

            if isExpanded {
                // Row 2: Week strip
                weekStripView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Row 3: Timeline content
                timelineContent()
                    .frame(maxHeight: .infinity)

                // Row 4: Drag handle (with close gesture)
                dragHandleView
            }
        }
        .frame(
            width: isExpanded ? expandedWidth : nil,
            height: isExpanded ? expandedHeight + dragOffset : collapsedHeight
        )
        .glassEffect(.regular, in: .rect(cornerRadius: currentCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
        .scaleEffect((!isExpanded && isPressed) ? 0.95 : 1.0, anchor: .topLeading)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.15), value: dateLabel)
        .onTapGesture {
            if !isExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isExpanded = true
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isExpanded {
                        if abs(value.translation.height) < 2 && abs(value.translation.width) < 2 {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    if !isExpanded {
                        isPressed = false
                    }
                }
        )
    }

    // MARK: - Drag Handle

    private var dragHandleView: some View {
        Capsule()
            .fill(Color.primary.opacity(0.2))
            .frame(width: 36, height: 5)
            .padding(.vertical, 12)
            .contentShape(Rectangle().size(width: 100, height: 44))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.height < 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        if velocity < -300 || value.translation.height < -100 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded = false
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text(dateLabel)
                .font(.system(size: isExpanded ? 17 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !isExpanded {
                // No spacer needed — auto-size width
            } else {
                Spacer()
            }
        }
        .frame(height: collapsedHeight)
    }

    // MARK: - Week Strip with Progress Rings

    private var weekStripView: some View {
        HStack(spacing: 0) {
            ForEach(weekData) { day in
                VStack(spacing: 6) {
                    Text(day.dayLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            day.isFuture ? Color.primary.opacity(0.25) : Color.primary.opacity(0.5)
                        )

                    ZStack {
                        Circle()
                            .stroke(
                                day.isFuture ? Color.primary.opacity(0.06) : Color.primary.opacity(0.1),
                                lineWidth: 3
                            )
                            .frame(width: 36, height: 36)

                        if !day.isFuture && day.completionRate > 0 {
                            Circle()
                                .trim(from: 0, to: day.completionRate)
                                .stroke(
                                    brandMint,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 36, height: 36)
                                .rotationEffect(.degrees(-90))
                        }

                        if day.isToday {
                            Circle()
                                .fill(brandMint.opacity(0.1))
                                .frame(width: 30, height: 30)
                        }

                        Text("\(day.dayNumber)")
                            .font(.system(size: 15, weight: day.isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(
                                day.isFuture ? Color.primary.opacity(0.4) : Color.primary
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Floating Plus Button (top-right)

struct FloatingPlusButton: View {
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(width: 40, height: 40)
            .glassEffect(.regular, in: .circle)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
            .onTapGesture {
                onTap()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if abs(value.translation.height) < 2 && abs(value.translation.width) < 2 {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Legacy HeaderView (used by ContentView)

struct HeaderView: View {
    let completionRate: Double
    let totalBlocks: Int

    var body: some View {
        HStack {
            Text(Date().formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
            Spacer()
            Text("\(Int(completionRate * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
