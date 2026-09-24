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
    private static let tabBarClearance: CGFloat = 8

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
                    header
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
                        Text("Nothing logged this day.")
                            .font(Typography.bodySmall)
                            .foregroundStyle(AppColors.inkQuiet)
                            .padding(.horizontal, GridConstants.horizontalPadding)
                            .padding(.top, 28)
                        Spacer(minLength: 24)
                    } else {
                        Spacer(minLength: 24)
                        tower
                            .frame(maxWidth: .infinity)
                    }
                    // The tab bar's room, as CONTENT rather than as padding.
                    // Padding sits inside the min-height frame, so the spacer
                    // stopped 110pt short and the tower floated in the middle
                    // instead of standing at the bottom.
                    Color.clear.frame(height: Self.tabBarClearance)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .fullScreenCover(item: Binding(
            get: { viewing.map(PhotoID.init) },
            set: { viewing = $0?.id }
        )) { photo in
            PhotoViewer(photos: galleryPhotos,
                        startAt: photo.id,
                        onClose: { viewing = nil },
                        onDelete: { _ in reload() })
        }
    }

    private struct PhotoID: Identifiable { let id: String }

    private func reload() {
        let key = route.dateString
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == key })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        logs = (try? modelContext.fetch(d)) ?? []
        _ = vm.buildTower(from: logs, filterMode: .day)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The shared screen title, on one line: "Saturday 5 September"
            // wrapping to two puts the win count halfway down the screen and
            // pushes the tower with it. In the owner's face when the whole
            // date fits in it, SF otherwise (`DynamicScreenTitle`).
            DynamicScreenTitle(text: title)
                .foregroundStyle(AppColors.inkPrimary)
            // **The count is a readout.** The design language's §2: counts
            // and indices are the owner's face, tabular, never abbreviated
            // when they fit. The whole line was SF, which made the one number
            // on this screen the only count in the app that was not his
            // digits, sitting directly above a tower whose day numerals are.
            //
            // `StrataFont.digits`, never `Text("\(n)")`: interpolation is a
            // `LocalizedStringKey` and groups 1000 as "1,000", and the face
            // has no comma.
            //
            // The word stays SF at the subtitle size, which is the split the
            // tower's header already makes: the count is the fact and the
            // word is a caption for it. No optical inset here, unlike the
            // tally, because at 15pt the face's mean left bearing works out
            // near 1pt, under the size worth correcting.
            HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
                Text(verbatim: StrataFont.digits(logs.count))
                    .font(StrataFont.relative(Self.countSize, to: .subheadline))
                    .contentTransition(.numericText())
                Text(logs.count == 1 ? "win" : "wins")
                    .font(Typography.screenSubtitle)
            }
            .foregroundStyle(AppColors.inkQuiet)
            .accessibilityElement(children: .combine)
            // **Nothing to count, so nothing counted.** On a day with no wins
            // the readout said "0 wins" and the body under it said "Nothing
            // logged this day": the same fact twice, one of them as a zero,
            // which is how a correct screen reads as a broken one. The design
            // language's §7 wants "how much is here" answered once, and on an
            // empty day the sentence is the better of the two answers.
            //
            // Opacity rather than an `if`, so the box is still reserved and
            // the title does not sit at a different height on an empty day.
            // `PhotoCollectionView`'s header does the same.
            .opacity(logs.isEmpty ? 0 : 1)
            .accessibilityHidden(logs.isEmpty)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
    }

    /// The subheadline's own default size, so the digits and the word beside
    /// them are one line of type rather than two sizes agreeing by accident.
    /// Both scale together from `.subheadline`.
    private static let countSize: CGFloat = 15

    private var title: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: route.dateString) else { return route.dateString }
        let out = DateFormatter()
        out.dateFormat = "EEEE d MMMM"
        return out.string(from: date)
    }

    // MARK: - The day's tower

    /// Rendered outside the tower tab, so the two environment values the block
    /// views read have to be supplied by hand — there is nothing to inherit
    /// them from here. `TowerShare` learned this the same way.
    private var tower: some View {
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
            width: UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2,
            maxCell: 200,
            onTapBlock: { block in
                // The photo is ON the block. A separate grid underneath was a
                // second copy of the same pictures, and it pushed the tower —
                // the thing you came here to look at — up the screen to make
                // room for it.
                guard let name = block.log.imageFileName else { return }
                HapticsEngine.lightTap()
                viewing = name
            }
        )
        .environment(\.towerFilterMode, .day)
        .environment(\.perfectDayDates, [])
    }

}
