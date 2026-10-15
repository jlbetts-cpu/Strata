import SwiftUI

/// **A friend's profile** (the owner, 2026-10-15: "you should be able to see
/// other people's profiles so that needs to look clean and consistent with
/// that"). The top is yours exactly (`ProfileTop`), with their head and name;
/// the figures are only what a crew already shares: their wins today, in the
/// crews you share, and how many crews you share. Never their score: that
/// is counted from a record only their phone holds, and turning it into a
/// comparison is what the profile research warned against.
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

    /// What they shared today in those crews, each crew's today by its own
    /// clock, once each, without anything you hid.
    private var wins: [SharedWin] {
        var seen: Set<UUID> = []
        return together.flatMap { crew in
            store.wins(in: crew.id, on: CrewDay.string(for: Date(), in: crew.timeZone))
        }
        .filter { $0.senderProfileID == member.profileID && !store.hiddenWins.contains($0.winID) }
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
            let profile = self
            reacts.crewOf = { id in profile.wins.first { $0.winID == id }?.crewID }
        }
        .task(id: today) { rebuild(today) }
        // A reaction given here, or by anyone, shows on its block as it does
        // on the crew's tower (`CrewTowerView` watches the same map).
        .onChange(of: together.map { store.reactionsByCrew[$0.id] }) { _, _ in rebuild(wins) }
        .fullScreenCover(item: Binding(get: { viewing.map(Viewed.init) }, set: { viewing = $0?.id })) { shown in
            let crew = today.first { $0.winID.uuidString == shown.id }?.crewID ?? crewID
            PhotoViewer(photos: CrewGallery.photos(today, crew: store.crew(crew), me: store.me), startAt: shown.id,
                        onClose: { viewing = nil },
                        crew: crew,
                        onReport: { photo in
                            viewing = nil
                            // After the cover has gone, as `CrewDayView`.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                reporting = today.first { $0.winID.uuidString == photo.id }
                            }
                        },
                        onHide: { photo in
                            if let id = UUID(uuidString: photo.id) { CrewHiding.hide(id) }
                        },
                        reactions: { photo in
                            guard let id = UUID(uuidString: photo.id) else { return AnyView(EmptyView()) }
                            return AnyView(CrewPhotoReactions(winID: id, crewID: crew, mine: false))
                        })
        }
        .overlay(alignment: .bottom) { CrewReportAnchor(reporting: $reporting, crewID: reporting?.crewID ?? crewID) }
    }

    private struct Viewed: Identifiable { let id: String }

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
                           figures: [ProfileTop.Figure(today.count, today.count == 1 ? "win today" : "wins today"),
                                     ProfileTop.Figure(shared, shared == 1 ? "crew together" : "crews together")])
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
        }
        // A finger choosing a reaction must not scroll the page under it.
        .scrollDisabled(reacts.reacting != nil)
        .softScrollEdge(.top)
    }
}

