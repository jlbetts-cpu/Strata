import SwiftUI

struct BottomBarView: View {
    @Binding var selectedTab: StrataTab
    var onHandleTap: () -> Void

    private let brandMint = Color(hex: 0x10B77F)

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            Capsule()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .contentShape(Rectangle().size(width: 100, height: 44))
                .onTapGesture { onHandleTap() }
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            if value.translation.height < -30 {
                                onHandleTap()
                            }
                        }
                )

            // Tab bar
            HStack {
                ForEach(StrataTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                                .symbolEffect(.bounce, value: selectedTab == tab)

                            Text(tab.rawValue)
                                .font(Typography.caption2)
                        }
                        .foregroundStyle(selectedTab == tab ? brandMint : Color.secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .glassEffect(.regular.interactive(), in: .rect(topLeadingRadius: 24, topTrailingRadius: 24))
    }
}
