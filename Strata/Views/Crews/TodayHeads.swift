import SwiftUI

/// **Today, across your crews** (2026-10-15: the owner, "the crews page is
/// also pretty empty other than the chats", and "I want the app to feel
/// addicting to win and show your friends").
///
/// Every friend in every crew, once, as their head, **dimmed until they have
/// a win today** (the owner, 2026-10-16: "the person should be dimmed when
/// they haven't logged that day at all"). A green dot stood here first and
/// went the same day: it read as "online", and the app never says who has it
/// open. Tonight's stories lead the row; a press opens a story, or the
/// friend's profile.
struct TodayHeads: View {
    private var store: SocialStore { SocialStore.shared }
    /// The friend whose profile is open (`FriendProfileSheet`).
    @State private var profile: Person?
    /// Tonight's stories being watched (`StoryViewer`).
    @State private var watching: Watching?
    /// Read in the body, so the row redraws itself each minute and a ring
    /// lights at 8pm and a preview goes at 9am with nothing else changing
    /// (the review, 2026-10-15).
    @State private var minute = 0

    struct Watching: Identifiable {
        let people: [StoryPerson]
        let start: UUID
        var id: UUID { start }
    }

    struct Person: Identifiable, Equatable {
        let member: CrewMember
        let crew: CrewID
        /// Their newest win today, in any crew you share.
        let newest: SharedWin?
        let wins: Int
        var id: UUID { member.profileID }
    }

    /// **From 8pm, tonight's stories first** (the spec, 1.4): open and
    /// unwatched, newest first; then open and watched; then everyone else as
    /// the day had them: logged first, newest first, then by name. Each person
    /// once, from the crew of their newest win.
    static func people(store: SocialStore, stories: [StoryPerson] = []) -> [Person] {
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
        let rank: [UUID: Int] = Dictionary(uniqueKeysWithValues: stories.enumerated()
            .filter { $0.element.phase == .open }.map { ($0.element.profileID, $0.offset) })
        return all.sorted { a, b in
            switch (rank[a.id], rank[b.id]) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): break
            }
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

