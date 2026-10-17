import SwiftUI

/// **A friend's profile** (the owner, 2026-10-15: "you should be able to see
/// other people's profiles so that needs to look clean and consistent with
/// that"). The top is yours exactly (`ProfileTop`), with their head and name,
/// and **their score and wins as their own phone counts them** (the owner,
/// later the same day: "I feel like the score and wins should be visable in
/// peoples profile"), sent on their member record (`noteMyScore`). From a
/// phone on an older build, their wins today instead.
///
/// **Under it, their tower** (the owner, the same day: "it should be like the
/// tower still with the lattice and everything no different than how it
/// behaves"; "make sure the profile looks good even bare with the lattice").
/// Today's wins they shared with you, and only those, built on the lattice
/// with the blocks `CrewDayView` draws, a press opening the same viewer and
/// a hold the same reactions (`TowerReactions`).
/// Nothing shared yet is the bare lattice, as an empty tower is anywhere.
struct FriendProfileSheet: View {
    let member: CrewMember
    /// The crew the profile was opened from, for the head's own rules.
    let crewID: CrewID
    /// Pushed inside a sheet's own stack (the crew card): the glass back,
    /// not Done.
    var pushed = false
    /// **The top of a person's page** (`PersonPage`): no bar of its own and
    /// no Message, since the conversation rests at the page's foot.
    var embedded = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = CrewTowerModel()
    @State private var viewing: String?
    /// What the viewer pages through: today's tower, or the recent photos,
    /// whichever was pressed.
    @State private var viewerWins: [SharedWin] = []
    /// Whether the viewer was opened from Recent Photos, which reads newest first.
    @State private var viewerNewest = false
    /// Recent Photos, sorted once per change rather than on every draw (a
    /// hold to react redraws the page many times a second).
    @State private var recent: [SharedWin] = []
    /// Read in the body, so tonight's story joins their tower at 8pm and
    /// leaves it at 9am with nothing else changing.
    @State private var minute = 0
    @State private var reporting: SharedWin?
    /// Hold to react and double-tap hearts, as on a crew's tower.
    @State private var reacts = TowerReactions()
    @State private var startingMessage = false
    @State private var messageFailed = false
    private var store: SocialStore { SocialStore.shared }
    private let spacing = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let hPad = GridConstants.horizontalPadding

    /// The crews you share with them, as this phone sees them.
    private var together: [Crew] {
        store.crews.compactMap { store.visible($0.id) }
            .filter { crew in crew.members.contains { $0.profileID == member.profileID } }
    }

    private var wins: [SharedWin] { Self.today(of: member.profileID, store: store) }

    /// Everyone in every crew you share with them, for "Sam with Ana" on a
    /// win from any of those crews.
    private var everyName: [UUID: String] {
        var names: [UUID: String] = [:]
        for crew in together { for m in crew.members where names[m.profileID] == nil { names[m.profileID] = m.shortName } }
        return names
    }

    /// What Recent Photos depends on, counted without sorting: a win that
    /// arrives, a photo that passes its check, a win hidden, a block.
    private var photosKey: [Int] {
        together.map { crew in (store.winsByCrew[crew.id] ?? []).reduce(0) { $0 + ($1.photo == nil ? 1 : 1_000) } }
            + [store.hiddenWins.count, store.blocked.count]
    }

    /// What they shared today in the crews you share, each crew's today by
    /// its own clock (`store.today`, which also reads the test clock), once
    /// each, without anything you hid. Static, so the reactions' lookup can
    /// hold an id rather than this view.
    ///
    /// **With tonight's story, after 8pm** (R13): a story win that went to no
    /// crew stands on their tower too, and every story win is edged in the
    /// evening colour (`onStory`).
    static func today(of friend: UUID, store: SocialStore) -> [SharedWin] {
        var seen: Set<UUID> = []
        let crewWins = store.crews.compactMap { store.visible($0.id) }
            .filter { crew in crew.members.contains { $0.profileID == friend } }
            .flatMap { store.today(in: $0.id) }
        return (crewWins + story(of: friend, store: store).map(\.win))
            .filter { $0.senderProfileID == friend && !store.hiddenWins.contains($0.winID) }
            .sorted { $0.createdAt < $1.createdAt }
            .filter { seen.insert($0.winID).inserted }
    }

    /// Their story, while it is open to you.
    static func story(of friend: UUID, store: SocialStore) -> [CrewStory] {
        store.storyPeople().first { $0.profileID == friend && $0.phase == .open }?.stories ?? []
    }

    private var name: String { member.shortName.isEmpty ? "A friend" : member.firstName }

