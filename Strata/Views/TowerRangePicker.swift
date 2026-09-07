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
    /// Which ranges this instance offers. Insights leaves Week out: a week of
    /// wins is not a thing you built, it is seven things you built, and the
    /// chart already shows those seven side by side. Day and Month are two
    /// genuinely different questions; Week was a third view of the first.
    var options: [TowerFilterMode] = TowerFilterMode.allCases
    @Namespace private var plate

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { mode in
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
                    // The plate stays the size the type needs; the TARGET is
                    // 44pt tall regardless. Apple's minimum is 44x44, and the
                    // pill was about 24 — a control you had to aim at.
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
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
