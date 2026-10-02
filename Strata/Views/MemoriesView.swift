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
                            ForEach(replayRows) { row in
                                ReplayRow(
                                    replay: row.replay,
                                    poster: replays.cards[ReplayShelfModel.key(row.replay, scheme: colorScheme)],
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
                            // The copy, and then the real calendar under it.
                            // See `emptyState`.
                            emptyState
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
                        MemoriesShelf(model: replays, now: replays.now,
                                      albums: vm.carousel,
                                      onOpenAlbum: { route in
                                          switch route {
                                          case .day(let key):     path.append(.day(key))
                                          case .curated(let key): path.append(.curated(key))
                                          case .moment(let id):   path.append(.moment(id))
                                          }
                                      },
                                      excluding: monthReplay,
                                      transitionNamespace: photoTransition) { playing = $0 }
                            .id("MemoriesShelf")
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
                    // get back to the Memories from the map." It is in
                    // `MapBackButton` now, with its own measurements: the
                    // white-on-glass version built here measured 1.10:1
                    // against its own disc, which is an empty white circle on
                    // a map that is mostly white.
                    .overlay(alignment: .topLeading) {
                        MapBackButton { path.removeLast() }
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
            rows.append(ReplayOffer(replay: monthReplay, title: vm.monthTitle.capitalized))
        }
        if let live = ReplayShelfModel.live(in: replays.months + replays.weeks,
                                            besides: monthReplay, now: replays.now) {
            rows.append(ReplayOffer(replay: live,
                                    title: MemoriesShelf.name(of: live.period, now: replays.now)))
        }
        return rows
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
            // **ON THE PAGE MARGIN, AND IT WAS 6.** (2026-10-01, check 11d)
            //
            // This was `horizontalPadding - 10`, and the comment beside it said
            // the 10 was "the menu label's own inset, so the WORD lines up with
            // the title above it". That inset is `gapLabel`, 16, not 10 — the
            // picker's label is a `glassCapsule` with 16pt of its own horizontal
            // padding (`MonthPicker`) — so the 10 bought neither alignment: the
            // word landed at 22 and the CAPSULE, which is the drawn object, at
            // **6.0**. Measured on the built page, that 6.0 was the leftmost of
            // ten different left edges on this screen and the one furthest from
            // the margin (`docs/space.md` §6, clause 11d).
            //
            // The capsule is a surface, so the capsule's edge is the band. It
            // stands on 16 like the title, the replay rows, the album shelf and
            // every heading on the page; its word sits 16 inside it, which is
            // what a filled control's label does and is not a margin.
            .padding(.leading, GridConstants.horizontalPadding)

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

    /// What this page says before there is anything on it.
    ///
    /// **Show the shape of the thing that is missing**, which is still the
    /// right instruction and used to be followed with a drawing of the wrong
    /// thing. The calendar under this copy is the shape, so nothing here has
    /// to draw one.
    private var emptyState: some View {
        // **A SUBHEAD, NOT A POSTER.**
        //
        // It was a centred cluster of four dashed ghost blocks packed the way
        // the month tower used to pack them, with a centred headline and a
        // centred sentence under it, 72pt down an otherwise blank page. Three
        // things were wrong at once.
        //
        // The ghosts drew a packed tower, and this page is a calendar. The
        // empty state was still advertising the design it had replaced.
        //
        // The dash is a vocabulary this app does not have. The tower's slot
        // is a solid stroke and the calendar's empty days are solid wells;
        // the only other dashed thing in the app was the add sheet's photo
        // well, which has just stopped being one for the same reason.
        //
        // And it was centred on a page whose title, picker and calendar all
        // start at 16. Centred copy on a left aligned page is two alignment
        // systems on one screen, and the same fault the empty tower had.
        //
        // So the art is deleted rather than redrawn: the real calendar sits
        // under this copy and shows a real empty month, which is a better
        // promise of the thing than a drawing of a different thing. This is
        // what is left, and it is the page's one sentence on its own margin.
        //
        // **AND NOW IT IS ONE LINE.** (`docs/copy-audit.md` cut 11.) The second
        // line read "Every win you log becomes a block, and they collect here by
        // month." — thirteen words restating onboarding page 1 ("Finish
        // something and it becomes a block"), under a line that already makes
        // the promise, over a real empty calendar that makes it again. The
        // paragraph above is the argument: a drawing of the thing loses to the
        // thing, and a sentence describing the calendar loses to the calendar
        // under it. The owner, the same afternoon: "the areas are very self
        // explanitory and I think over explaining components loses the charm."
        //
        // What is left is one medium-weight line on the page's own margin, which
        // is what he asked the app's text to be.
        Text("Your first month starts here")
            .font(Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapWide)
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
