import SwiftUI

struct TowerFilterPill: View {
    @Binding var selection: TowerFilterMode
    @Namespace private var filterNS
    @Environment(\.colorScheme) private var colorScheme

    private var iconActive: Color {
        colorScheme == .dark ? Color(hex: 0xFAFAF6) : Color(hex: 0x2C2A26)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TowerFilterMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        selection = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(iconActive.opacity(selection == mode ? 1.0 : 0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if selection == mode {
                                Capsule()
                                    .fill(iconActive.opacity(0.12))
                                    .matchedGeometryEffect(id: "activeFilter", in: filterNS)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }
}
