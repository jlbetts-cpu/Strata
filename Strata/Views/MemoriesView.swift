import SwiftUI
import SwiftData

/// Memories: the photographs first, then the month you are in.
///
/// This replaces History, which replaced Insights. Insights drew a chart of
/// past towers and made none of it reachable. History made it reachable but
/// still opened on a chart, so it read as a report — and a day with no
/// photograph still produced a card showing a little tower, which is a card
/// about nothing.
///
/// So: a shelf of albums, curated by what you keep doing and otherwise by day,
/// photographs only. Under it the month as a tower that grows through itself,
/// each day a block sized by how much you did. Built to the lowfi at
/// `KZsjpiFjwv3pgAwRCht4gU`, node `611:109`.
///
/// Where the lowfi and the codebase disagree, the codebase wins — CLAUDE.md
/// makes the tower the arbiter. Its Bold 48 and Semibold 20 become medium,
/// because this app has two weights, and its SF Pro becomes Rounded.
///
/// **The order is not the lowfi's, and that is deliberate.** It opened on a
/// search field, then a shelf of photo cards, with the month tower — the one
/// element unmistakably from this app — starting about 60% down and cut off by
/// the tab bar. The design audit rated the page 5/10 for exactly that. The
/// month leads now, and the search field is gone: `AllAlbumsView` has one over
/// the whole record, which is the only place searching is worth doing. A shelf
/// of two dozen cards is scrolled, not queried.
struct MemoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    /// Whether a cover above this page has put its heads to sleep.
    @Environment(\.headsAwake) private var coveringHeadsAwake
    @State private var vm = MemoriesViewModel()
    @State private var path: [MemoriesRoute] = []
    @State private var viewing: ViewedPhoto?
    /// The Replays shelf, and the replay playing out of one of its cards.
    @State private var replays = ReplayShelfModel()
    @State private var playing: Replay?
    /// Ties each thumbnail to the viewer that opens out of it.
    @Namespace private var photoTransition
    // **The drawer's state is gone**, with the drawer (2026-09-30). It held
    // how far the page was pulled up over the map, whether the page had been
    // BUILT yet — it was built lazily, off screen, once the map's camera had
    // been still for 1.5s, because building it during the raise held the first
    // one for 1.8s — and a flag for a raise that arrived before the page
    // existed. The page is the screen now, so it is built when the screen is,
    // and none of that has anything to hold.
    #if DEBUG
    @State private var debugFlingCounted = false
    #endif

    /// Which ground the map draws on.
    ///
    /// **The dark map IS dark mode.** MapKit cannot be recoloured, but it has
    /// two palettes, and the night one is not a separate feature to choose —
    /// it is what this screen must be when the phone is dark. A pale map
    /// filling the screen inside a dark app is not a design that "works in
    /// both", it is a light screen that got missed. Measured, the two grounds
    /// are mean luminance 212 and 63, which is the whole distance between an
    /// app that flips and one that does not.
    ///
    /// `-strataMapStyle` still overrides, because both have to be
    /// photographable on demand.
    private var mapStyle: MemoriesMapView.Style {
        #if DEBUG
        if DebugHarness.hasMapStyleOverride { return DebugHarness.mapStyle }
        #endif
        return colorScheme == .dark ? .night : .quiet
    }

    var openProfile: (() -> Void)?

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("MemoriesView")
        #endif
        NavigationStack(path: $path) {
            // **THE PAGE IS THE SCREEN AND THE MAP IS A BUTTON.**
            //
            // The owner, 2026-09-30: "for the Memories tab I would like it to be
            // designed normally, and then the map would be a button on the top
            // instead of the Memories sheet being a button — I think that makes
            // more sense tbh."
            //
            // It does, and it undoes an inversion that cost this file a lot. The
            // map was the ground, the page was a drawer over it, and the page
            // had to be a BUTTON on the map to get back to. Everything that was
            // awkward here followed from that: a page that had to be built
            // lazily and raised, a "Done" that dismissed a screen rather than a
            // sheet, a title drawn in white over imagery and ink over the pale
            // map, and a legibility wash to hold it up.
            //
            // All of it goes. The page stands on the app's own ground like every
            // other screen, and the map is a route off it — which it already was
            // in `MemoriesRoute`, pushed full screen, for a reason that comment
            // still records.
            //
            // The honest trade: the map no longer gets the whole screen the
            // moment you arrive, and that WAS the owner's earlier call ("the map
            // is the feature"). This is him changing it, not me forgetting it.
            VStack(spacing: 0) {
            pageHeader
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // **`pinnedViews` here, and the Section at the TOP level.**
                //
                // A `Section` nested inside a conditional is never pinned —
                // that is written down in CLAUDE.md and it is why the month
                // heading has never stuck. So the conditional moves INSIDE the
                // section instead of wrapping it.
                LazyVStack(alignment: .leading, spacing: 0,
                           pinnedViews: [.sectionHeaders]) {
                    // **The month picker belongs to the month, not to the
                    // page.**
                    //
                    // The owner, after asking four times: "the header is
                    // memories and done, not september — thats not part of the
                    // header for memories", and "this should not scroll".
                    // Both are satisfied by the same move, and neither was
                    // satisfied by where I had put it: as a section header it
                    // is attached to the tower it controls, and it PINS, so it
                    // stays put for exactly as long as the thing it governs is
                    // on screen and then leaves with it.
                    Section {
                        if pageIsEmpty {
                            emptyState
                        } else if pageIsUndecided {
                            // Neither the empty state nor an empty month for
                            // the moment the shelf takes to answer.
                            EmptyView()
                        } else {
                            // The month leads. It used to open on a search
                            // field, then a shelf of photo cards, with the
                            // month tower — the one element on this page that
                            // is unmistakably this app — starting around 60%
                            // down and cut off by the tab bar.
                            monthTower
                        }
                    }

                    if !pageIsEmpty {
                        // Between the month and the albums: finished months
                        // and weeks as posters. Draws nothing, heading
                        // included, until one has a win.
                        ReplayShelf(model: replays, now: replays.now, transitionNamespace: photoTransition) { playing = $0 }

                        // No heading over a gap. When nothing has earned a
                        // card the shelf is not drawn at all — only what there
                        // is to show gets shown.
                        if !vm.carousel.isEmpty {
                            // **What this is, and how much is here.** The
                            // design language's §7 asks every section for
                            // both; the heading answered the first and left
                            // the second to be found by scrolling the shelf
                            // to its end.
                            // **No count on this one, and that is a
                            // subtraction rather than an omission.**
                            //
                            // Three of us applied the design doc's "how much
                            // is here" to our own section on the same day,
                            // and the page ended up saying how much is here
                            // six times on one scroll, four of them with the
                            // word PHOTOS. The doc asks a SCREEN to answer
                            // it, not every band of a screen. The page header
                            // answers it, and a shelf of seven cards is
                            // countable by looking.
                            SectionHeading(text: "Albums")
                                .id("MemoriesShelf")
                            shelf
                        }

                        // Edge to edge. Every other thing on this page is
                        // inset to the page margin; the camera roll is the one
                        // that is not, because a photo grid with a margin is a
                        // set of cards.
                        PhotoGalleryGrid(sections: vm.gallery,
                                         transitionNamespace: photoTransition) { photo in
                            viewing = ViewedPhoto(id: photo.fileName, title: photo.title)
                        }
                    }
                }
                .padding(.bottom, GridConstants.tabBarClearance)
                .id("MemoriesContent")
            }
            #if DEBUG
            // `-strataPerfProbe`: the first finger on the page opens a 10s
            // window, so a UI test's flings are counted from their start.
            .onScrollPhaseChange { _, phase in
                // One window per burst of flings, not one per launch: a
                // second pass back over the same cells is the warm re-entry
                // figure, and it needs its own line.
                guard PerfProbe.isOn, phase == .interacting, !debugFlingCounted else { return }
                debugFlingCounted = true
                PerfProbe.window("Gallery fling", seconds: 10)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(10.5))
                    debugFlingCounted = false
                }
            }
            .task {
                guard DebugHarness.scrollsMemories else { return }
                try? await Task.sleep(for: .seconds(3))
                withAnimation(nil) {
                    let target = switch DebugHarness.scrollTarget {
                    case "shelf": "MemoriesShelf"
                    case "replays": "MemoriesReplays"
                    default: "MemoriesContent"
                    }
                    proxy.scrollTo(target, anchor: .top)
                }
            }
                #endif
                }
            // **THE SCROLL EDGE IS GONE, AND IT WAS THE SEAM.**
            //
            // The owner: "the header isn't even the same page."
            //
            // He is describing a measurement. This faded from
            // `WarmBackground.top` at 85%, and `top` is the ground BEFORE
            // `GroundField` and its `seat` darken it — so over the real page
            // it painted a stripe four levels BRIGHTER than everything around
            // it. Sampled down the right margin: 247 through the header, 252
            // across this band, 247 again below. A line you cannot quite see
            // and cannot stop seeing, exactly under the title.
            //
            // It was there to soften the cut when content scrolled under a
            // floating header. The header does not float any more — the page is
            // the screen and the header sits above the scroll in its own band —
            // so there is no cut to soften and nothing left for this to do but
            // draw the line it was accused of.
            }
            // Covered by a photograph, a replay or a pushed page: nobody can
            // see the month, so its slideshows hold still. It used to also ask
            // whether the drawer was down; there is no drawer.
            .environment(\.memoriesDrawerVisible,
                         viewing == nil && playing == nil && path.isEmpty)
            .background { WarmBackground().ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            // The header's head and the map's sleep under a photograph or a
            // replay, and under whatever already covers this page. Before the
            // covers, so nothing inside them is put to sleep.
            .environment(\.headsAwake, coveringHeadsAwake && viewing == nil && playing == nil)
            .fullScreenCover(item: $viewing) { photo in
                // The whole roll, so the next photograph is a swipe away.
                PhotoViewer(photos: vm.gallery.flatMap(\.photos),
                            startAt: photo.id,
                            onClose: { viewing = nil },
                            onDelete: { _ in
                                Task { await vm.reload(context: modelContext) }
                                // A card is mostly photographs.
                                Task { await reloadReplays(redrawsStale: true) }
                            })
                    // Out of the thumbnail, not up from the bottom.
                    .navigationTransition(.zoom(sourceID: photo.id, in: photoTransition))
            }
            .fullScreenCover(item: $playing) { replay in
                // A photograph deleted from a block inside the replay is gone
                // from this page too: the gallery, the albums, and the card.
                ReplayView(replay: replay, onPhotoDeleted: {
                    Task { await vm.reload(context: modelContext) }
                    Task { await reloadReplays(redrawsStale: true) }
                }) { playing = nil }
                    // Out of its card, the way a photograph opens.
                    .navigationTransition(.zoom(sourceID: replay.id, in: photoTransition))
            }
            .navigationDestination(for: MemoriesRoute.self) { route in
                switch route {
                case .map:
                    MemoriesMapView(pins: vm.pins, hasLoaded: vm.hasLoaded, style: mapStyle) { key in
                        path.append(.place(key))
                    }
                    .ignoresSafeArea()
                    .toolbar(.hidden, for: .navigationBar)
                    // **A WAY BACK.** The owner: "make sure there is a way to
                    // get back to the Memories from the map."
                    //
                    // The navigation bar is hidden here — a bar across the top
                    // of a map is a bar across the map — and the swipe from the
                    // edge is not a thing anybody should have to know about,
                    // least of all on a screen whose whole gesture vocabulary is
                    // pan and pinch, where a drag from the left edge is how you
                    // move the map west.
                    //
                    // Light in both appearances and NOT `onPage`: it is floating
                    // over imagery, which is the case `.regular` glass is for
                    // and the case `GlassRecipe.onPage` is explicitly not. See
                    // `GlassIconButton`.
                    .overlay(alignment: .topLeading) {
                        GlassIconButton(systemName: "chevron.left", tint: .white,
                                        accessibilityLabel: "Back to Memories") {
                            path.removeLast()
                        }
                        .environment(\.colorScheme, .dark)
                        .padding(.leading, GridConstants.horizontalPadding)
                        .padding(.top, GridConstants.headerArtworkTopPadding)
                    }
                case .day(let key):
                    DayAlbumDetailView(route: DayRoute(dateString: key))
                        // Out of the day's own block on the month tower, the
                        // same way a photograph comes out of its thumbnail.
                        // A month you can open is what makes the two pages
                        // one place rather than two lists of the same days.
                        .navigationTransition(.zoom(sourceID: key, in: photoTransition))
                case .place(let key):
                    PhotoCollectionView(source: .place(key))
                case .curated(let key):
                    PhotoCollectionView(source: .interest(key))
                case .moment(let id):
                    PhotoCollectionView(source: .moment(id))
                }
            }
        }
        // **The replay cards, drawn once the page has something to draw from.**
        //
        // Keyed by scheme and scale: posters are drawn in the page's scheme, so
        // a switch draws (once) the set for the other.
        //
        // **This used to be keyed on the drawer as well, and the drawer is
        // gone.** The shape of it was: draw what is MISSING only once the map
        // had stopped moving, because drawing straight away put 1.27s of
        // `ImageRenderer` on the main actor under the map's first frames, and
        // drawing on the raise instead put the same 1.3s under a moving panel.
        //
        // Neither hazard exists now. The map is not the ground and is not on
        // screen when this runs; there is no panel to raise. So the two-pass
        // dance collapses into what it was always trying to be — draw the
        // missing ones, then come back for the stale ones — and the measured
        // reason it was ever more complicated than that is kept above, because
        // the cost of `ImageRenderer` on the main actor has not changed and
        // whoever puts a map back on this screen will meet it again.
        .task(id: "\(colorScheme)-\(displayScale)") {
            await reloadReplays(redrawsStale: false, drawsMissing: false)
            while !Task.isCancelled, !vm.hasLoaded {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !Task.isCancelled else { return }
            await reloadReplays(redrawsStale: false, drawsMissing: true)
            try? await Task.sleep(for: Self.springSettle)
            guard !Task.isCancelled else { return }
            await reloadReplays(redrawsStale: true)
        }
        .task {
            #if DEBUG
            let reloadStart = CACurrentMediaTime()
            #endif
            await vm.reload(context: modelContext)
            #if DEBUG
            PerfProbe.duration("MemoriesViewModel.reload wall", since: reloadStart)
            #endif
            #if DEBUG
            // `-strataOpenDrawer` and `-strataRaiseDrawerAfter` went with the
            // drawer. The page they used to raise is the screen now, so the
            // flags had nothing left to do.
            if let back = DebugHarness.openDayBack,
               let date = Calendar.current.date(byAdding: .day, value: -back, to: Date()) {
                path.append(.day(DateUtils.dateString(from: date)))
            }
            if let months = DebugHarness.openMonthBack {
                vm.step(months: -months, context: modelContext)
            }
            if let index = DebugHarness.openCuratedIndex {
                let curated = vm.carousel.compactMap { album -> String? in
                    if case .curated(let key) = album.kind { return key }
                    return nil
                }
                if index < curated.count { path.append(.curated(curated[index])) }
            }
            if DebugHarness.opensMap { path.append(.map) }
            if let index = DebugHarness.openPhotoIndex {
                let photos = vm.gallery.flatMap(\.photos)
                if index < photos.count {
                    viewing = ViewedPhoto(id: photos[index].fileName,
                                          title: photos[index].title)
                }
            }
            if let index = DebugHarness.openMomentIndex {
                let moments = vm.carousel.compactMap { album -> String? in
                    if case .moment(let id) = album.kind { return id }
                    return nil
                }
                if index < moments.count { path.append(.moment(moments[index])) }
            }
            #endif
        }
    }

    /// Nothing at all to show: no photographs, no wins this month, and no
    /// finished replay. A person with last month's replay and nothing yet in
    /// this one gets the month (empty) and the shelf, not "Your first month
    /// starts here", which would be untrue.
    ///
    /// Only once the shelf has loaded: before that its rows are empty because
    /// nobody has asked, and the empty state flashed for a person with a past
    /// replay and nothing else.
    private var pageIsEmpty: Bool {
        replays.hasLoaded
            && vm.carousel.isEmpty && vm.month.isEmpty && replays.months.isEmpty && replays.weeks.isEmpty
    }

    /// Everything but the shelf is empty and the shelf has not answered yet,
    /// so the page could still go either way.
    private var pageIsUndecided: Bool {
        !replays.hasLoaded && vm.carousel.isEmpty && vm.month.isEmpty
    }

    /// How long `naturalSettle` takes to come to rest, near enough.
    private static let springSettle: Duration = .milliseconds(700)

    // **`waitForQuietMap` and `buildDrawer` are gone with the drawer**, and the
    // measurement in them is worth keeping even though the code is not: long
    // main-actor work — `ImageRenderer` drawing a poster, the page's first
    // layout — must not land while the map is reading its own pictures. A
    // single check for quiet is not enough either; reading 320px derivatives
    // the store empties BETWEEN landings, and one such check still put a 390ms
    // frame among 86 of them. Whoever puts a map back on this screen needs both
    // halves of that again.
    private func reloadReplays(redrawsStale: Bool, drawsMissing: Bool = true) async {
        await replays.reload(context: modelContext, colorScheme: colorScheme, displayScale: displayScale,
                             now: Date(), redrawsStale: redrawsStale,
                             drawsMissing: drawsMissing)
    }

    // **`titleRow` is gone.** It was the title and two buttons floating ON the
    // map, in white over imagery and ink over the pale style, held up by a
    // legibility wash. The page has an ordinary header now — see `pageHeader` —
    // which needs none of that, because it stands on the app's own ground like
    // every other screen's.

    // MARK: - The shelf

    private var shelf: some View {
        AlbumCarousel(
            albums: vm.carousel,
            onSelect: { route in
                switch route {
                case .day(let key):     path.append(.day(key))
                case .curated(let key): path.append(.curated(key))
                case .moment(let id):   path.append(.moment(id))
                }
            }
        )
    }

    // MARK: - The month

    /// Every photograph the page holds, which is what the gallery below it is
    /// a grid of. Summed from the sections rather than kept as a second
    /// number: a count that can disagree with the thing it counts is worse
    /// than no count at all.
    private var photographCount: Int {
        vm.gallery.reduce(0) { $0 + $1.photos.count }
    }

    /// The page's own header: what this is, how much is in it, how to leave,
    /// and which month.
    ///
    /// The title used to live only on the map, so the page you pulled up over
    /// it was unnamed — the owner's call is that "that section also needs the
    /// memories title", and it is right: a screen that fills the display and
    /// says nothing about itself is a screen you have to remember your way
    /// out of. `Done` is the way out, stated rather than implied by a drag.
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // **The title says its name and nothing else.**
                //
                // It carried a photograph count for an afternoon and the
                // owner cut it: "the memories section didn't really change
                // outside of adding photos to the title, which looks bad and
                // isn't needed." He is right twice over. A number welded to a
                // drawn wordmark fights it, and the page already had five
                // other places telling you how much was in it.
                HStack(alignment: .lastTextBaseline, spacing: GridConstants.gapTight) {
                    MemoriesTitle(color: AppColors.inkPrimary)

                }
                Spacer(minLength: 0)
                // **THE MAP, AS A BUTTON.** The owner: "the map would be a
                // button on the top instead of the Memories sheet being a
                // button — I think that makes more sense."
                //
                // This slot held "Done", which dismissed the page back to the
                // map it was a drawer over. Now the page is the screen and the
                // map is the thing you go to, so the same corner does the
                // opposite job with one fewer concept: there is nothing to come
                // back FROM, so there is nothing to say Done to.
                //
                // **ALWAYS THERE**, and gating it was my own mistake twice over.
                //
                // The owner: "make sure you are adding the map button, I still
                // don't see it in the Memories." It was there — gated on
                // `vm.pins`, which is empty until a photograph has a PLACE, and
                // a place only arrives once location has been granted, and the
                // only screen that asks for location is the map. A closed loop,
                // and the comment I wrote beside the gate said so in the same
                // breath as adding it.
                //
                // The map opens on its own empty state, which is where the
                // asking belongs. That is the same reasoning the old
                // photographs button had written on it, which is how this was
                // avoidable.
                GlassIconButton(systemName: "map", onPage: true,
                                accessibilityLabel: "Map") {
                    path.append(.map)
                }
                .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
                ProfileButton { openProfile?() }
                // Centred on the title's cap by hand. A drawn title is only as
                // tall as its cap, so a baseline or centre rule against a 44pt
                // control puts the title 7.6pt below the line every other
                // header sits on — measured, and recorded in CLAUDE.md.
                .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapItem)
            // **THE MONTH IS IN THE HEADER NOW, AND IT DOES NOT MOVE.**
            //
            // The owner: "I don't like that the September dropdown moves — what
            // is the point of that? Keep it in one place."
            //
            // It was a pinned section header, which is a thing that travels up
            // the page and then sticks. That was right when it governed a tower
            // somewhere down a long scroll: pinning kept it with the thing it
            // controls for exactly as long as that thing is on screen. It is
            // wrong now, because the calendar is the FIRST thing on the page,
            // so the picker's whole journey is the few points between where it
            // starts and where it pins — motion with no destination, which
            // reads as the control being loose.
            //
            // In the fixed band it is simply where it is. The page scrolls
            // under it, which is what the band is for.
            monthHeader
                .padding(.bottom, GridConstants.gapTight)
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            MonthPicker(
                title: vm.monthTitle,
                months: vm.availableMonths,
                titleFor: { vm.title(for: $0) },
                onSelect: { month in
                    withAnimation(GridConstants.crossFade) {
                        vm.select(month: month, context: modelContext)
                    }
                }
            )
            // Aligned to the page margin, less the menu label's own 10pt
            // inset, so the WORD lines up with the title above it and with
            // every heading below it rather than the tap target's edge doing.
            .padding(.leading, GridConstants.horizontalPadding - 10)

            // **How much of the month is here.** The design language's §7,
            // and the count is DAYS rather than wins on purpose: the blocks
            // under this heading are days, one each, so the number can be
            // checked against the thing it labels by looking. That is what
            // §7 means by the structure being visible. The exact win count
            // belongs to the day's own screen, one tap away, which is the
            // line `MonthTower.size` already draws ("this ranks days; it does
            // not measure them").
            //
            // `.center`, and the picker is 44pt tall with its label centred
            // in that, so the two words sit on one line without either of
            // them depending on a baseline surviving a `frame`.
            // **And no count here either.** The blocks under this heading
            // ARE the days, which is the doc's own "structure visible, not
            // implied": the tower says how many there are by being that many.
            // A number on top of it is the page narrating itself.
        }
        .padding(.top, GridConstants.gapTight)
        .padding(.bottom, GridConstants.gapTight)
        // **Above the tower, or its chevrons do not take their own taps.**
        //
        // The month blocks are positioned with `.offset`, which moves what is
        // drawn and not what is laid out, so a block's hit area reaches up
        // over the picker. Measured off the accessibility tree: the topmost
        // block's frame was `{17, 120, 182, 242}` and the back chevron's
        // `{18, 136.7, 44, 44}` — entirely inside it. Pressing `‹` opened a
        // DAY instead of stepping the month.
        //
        // The picker now sits OUTSIDE the scroll view, which clips its own
        // content, so the tower can no longer reach it at all. This is kept
        // because it costs nothing and the hazard it guards against is a
        // silent one — the symptom is a different screen opening, not an
        // error. `testTheMonthPickerStepsAndStopsAtToday` is the proof.
        .zIndex(1)
    }

    /// The width the month is packed into, and the cell that falls out of it.
    ///
    /// Named because two things need the same answer now: the tower draws its
    /// blocks at this cell and the lattice behind it draws its slots at the
    /// same one. A lattice a few points out of step with the blocks is worse
    /// than no lattice, which is the warning `TowerLatticeShape.cellRects`
    /// already carries.
    private var monthGridWidth: CGFloat {
        UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2
    }

    private var monthCell: CGFloat {
        GridConstants.cellSize(forGridWidth: monthGridWidth)
    }

    @ViewBuilder
    private var monthTower: some View {
        if vm.month.isEmpty {
            // A quiet row of slots, not a sentence. Same reasoning as the
            // page's own empty state: show the shape of what is missing.
            VStack(spacing: GridConstants.gapItem) {
                ghostRow(cell: 46)
                Text("Nothing in \(vm.monthTitle.capitalized) yet.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
            // **A CALENDAR, NOT A PACKED TOWER.** See `MonthCalendarView` for
            // the whole argument; the short version is that first-fit packing
            // threw away the one thing a month has, which is that a day's
            // position means which day it is. The lattice this used to need as
            // a BACKGROUND is inside it now, one pane per cell, which is also
            // what makes an empty month read as a month.
            MonthCalendarView(
                packed: vm.month,
                month: vm.selectedMonth,
                calendar: MemoriesViewModel.mondayCalendar,
                width: monthGridWidth,
                onSelect: { path.append(.day($0)) },
                transitionNamespace: photoTransition
            )
            .frame(maxWidth: .infinity, alignment: .center)
            // **Air, and the owner asked for it by name**: "make the white
            // space a big part of the designs." The calendar used to start a
            // `gapTight` under the picker, which on a fixed band reads as the
            // control sitting ON the grid rather than above it. A full `gapWide`
            // separates the thing that chooses from the thing it chose.
            .padding(.top, GridConstants.gapWide)
            // The month is REPLACED, not moved, so it cross-fades. A spring
            // would claim the blocks travelled somewhere.
            .id(vm.monthTitle)
            .transition(.opacity)
        }
    }

    /// What this page looks like before there is anything on it.
    ///
    /// **Show the shape of the thing that is missing.** It was two lines of
    /// grey type in the middle of a blank page, which the owner called dull
    /// and which is — it tells you nothing is here and then gives your eye
    /// nothing to do. A page waiting for a month of wins can show the outline
    /// of one: the same empty slot the tower uses, in the arrangement the
    /// month tower packs into, so what you are looking at is a promise of the
    /// real thing rather than an apology for its absence.
    ///
    /// Ghosts, not blocks. A filled block here would be a win that does not
    /// exist, and this app does not draw those.
    /// One row of empty slots, at whatever size the caller needs.
    ///
    /// Shared by the page's empty state and the month's, so "nothing here
    /// yet" looks like one idea in two places rather than two designs.
    private func ghostRow(cell: CGFloat) -> some View {
        let gutter = GridConstants.spacing
        let radius = GridConstants.blockCornerRadius(forCell: cell)
        return HStack(spacing: gutter) {
            ForEach([2, 1, 1], id: \.self) { span in
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppColors.slotInk.opacity(0.16),
                                  style: StrokeStyle(lineWidth: 1.5,
                                                     dash: [GridConstants.ghostBlockDashLength]))
                    .background {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(AppColors.slotInk.opacity(0.035))
                    }
                    .frame(width: CGFloat(span) * cell + CGFloat(span - 1) * gutter,
                           height: cell)
            }
        }
    }

    private var emptyState: some View {
        let cell: CGFloat = 62
        let gutter = GridConstants.spacing
        let radius = GridConstants.blockCornerRadius(forCell: cell)
        // One of each size, packed the way the month tower would pack them.
        let ghosts: [(c: CGFloat, r: CGFloat, w: CGFloat, h: CGFloat)] = [
            (0, 0, 2, 1), (2, 0, 1, 1), (0, 1, 1, 1), (1, 1, 2, 2)
        ]

        return VStack(spacing: GridConstants.gapSection) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(ghosts.enumerated()), id: \.offset) { _, g in
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(AppColors.slotInk.opacity(0.16),
                                      style: StrokeStyle(lineWidth: 1.5,
                                                         dash: [GridConstants.ghostBlockDashLength]))
                        .background {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(AppColors.slotInk.opacity(0.035))
                        }
                        .frame(width: g.w * cell + (g.w - 1) * gutter,
                               height: g.h * cell + (g.h - 1) * gutter)
                        .offset(x: g.c * (cell + gutter), y: g.r * (cell + gutter))
                        // **No entrance.** They used to fade up in order,
                        // staggered off the index, "so the page arrives
                        // rather than appearing". The design language refuses
                        // that outright (§5, §8): "nothing animates because a
                        // screen appeared. Things animate because a person
                        // did something, and they animate where it happened."
                        // Nobody has done anything here yet, which is the
                        // whole subject of this screen, so there is nothing
                        // for it to be answering.
                        .opacity(0.9)
                }
            }
            // **`.topLeading`, or the ghosts sit 33pt right and down.** The
            // ghosts are placed with `.offset`, which moves the drawing and
            // not the layout, so the ZStack's own size is only its biggest
            // child (128pt). A centred frame centres that 128pt box, pushing
            // every ghost off centre and into the headline below.
            .frame(width: 3 * cell + 2 * gutter, height: 3 * cell + 2 * gutter,
                   alignment: .topLeading)

            VStack(spacing: GridConstants.gapTight) {
                Text("Your first month starts here")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("Every win you log becomes a block, and they collect here by month.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }
}

// MARK: - How much is here

/// A count, the way an instrument reads one out: the owner's digits, and the
/// unit beside them in the heading's own register.
///
/// **The digits are not the label's face and never should be.** The design
/// language's §2 splits the two jobs: the owner's face carries the app's
/// nouns and numbers, SF Rounded carries everything read as language, and
/// "counts and indices are Jaro, tabular, and never abbreviated when they
/// fit". A count set in the label's face is a word that happens to be made of
/// digits; set in his, it is a readout.
///
/// **Relative to `.footnote`, not `Typography.numeral`.** That token takes a
/// fixed point size, which is right for a month block's numeral (solved off
/// its cell) and wrong here: this sits beside `Typography.sectionLabel`,
/// which is a text STYLE, so at any Dynamic Type setting but the default the
/// two would drift apart. It belongs in `Typography` beside `sectionLabel`
/// the next time that file is free to edit.
///
/// **The case comes from the style, not the caller**, which is the rule
/// `SectionHeading` exists to enforce: pass "photos", not "PHOTOS".
struct CountReadout: View {
    let count: Int
    /// What is being counted, or nil where the heading beside it already
    /// says (a shelf headed ALBUMS does not need the word twice).
    var unit: String? = nil

    /// The section label's own size, so the digits and the word are one line
    /// of type rather than two sizes agreeing by accident.
    private static let digitFont = StrataFont.relative(13, to: .footnote)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            // `StrataFont.digits`, never `Text("\(count)")`: interpolation is
            // a `LocalizedStringKey` and groups 1000 as "1,000", and the face
            // has no comma. That is how the map badge came out as "1,0" over
            // "00".
            Text(verbatim: StrataFont.digits(count))
                .font(Self.digitFont)
                .foregroundStyle(AppColors.inkSecondary)
                // §2: "a count that ticks should tick, not cross-fade".
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .font(Typography.sectionLabel)
                    .kerning(Typography.sectionKerning)
                    .textCase(.uppercase)
                    // A shade under the digits. The number is the fact and
                    // the unit is a caption for it, which is the same order
                    // the tower's header puts its count and its word in.
                    .foregroundStyle(AppColors.inkTertiary)
            }
        }
        .lineLimit(1)
        // Inflexible on purpose: it is laid out beside things that expand,
        // and an `HStack` hands a fixed child its ideal width first and the
        // remainder to the flexible one. Without it the heading beside it
        // would take everything and squeeze the count to nothing.
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// A section heading with its count: what this is, and how much is here.
///
/// The design language's §7 asks both of every section. `SectionHeading` is
/// still the one owner of the heading's style, ink, case and spacing, for the
/// reason that file records at length ("a token is not a style"); this only
/// puts a readout on the other end of the same line.
///
/// **It belongs in `SectionHeading.swift`**, and is here because that file is
/// being edited elsewhere. Move it when the two can be in one place.
///
/// **Why the readout mirrors the heading's vertical padding.** The two have to
/// sit on one line, and `.firstTextBaseline` would be the natural way to say
/// so, except that the heading's own text is wrapped in three paddings and a
/// flexible `frame` before anything outside it can see a baseline. Giving the
/// readout the same box top and bottom makes the two children the same shape,
/// so plain `.center` puts the digits on the label's line with nothing
/// depending on a baseline surviving a modifier. If `SectionHeading`'s padding
/// moves, this has to move with it.
struct SectionHeadingCount: View {
    let text: String
    let count: Int
    var unit: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Carries the page margins on both sides, so its trailing 16 is
            // the gutter between the label and the readout.
            SectionHeading(text: text)
            CountReadout(count: count, unit: unit)
                .padding(.top, GridConstants.gapSection)
                .padding(.bottom, GridConstants.gapLabel)
                .padding(.trailing, GridConstants.horizontalPadding)
        }
    }
}

struct ViewedPhoto: Identifiable, Equatable {
    /// The image's file name, which is also its identity.
    let id: String
    /// What the win was called, or nil if it was never named.
    var title: String?
}

/// Where the Memories tab can go.
enum MemoriesRoute: Hashable {
    /// The map, full screen. **Not embedded in the page.**
    ///
    /// A MapKit `Map` placed inside this screen's `LazyVStack` stopped the
    /// whole body re-evaluating: the page kept rendering its EMPTY state while
    /// the view model held forty pins, and nothing errored, nothing crashed
    /// and no annotation was at fault — a plain `Color` in the same slot
    /// worked, and a plain rectangle as the annotation did not help. A `Map`
    /// simply cannot live in a lazy stack inside a scroll view here.
    case map
    /// One place, and everything you did there. A `PlaceKey` is a step and a name,
    /// so this is a route rather than a payload — `PhotoCollectionView`
    /// re-derives the photographs from the store, which is the contract that
    /// file already documents.
    case place(PlaceMap.PlaceKey)
    case day(String)
    case curated(String)
    case moment(String)
}
