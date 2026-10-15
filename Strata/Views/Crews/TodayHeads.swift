import SwiftUI

/// **Today, across your crews** (2026-10-15: the owner, "the crews page is
/// also pretty empty other than the chats", and "I want the app to feel
/// addicting to win and show your friends").
///
/// Every friend in every crew, once, as their head: someone who has logged
/// today stands in a ring the colour of their newest win, and a press opens
/// that win in its crew; someone who has not is faded, and a press opens a
/// crew you share. The row the crew widget draws on the home screen, inside
/// the app: the same people, the same rule.
struct TodayHeads: View {
    private var store: SocialStore { SocialStore.shared }

    struct Person: Identifiable, Equatable {
        let member: CrewMember
        let crew: CrewID
        /// Their newest win today, in any crew you share.
        let newest: SharedWin?
        let wins: Int
        var id: UUID { member.profileID }
    }

    /// Logged first, newest first; then everyone else by name. Each person
    /// once, from the crew of their newest win.
    static func people(store: SocialStore) -> [Person] {
        var seen: [UUID: Person] = [:]
        var counted: [UUID: Set<UUID>] = [:]
        for crew in store.crews {
            guard let shown = store.visible(crew.id) else { continue }
            let today = store.today(in: crew.id)
            for member in shown.members where member.profileID != store.me {
                let theirs = today.filter { $0.senderProfileID == member.profileID }
                counted[member.profileID, default: []].formUnion(theirs.map(\.winID))
                let newest = theirs.max { $0.createdAt < $1.createdAt }
                let previous = seen[member.profileID]
                if previous == nil || (newest?.createdAt ?? .distantPast) > (previous?.newest?.createdAt ?? .distantPast) {
                    seen[member.profileID] = Person(member: member, crew: crew.id, newest: newest, wins: 0)
                }
            }
        }
        let all = seen.values.map {
            Person(member: $0.member, crew: $0.crew, newest: $0.newest, wins: counted[$0.id]?.count ?? 0)
        }
        return all.sorted { a, b in
            switch (a.newest, b.newest) {
            case let (x?, y?): return x.createdAt > y.createdAt
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.member.shortName.localizedCaseInsensitiveCompare(b.member.shortName) == .orderedAscending
            }
        }
    }

    static let side: CGFloat = 56
    private static let ring: CGFloat = 2.5

    var body: some View {
        let people = Self.people(store: store)
        if !store.crews.isEmpty {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                Text("Today")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(AppColors.inkSecondary)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: GridConstants.gapItem) {
                        ForEach(people) { person in face(person) }
                        // Only where there is room for one more.
                        if store.crews.contains(where: { $0.members.count < CrewCaps.members }), store.canReply() { invite }
                    }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                }
                .edgeFade()
            }
        }
    }

    /// **One more friend, at the end of the row** (the social research,
    /// 2026-10-15, item 5: we underestimate how much people like being asked).
    /// Into the crew that has the fewest people, where one more counts most.
    private var invite: some View {
        let crew = store.crews.filter { $0.members.count < CrewCaps.members }.min { $0.members.count < $1.members.count }
        return Button {
            HapticsEngine.lightTap()
            if let crew { Task { await CrewSharing.invite(crew.id) } }
        } label: {
            VStack(spacing: GridConstants.spacing) {
                Circle()
                    .strokeBorder(AppColors.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(width: Self.side, height: Self.side)
                    .overlay {
                        Image(systemName: "plus")
                            .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                    .padding(Self.ring * 2)
                Text("Invite")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("Invite a friend")
        .accessibilityHint(crew.map { "Shares an invitation to \($0.displayName(excluding: store.me))." } ?? "")
    }

    private func face(_ person: Person) -> some View {
        let logged = person.newest != nil
        let name = person.member.shortName.isEmpty ? "A friend" : person.member.shortName
        return Button {
            HapticsEngine.lightTap()
            if let win = person.newest { CrewRouter.shared.openWin = win.winID }
            CrewRouter.shared.open = person.crew
        } label: {
            VStack(spacing: GridConstants.spacing) {
                PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.side)
                    .padding(Self.ring * 2)
                    .overlay {
                        if let win = person.newest {
                            Circle().strokeBorder(win.colour.style.baseColor, lineWidth: Self.ring)
                        }
                    }
                    .opacity(logged ? 1 : 0.45)
                    .grayscale(logged ? 0 : 1)
                Text(name)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(logged ? AppColors.inkPrimary : AppColors.inkTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: Self.side + Self.ring * 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(logged ? "\(name), \(person.wins == 1 ? "1 win" : "\(person.wins) wins") today" : "\(name), no wins yet today")
        .accessibilityHint(logged ? "Opens their newest win." : "Opens your crew.")
    }
}
