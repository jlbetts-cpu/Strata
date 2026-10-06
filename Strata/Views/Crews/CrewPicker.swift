import SwiftUI

/// Who sees this win: one tick per crew, in a row.
///
/// Preset to whatever was ticked last time, so a win goes where the last one
/// went without anyone being asked (the owner, 2026-10-02: recording a win
/// stays the fastest thing in the app). Nothing ticked: it is yours alone.
/// Shown only when crews are on and you are in one.
struct CrewPicker: View {
    @Binding var selection: Set<CrewID>
    /// The camera's review screen is dark; the sheets are light.
    var onDark = false
    /// Under 16 photos stay on the phone, and the camera says so.
    var mentionsPhotos = false

    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        if CrewsFlag.isOn, !store.crews.isEmpty {
            VStack(alignment: onDark ? .center : .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    // `gapWide` between choices now there is no capsule to
                    // hold each one apart (2026-10-06).
                    HStack(spacing: GridConstants.gapWide) {
                        ForEach(store.crews) { crew in
                            chip(crew)
                        }
                    }
                    .padding(.horizontal, onDark ? GridConstants.gapWide : 0)
                }
                .scrollClipDisabled()
                // Its own height, always: with the keyboard up the page is
                // short and a horizontal scroll is the first thing squeezed,
                // which ran the block up over the names (2026-10-06).
                .fixedSize(horizontal: false, vertical: true)
                if mentionsPhotos, !CrewAge.current.sendsPhotos {
                    Text("Photos stay with you")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(onDark ? AppColors.onDarkSecondary : AppColors.inkSecondary)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Send to")
        }
    }

    private func chip(_ crew: Crew) -> some View {
        let on = selection.contains(crew.id)
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) {
                if on { selection.remove(crew.id) } else { selection.insert(crew.id) }
            }
        } label: {
            HStack(spacing: GridConstants.gapTight) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(Typography.headerMedium)
                    .contentTransition(.symbolEffect(.replace))
                Text(crew.displayName(excluding: store.me))
                    .font(Typography.headerSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(onDark ? (on ? Color.white : AppColors.onDarkSecondary)
                                    : (on ? AppColors.inkPrimary : AppColors.inkSecondary))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        // **Ink, not glass** (the owner, 2026-10-06): Add a win could pass
        // ten glass capsules with crews and people ticked, against a budget
        // of three. The tick and the ink say chosen; the word press answers.
        .buttonStyle(.pressWord)
        .accessibilityLabel(crew.displayName(excluding: store.me))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
