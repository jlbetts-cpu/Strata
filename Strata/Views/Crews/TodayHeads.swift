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
    /// Space the story crest's glass light needs past its circle.
    private static let glassRoom: CGFloat = 16
    /// The picture inside a story's crest: the crest is the head and its
    /// breathing room, and the ring and glass take the rest.
    static var storyFace: CGFloat { StoryCrestSize.face(in: side + inset * 2) }
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
                    // Room above and below inside the scroll, so the glass's
                    // own light is never cut flat by the edge fade's mask (the
                    // owner, 2026-10-16: "a weird grey line, it should be
                    // blended into the background"). Taken back outside, so
                    // the row sits where it did.
                    .padding(.vertical, Self.glassRoom)
                }
                .edgeFade()
                .padding(.vertical, -Self.glassRoom)
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
                    if let story {
                        // **A story wears the Wins goal ring** (the owner,
                        // 2026-10-16: "treat the story icons as the liquid
                        // glass ring in wins, with the pic in the middle and
                        // the number of notches the number of win stories").
                        StoryCrest(story: story, side: Self.side + Self.inset * 2, seen: store.storiesSeen) {
                            if showing {
                                StoryBubble(story: story, side: Self.storyFace)
                            } else {
                                PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.storyFace)
                            }
                        }
                    } else {
                        PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.side)
                            .padding(.horizontal, Self.inset)
                            .padding(.top, Self.inset)
                    }
                }
                    // **Dimmed until they log today** (the owner, 2026-10-16:
                    // "the person should be dimmed when they haven't logged that
                    // day"). The green dot came out: it read as "online", and
                    // the app never says who has it open.
                    .opacity(logged || showing ? 1 : 0.45)
                    .animation(GridConstants.motionSnappy, value: logged)
                // Their name under it. (The owner's "no names under the
                // icons", 2026-10-16, was the tab bar's, he said after.)
                Text(name)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(logged || showing ? AppColors.inkPrimary : AppColors.inkTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: Self.side + Self.inset * 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        // **A hold lifts that head alone** (the owner, 2026-10-16: "when you
        // hold for view profile the whole bar highlights when it should just
        // be that profile"): the system's lift took the row's whole scroll
        // with it, so the preview is drawn here, the head and the name.
        .applying(showing) { view in
            view.contextMenu {
                Button { profile = person } label: { Label("View Profile", systemImage: "person.crop.circle") }
            } preview: {
                VStack(spacing: GridConstants.gapTight) {
                    PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: 96)
                    Text(name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                .padding(GridConstants.gapWide)
                .background(WarmBackground.top)
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
                StoryCrest(story: me, side: Self.side + Self.inset * 2, seen: []) {
                    StoryBubble(story: me, side: Self.storyFace)
                }
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

/// **A head with a story, in the goal ring's glass** (the owner,
/// 2026-10-16). The Wins crest's own parts: `GoalRingStroke`, a segment a
/// story, on `stillGlassCircle`, with the picture in the middle. A segment is
/// ink until that story has been opened; before 8pm every segment is the
/// faint track, something coming tonight with no count said. So a glance
/// says how many, and how many are new.
enum StoryCrestSize {
    /// The Wins crest's own proportion (`GoalCrest.faceInset`), a touch
    /// tighter so the face stays near a plain head's size in the row.
    static func face(in side: CGFloat) -> CGFloat { side - 2 * (GoalCrest.faceInset - 2) }
}

struct StoryCrest<Face: View>: View {
    let story: StoryPerson
    /// The whole crest, ring and glass: the row's head and its breathing room.
    let side: CGFloat
    let seen: Set<UUID>
    @ViewBuilder let face: () -> Face

    private var lit: Int {
        story.phase == .open ? story.stories.filter { !seen.contains($0.id) }.count : 0
    }

    var body: some View {
        ZStack {
            GoalRingStroke(wins: lit, goal: story.stories.count, line: GoalCrest.line)
                .padding(GoalCrest.ringInset - 1)
            face()
                .frame(width: StoryCrestSize.face(in: side), height: StoryCrestSize.face(in: side))
                .clipShape(Circle())
        }
        .frame(width: side, height: side)
        .stillGlassCircle()
        .animation(GridConstants.crossFade, value: lit)
        .accessibilityHidden(true)
    }
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
