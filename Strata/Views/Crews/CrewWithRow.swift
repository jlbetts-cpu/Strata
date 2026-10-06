import SwiftUI

/// **"With…"**: who a win was with, under the crew chips on Add Win
/// (shared wins, spec 1).
///
/// Quiet on purpose: one row of the same chips as `CrewPicker`, shown only
/// when the win is going to at least one crew, and listing only the people
/// in the crews ticked above it, never your contacts. Up to three
/// (`CrewCaps.withPeople`); past that the rest stand down rather than
/// swapping someone out behind your back.
///
/// Each person tagged is asked once whether to keep a copy, and the line
/// under the row says so before anyone is tagged, not after.
struct CrewWithRow: View {
    /// The crews ticked above. Their people are the only ones offered.
    let crews: Set<CrewID>
    @Binding var selection: [UUID]

    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        let people = store.taggable(in: crews)
        if CrewsFlag.isOn, !people.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GridConstants.gapTight) {
                        Text("With…")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.inkSecondary)
                            .accessibilityHidden(true)
                        ForEach(people) { person in
                            chip(person)
                        }
                    }
                }
                .scrollClipDisabled()
                Text("They'll be asked if they want to keep it too.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("With")
            // A crew unticked takes its people with it.
            .onChange(of: crews) { _, _ in
                let offered = Set(store.taggable(in: crews).map(\.profileID))
                selection.removeAll { !offered.contains($0) }
            }
        }
    }

    private func chip(_ person: CrewMember) -> some View {
        let on = selection.contains(person.profileID)
        let full = selection.count >= CrewCaps.withPeople
        let name = person.shortName.isEmpty ? "A friend" : person.shortName
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) {
                if on { selection.removeAll { $0 == person.profileID } } else { selection.append(person.profileID) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(Typography.headerMedium)
                    .contentTransition(.symbolEffect(.replace))
                Text(name)
                    .font(Typography.headerSmall)
                    .lineLimit(1)
            }
            // Three chosen: the rest go to the quietest ink, the one a
            // control that cannot be pressed wears, not a private opacity.
            .foregroundStyle(on ? AppColors.inkPrimary : (full ? AppColors.inkQuiet : AppColors.inkSecondary))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .glassCapsule(onPage: true)
        }
        .buttonStyle(.pressSurface)
        .disabled(!on && full)
        .accessibilityLabel(name)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
