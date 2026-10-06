import SwiftUI

/// **One of a crew's recent days**, opened from Recent Days in Crew Info.
///
/// The owner, 2026-10-05: "being able to see the previous day from the middle
/// menu or just seeing images from previous days saved in the chat". The
/// day's tower as it stood at the crew's midnight, drawn exactly as today's
/// is: no photo grid under it (the owner: "looks dumb"). A tap on a block
/// opens the day's carousel, reactions and all. The video is one tap away,
/// in the corner.
///
/// Nothing here counts who looked. A crew keeps two weeks of days
/// (`CrewDay.keptDays`); after that only the numbers stay.
struct CrewDayView: View {
    let crew: Crew
    /// The crew day, `yyyy-MM-dd` in the crew's zone.
    let day: String
    let title: String
    /// The bar's header in two tones, "Sunday / 4 October" (`TwoToneTitle`).
    var header: String? = nil
    let play: () -> Void

    @State private var model = CrewTowerModel()
    @State private var viewing: String?
    @State private var reporting: SharedWin?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var store: SocialStore { SocialStore.shared }
    private let spacing = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let hPad = GridConstants.horizontalPadding

    private var wins: [SharedWin] {
        store.wins(in: crew.id, on: day).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        GeometryReader { geo in
            let usable = geo.size.width - hPad * 2 - spacing * CGFloat(columns - 1)
            tower(colW: floor(usable / CGFloat(columns)), viewport: geo.size.height)
        }
        .background { WarmBackground().ignoresSafeArea().allowsHitTesting(false) }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { CrewDayToolbar(title: title, header: header ?? title, play: play) }
        .glassBackButton()
        .task(id: wins) {
            let names = Dictionary(uniqueKeysWithValues: crew.members.map { ($0.profileID, $0.shortName) })
            model.rebuild(wins: wins, me: store.me, names: names,
                          reactions: { store.reactions(to: $0, in: crew.id) })
        }
        .fullScreenCover(item: Binding(get: { viewing.map(Viewed.init) }, set: { viewing = $0?.id })) { shown in
            PhotoViewer(photos: CrewGallery.photos(wins, crew: crew, me: store.me), startAt: shown.id,
                        onClose: { viewing = nil },
                        crew: crew.id,
                        onReport: { photo in
                            viewing = nil
                            // After the cover has gone: UIKit drops a dialog
                            // asked for while another view is dismissing.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                reporting = wins.first { $0.winID.uuidString == photo.id }
                            }
                        },
                        onWithdraw: { photo in
                            guard let id = UUID(uuidString: photo.id) else { return }
                            Task { await store.remove(winID: id, from: crew.id) }
                        },
                        canRemove: { photo in
                            UUID(uuidString: photo.id).map { store.canRemove($0, from: crew.id) } ?? false
                        },
                        onHide: { photo in
                            if let id = UUID(uuidString: photo.id) { store.hide(winID: id) }
                        },
                        reactions: { photo in
                            guard let id = UUID(uuidString: photo.id) else { return AnyView(EmptyView()) }
                            return AnyView(CrewReactionsPanel(winID: id, crewID: crew.id,
                                                              mine: photo.byline == nil, onDark: true))
                        })
        }
        .overlay(alignment: .bottom) { CrewReportAnchor(reporting: $reporting, crewID: crew.id) }
    }

    private struct Viewed: Identifiable { let id: String }

    // MARK: The bar

    /// **Back, then Play, the app's own glass** (the cohesion pass,
    /// 2026-10-05). Play was a bare `play.fill` in the system's toolbar
    /// capsule, beside a system back button: two materials and a filled glyph
    /// on a bar where every other page has hollow glyphs on
    /// `GlassIconButton`. It is `play`, hollow, now, with the toolbar's shared
    /// capsule hidden so it is not glass on glass.
    ///
    /// **No journal here** (the owner, 2026-10-06: "why is there journal
    /// button there that shouldnt be there at all only in memories"). Your
    /// note is yours, and a crew's day is the crew's; the journal of a past
    /// day lives on your own days in Memories.
    private struct CrewDayToolbar: ToolbarContent {
        let title: String
        let header: String
        let play: () -> Void

        @ToolbarContentBuilder
        var body: some ToolbarContent {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .principal) { TwoToneTitle(title: header) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { playButton }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) { TwoToneTitle(title: header) }
                ToolbarItem(placement: .topBarTrailing) { playButton }
            }
        }

        private var playButton: some View {
            GlassIconButton(systemName: "play", onPage: true, accessibilityLabel: "Play \(title)", action: play)
                .accessibilityHint("You can save it as a video.")
        }
    }

    // MARK: The tower

    /// **Today's tower, exactly, on another day** (the owner, 2026-10-05:
    /// "just have it be the tower with the lattice looking exactly the same
    /// as the tower"). The same lattice, the same light, the same bottom
    /// anchor and margins as `CrewTowerView.tower`; only the next slot is
    /// missing, because the day is over. Built once, without a drop: a
    /// model's first build never falls. A tap on a block opens the day's
    /// carousel, photographs and all.
    private func tower(colW: CGFloat, viewport: CGFloat) -> some View {
        let tower = model.tower
        let rows = tower.totalRows
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let gridH = rows > 0 ? CGFloat(rows) * colW + CGFloat(rows - 1) * spacing : 0
        return ScrollView(.vertical, showsIndicators: false) {
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
                        onTapExpandBlock: { viewing = $0.uuidString },
                        liftedBlockID: nil)
                }
            }
            .environment(\.blockLight, BlockLight.over(rows: max(rows, 1)))
            .background(alignment: .bottom) {
                TowerLattice(cellSize: colW, contentHeight: max(gridH, 1), ripple: nil)
                    .frame(width: gridW)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, GridConstants.gapWide)
            .frame(minHeight: viewport, alignment: .bottom)
        }
        .defaultScrollAnchor(.bottom)
        .softScrollEdge(.top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title)'s crew tower, \(tower.placedBlocks.count) wins")
    }
}

