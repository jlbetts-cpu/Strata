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
            HStack(spacing: 5) {
                // Bare glyph, not the .circle / .circle.fill pair: those draw a
                // filled grey disc that reads as a second button next to the
                // label. Weight carries the active state instead.
                Image(systemName: "line.3.horizontal.decrease")
                    .iconSize(GridConstants.iconMedium,
                              relativeTo: .subheadline,
                              weight: isNonDefault ? .semibold : .regular)
                Text(selection.rawValue)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .onChange(of: selection) { HapticsEngine.tick() }
    }
}
