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

// MARK: - Legacy HeaderView (used by ContentView)

struct HeaderView: View {
    let completionRate: Double
    let totalBlocks: Int

    var body: some View {
        HStack {
            Text(Date().formatted(.dateTime.month(.wide).day().year()))
                .font(Typography.headerLarge)
                .kerning(Typography.headerKerning)
                .foregroundStyle(Color.primary)
            Spacer()
            Text("\(Int(completionRate * 100))%")
                .font(Typography.bodyMedium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Floating Plus Button

struct FloatingPlusButton: View {
    let onTap: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(width: 40, height: 40)
            .glassEffect(.regular, in: .circle)
            .shadow(color: .black.opacity(GridConstants.adaptiveShadowOpacity(0.06, colorScheme: colorScheme)), radius: 10, x: 0, y: 5)
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
