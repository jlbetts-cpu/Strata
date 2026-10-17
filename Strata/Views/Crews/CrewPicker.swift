import SwiftUI

/// Who sees this win: **one small chip** (the owner, 2026-10-18: "Who sees
/// it ('Just you' or crews): one small chip", and "make every control ...
/// match one system"). It was a row of ticks here and a chip on the camera
/// card; it is the chip everywhere now, its menu holding Just Me, Every
/// Crew, each crew and, on the card, Tonight's Story.
///
/// Preset to whatever was ticked last time, so a win goes where the last one
/// went without anyone being asked (the owner, 2026-10-02: recording a win
/// stays the fastest thing in the app). Nothing ticked: it is yours alone.
/// Shown only when crews are on and you are in one.
struct CrewPicker: View {
    @Binding var selection: Set<CrewID>
    /// On the camera's dark ground; the sheets are light.
    var onDark = false
    /// Under 16 photos stay on the phone, and the camera says so.
    var mentionsPhotos = false
    /// Kept for its callers: a chip never runs on to the row's edge.
    var endsAtEdge = false
    /// **One crew, not several** (a plan made from the Crews list, 2026-10-14:
    /// a plan is a line in one crew's chat). No Every Crew, and a choice
    /// moves rather than adds.
    var single = false
    /// Tonight's Story, offered in the same menu (the camera card).
    var story: Binding<Bool>? = nil

    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        if CrewsFlag.isOn, !store.groupCrews.isEmpty {
            VStack(alignment: onDark ? .center : .leading, spacing: 6) {
                Menu { choices } label: { chip }
                    .menuActionDismissBehavior(single ? .automatic : .disabled)
                    .accessibilityLabel("Sending to \(words)" + (story?.wrappedValue == true ? " and tonight's story" : ""))
                    .accessibilityHint("Choose who sees it.")
                if mentionsPhotos, !CrewAge.current.sendsPhotos {
                    Text("Photos stay with you")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(onDark ? AppColors.onDarkSecondary : AppColors.inkSecondary)
                }
            }
        }
    }

    /// **Every crew in one press** (the owner, 2026-10-13: "create a select
    /// all for when you are adding wins"), first, when there is more than one.
    @ViewBuilder
    private var choices: some View {
        if single {
            ForEach(store.groupCrews) { crew in
                Button {
                    HapticsEngine.tick()
                    selection = [crew.id]
                } label: {
                    if selection.contains(crew.id) {
                        Label(crew.displayName(excluding: store.me), systemImage: "checkmark")
                    } else {
                        Text(crew.displayName(excluding: store.me))
                    }
                }
            }
        } else {
            Toggle("Just Me", isOn: Binding(get: { selection.isEmpty }, set: { if $0 { selection = [] } }))
            if store.groupCrewCount > 1 {
                let all = Set(store.groupCrews.map(\.id))
                Toggle(Self.everyCrewMenuWord, isOn: Binding(get: { !all.isEmpty && all.isSubset(of: selection) },
                                                       set: { selection = $0 ? selection.union(all) : selection.subtracting(all) }))
            }
            ForEach(store.groupCrews) { crew in
                Toggle(crew.displayName(excluding: store.me),
                       isOn: Binding(get: { selection.contains(crew.id) },
                                     set: { if $0 { selection.insert(crew.id) } else { selection.remove(crew.id) } }))
            }
        }
        if let story {
            Divider()
            Toggle("Tonight's Story", systemImage: "moon.stars", isOn: story)
        }
    }

    private var chip: some View {
        HStack(spacing: GridConstants.spacing) {
            if story?.wrappedValue == true { Image(systemName: "moon.stars") }
            Text(words).lineLimit(1)
            Image(systemName: "chevron.down")
                .iconSize(GridConstants.iconMedium, relativeTo: .footnote, weight: .semibold)
                .foregroundStyle(onDark ? AppColors.onDarkSecondary : AppColors.inkTertiary)
        }
        .font(Typography.headerSmall)
        .foregroundStyle(onDark ? Color.white : AppColors.inkPrimary)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .glassCapsule(onPage: !onDark)
        .contentShape(Capsule())
    }

    /// Said as the person would say it: "Just you", "Roommates", "Every
    /// crew", "Roommates and 2 more".
    private var words: String {
        let chosen = store.groupCrews.filter { selection.contains($0.id) }
        if chosen.isEmpty { return single ? "Choose a crew" : "Just you" }
        if chosen.count > 1, chosen.count == store.groupCrews.count { return Self.everyCrewWord }
        let first = chosen[0].displayName(excluding: store.me)
        return chosen.count == 1 ? first : "\(first) and \(chosen.count - 1) more"
    }

    /// Said as the person would say it, "send it to every crew", not as a
    /// control ("Select all").
    static let everyCrewWord = "Every crew"
    static let everyCrewMenuWord = "Every Crew"
}
