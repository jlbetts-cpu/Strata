import SwiftUI
import SwiftData

/// One day, opened: the tower you built that day, and the photographs on it.
struct DayAlbumDetailView: View {
    let route: DayRoute

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// A SECOND tower view model, private to this screen.
    ///
    /// `buildTower` is not a pure function — it writes `placedBlocks`,
    /// `mergeGroups`, `newlyDroppedIDs`, `previousBlockIDs` and the stagger
    /// cache straight onto the instance, and schedules a cleanup task. Calling
    /// it on the live `towerVM` for a past day would leave the Wins tab
    /// showing yesterday. A fresh instance is safe: it is a plain `@Observable`
    /// class that takes logs and gives back geometry.
    ///
    /// Packing alone would not do here. `GridPacker.firstFit` (which is what
    /// `MiniTowerPacker` became) gives back a cell and nothing else, so the
    /// block faces (photograph, title) have no `HabitLog` to draw from. It
    /// stays the right tool for the covers, where a coloured cell is all there
    /// is to draw.
    @State private var vm = TowerViewModel()
    @State private var logs: [HabitLog] = []
    @State private var viewing: String?
    /// A win with no photograph, opened to be named, recoloured or deleted.
    @State private var editingLog: HabitLog?

    /// The last gap under the tower, on top of what the scroll view already
    /// reserves for the floating tab bar.
    ///
    /// **Measured against the Wins tab rather than reasoned about.** It was
    /// 110, on the assumption that the tab bar's room had to be added by hand;
    /// the scroll view was already reserving it, so the day's tower floated
    /// 194pt above the bottom against the real tower's 91pt — which is exactly
    /// the "it does not start at the bottom" the owner reported. At 0 the gap
    /// came out 83pt. 8 is the remainder, and the two towers now stand on the
    /// same line.
    ///
    /// **Renamed off `tabBarClearance`.** There is a shared
    /// `GridConstants.tabBarClearance` and it is 110, so a reader meeting
    /// `Self.tabBarClearance = 8` next to it had two different answers to the
    /// same-sounding question on one screen, which is the confusion that put
    /// the 110 here in the first place. This is not the tab bar's room. It is
    /// the last 8pt of ground under the tower, after the room the scroll view
    /// has already reserved.
    private static let groundGap: CGFloat = 8

    private var photos: [String] {
        logs.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap(\.imageFileName)
    }

    /// The same photographs, with what each one was of, for the viewer.
    ///
    /// Through `Album.gallery` rather than assembled here, so this screen's
    /// idea of which wins count as unnamed is the gallery's idea rather than a
    /// second copy of the rule.
    private var galleryPhotos: [GalleryPhoto] {
        Album.gallery(from: Album.records(from: logs))
    }