    var body: some View {
        let _ = minute
        let stories = store.storyPeople()
        let people = Self.people(store: store, stories: stories)
        let byPerson = Dictionary(uniqueKeysWithValues: stories.map { ($0.profileID, $0) })
        let open = stories.filter { $0.phase == .open }
        let mine = store.myStory
        if !store.crews.isEmpty {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: GridConstants.gapItem) {
                        // **Your Story first**, as yours is in every story
                        // row; it opens any time, as it will look at 8pm.
                        if !mine.isEmpty { yourStory(mine) }
                        ForEach(people) { person in face(person, story: byPerson[person.id], open: open) }
                        // Invited from outside the app and not yet in.
                        ForEach(InvitedPeople.shared.waiting(in: store.crews)) { person in
                            InvitedHead(person: person, side: Self.side, inset: Self.inset)
                        }
                        // Only where there is room for one more.
                        if store.crews.contains(where: { $0.members.count < CrewCaps.members }), store.canReply() { invite }
                    }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                }
                .edgeFade()
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60 - Double(Calendar.current.component(.second, from: Date()))))
                    minute &+= 1
                }
            }
            .fullScreenCover(item: $watching) { watching in
                StoryViewer(people: watching.people, start: watching.start, onClose: { self.watching = nil })
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
        // **A person, or a link** (2026-10-16): a contact chosen here stands
        // on the row as invited until they join (`InvitedPeople`); the link
        // goes anywhere, as before.
        return Menu {
            Button {
                if let crew { InvitePicking.start(crew.id) }
            } label: {
                Label("Text a Friend", systemImage: "message")
            }
            Button {
                if let crew { Task { await CrewSharing.invite(crew.id) } }
            } label: {
                Label("Share Invite Link", systemImage: "square.and.arrow.up")
            }
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
        .menuStyle(.button)
        .buttonStyle(.press)
        .accessibilityLabel("Invite a friend")
        .accessibilityHint(crew.map { "Shares an invitation to \($0.displayName(excluding: store.me))." } ?? "")
    }

    private func face(_ person: Person, story: StoryPerson?, open: [StoryPerson]) -> some View {
        let logged = person.newest != nil
        let name = person.member.shortName.isEmpty ? "A friend" : person.member.shortName
        let showing = story?.phase == .open
        return Button {
            // **Their story, from 8pm** (the owner, 2026-10-15: Snapchat
            // style, the head becomes a preview); otherwise **their profile**
            // (the owner, 2026-10-15: "you should be able to see other
            // people's profiles"), with their newest win first in it.
            HapticsEngine.lightTap()
            if showing { watching = Watching(people: open, start: person.id) } else { profile = person }
        } label: {
            VStack(spacing: GridConstants.spacing) {
                Group {
                    if showing, let story {
                        StoryBubble(story: story, side: Self.side)
                    } else {
                        PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.side)
                    }
                }
                    .overlay {
                        if let story { StoryRing(phase: story.phase, watched: story.watched, side: Self.side + Self.inset * 2 - 1) }
                    }
                    // **Dimmed until they log today** (the owner, 2026-10-16:
                    // "the person should be dimmed when they haven't logged that
                    // day"). The green dot came out: it read as "online", and
                    // the app never says who has it open.
                    .opacity(logged || showing ? 1 : 0.45)
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
        .contextMenu {
            if showing {
                Button { profile = person } label: { Label("View Profile", systemImage: "person.crop.circle") }
            }
        }
        .accessibilityLabel(logged ? "\(name), \(person.wins == 1 ? "1 win" : "\(person.wins) wins") today" : "\(name), no wins yet today")
        .accessibilityValue(showing ? (story?.watched == true ? "Story" : "New story")
                            : story?.phase == .waiting ? "A story tonight" : "")
        .accessibilityHint(showing ? "Opens their story." : "Opens their profile.")
    }

    /// You, first, with tonight's story: your own preview and a lit ring,
    /// "Your Story" under it.
    private func yourStory(_ stories: [CrewStory]) -> some View {
        let me = StoryPerson(profileID: store.me, stories: stories, phase: .open, watched: false)
        return Button {
            HapticsEngine.lightTap()
            watching = Watching(people: [me], start: me.profileID)
        } label: {
            VStack(spacing: GridConstants.spacing) {
                StoryBubble(story: me, side: Self.side)
                    .overlay { StoryRing(phase: .open, watched: false, side: Self.side + Self.inset * 2 - 1) }
                    .padding(.horizontal, Self.inset)
                    .padding(.top, Self.inset)
                // Whole, never "Your St...": the one name in the row that is
                // two words, so its column is as wide as the words.
                Text("Your Story")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("Your Story")
        .accessibilityHint("Opens it as your friends see it from 8pm.")
    }
}

/// **The ring round a head with a story**: drawn, in ink, as his pen draws
/// (the owner, 2026-10-16: "why isn't the outline just a doodle black
/// outline"). The goal ring's own hand (`DoodleRing`), so every ring in the
/// app is the same mark. Before 8pm, faint: something is coming tonight,
/// and no count. From 8pm, the full line. Opened, a clean thin grey circle.
struct StoryRing: View {
    let phase: StoryClock.Phase
    let watched: Bool
    let side: CGFloat

    var body: some View {
        Group {
            // Opened: a clean line, a true circle (the owner, 2026-10-16:
            // "the watched should be a clean line"). New or waiting: drawn.
            if phase == .open && watched {
                Circle().stroke(colour, lineWidth: width)
            } else {
                DoodleRing().stroke(colour, style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
            .padding(width / 2)
            .frame(width: side, height: side)
            .animation(GridConstants.crossFade, value: watched)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var colour: Color {
        switch phase {
        case .waiting: AppColors.drawingInk.opacity(0.28)
        case .open: watched ? AppColors.inkTertiary : AppColors.drawingInk
        case .gone: .clear
        }
    }

    /// His pen's line (~2.6pt) when there is something new; a hairline else.
    private var width: CGFloat { phase == .open && !watched ? 2.6 : 1.5 }
}

/// **The head become a preview** (the owner, 2026-10-15: "the friend's
/// picture turns into a preview of their photo when they have a story"):
/// a circle cut from their first story photo; with no photo, the block's own
/// colour and icon. Their name is under it; no head on top (the owner,
/// 2026-10-16: "there isn't a need for the head on the bottom right"). Decoded off the main
/// thread at the size it is drawn (`CrewPhotoView`).
struct StoryBubble: View {
    let story: StoryPerson
    let side: CGFloat

    var body: some View {
        ZStack {
            if let cover = story.cover?.win, let url = cover.photo {
                CrewPhotoView(url: url, width: side, height: side, crop: CGPoint(x: cover.cropX ?? 0, y: cover.cropY ?? 0))
            } else if let cover = story.cover?.win {
                cover.colour.style.baseColor
                if let icon = cover.icon.iconName {
                    Image(systemName: icon)
                        .font(.system(size: side * 0.36, weight: .medium))
                        .foregroundStyle(cover.colour.style.text)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