    /// **Message them** (the owner, 2026-10-16: "a way to message
    /// individuals"): your conversation with them, started if there is none,
    /// opened in Crews as a message thread.
    private var messageButton: some View {
        Button {
            HapticsEngine.lightTap()
            startingMessage = true
            Task {
                let crew = await store.startPersonal(with: member.profileID)
                startingMessage = false
                guard let crew else { messageFailed = true; return }
                dismiss()
                try? await Task.sleep(for: .milliseconds(400))
                CrewRouter.shared.open = crew.id
            }
        } label: {
            HStack(spacing: GridConstants.spacing + 2) {
                if startingMessage { ProgressView().controlSize(.small) } else { Image(systemName: "bubble.left") }
                Text("Message")
            }
            .font(Typography.headerSmall)
            .foregroundStyle(AppColors.inkPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .glassCapsule(onPage: true, carriesType: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(startingMessage)
        .accessibilityLabel("Message \(name)")
        .alert("That didn't start", isPresented: $messageFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("They may need the latest Some Wins. Try again in a moment.")
        }
    }

    var body: some View {
        let _ = minute
        let today = wins
        GeometryReader { geo in
            let usable = geo.size.width - hPad * 2 - spacing * CGFloat(columns - 1)
            page(today: today, colW: floor(usable / CGFloat(columns)), viewport: geo.size.height)
        }
        .background { WarmBackground().ignoresSafeArea().allowsHitTesting(false) }
        // The name once, under the head, as Contacts writes it: the bar's
        // copy of it said the same word twice. It stays the title for the
        // back button and VoiceOver.
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            if !pushed, !embedded {
                BareToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsEngine.lightTap()
                        dismiss()
                    } label: {
                        Text("Done").sheetAction()
                    }
                    .buttonStyle(.pressWord)
                }
            }
        }
        .applying(pushed) { $0.glassBackButton() }
        .onAppear {
            model.wire(reduceMotion: reduceMotion)
            let friend = member.profileID
            reacts.crewOf = { id in
                Self.today(of: friend, store: .shared).first { $0.winID == id }?.crewID
            }
        }
        .task(id: today) { rebuild(today) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 - Double(Calendar.current.component(.second, from: Date()))))
                minute &+= 1
            }
        }
        .task(id: photosKey) { recent = Self.recentPhotos(of: member.profileID, store: store) }
        // A reaction given here, or by anyone, shows on its block as it does
        // on the crew's tower (`CrewTowerView` watches the same map).
        .onChange(of: together.map { store.reactionsByCrew[$0.id] }) { _, _ in rebuild(wins) }
        .fullScreenCover(item: Binding(get: { viewing.map(Viewed.init) }, set: { viewing = $0?.id })) { shown in
            let shownWins = viewerWins
            let crew = shownWins.first { $0.winID.uuidString == shown.id }?.crewID ?? crewID
            PhotoViewer(photos: CrewGallery.photos(shownWins, crew: store.crew(crew), me: store.me,
                                                   names: everyName, newestFirst: viewerNewest),
                        startAt: shown.id,
                        onClose: { viewing = nil },
                        crew: crew,
                        onReport: { photo in
                            viewing = nil
                            // After the cover has gone, as `CrewDayView`.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                reporting = shownWins.first { $0.winID.uuidString == photo.id }
                            }
                        },
                        onHide: { photo in
                            if let id = UUID(uuidString: photo.id) { CrewHiding.hide(id) }
                        },
                        reactions: { photo in
                            guard let id = UUID(uuidString: photo.id) else { return AnyView(EmptyView()) }
                            // The crew of the win on screen, not of the one
                            // tapped: the carousel runs across every crew you
                            // share (found by review, 2026-10-15).
                            let its = shownWins.first { $0.winID == id }?.crewID ?? crew
                            return AnyView(CrewPhotoReactions(winID: id, crewID: its, mine: false))
                        })
        }
        .overlay(alignment: .bottom) { CrewReportAnchor(reporting: $reporting, crewID: reporting?.crewID ?? crewID) }
    }

    private struct Viewed: Identifiable { let id: String }

    /// Score and wins when their phone has sent them, as yours reads; their
    /// wins today otherwise.
    /// **Their score, and nothing else** (the owner, 2026-10-16: "wins aren't
    /// important, the score is the only thing that should show on other
    /// people's profiles"). Nothing at all from a phone too old to send one.
    private func figures(today: Int, shared: Int) -> [ProfileTop.Figure] {
        let live = store.crew(crewID)?.member(member.profileID) ?? member
        return live.score.map { [ProfileTop.Figure($0, "score")] } ?? []
    }

    private func rebuild(_ today: [SharedWin]) {
        let names = Dictionary(together.flatMap(\.members).map { ($0.profileID, $0.shortName) },
                               uniquingKeysWith: { first, _ in first })
        model.rebuild(wins: today, me: store.me, names: names,
                      onStory: Set(Self.story(of: member.profileID, store: store).map(\.id)),
                      reactions: { id in
                          guard let crew = today.first(where: { $0.winID == id })?.crewID else { return [] }
                          return store.reactions(to: id, in: crew)
                      })
    }

    /// **The same profile as yours** (the owner, 2026-10-16: "having the
    /// tower isn't useful, let's put the banner profile thing with the stats
    /// and recent photos ... make sure the profile is consistent like on the
    /// Memories and the crew, consistency is key"). Their banner card, built
    /// as yours is (`ProfileTop`, `ProfileBanner`): their latest shared
    /// photographs over their head, their name, their facts in a quiet line;
    /// then what you share and since when, a line each (`InfoCard`); then
    /// their photographs. What a social profile is for, in the research
    /// behind it (Hinge, Strava, BeReal): who they are, how they are doing,
    /// what you have in common, and what they have shared lately.
    private func page(today: [SharedWin], colW: CGFloat, viewport: CGFloat) -> some View {
        let width = colW * CGFloat(columns) + spacing * CGFloat(columns - 1)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PageCard.gap) {
                ProfileTop(person: .member(member, crew: crewID, me: store.me), name: name,
                           figures: [],
                           // This month's, by the rule yours keeps.
                           banner: recent.filter { Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month) }
                               .compactMap(\.photo).prefix(ProfileBanner.most).map(BannerPicture.theirs),
                           chips: chips(today: today.count),
                           handle: Usernames.shown ? store.shownHandle(of: store.crew(crewID)?.member(member.profileID) ?? member) : nil)
                if member.profileID != store.me, store.canReply(), !embedded { messageButton }
                if !facts.isEmpty {
                    InfoCard(rows: facts, contained: true)
                }
                // Their featured wins, as on your own profile: only ones
                // they sent you, only photographs the check lets show.
                ForEach(theirFeatured, id: \.win.winID) { item in
                    if let url = item.win.photo {
                        WinCard(picture: .theirs(url), prompt: item.prompt)
                    }
                }
                photos(width: width - PageCard.inset * 2)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, GridConstants.gapPage)
        }
        // On a person's page the chat rests at the foot, and the page fades
        // under it too (2026-10-17).
        .softScrollEdge(embedded ? [.top, .bottom] : .top)
    }

    /// Their figures, as yours sit under your name: the score their phone
    /// sends, and today.
    private func chips(today: Int) -> [InfoCard.Fact] {
        let live = store.crew(crewID)?.member(member.profileID) ?? member
        var out: [InfoCard.Fact] = []
        if let score = live.score { out.append(InfoCard.Fact(icon: "star", text: "Score \(score)")) }
        out.append(InfoCard.Fact(icon: "checkmark.circle", text: today == 1 ? "1 today" : "\(today) today"))
        return out
    }

    /// Their featured wins you hold, in their order, with their words.
    private var theirFeatured: [(win: SharedWin, prompt: String)] {
        let live = store.crew(crewID)?.member(member.profileID) ?? member
        let held = together.flatMap { store.wins(in: $0.id) }
            .filter { $0.senderProfileID == member.profileID && !store.hiddenWins.contains($0.winID) }
        return live.featured.compactMap { item in
            guard let win = held.first(where: { $0.winID == item.win }), let photo = win.photo,
                  store.photoIsShown(photo) else { return nil }
            return (win, item.prompt)
        }
    }

    /// What you have in common, and since when.
    private var facts: [InfoCard.Fact] {
        var out: [InfoCard.Fact] = []
        let names = together.map { $0.displayName(excluding: store.me) }
        if !names.isEmpty {
            out.append(InfoCard.Fact(icon: "person.2", text: names.count == 1 ? names[0] : "\(names.count) crews together"))
        }
        if let joined = together.compactMap({ $0.member(member.profileID)?.joinedAt }).min() {
            out.append(InfoCard.Fact(icon: "clock", text: "Since \(joined.formatted(.dateTime.month(.abbreviated).year()))"))
        }
        if !Self.story(of: member.profileID, store: store).isEmpty {
            out.append(InfoCard.Fact(icon: "sparkles", text: "On tonight's story"))
        }
        return out
    }

    // MARK: Their photos

    /// **Their photographs together, under the tower** (the owner,
    /// 2026-10-15: "the profile could also kinda showcase the images
    /// together which helps with socialbility"). What they shared with you,
    /// newest first, from the days your crews still keep (two weeks), in a
    /// grid of squares as your own Memories shows yours. A press opens them
    /// in the carousel. Nothing they did not share, and nothing you hid.
    @ViewBuilder
    private func photos(width: CGFloat) -> some View {
        if !recent.isEmpty {
            // The one photo card, as Memories' months are (`PhotoGridCard`).
            PhotoGridCard(title: "Recent photos",
                          pictures: recent.compactMap { win in win.photo.map { (win.winID.uuidString, BannerPicture.theirs($0)) } }) { id in
                viewerWins = recent
                viewerNewest = true
                viewing = id
            }
        }
    }

    /// Their photographs this phone may show, once each, newest first.
    static func recentPhotos(of friend: UUID, store: SocialStore, limit: Int = 30) -> [SharedWin] {
        guard !store.blocked.contains(friend) else { return [] }
        var seen: Set<UUID> = []
        return store.crews.compactMap { store.visible($0.id) }
            .filter { crew in crew.members.contains { $0.profileID == friend } }
            .flatMap { store.wins(in: $0.id) }
            .filter { $0.senderProfileID == friend && $0.photo != nil && !store.hiddenWins.contains($0.winID) }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.winID).inserted }
            .prefix(limit)
            .map { $0 }
    }
}
