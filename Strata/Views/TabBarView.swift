import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case journal = "Journal"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .tower: return "square.stack.3d.up.fill"
        case .journal: return "book.fill"
        case .profile: return "person.fill"
        }
    }
}

struct TabBarView: View {
    @Binding var selectedTab: StrataTab

    private let brandMint = Color(hex: 0x10B77F)

    var body: some View {
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
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
    }
}
