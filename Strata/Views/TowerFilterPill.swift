import SwiftUI

struct TowerFilterMenuButton: View {
    @Binding var selection: TowerFilterMode

    private var isNonDefault: Bool { selection != .day }

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(TowerFilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            } label: {
                // Empty — Picker provides the checkmark UI
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isNonDefault
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                Text(selection.rawValue)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .onChange(of: selection) { HapticsEngine.tick() }
    }
}
