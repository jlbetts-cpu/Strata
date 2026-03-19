import SwiftUI

struct SheetContentView: View {
    @Binding var selectedDetent: PresentationDetent
    @Binding var selectedTab: Int
    var weekData: [DayProgressData]
    var timelineContent: AnyView

    @Namespace private var glassNS

    static let smallDetent: PresentationDetent = .height(90)
    static let mediumDetent: PresentationDetent = .fraction(0.45)
    static let largeDetent: PresentationDetent = .large

    private let healthGreen = Color(hex: 0x34C48B)

    private var isCollapsed: Bool {
        selectedDetent == Self.smallDetent
    }

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // Drag handle — always visible
                Capsule()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, isCollapsed ? 4 : 8)

                // Expandable content — revealed by pulling up
                if !isCollapsed {
                    weekStripView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)

                    timelineContent
                        .frame(maxHeight: .infinity)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Tab bar — always at bottom
                tabBar
            }
            .glassEffect(.regular, in: .rect(cornerRadius: isCollapsed ? 40 : 28))
            .glassEffectID("footer", in: glassNS)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedDetent)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "square.stack.3d.up", label: "Tower", tag: 0)
            tabButton(icon: "book", label: "Journal", tag: 1)
            tabButton(icon: "person", label: "Profile", tag: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tabButton(icon: String, label: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(Typography.caption2)
            }
            .foregroundStyle(selectedTab == tag ? Color.accentColor : Color.primary.opacity(0.5))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Strip

    private var weekStripView: some View {
        HStack(spacing: 0) {
            ForEach(weekData) { day in
                VStack(spacing: 6) {
                    Text(day.dayLabel)
                        .font(Typography.caption2)
                        .foregroundStyle(
                            day.isFuture ? Color.primary.opacity(0.25) : Color.primary.opacity(0.55)
                        )

                    ZStack {
                        Circle()
                            .stroke(
                                day.isFuture ? Color.primary.opacity(0.06) : Color.primary.opacity(0.08),
                                lineWidth: 2.5
                            )
                            .frame(width: 36, height: 36)

                        if !day.isFuture && day.completionRate > 0 {
                            Circle()
                                .trim(from: 0, to: day.completionRate)
                                .stroke(
                                    healthGreen,
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                                .frame(width: 36, height: 36)
                                .rotationEffect(.degrees(-90))
                        }

                        if day.isToday {
                            Circle()
                                .fill(healthGreen.opacity(0.12))
                                .frame(width: 32, height: 32)
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
