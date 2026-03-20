import SwiftUI

struct FloatingBottomBar: View {
    @Binding var selectedTab: StrataTab
    @Binding var filterMode: TowerFilterMode
    @Binding var isCollapsed: Bool
    var onAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let iconColor = Color(hex: 0x403D39)
    private let springAnim = Animation.spring(response: 0.4, dampingFraction: 0.75)

    var body: some View {
        HStack(spacing: 12) {
            // Left pill — tab selector
            tabPill

            // Middle pill — filter (collapsed + tower only)
            if isCollapsed && selectedTab == .tower {
                filterPill
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Right pill — add button
            addButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .animation(springAnim, value: isCollapsed)
        .animation(springAnim, value: selectedTab)
    }

    // MARK: - Tab Pill

    private var tabPill: some View {
        HStack(spacing: isCollapsed ? 8 : 16) {
            ForEach(StrataTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, isCollapsed ? 12 : 16)
        .padding(.vertical, isCollapsed ? 10 : 12)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(GridConstants.adaptiveShadowOpacity(0.08, colorScheme: colorScheme)), radius: 12, y: 4)
    }

    private func tabButton(for tab: StrataTab) -> some View {
        Button {
            if tab == selectedTab && tab == .tower {
                withAnimation(springAnim) {
                    isCollapsed.toggle()
                }
            } else {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                    .font(.system(size: isCollapsed ? 16 : 18, weight: .medium))
                    .foregroundStyle(iconColor.opacity(selectedTab == tab ? 1.0 : 0.45))
                    .contentTransition(.symbolEffect(.replace))

                if !isCollapsed {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor.opacity(selectedTab == tab ? 1.0 : 0.45))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Pill

    private var filterPill: some View {
        TowerFilterPill(selection: $filterMode)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
                .shadow(color: .black.opacity(GridConstants.adaptiveShadowOpacity(0.08, colorScheme: colorScheme)), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
