import SwiftUI

/// View mode picker for the Today screen — mirrors TowerFilterMenuButton pattern.
/// Apple HIG: "Use segmented controls or menus to switch between views within a current screen."
struct TodayViewModePicker: View {
    @Binding var selection: TodayViewMode

    var body: some View {
        Menu {
            Picker("View", selection: $selection) {
                ForEach(TodayViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selection == .timeline
                      ? "calendar.day.timeline.leading"
                      : "list.bullet")
                Text(selection.rawValue)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.headline)
            .foregroundStyle(.primary)
        }
        .onChange(of: selection) { _, _ in
            HapticsEngine.tick()
        }
        .accessibilityLabel("View mode: \(selection.rawValue)")
        .accessibilityHint("Double tap to switch between List and Timeline views")
    }
}
