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
    /// Something stands at the row's end (the add sheet's tag button): the
    /// names are cut at the row's edge and fade into it, instead of running
    /// on under it (seen 2026-10-13: "Ana, Leo" under the tag).
    var endsAtEdge = false
    /// **One crew, not several** (a plan made from the Crews list, 2026-10-14:
    /// a plan is a line in one crew's chat). No Every crew, and a press moves
    /// the choice rather than adding to it.
    var single = false

    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        if CrewsFlag.isOn, !store.groupCrews.isEmpty {
            VStack(alignment: onDark ? .center : .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    // `gapWide` between choices now there is no capsule to
                    // hold each one apart (2026-10-06).
                    HStack(spacing: GridConstants.gapWide) {
                        // **Every crew in one press** (the owner, 2026-10-13,
                        // from his phone: "create a select all for when you
                        // are adding wins so you don't have to individually
                        // click crews"). First, and only when there is more
                        // than one crew to choose: with one, it is that crew.
                        if store.groupCrewCount > 1, !single { everyCrew }
                        ForEach(store.groupCrews) { crew in
                            chip(crew)
                        }
                    }
                    .padding(.horizontal, onDark ? GridConstants.gapWide : 0)
                }
                .edgeFade()
                .scrollClipDisabled(!endsAtEdge)
                .mask {
                    if endsAtEdge {
                        LinearGradient(stops: [.init(color: .black, location: 0),
                                               .init(color: .black, location: 0.9),
                                               .init(color: .clear, location: 1)],
                                       startPoint: .leading, endPoint: .trailing)
                    } else {
                        Rectangle().padding(-1000)
                    }
                }
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

    /// On when every crew is chosen. A press chooses them all, or, when they
    /// all are, none: the one switch a person reaches for either way.
    private var everyCrew: some View {
        let all = Set(store.groupCrews.map(\.id))
        let on = !all.isEmpty && all.isSubset(of: selection)
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) {
                selection = on ? selection.subtracting(all) : selection.union(all)
            }
        } label: {
            label(Self.everyCrewWord, on: on)
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(on ? "Every crew, chosen" : "Every crew")
        .accessibilityHint(on ? "Takes the win off every crew." : "Sends the win to every crew.")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// Said as the person would say it, "send it to every crew", not as a
    /// control ("Select all").
    static let everyCrewWord = "Every crew"

    private func label(_ word: String, on: Bool) -> some View {
        HStack(spacing: GridConstants.gapTight) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(Typography.headerMedium)
                .contentTransition(.symbolEffect(.replace))
            Text(word)
                .font(Typography.headerSmall)
                .lineLimit(1)
        }
        .foregroundStyle(onDark ? (on ? Color.white : AppColors.onDarkSecondary)
                                : (on ? AppColors.inkPrimary : AppColors.inkSecondary))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func chip(_ crew: Crew) -> some View {
        let on = selection.contains(crew.id)
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) {
                if single { selection = [crew.id] }
                else if on { selection.remove(crew.id) } else { selection.insert(crew.id) }
            }
        } label: {
            label(crew.displayName(excluding: store.me), on: on)
        }
        // **Ink, not glass** (the owner, 2026-10-06): Add a win could pass
        // ten glass capsules with crews and people ticked, against a budget
        // of three. The tick and the ink say chosen; the word press answers.
        .buttonStyle(.pressWord)
        .accessibilityLabel(crew.displayName(excluding: store.me))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
