import SwiftUI

/// **Today, across your crews** (2026-10-15: the owner, "the crews page is
/// also pretty empty other than the chats", and "I want the app to feel
/// addicting to win and show your friends").
///
/// Every friend in every crew, once, as their head, **with a dot when they
/// have a win today**, where an online dot sits (the owner, 2026-10-15: "im
/// not a big fan of the blocks under ... maybe the indicator can just be
/// like an online indicator instead"). The ring and then a stand of blocks
/// came first and went. The dot says only what the crews already share, a
/// win today, never whether someone has the app open. A press opens their
/// profile.
struct TodayHeads: View {
    private var store: SocialStore { SocialStore.shared }
    /// The friend whose profile is open (`FriendProfileSheet`).
    @State private var profile: Person?

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
    /// The breathing room around a head, so Invite and the heads line up.
    private static let inset: CGFloat = 5
    /// The dot, and the page-coloured rim that sets it off the head.
    private static let dot: CGFloat = 14
    private static let dotRim: CGFloat = 2.5

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
            .sheet(item: $profile) { person in
                NavigationStack {
                    FriendProfileSheet(member: person.member, crewID: person.crew)
                }
                .presentationBackground { WarmBackground().ignoresSafeArea() }
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
                VStack(spacing: 0) {
                    Circle()
                        .strokeBorder(AppColors.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(width: Self.side, height: Self.side)
                        .overlay {
                            Image(systemName: "plus")
                                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                                .foregroundStyle(AppColors.inkSecondary)
                        }
                        .padding(.horizontal, Self.inset)
                        .padding(.top, Self.inset)
                }
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
            // **Their profile** (the owner, 2026-10-15: "you should be able
            // to see other people's profiles"), with their newest win first
            // in it, a press away.
            HapticsEngine.lightTap()
            profile = person
        } label: {
            VStack(spacing: GridConstants.spacing) {
                PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.side)
                    .overlay(alignment: .bottomTrailing) {
                        if logged {
                            Circle()
                                .fill(HabitCategory.health.style.baseColor)
                                .frame(width: Self.dot, height: Self.dot)
                                .padding(Self.dotRim)
                                .background(Circle().fill(WarmBackground.top))
                                .offset(x: 1, y: 1)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(GridConstants.motionSnappy, value: logged)
                    .padding(.horizontal, Self.inset)
                    .padding(.top, Self.inset)
                Text(name)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(logged ? AppColors.inkPrimary : AppColors.inkTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: Self.side + Self.inset * 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(logged ? "\(name), \(person.wins == 1 ? "1 win" : "\(person.wins) wins") today" : "\(name), no wins yet today")
        .accessibilityHint("Opens their profile.")
    }
}
