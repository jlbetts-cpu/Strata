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
    static func today(of friend: UUID, store: SocialStore) -> [SharedWin] {
        var seen: Set<UUID> = []
        return store.crews.compactMap { store.visible($0.id) }
            .filter { crew in crew.members.contains { $0.profileID == friend } }
            .flatMap { store.today(in: $0.id) }
            .filter { $0.senderProfileID == friend && !store.hiddenWins.contains($0.winID) }
            .sorted { $0.createdAt < $1.createdAt }
            .filter { seen.insert($0.winID).inserted }
    }

    private var name: String { member.shortName.isEmpty ? "A friend" : member.firstName }

    var body: some View {
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
    private func figures(today: Int, shared: Int) -> [ProfileTop.Figure] {
        let live = store.crew(crewID)?.member(member.profileID) ?? member
        let together = ProfileTop.Figure(shared, shared == 1 ? "crew together" : "crews together")
        guard let score = live.score, let wins = live.wins else {
            return [ProfileTop.Figure(today, today == 1 ? "win today" : "wins today"), together]
        }
        return [ProfileTop.Figure(score, "score"), ProfileTop.Figure(wins, wins == 1 ? "win" : "wins"), together]
    }

    private func rebuild(_ today: [SharedWin]) {
        let names = Dictionary(together.flatMap(\.members).map { ($0.profileID, $0.shortName) },
                               uniquingKeysWith: { first, _ in first })
        model.rebuild(wins: today, me: store.me, names: names,
                      reactions: { id in
                          guard let crew = today.first(where: { $0.winID == id })?.crewID else { return [] }
                          return store.reactions(to: id, in: crew)
                      })
    }

    /// The top, then the tower standing on the foot of the page: the lattice
    /// is the floor whether a block is on it or not.
    private func page(today: [SharedWin], colW: CGFloat, viewport: CGFloat) -> some View {
        let shared = together.count
        let tower = model.tower
        let rows = tower.totalRows
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let gridH = rows > 0 ? CGFloat(rows) * colW + CGFloat(rows - 1) * spacing : 0
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ProfileTop(person: .member(member, crew: crewID, me: store.me), name: name,
                           figures: figures(today: today.count, shared: shared))
                Spacer(minLength: GridConstants.gapSection)
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .allowsHitTesting(false)
                        .frame(width: gridW, height: max(gridH, 1))
                    if rows > 0 {
                        TowerBlocksForEach(
                            visibleBlocks: tower.placedBlocks, animCoord: model.animation, towerVM: tower,
                            groupedIDs: [], mergeDestinedIDs: [],
                            colW: colW, gridH: gridH,
                            cornerRadius: GridConstants.cornerRadius, expandedBlockID: nil,
                            reduceMotion: reduceMotion, colorScheme: colorScheme,
                            onTapExpandBlock: { id in
                                if reacts.reacting != nil { reacts.close(); return }
                                guard !reacts.justHeld else { return }
                                viewerWins = today
                                viewerNewest = false
                                viewing = id.uuidString
                            },
                            liftedBlockID: nil,
                            onDoubleTapBlock: { reacts.doubleTap($0) },
                            onHoldBlock: { id, phase in reacts.hold(id, phase) })
                    }
                }
                .modifier(TowerReactionLayers(reactions: reacts, blocks: tower.placedBlocks,
                                              colW: colW, gridW: gridW, gridH: gridH))
                .environment(\.blockLight, BlockLight.over(rows: max(rows, 1)))
                .background(alignment: .bottom) {
                    TowerLattice(cellSize: colW, contentHeight: max(gridH, 1), ripple: nil)
                        .frame(width: gridW)
                }
                .padding(.horizontal, hPad)
                .padding(.bottom, GridConstants.gapWide)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(rows > 0 ? "\(name)'s tower today, \(tower.placedBlocks.count) wins"
                                             : "\(name)'s tower today, nothing shared yet")
            }
            .frame(minHeight: viewport)
            photos(width: colW * CGFloat(columns) + spacing * CGFloat(columns - 1))
        }
        // A finger choosing a reaction must not scroll the page under it.
        .scrollDisabled(reacts.reacting != nil)
        .softScrollEdge(.top)
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
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                Text("Recent Photos")
                    .font(Typography.sectionLabel)
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
            .padding(.horizontal, hPad)
            .padding(.top, GridConstants.gapItem)
            .padding(.bottom, GridConstants.gapPage)
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
