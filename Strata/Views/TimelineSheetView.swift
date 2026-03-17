import SwiftUI
import SwiftData

struct TimelineSheetView: View {
    @Binding var isExpanded: Bool
    let weekData: [DayProgressData]
    let timelineContent: AnyView
    let screenHeight: CGFloat

    @State private var dragOffset: CGFloat = 0

    private let brandMint = Color(hex: 0x10B77F)

    var body: some View {
        ZStack(alignment: .bottom) {
            if isExpanded {
                // Dimmer
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)

                // Sheet
                VStack(spacing: 0) {
                    grabHandle
                    weekStripView
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    Divider()
                    timelineContent
                        .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: screenHeight - 60)
                .glassEffect(.regular, in: .rect(topLeadingRadius: 20, topTrailingRadius: 20))
                .offset(y: max(0, dragOffset))
                .transition(.move(edge: .bottom))
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.height - value.translation.height
                            if velocity > 300 || value.translation.height > 150 {
                                close()
                            } else {
                                withAnimation(.interactiveSpring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
    }

    private var grabHandle: some View {
        Capsule()
            .fill(Color.primary.opacity(0.2))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func close() {
        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.85)) {
            dragOffset = 0
            isExpanded = false
        }
    }

    // MARK: - Week Strip

    private var weekStripView: some View {
        HStack(spacing: 0) {
            ForEach(weekData) { day in
                VStack(spacing: 6) {
                    Text(day.dayLabel)
                        .font(Typography.caption2)
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
                            .font(Typography.headerSmall)
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