/// A crew's wins as the photo viewer's carousel: photographs, and the rest
/// as their blocks, each with who sent it.
enum CrewGallery {
    @MainActor
    static func photos(_ wins: [SharedWin], crew: Crew?, me: UUID) -> [GalleryPhoto] {
        // The same line the block says, "Sam with Ana" on a shared win.
        let names = Dictionary(uniqueKeysWithValues: (crew?.members ?? []).map { ($0.profileID, $0.shortName) })
        return wins.sorted { $0.createdAt < $1.createdAt }.map { win in
            return GalleryPhoto(fileName: win.winID.uuidString,
                                title: win.title.isEmpty ? nil : win.title,
                                date: win.createdAt, dateString: win.crewDay, size: win.blockSize,
                                file: win.photo,
                                // Nil is how the viewer knows it is yours.
                                byline: win.senderProfileID == me ? nil : CrewTowerModel.senderLine(win, me: me, names: names),
                                block: win.photo == nil ? win.colour : nil)
        }
    }
}

/// Report, from a crew viewer's ⋯, and the thanks after it, offering a block
/// right there (the 2026-10-03 audit: a report vanished without a word, and
/// blocking was a separate hunt). Hang it on a point at the foot of the
/// screen: iOS 26 draws a dialog from the view it hangs on, and from a
/// full-screen one it never appeared.
struct CrewReportAnchor: View {
    @Binding var reporting: SharedWin?
    let crewID: CrewID
    @State private var reported: SharedWin?

    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        Color.clear.frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .confirmationDialog("Report this win?",
                                isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                                titleVisibility: .visible, presenting: reporting) { win in
                ForEach(CrewSafety.Reason.allCases) { reason in
                    Button(reason.words) {
                        Task {
                            await CrewSafety.report(.win(win), in: crewID, reason: reason)
                            reported = win
                        }
                    }
                }
            } message: { _ in
                Text("Your report goes to Some Wins. Nobody in the crew is told.")
            }
            .alert("Thanks for telling us",
                   isPresented: Binding(get: { reported != nil }, set: { if !$0 { reported = nil } }),
                   presenting: reported) { win in
                if win.senderProfileID != store.me, !store.blocked.contains(win.senderProfileID) {
                    let name = store.crew(crewID)?.member(win.senderProfileID)?.shortName ?? ""
                    Button("Block \(name.isEmpty ? "Them" : name)", role: .destructive) {
                        Task { await CrewSafety.block(win.senderProfileID, from: crewID) }
                    }
                }
                Button("Done", role: .cancel) {}
            } message: { _ in
                Text("Every report is looked at within a day. Blocking hides them from you everywhere, and they are not told.")
            }
    }
}