    var body: some View {
        // The day's tower STANDS, like the one on the Wins tab.
        //
        // It used to hang from the top of the screen with the whole rest of
        // the page empty below it — the same object anchored two different
        // ways on two screens, which is the sort of thing that reads as
        // "unfinished" without anyone being able to say why. A tower grows up
        // from the ground; the room above it is the room it has left to grow
        // into, and that is true of a past day as much as of today.
        //
        // `minHeight` rather than a fixed frame, so a busy day whose tower is
        // taller than the screen still scrolls normally.
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // The tower is bottom-anchored because a tower stands.
                    // A sentence is not a tower: pushed to the bottom it
                    // hugs the tab bar and reads as a caption for nothing, so
                    // the empty state sits under the header where you are
                    // already looking.
                    if logs.isEmpty {
                        // A day you did not log anything on.
                        //
                        // Unreachable from inside the app — you arrive at a
                        // day from an album or a month block, and both need at
                        // least one win — but `-strataOpenDay` gets here, and
                        // a screen that renders a title over nothing is a
                        // screen somebody will eventually see.
                        // **`headerMedium` in `inkPrimary`, which is what every
                        // other empty state in the app says.** It was
                        // `screenSubtitle` (15) in `inkTertiary`; the whole
                        // argument, including why the Plan sheet stays different
                        // and the level counts both ways, is on
                        // `PhotoCollectionView.emptyLine`, which is the other
                        // page off this shelf and had the identical line.
                        // **In the middle of the page** (the owner,
                        // 2026-10-15: "it should be centered"). The title is
                        // in the bar now, so nothing under it to hang from.
                        Spacer(minLength: GridConstants.gapWide)
                        EmptyPageLine("Nothing logged this day.")
                        Spacer(minLength: GridConstants.gapWide)
                    } else {
                        Spacer(minLength: GridConstants.gapWide)
                        tower(width: geo.size.width)
                            .frame(maxWidth: .infinity)
                    }
                    // The last gap, as CONTENT rather than as padding. Padding
                    // sits inside the min-height frame, so the spacer stopped
                    // short of it and the tower floated in the middle instead
                    // of standing at the bottom. See `groundGap`.
                    Color.clear.frame(height: Self.groundGap)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .background { WarmBackground().ignoresSafeArea() }
        // **The day in the middle of the bar**, in two tones, as a crew's
        // past day and every sheet name themselves (the owner, 2026-10-15:
        // "the dates in the previous day would like it to be cleaner maybe in
        // the middle on the header to stay consistent"). It was a large title
        // on the left with a count under it; the tower counts itself.
        .sheetTitle(DayTitle.twoTone(forKey: route.dateString), drawn: false)
        // **The bar gets a ground**, the same line and for the same reason as
        // `PhotoCollectionView`, which is the other page off the same shelf.
        //
        // A day with a few wins never reaches the top of the scroll, so this
        // looks like it is for nothing. A day with twenty-six does: the tower
        // is taller than the screen, it scrolls, and the top of it passes under
        // the back chevron. A dark chevron on a red block is the same failure
        // as a white glyph on a white sky, and the fix is the same kind of
        // thing: a material under the chrome rather than a darker chevron. The
        // navigation bar is the one place in this app allowed one, because it
        // is the system's own and not a card of ours pretending to be a block.
        //
        // The two pages disagreed about this until now, which is the drift the
        // audit is for: one of them had a ground and the other did not.
        .toolbarBackground(.visible, for: .navigationBar)
        // **That day's note, in the corner** (spec section 2: "A past day
        // (Memories, then a day): the top-right corner opens that day's
        // note, with the same icon rule"). The same button as beside the
        // Plan on Wins, with the same glyph (`JournalIcon`).
        .toolbar { JournalToolbarItem(dateString: route.dateString) }
        // Back in the same glass as the journal beside it, one style per
        // bar (the cohesion pass, 2026-10-05). See `GlassBackButton`.
        .glassBackButton()
        .task { reload() }
        .onChange(of: SocialStore.reactionsForMyTower) { reload() }
        .fullScreenCover(item: Binding(
            get: { viewing.map(PhotoID.init) },
            set: { viewing = $0?.id }
        )) { photo in
            PhotoViewer(photos: galleryPhotos,
                        startAt: photo.id,
                        onClose: { viewing = nil },
                        onDelete: { _ in reload() },
                        onWinChanged: { reload() })
        }
        // The same sheet the tower's long press opens, in edit mode, and the
        // same one the viewer's Edit opens for a photographed win.
        .sheet(item: $editingLog) { log in
            AddWinSheet(modelContext: modelContext,
                        tower: log.habit?.tower,
                        editing: log.habit,
                        editingLog: log,
                        onSaved: { _ in reload() },
                        onDeleted: { reload() })
        }
    }

    private struct PhotoID: Identifiable { let id: String }

