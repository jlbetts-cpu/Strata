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
    /// Each head's place on screen, for the story to grow out of.
    @State private var rings: [UUID: CGRect] = [:]
    /// Read in the body, so the row redraws itself each minute and a ring
    /// lights at 8pm and a preview goes at 9am with nothing else changing
    /// (the review, 2026-10-15).
    @State private var minute = 0
    /// **The 8pm unlock, once a night** (the owner, 2026-10-16: "make the 8pm
    /// unlock truly special ... something people genuinely look forward to").
    /// Research: a fixed time with the content unknown is what builds the
    /// wait (Fiorillo et al. 2003; Loewenstein 1987), and a ritual you take
    /// part in makes what follows better (Vohs et al. 2013). So at 8:00, or
    /// on the first look after, the faint rings hold a beat, ink themselves
    /// segment by segment down the row, and each head develops into its
    /// photograph; one soft tick; never again that night.
    @AppStorage("crews.storyUnlockNight") private var unlockedNight = ""
    @State private var unlockTick = 0
    /// Tonight's Story being made or changed (`PostMyDaySheet`).
    @State private var composing = false
    /// Tonight, while its unlock has not played on this phone: the rings stay
    /// faint and the heads stay heads. Read from what is stored, so the very
    /// first frame of the row is already the faint one.
    private var unveiling: Bool {
        guard let night = Self.night(store.storyPeople()) else { return false }
        return unlockedNight != night
    }

    /// The night tonight's open stories belong to, if any are open.
    static func night(_ stories: [StoryPerson]) -> String? {
        stories.first { $0.phase == .open }?.stories.first?.day
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The one line a cheer says.
    static let cheer = "Rooting for you today."

    /// A presentation with no system motion of its own: the story's own
    /// growing out of its ring is the only motion.
    static func still(_ change: () -> Void) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet, change)
    }

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
        let night = Self.night(stories)
        let mine = store.myStory
        if !store.crews.isEmpty {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: GridConstants.gapItem) {
                        // **Your Story first**, as yours is in every story
                        // row; it opens any time, as it will look at 8pm.
                        if !mine.isEmpty { yourStory(mine) } else if store.canReply() { addYourStory }
                        ForEach(people) { person in
                            face(person, story: byPerson[person.id], open: open,
                                 order: open.firstIndex { $0.profileID == person.id } ?? 0)
                        }
                        // Invited from outside the app and not yet in.
                        ForEach(InvitedPeople.shared.waiting(in: store.crews)) { person in
                            InvitedHead(person: person, side: Self.side, inset: Self.inset)
                        }
                        // Only where there is room for one more.
                        if store.groupCrews.contains(where: { $0.members.count < CrewCaps.members }), store.canReply() { invite }
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
            // The 8pm cue, tapped: tonight's stories, from the first unwatched.
            .onChange(of: CrewRouter.shared.openStories, initial: true) { _, opens in
                guard opens else { return }
                CrewRouter.shared.openStories = false
                let open = store.storyPeople().filter { $0.phase == .open && $0.profileID != store.me }
                guard let first = open.first(where: { !$0.watched }) ?? open.first else { return }
                watching = Watching(people: open, start: first.id)
            }
            .task(id: night) {
                guard let night, unlockedNight != night else { return }
                // A beat in the faint state, then the rings close.
                var hold = 0.45
                #if DEBUG
                if let seconds = DebugHarness.argument("-strataReplayUnlock").flatMap(Double.init) { hold = max(hold, seconds) }
                #endif
                try? await Task.sleep(for: .seconds(hold))
                guard !Task.isCancelled else { return }
                // Each segment and each picture keeps its own timing
                // (`GoalRingStroke.stagger`, `storyCrest`'s develop); this
                // only says the change is one to be seen.
                withAnimation(reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.6)) {
                    unlockedNight = night
                }
                unlockTick &+= 1
            }
            #if DEBUG
            // `-strataReplayUnlock <seconds>`: the unlock plays on every launch,
            // after holding that long, to be filmed.
            .onAppear { if DebugHarness.argument("-strataReplayUnlock") != nil { unlockedNight = "" } }
            #endif
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: unlockTick)
            .sheet(isPresented: $composing) {
                PostMyDaySheet()
                    .presentationBackground { WarmBackground().ignoresSafeArea() }
            }
            .fullScreenCover(item: $watching) { watching in
                StoryViewer(people: watching.people, start: watching.start, onClose: { Self.still { self.watching = nil } },
                            onEdit: {
                                self.watching = nil
                                // After the cover has gone: UIKit drops a sheet
                                // asked for while another is still leaving.
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(450))
                                    composing = true
                                }
                            },
                            onProfile: { member, _ in
                                self.watching = nil
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(450))
                                    CrewRouter.shared.openPerson = member.profileID
                                }
                            },
                            ring: { [rings] id in rings[id] })
                    // The row shows through while the story grows out of it.
                    .presentationBackground(.clear)
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
        let crew = store.groupCrews.filter { $0.members.count < CrewCaps.members }.min { $0.members.count < $1.members.count }
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
                    // **Liquid glass, not a dotted line** (the owner, 2026-10-16:
                    // "remove the dotted line on the invite and story, just
                    // have it liquid glass, that's our thing").
                    Image(systemName: "plus")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .frame(width: Self.side, height: Self.side)
                        .stillGlassCircle()
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

    private func face(_ person: Person, story: StoryPerson?, open: [StoryPerson], order: Int) -> some View {
        let logged = person.newest != nil
        let name = person.member.shortName.isEmpty ? "A friend" : person.member.shortName
        let showing = story?.phase == .open && !unveiling
        return Button {
            // **Their story, from 8pm** (the owner, 2026-10-15: Snapchat
            // style, the head becomes a preview); otherwise **their profile**
            // (the owner, 2026-10-15: "you should be able to see other
            // people's profiles"), with their newest win first in it.
            HapticsEngine.lightTap()
            // Their page: profile, and your conversation under it (the
            // launch pass, 3).
            if showing { Self.still { watching = Watching(people: open, start: person.id) } } else { CrewRouter.shared.openPerson = person.member.profileID }
        } label: {
            VStack(spacing: GridConstants.spacing) {
                Group {
                    if let story {
                        // **A story wears the Wins goal ring** (the owner,
                        // 2026-10-16: "treat the story icons as the liquid
                        // glass ring in wins, with the pic in the middle and
                        // the number of notches the number of win stories").
                        storyCrest(person, story: story, showing: showing, order: order)
                    } else {
                        // Alive, as chrome is (`.calm`: glances and brow flashes,
                        // never a stare), not a photograph of a head (the owner,
                        // 2026-10-16: "rather than just being there").
                        PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.side,
                                   life: .calm)
                            .padding(.horizontal, Self.inset)
                            .padding(.top, Self.inset)
                    }
                }
                    // **Dimmed until they log today** (the owner, 2026-10-16:
                    // "the person should be dimmed when they haven't logged that
                    // day"). The green dot came out: it read as "online", and
                    // the app never says who has it open.
                    // Flattened first (the owner, 2026-10-16: the eyes did
                    // not dim with the head): opacity on a stack fades each
                    // layer alone, so the drawn irises stayed dark on a faded
                    // face. One picture, then faded, fades as one.
                    .compositingGroup()
                    .opacity(logged || showing ? 1 : 0.45)
                    .animation(GridConstants.motionSnappy, value: logged)
                    // Where the ring stands, for the story to grow out of.
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rings[person.member.profileID] = $0 }
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
        // On every head, always: attached only while a story showed, it
        // swapped the head for a new view the moment the story opened, and
        // the 8pm unlock lost its timing with it.
        .contextMenu {
            Button { CrewRouter.shared.openPerson = person.member.profileID } label: { Label("View Profile", systemImage: "person.crop.circle") }
            // **Message them, from their head** (2026-10-16: "make sure
            // everything is connected"): their conversation, started if
            // there is none.
            if store.canReply() {
                Button {
                    let friend = person.member.profileID
                    Task {
                        guard let crew = await store.startPersonal(with: friend) else { return }
                        CrewRouter.shared.open = crew.id
                    }
                } label: { Label("Message", systemImage: "bubble.left") }
                // **A cheer for a friend with no win yet** (the owner's pick,
                // 2026-10-16): one private line from you, never from the app,
                // into your conversation with them.
                if !logged {
                    Button {
                        let friend = person.member.profileID
                        HapticsEngine.success()
                        // Sent once its Undo has passed, as a deleted line goes.
                        UndoLine.shared.show("Cheering on \(name)", undo: {}, expire: {
                            Task {
                                guard let crew = await SocialStore.shared.startPersonal(with: friend) else { return }
                                await SocialStore.shared.send(Self.cheer, in: crew.id)
                            }
                        })
                    } label: { Label("Send a Cheer", systemImage: "hands.clap") }
                }
            }
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
        .accessibilityLabel(logged ? "\(name), \(person.wins == 1 ? "1 win" : "\(person.wins) wins") today" : "\(name), no wins yet today")
        .accessibilityValue(showing ? (story?.watched == true ? "Story" : "New story")
                            : story?.phase == .waiting ? "A story tonight" : "")
        .accessibilityHint(showing ? "Opens their story." : "Opens their profile.")
    }

    /// A friend with a story: the crest, and the head that develops into
    /// the picture, blurred to sharp, once its ring has closed.
    private func storyCrest(_ person: Person, story: StoryPerson, showing: Bool, order: Int) -> some View {
        StoryCrest(story: story, side: Self.side + Self.inset * 2, seen: store.storiesSeen,
                   held: unveiling, order: order) {
            PersonHead(person: .member(person.member, crew: person.crew, me: store.me), side: Self.storyFace)
        } picture: {
            StoryBubble(story: story, side: Self.storyFace)
        }
    }

    /// **You, first, before you have posted**: your head in a dashed ring with
    /// a +, "Your Story" under it. A press makes tonight's story.
    private var addYourStory: some View {
        Button {
            HapticsEngine.lightTap()
            composing = true
        } label: {
            VStack(spacing: GridConstants.spacing) {
                // Your head on the crest's glass, a glass + at its corner:
                // the story's own mark before there is a story.
                PersonHead(person: .me, side: StoryCrestSize.face(in: Self.side + Self.inset * 2))
                    .frame(width: Self.side + Self.inset * 2, height: Self.side + Self.inset * 2)
                    .stillGlassCircle()
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "plus")
                            .iconSize(13, relativeTo: .caption, weight: .bold)
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(width: 24, height: 24)
                            .glassCircle(onPage: true)
                    }
                Text("Your Story")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("Add to Tonight's Story")
        .accessibilityHint("Pick the best of today for your friends to see at 8pm.")
    }

    /// You, first, with tonight's story: your own preview and a lit ring,
    /// "Your Story" under it.
    private func yourStory(_ stories: [CrewStory]) -> some View {
        let me = StoryPerson(profileID: store.me, stories: stories, phase: .open, watched: false)
        return Button {
            HapticsEngine.lightTap()
            Self.still { watching = Watching(people: [me], start: me.profileID) }
        } label: {
            VStack(spacing: GridConstants.spacing) {
                StoryCrest(story: me, side: Self.side + Self.inset * 2, seen: store.storiesSeen) {
                    EmptyView()
                } picture: {
                    StoryBubble(story: me, side: Self.storyFace)
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rings[store.me] = $0 }
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
        // Its own preview, as every head's: the system's lift took the
        // row's whole scroll with it (seen 2026-10-16 in light mode).
        .contextMenu {
            Button { composing = true } label: { Label("Edit Tonight's Story", systemImage: "pencil") }
        } preview: {
            VStack(spacing: GridConstants.gapTight) {
                StoryBubble(story: me, side: 96)
                    .clipShape(Circle())
                Text("Your Story")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .padding(GridConstants.gapWide)
            .background(WarmBackground.top)
        }
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

struct StoryCrest<Head: View, Picture: View>: View {
    let story: StoryPerson
    /// The whole crest, ring and glass: the row's head and its breathing room.
    let side: CGFloat
    let seen: Set<UUID>
    /// Held faint a beat before the unlock plays (`TodayHeads.unveiling`).
    var held = false
    /// Its place in the row, so the rings close one after another.
    var order = 0
    /// Who, while the story waits.
    @ViewBuilder let head: () -> Head
    /// Their first photograph, once it is open.
    @ViewBuilder let picture: () -> Picture

    /// **Its own moment of release**, after the crests before it in the row:
    /// the ring inks segment by segment, and once it has closed the head
    /// develops into the picture, blurred to sharp, as a print comes up.
    @State private var released: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(story: StoryPerson, side: CGFloat, seen: Set<UUID>, held: Bool = false, order: Int = 0,
         @ViewBuilder head: @escaping () -> Head, @ViewBuilder picture: @escaping () -> Picture) {
        self.story = story
        self.side = side
        self.seen = seen
        self.held = held
        self.order = order
        self.head = head
        self.picture = picture
        // Released already unless it is being held: only a held crest waits
        // for its own turn.
        _released = State(initialValue: !held)
    }

    /// A segment this long after the last; a crest this long after the one
    /// before it.
    static var segmentBeat: Double { 0.09 }
    static var crestBeat: Double { 0.16 }

    private var open: Bool { story.phase == .open && released && !held }

    private var lit: Int {
        guard open else { return 0 }
        return story.stories.filter { !seen.contains($0.id) }.count
    }

    var body: some View {
        let count = story.stories.count
        let develop: Animation = reduceMotion ? GridConstants.crossFade
            : .smooth(duration: 0.7).delay(Double(count) * Self.segmentBeat + 0.1)
        let change: AnyTransition = reduceMotion ? .opacity : AnyTransition(BlurReplaceTransition(configuration: .downUp))
        ZStack {
            GoalRingStroke(wins: lit, goal: count, line: GoalCrest.line,
                           stagger: reduceMotion ? 0 : Self.segmentBeat, closesWhenMet: false)
                .padding(GoalCrest.ringInset - 1)
            ZStack {
                if open {
                    picture().transition(change)
                } else {
                    head().transition(change)
                }
            }
            .animation(develop, value: open)
            .frame(width: StoryCrestSize.face(in: side), height: StoryCrestSize.face(in: side))
            .clipShape(Circle())
        }
        .frame(width: side, height: side)
        .stillGlassCircle()
        .accessibilityHidden(true)
        .onChange(of: held) { _, now in
            if now { released = false; return }
            let wait = reduceMotion ? 0 : Double(order) * Self.crestBeat
            Task {
                try? await Task.sleep(for: .seconds(wait))
                released = true
            }
        }
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
