import SwiftUI

/// Day / Week / Month, for the tower header.
///
/// Three words, no chrome until you need it. A stock segmented control was the
/// wrong instrument twice over: it is the single most recognisable "default
/// iOS" component, and its filled track would put a second bordered surface on
/// a page whose whole idea is that the blocks are the only objects with edges.
///
/// The selected range is marked by a soft plate that MOVES between the words
/// rather than appearing under the new one. One object travelling is the
/// difference between a control that responds and a control that redraws —
/// docs/apple-design.md §3, animate from where the thing is.
struct TowerRangePicker: View {
    @Binding var selection: TowerFilterMode
    @Namespace private var plate

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TowerFilterMode.allCases, id: \.self) { mode in
                let isOn = mode == selection
                Text(mode.shortLabel)
                    .font(Typography.caption)
                    .foregroundStyle(.primary.opacity(isOn ? 0.80 : 0.32))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        if isOn {
                            Capsule(style: .continuous)
                                .fill(AppColors.warmBlack.opacity(0.06))
                                .matchedGeometryEffect(id: "rangePlate", in: plate)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                    .onTapGesture {
                        guard mode != selection else { return }
                        HapticsEngine.tick()
                        withAnimation(GridConstants.slotSnap) { selection = mode }
                    }
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    .accessibilityLabel(mode.rawValue)
            }
        }
        .animation(GridConstants.slotSnap, value: selection)
    }
}
