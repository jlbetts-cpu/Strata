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
            if !pushed {
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
            VStack(spacing: GridConstants.gapSection) {
                ProfileTop(person: .member(member, crew: crewID, me: store.me), name: name,
                           figures: [],
                           // This month's, by the rule yours keeps.
                           banner: recent.filter { Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month) }
                               .compactMap(\.photo).prefix(ProfileBanner.most).map(BannerPicture.theirs),
                           chips: chips(today: today.count),
                           handle: store.shownHandle(of: store.crew(crewID)?.member(member.profileID) ?? member))
                if !facts.isEmpty {
                    InfoCard(rows: facts, contained: true)
                }
                photos(width: width - PageCard.inset * 2)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, GridConstants.gapPage)
        }
        .softScrollEdge(.top)
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

    /// What you have in common, and since when.
    private var facts: [InfoCard.Fact] {
        var out: [InfoCard.Fact] = []
        let names = together.map { $0.displayName(excluding: store.me) }
        if !names.isEmpty {
            out.append(InfoCard.Fact(icon: "person.2", text: names.prefix(2).formatted(.list(type: .and))
                                     + (names.count > 2 ? " and \(names.count - 2) more" : "")))
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
            let gap = GridConstants.spacing
            let side = floor((width - gap * 2) / 3)
            // On its card with its title inside, as every section's is now.
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                Text("Recent photos")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: 3), spacing: gap) {
                    ForEach(recent) { win in
                        Button {
                            HapticsEngine.lightTap()
                            viewerWins = recent
                            viewerNewest = true
                            viewing = win.winID.uuidString
                        } label: {
                            if let url = win.photo {
                                CrewPhotoView(url: url, width: side, height: side)
                                    .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
                            }
                        }
                        .buttonStyle(.press)
                        .accessibilityLabel(win.title.isEmpty ? "A photo" : win.title)
                        .accessibilityHint("Opens it full screen.")
                    }
                }
            }
            .padding(PageCard.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageCard()
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
