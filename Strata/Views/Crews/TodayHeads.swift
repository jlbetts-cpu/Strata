import SwiftUI

/// **Today, across your crews** (2026-10-15: the owner, "the crews page is
/// also pretty empty other than the chats", and "I want the app to feel
/// addicting to win and show your friends").
///
/// Every friend in every crew, once, as their head, **standing on today's
/// blocks** (the owner, 2026-10-15: "I don't like the ring at all tbh the
/// color isn't important find a different thing that feels more like Some
/// Wins"). Your head stands on your tower; theirs stands on a small one, a
/// block a win, so the row says how far each friend's day has got without a
/// legend. Someone who has not logged stands on one empty lattice cell,
/// faded. A press opens their profile.
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
        /// Today's wins, oldest first, once each: the blocks they stand on.
        var today: [SharedWin] = []
        var id: UUID { member.profileID }
    }

    /// Logged first, newest first; then everyone else by name. Each person
    /// once, from the crew of their newest win.
    static func people(store: SocialStore) -> [Person] {
        var seen: [UUID: Person] = [:]
        var counted: [UUID: [UUID: SharedWin]] = [:]
        for crew in store.crews {
            guard let shown = store.visible(crew.id) else { continue }
            let today = store.today(in: crew.id)
            for member in shown.members where member.profileID != store.me {
                let theirs = today.filter { $0.senderProfileID == member.profileID }
                for win in theirs { counted[member.profileID, default: [:]][win.winID] = win }
                let newest = theirs.max { $0.createdAt < $1.createdAt }
                let previous = seen[member.profileID]
                if previous == nil || (newest?.createdAt ?? .distantPast) > (previous?.newest?.createdAt ?? .distantPast) {
                    seen[member.profileID] = Person(member: member, crew: crew.id, newest: newest, wins: 0)
                }
            }
        }
        let all = seen.values.map {
            Person(member: $0.member, crew: $0.crew, newest: $0.newest, wins: counted[$0.id]?.count ?? 0,
                   today: (counted[$0.id]?.values).map { $0.sorted { $0.createdAt < $1.createdAt } } ?? [])
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
    /// The breathing room the ring used to take, kept so Invite and the
    /// heads still line up.
    private static let inset: CGFloat = 5
    /// The little tower: a block a win, up to four across the head's width.
    private static let block: CGFloat = 10
    private static let blocksShown = 4

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
                Color.clear.frame(height: Self.block)
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
                VStack(spacing: GridConstants.spacing / 2) {
                    PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.side)
                        .opacity(logged ? 1 : 0.45)
                        .grayscale(logged ? 0 : 1)
                    stand(person.today)
                }
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

    /// What a head stands on: today's blocks side by side, in the tower's own
    /// corner and gutter at a small size, newest on the right. Before the
    /// first win, one empty cell of the lattice, as a bare tower shows.
    private func stand(_ wins: [SharedWin]) -> some View {
        let shown = wins.suffix(Self.blocksShown)
        let shape = RoundedRectangle(cornerRadius: Self.block / 4, style: .continuous)
        return HStack(spacing: GridConstants.spacing / 2) {
            if shown.isEmpty {
                shape.fill(AppColors.quietFill)
                    .frame(width: Self.block, height: Self.block)
            } else {
                ForEach(Array(shown), id: \.winID) { win in
                    shape.fill(win.colour.style.baseColor)
                        .frame(width: Self.block, height: Self.block)
                        .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(height: Self.block)
        .animation(GridConstants.motionSnappy, value: wins.count)
        .accessibilityHidden(true)
    }
}
