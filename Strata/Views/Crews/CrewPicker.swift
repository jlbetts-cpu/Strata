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
                    HStack(spacing: GridConstants.gapTight) {
                        ForEach(store.crews) { crew in
                            chip(crew)
                        }
                    }
                    .padding(.horizontal, onDark ? GridConstants.gapWide : 0)
                }
                .scrollClipDisabled()
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
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(crew.displayName(excluding: store.me))
                    .font(Typography.headerSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(onDark ? (on ? Color.white : AppColors.onDarkSecondary)
                                    : (on ? AppColors.inkPrimary : AppColors.inkSecondary))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .glassCapsule(onPage: !onDark)
        }
        .buttonStyle(.pressSurface)
        .accessibilityLabel(crew.displayName(excluding: store.me))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
