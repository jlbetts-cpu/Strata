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
    @AppStorage("memoriesPhotosOpen") private var photosOpen = false
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
                    // **ABOVE THE CALENDAR, NOT UNDER IT.**
                    //
                    // Measured: at four columns the calendar is eight rows of
                    // 91pt — 724pt — against about 605pt of usable screen. So
                    // under the calendar meant under the FOLD, on every visit,
                    // for the one thing this page offers you to do. A page's
                    // single action cannot be the thing you have to scroll past
                    // a month to find.
                    //
                    // Above it, the first screen is the title, the month, the
                    // one action, and the month beginning — which is the page
                    // saying what it is and what you can do with it before it
                    // starts listing.
                    if !replayRows.isEmpty {
                        // **ONE ROW OR TWO, AND NEVER THREE.** See
                        // `replayRows`: the month you have chosen, and the
                        // period whose window is open if the first row is not
                        // already it. `gapItem` between them, because two rows
                        // offering the same kind of thing are items in a set.
                        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                            // **The poster rides IN the offer, read where
                            // the body is evaluated** (2026-10-02). It was
                            // read here, inside the `ForEach` closure, and
                            // CLAUDE.md's rule is that a read in there is not a
                            // dependency you can rely on. This was NOT the
                            // blank row (that was the thumbnail's crop, see
                            // `ReplayRow.thumbnail`); it is the rule applied
                            // where it was being broken. `replayRows` reads
                            // `cards` now, in the body's own pass.
                            ForEach(replayRows) { row in
                                ReplayRow(
                                    replay: row.replay,
                                    poster: row.poster,
                                    title: row.title
                                ) { playing = row.replay }
                            }
                        }
                        // **NO BOTTOM PADDING, BECAUSE THE CALENDAR ALREADY
                        // CARRIES ONE.**
                        //
                        // Measured on the built page: 22pt above this row and
                        // 56 below it. `gapSection` here and `gapWide` on
                        // `MonthCalendarView` are each defensible alone and
                        // they stack, which is the same fault as two shadows
                        // under one object. An element with 22 above and 56
                        // below reads as belonging to the thing above it and
                        // spaced as if it belongs to nothing.
                        //
                        // The picker, this row and the calendar are one
                        // section about one month: you choose the month, you
                        // play the month, you read the month. So they take
                        // one rhythm, `gapWide` throughout, and the page's
                        // biggest gap is kept for the real section break
                        // below the calendar where the collections begin.
                    }

                    Section {
                        if pageIsEmpty {
                            // **Just the calendar, empty** (2026-10-03). It
                            // had a sentence over it; an empty month already
                            // says it is waiting, and the emptiness you then
                            // fill is the point (the owner: "I love how empty
                            // the app feels").
                            monthTower
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
                        // **ONE SHELF.** Replays and albums were two bands of
                        // cards, one directly under the other, at the same
                        // width — and the owner's read of the page was that it
                        // was still four stacked lists. They are the same kind
                        // of thing: something the app made out of wins you
                        // already logged, opened by pressing a picture of it.
                        // See `MemoriesShelf`.
                        // **Two albums and two closures, where it used to take
                        // seven arguments.** `model`, `now`, `excluding`,
                        // `transitionNamespace` and the trailing `onPlay` were
                        // all filled in here and read by nothing: they fed
                        // `MemoriesShelf.card`, which lost its caller when the
                        // replays became `ReplayRow`s and has been deleted
                        // (`docs/consistency-audit.md` §1.13). A call site that
                        // hands a view a namespace and a play handler says the
                        // view plays things and opens transitions out of them,
                        // and this one draws neither.
                        // **One way to see the photographs, not three** (the
                        // owner, 2026-10-03: "so many different ways of showing
                        // off the images makes the screen not look as structured
                        // and clean"). The calendar is the days, and this is the
                        // pictures, drawn as the calendar is drawn: the page's
                        // margin, its gap, a block's corner. The carousel of
                        // curated albums under the calendar is gone.
                        // **This month's photographs, and only this month's**
                        // (see `pageHeader`). Untitled: the month is at the top.
                        let shown = monthPhotos
                        let count = shown.reduce(0) { $0 + $1.photos.count }
                        if count > 0 {
                            photosToggle(count)
                                .padding(.top, GridConstants.gapSection)
                            if photosOpen {
                                // The camera roll, edge to edge, as it was:
                                                // opened, it reads as the photos, not as
                                                // more blocks (the owner, 2026-10-03).
                                PhotoGalleryGrid(sections: shown,
                                                 transitionNamespace: photoTransition,
                                                 onSelect: { photo in
                                    viewing = ViewedPhoto(id: photo.fileName, title: photo.title)
                                },
                                                 screenTitle: shown.first?.title)
                                .padding(.top, GridConstants.gapTight)
                                .transition(.opacity.combined(with: .offset(y: -8)))
                            }
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
                    // get back to the Memories from the map." It is in
                    // `MapBackButton` now, with its own measurements: the
                    // white-on-glass version built here measured 1.10:1
                    // against its own disc, which is an empty white circle on
                    // a map that is mostly white.
                    .overlay(alignment: .topLeading) {
                        MapBackButton(night: mapStyle == .night) { path.removeLast() }
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

    // **`shelf` and `AlbumCarousel` are gone.** The albums are in
    // `MemoriesShelf` with the replays now — one row, one heading, one scroll.
    // `AlbumCard` survived the carousel that owned it and is the part worth
    // keeping; `AlbumCoverView` under it is untouched.

    // MARK: - The month

    /// Every photograph the page holds, which is what the gallery below it is
    /// a grid of. Summed from the sections rather than kept as a second
    /// number: a count that can disagree with the thing it counts is worse
    /// than no count at all.
    /// The replay OF the month on screen, if there is one.
    ///
    /// Matched on the period's first day rather than on a title, because a
    /// title is a formatted string and two of them agreeing is a coincidence
    /// this page should not depend on.
    private var monthReplay: Replay? {
        replays.months.first {
            MemoriesViewModel.mondayCalendar.isDate($0.period.firstDay,
                                                    equalTo: vm.selectedMonth,
                                                    toGranularity: .month)
        }
    }

    /// **Every replay this page offers, in the order it offers them.**
    ///
    /// At most two, and usually one.
    ///
    /// 1. **The month you have chosen**, directly under the picker that chose
    ///    it, because the picker, this row and the calendar are one section
    ///    about one month.
    /// 2. **The period whose window is open right now**, when that is not
    ///    already the row above — a week on a Sunday evening, a month at the
    ///    turn of a month. This is the row that replaces the Wins tab's deleted
    ///    `headerReplayPill`: without it the open week had no route anywhere in
    ///    the app. `ReplayShelfModel.live` carries the rule and why a week beats
    ///    a month here.
    ///
    /// **The dedupe is on the replay's id, not on a title.** Two formatted
    /// strings agreeing is a coincidence, and at the turn of a month the open
    /// period IS a month, so the page would otherwise draw September twice to
    /// anybody who had stepped the picker back to it.
    ///
    /// A period's own name in both rows: `vm.monthTitle` for the month the
    /// picker names, and the replay's own range for the other, which is
    /// "September" for a month and "9/22-9/28" for a week. Both are the period's
    /// name rather than the app talking about itself — the owner cut "Your week"
    /// off the replay for that reason (2026-09-15) and it would be odd to put it
    /// back on the row that opens it.
    private var replayRows: [ReplayOffer] {
        var rows: [ReplayOffer] = []
        if let monthReplay {
            rows.append(ReplayOffer(replay: monthReplay, title: vm.monthTitle.capitalized,
                                    poster: poster(for: monthReplay)))
        }
        if let live = ReplayShelfModel.live(in: replays.months + replays.weeks,
                                            besides: monthReplay, now: replays.now) {
            rows.append(ReplayOffer(replay: live,
                                    title: MemoriesShelf.name(of: live.period, now: replays.now),
                                    poster: poster(for: live)))
        }
        return rows
    }

    /// A row's poster, read here so the body depends on it. See the note at
    /// the `ForEach` that draws the rows.
    private func poster(for replay: Replay) -> UIImage? {
        replays.cards[ReplayShelfModel.key(replay, scheme: colorScheme)]
    }

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
    /// **No title** (the owner, 2026-10-03: "the memories big title would work
    /// if we used that anywhere else but we dont use titles anywhere else").
    /// The top of the page is every page's top: two glass buttons in its
    /// corners and, between them, the one thing that is this page's: the
    /// month.
    ///
    /// **The month governs the whole page** (the owner, 2026-10-03: "if you
    /// are going to make the october picker dictate the page then it should
    /// actually dictate the page like things that show should only be from
    /// that month"): its calendar, then its photographs, and nothing from
    /// any other month. It does not scroll.
    private var pageHeader: some View {
        ZStack {
            HStack(spacing: 8) {
                // **THE MAP, AS A BUTTON.** The owner: "the map would be a
                // button on the top instead of the Memories sheet being a
                // button — I think that makes more sense."
                GlassIconButton(systemName: "map", onPage: true,
                                accessibilityLabel: "Map") {
                    path.append(.map)
                }
                Spacer(minLength: 0)
                ProfileButton { openProfile?() }
            }
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
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapTight)
        .zIndex(1)
    }

    /// **The month's photographs, folded under the calendar** (the owner,
    /// 2026-10-03: "make the photos dropdown so the calendar gets its air...
    /// not super noticable or ugly"). One quiet line, the count and a
    /// chevron in the secondary ink, no glass and no rule: the calendar keeps
    /// the page, and the photos are a tap away. Remembered.
    private func photosToggle(_ count: Int) -> some View {
        Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) { photosOpen.toggle() }
        } label: {
            HStack(spacing: GridConstants.gapTight) {
                Text(count == 1 ? "1 Photo" : "\(count) Photos")
                    .font(Typography.screenSubtitle)
                Image(systemName: "chevron.down")
                    .iconSize(GridConstants.iconChevron, relativeTo: .subheadline, weight: .semibold)
                    .rotationEffect(.degrees(photosOpen ? 180 : 0))
            }
            .foregroundStyle(AppColors.inkSecondary)
            .frame(minHeight: 44)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(count == 1 ? "1 photo" : "\(count) photos")
        .accessibilityHint(photosOpen ? "Hides them." : "Shows them.")
    }

    /// The chosen month's photographs, as one untitled section.
    private var monthPhotos: [GallerySection] {
        let parts = MemoriesViewModel.mondayCalendar.dateComponents([.year, .month], from: vm.selectedMonth)
        let key = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        return vm.gallery.filter { $0.id == key }
    }

    private var monthGridWidth: CGFloat {
        UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2
    }

    private var monthCell: CGFloat {
        GridConstants.cellSize(forGridWidth: monthGridWidth)
    }

    /// **CHECK 11c FAILS ON A BARE MONTH AND IT IS EXEMPT. WRITTEN DOWN WITH
    /// WHAT THE FIX WOULD COST** (2026-10-01).
    ///
    /// Measured off `/tmp/s2/light/m1-memories-empty.png` and `m2-memories-one`:
    /// the calendar's last row ends at y=510 with nothing logged and y=466 with
    /// one win, so the biggest break on the page is **281pt and 325pt of ground
    /// between the month and the tab bar**. Clause 11c says the biggest break
    /// must fall between two drawn bands that are both content, and a tab bar is
    /// not the second band. With anything to show it passes: at a month half
    /// full the biggest break is 64pt, between the calendar and the shelf.
    ///
    /// **Centring the month in the field was built in the head and refused on
    /// the measurement.** It would make where the month sits depend on whether
    /// the shelf below it has anything in it, so logging your first win would
    /// move the calendar up the page. That is the exact fault `PhotoViewer`'s
    /// `dateHeight` was rewritten to remove — a stage that resizes because data
    /// arrived — and check 10's own words for it are "anything that animates
    /// because it appeared". It would also pull the month away from the picker
    /// in the fixed band that chooses it, which is the thing the owner asked for
    /// twice ("this should not scroll", "keep it in one place").
    ///
    /// **And the field is not nothing.** `docs/illustrations.md` rule 5 is that
    /// the figure sits small in a big empty field and "on this app's page that
    /// field is already there"; this is 281pt of it, on the page a person opens
    /// before they have logged anything. The same clause is already exempted on
    /// the place collection for the same shape of reason: content that is less
    /// than a screenful is not a composition failure.
    @ViewBuilder
    private var monthTower: some View {
        do {
            // **AN EMPTY MONTH IS STILL A MONTH, SO IT IS STILL THE CALENDAR.**
            //
            // There used to be a branch here: a row of three dashed ghost
            // blocks and the sentence "Nothing in October yet.", centred.
            // It was written when this page was a packed tower, and it drew
            // the shape of a thing the page had stopped being. A calendar
            // whose month is empty already renders thirty one empty cells
            // with their numbers in them, which is both the real shape and
            // the thing the owner asked for by name: "add some lattice at
            // the end of the calendar in the empty spots just so it doesnt
            // look like empty state completely."
            //
            // So the branch is gone, and with it `ghostRow` and the dashed
            // outline, which existed nowhere else in the app except the add
            // sheet's photo well, where it has also just been removed. One
            // component fewer, and the empty state is now the page.
            //
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
}

// MARK: - How much is here



/// One replay the page offers, and what to call it on its row.
///
/// A struct rather than a labelled tuple because `ForEach` needs an
/// `Identifiable` element or a key path, and Swift has no key paths into tuple
/// components. Its identity is the replay's, which is the period's id, so the
/// two rows can never collide: that is the same identity the dedupe in
/// `MemoriesView.replayRows` is written against.
private struct ReplayOffer: Identifiable {
    let replay: Replay
    let title: String
    /// The drawn poster, or nil while the shelf model is still drawing it.
    let poster: UIImage?
    var id: String { replay.id }
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