    private func reload() {
        let key = route.dateString
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == key })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        logs = (try? modelContext.fetch(d)) ?? []
        // Friends' reactions to these wins, as the Wins tower shows them
        // (`MyWinReactions`, 2026-10-14).
        _ = vm.buildTower(from: logs, filterMode: .day, reactions: SocialStore.reactionsForMyTower)
    }

    private var title: String { DayTitle.title(forKey: route.dateString) }

    // MARK: - The day's tower

    /// Rendered outside the tower tab, so the two environment values the block
    /// views read have to be supplied by hand — there is nothing to inherit
    /// them from here. `TowerShare` learned this the same way.
    ///
    /// **The width is handed in from the page's own `GeometryReader`**, which
    /// this screen already has and was not using for it. It was
    /// `UIScreen.main.bounds.width - 16 * 2`: on this phone the two agree to
    /// the point, so nothing was visibly wrong, but one of them is the device
    /// and the other is the column the tower is actually standing in. They
    /// stop agreeing in landscape, on an iPad, and in a Slide Over, and the
    /// failure when they do is a tower drawn to a width its page does not
    /// have. The reader was two lines up the file the whole time.
    /// The tower's own geometry, worked out the way `StaticTowerView` works it
    /// out, because the lattice behind it has to land on the same grid.
    ///
    /// **A lattice a few points out of step with the blocks is worse than no
    /// lattice**, which is the warning `TowerLatticeShape.cellRects` already
    /// carries, so these are not approximations of that view's arithmetic —
    /// they are the same three lines. `StaticTowerView`'s own frame is
    /// `width x towerHeight` with the grid centred in it, so a background
    /// aligned to `.bottom` at `gridWidth` sits exactly on the blocks.
    private func towerCell(width containerWidth: CGFloat) -> CGFloat {
        let columns = CGFloat(GridConstants.columnCount)
        let content = containerWidth - GridConstants.horizontalPadding * 2
        return min((content - (columns - 1) * GridConstants.spacing) / columns, 200)
    }

    /// Rows of lattice above a past day's tower. See the `.background` below.
    static let pastDayOverhang = 1

    private var towerRows: Int {
        vm.placedBlocks.reduce(0) { max($0, $1.row + $1.rowSpan) }
    }

    private func tower(width containerWidth: CGFloat) -> some View {
        // Full size, the same cell the Wins tab draws at.
        //
        // It was capped at 74 so a three-block day would not become a
        // billboard — but the effect on a normal day was a miniature of the
        // tower rather than the tower, which is the one thing this screen is
        // for. It fills the width now, exactly as the live tower does.
        StaticTowerView(
            blocks: vm.placedBlocks,
            mergeGroups: vm.mergeGroups,
            groupedIDs: vm.groupedBlockIDs,
            coveredIDs: vm.coveredBlockIDs,
            modelContext: modelContext,
            width: containerWidth - GridConstants.horizontalPadding * 2,
            maxCell: 200,
            // **Every win on the page opens** (the QoL review, 2026-10-06).
            // Only a photographed block took a tap, so a win logged without a
            // picture could be looked at here and nothing else: no rename, no
            // colour, no delete, short of finding it again on the tower that
            // day. A photograph opens the viewer, as before; anything else
            // opens the add sheet in edit mode, as the tower's long press
            // does, and the page reloads when it closes on a change.
            canTapBlock: { $0.look.imageFileName != nil || $0.log?.habit != nil },
            onTapBlock: { block in
                // The photo is ON the block. A separate grid underneath was a
                // second copy of the same pictures, and it pushed the tower —
                // the thing you came here to look at — up the screen to make
                // room for it.
                // **No haptic here.** `FlippableBlockView` fires
                // `HapticsEngine.lightTap()` itself, in the same tap handler,
                // immediately before it calls this one, so one tap on a
                // block with a photograph on it produced two taps of
                // feedback, back to back, which reads as a stutter rather
                // than as a press. The block owns the press; this owns what
                // the press is for.
                guard let name = block.look.imageFileName else {
                    editingLog = block.log
                    return
                }
                viewing = name
            }
        )
        // **THE SURFACE THE TOWER IS BUILT ON, AND THIS WAS THE ONLY TOWER IN
        // THE APP STANDING ON NOTHING.** (2026-10-01, check 11c)
        //
        // Measured: a day with two wins draws a title, a count line, and then
        // **520pt of nothing** before two blocks at the bottom of the screen —
        // 71.4% of the page empty with 93% of that emptiness in one run, and the
        // tower and the tab bar so close that `tools/page-room.py` reports them
        // as ONE band. That is clause 11c's exact failure: the biggest break on
        // the page is the one under the last thing on it.
        //
        // **The number is not the evidence here; the screenshot is.** The Wins
        // tab photographed with the same two wins has the same shape — a header,
        // a 577pt break and a short tower on the floor — and it reads as a tower
        // with room to grow, because `TowerLattice` fills that break with the
        // grid the blocks land in. `page-room.py` cannot see the difference
        // (`docs/space.md` §0 records that the lattice measures 1.03:1 against
        // its page and the instrument calls all of it ground), so the two pages
        // measure the same and only one of them looks finished.
        //
        // CLAUDE.md settles which way the fix goes: "Every other screen is meant
        // to end up looking like it, so when the two disagree, the tower is
        // right." Same component, same cell, same 4pt gutter, bottom aligned on
        // the same row — not a decoration added to this page, the surface this
        // page's tower was already supposed to be standing on. The owner has
        // asked for it twice on other screens ("add some lattice at the end of
        // the calendar in the empty spots").
        //
        // **Not drawn on an empty day**, which has no tower: a grid of empty
        // cells under a sentence saying nothing was logged would be an empty
        // state drawing the shape of a thing, which is what `MemoriesView`'s
        // ghost blocks were deleted for.
        .background(alignment: .bottom) {
            let cell = towerCell(width: containerWidth)
            TowerLattice(cellSize: cell,
                         contentHeight: max(GridConstants.gridHeight(rows: towerRows,
                                                                    cellSize: cell), 1),
                         rowsOver: Self.pastDayOverhang)
                .frame(width: GridConstants.gridWidth(cellSize: cell))
        }
        // **One row over a past day, not three** (the owner's call, 2026-10-02).
        // On the Wins tab the rows above the tower are where the next win
        // lands. On a past day nothing lands, so four rows of empty panes over
        // two blocks were room doing no work; one row says the tower stands on
        // a surface and stops.
        .environment(\.towerFilterMode, .day)
    }

}
