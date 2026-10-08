import SwiftUI
import SwiftData
import TipKit

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether a cover above this page has put its heads to sleep.
    @Environment(\.headsAwake) private var coveringHeadsAwake
    /// The direction of the last swipe, for the month's slide. 0 is the picker.
    @State private var monthStep = 0
    @State private var vm = MemoriesViewModel()
    /// Today's past win (`PastWin`), the line under the calendar.
    @State private var path: [MemoriesRoute] = []
    @State private var viewing: ViewedPhoto?
    /// The Replays shelf, and the replay playing out of one of its cards.
    @State private var replays = ReplayShelfModel()
    @State private var playing: Replay?
    /// The month whose drawing is being drawn ("Draw Your Own").
    @State private var drawingMonth: DrawingMonth?
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

    @AppStorage(JournalLock.defaultsKey) private var journalLockOn = false
    /// Lock Journal is on and this session has not opened it yet.
    private var journalHidden: Bool { journalLockOn && !JournalLock.shared.isUnlocked }

    /// A tapped notification's subject (`NotificationRoute`), once.
    private func land(_ route: NotificationRoute?) {
        guard let route else { return }
        LandingRouter.shared.memories = nil
        switch route {
        case .memoriesDay(let day):
            playing = nil
            viewing = nil
            path = [.day(day)]
        case .replay(let kind, let first):
            guard let date = DateUtils.date(from: first) else { return }
            let period = kind == "month" ? ReplayPeriod.month(containing: date)
                                         : ReplayPeriod.week(containing: date)
            let replay = ReplayLoader.replay(for: period, context: modelContext)
            guard replay.count > 0 else { return }
            path = []
            viewing = nil
            playing = replay
        default:
            break
        }
    }

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
                    // The recaps are a play button in the top row now, not a
                    // section of their own (the owner, 2026-10-03: "instead of
                    // a bulky section lets just add a play button next to the
                    // profile icon"). See `recapButton`.

                    // **The month stands at the foot of the page, as the
                    // tower does on Wins** (the owner, 2026-10-03: "put the
                    // calendar and stuff near the bottom so it balances with
                    // the wins page"). The room above it is the month's own,
                    // for the drawing he is making for each month
                    // (`monthArt`), and empty until there is one. The photos
                    // open below and scroll.
                    let shown = monthPhotos
                    let count = shown.reduce(0) { $0 + $1.photos.count }
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)
                        monthArt
                        // The drawing stands in the middle of its room, not
                        // pressed onto the calendar: the space above and below
                        // it is equal, which is what makes the page balance.
                        Spacer(minLength: 0)
                        // Nothing for the moment the page takes to learn
                        // whether it is empty; an empty month is the calendar
                        // alone, the emptiness you then fill being the point.
                        if !pageIsUndecided || pageIsEmpty {
                            // The past-win line that stood under the calendar
                            // is gone (the owner, 2026-10-06: "why does it say
                            // september 7 inbox zero i dont like that section
                            // ... i liked the look of the memories screen
                            // before that was added"). It also arrived after
                            // the page had drawn and pushed the month down.
                            // The evening Past Wins notification stays.
                            monthTower
                        }
                    }
                    // The scroll view already stops above the tab bar; the
                    // calendar's last row sits where the tower's last row
                    // does on Wins (the owner, 2026-10-03: "the calendar
                    // bottom should sit where the tower bottom is and then the
                    // photos under that").
                    .containerRelativeFrame(.vertical, alignment: .bottom) { length, _ in
                        max(length - GridConstants.gapTight, 0)
                    }

                    // Under the fold: the photos are a scroll away, their
                    // count just showing under the tab bar's glass. Always
                    // there: a fold hid them for nothing (the owner,
                    // 2026-10-03: "i dont think theres a point to closing
                    // them at all").
                    if !pageIsEmpty, count > 0 {
                        photosCaption(count)
                            .padding(.top, GridConstants.gapSection)
                        // The camera roll, edge to edge: it reads as the
                        // photos, not as more blocks (the owner, 2026-10-03).
                        PhotoGalleryGrid(sections: shown,
                                         transitionNamespace: photoTransition,
                                         onSelect: { photo in
                                             viewing = ViewedPhoto(id: photo.fileName, title: photo.title)
                                         },
                                         screenTitle: shown.first?.title)
                            .padding(.top, GridConstants.gapTight)
                    }
                }
                // Room under the photos for the tab bar.
                .padding(.bottom, GridConstants.tabBarClearance)
                .id("MemoriesContent")
            }
            // **A tap on Memories while on Memories goes home** (the cohesion
            // pass, 2026-10-05): a pushed page comes back first, as every tab
            // on the phone does; on the page itself, back to this month and
            // to the top. Months away with no way back but swiping one at a
            // time was the case this is for.
            .onChange(of: LandingRouter.shared.memoriesReselected) { _, _ in
                if !path.isEmpty {
                    path.removeAll()
                    return
                }
                let calendar = MemoriesViewModel.mondayCalendar
                if !calendar.isDate(vm.selectedMonth, equalTo: Date(), toGranularity: .month) {
                    monthStep = 0
                    withAnimation(reduceMotion ? nil : GridConstants.crossFade) {
                        vm.select(month: Date(), context: modelContext)
                    }
                }
                withAnimation(reduceMotion ? nil : GridConstants.motionSnappy) {
                    proxy.scrollTo("MemoriesContent", anchor: .top)
                }
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
            // Back from a day whose emoji was chosen there: the calendar
            // shows it at once. See `MemoriesViewModel.symbols`.
            .onChange(of: path.isEmpty) { _, isEmpty in
                if isEmpty { vm.refreshSymbols(context: modelContext) }
            }
            // A tapped notification's subject (`NotificationRoute`): the past
            // win's day, or the replay it announced, playing.
            .onChange(of: LandingRouter.shared.memories) { _, route in land(route) }
            .onAppear { land(LandingRouter.shared.memories) }
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
                                Task { await reloadReplays() }
                            },
                            onWinChanged: { Task { await vm.reload(context: modelContext) } })
                    // Out of the thumbnail, not up from the bottom.
                    .navigationTransition(.zoom(sourceID: photo.id, in: photoTransition))
            }
            .fullScreenCover(item: $playing) { replay in
                // A photograph deleted from a block inside the replay is gone
                // from this page too: the gallery, the albums, and the card.
                ReplayView(replay: replay, onPhotoDeleted: {
                    Task { await vm.reload(context: modelContext) }
                    Task { await reloadReplays() }
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
                        MapBackButton(night: mapStyle == .night) { if !path.isEmpty { path.removeLast() } }
                    }
                case .day(let key):
                    // **The standard push and back**, not a zoom out of the
                    // day's block (2026-10-03): coming back, the zoom aimed
                    // at a cell that had moved under the new top row and the
                    // page went off the screen sideways (the owner: "it
                    // transitions off the screen weird").
                    DayAlbumDetailView(route: DayRoute(dateString: key))
                case .place(let key):
                    PhotoCollectionView(source: .place(key))
                case .curated(let key):
                    PhotoCollectionView(source: .interest(key))
                case .moment(let id):
                    PhotoCollectionView(source: .moment(id))
                }
            }
        }
        // **The recaps the play button offers: found, never drawn.**
        //
        // This drew every replay's poster with `ImageRenderer` on the main
        // actor, three passes on every visit, for a shelf of cards that is
        // gone: the recaps became one play button on 2026-10-03, and
        // `ReplayRow` and `MemoriesShelf` have no caller left. Measured on the
        // first visit (2026-10-07, `-strataPerfProbe`): 8 posters, 116
        // thumbnail reads and 50-470ms frames for the 1.5s after the page
        // appears, and every poster that landed ran this body again through
        // `replayRows`, for a picture nothing showed. The play button needs
        // the periods, not their posters. `ReplayView` draws its own.
        .task {
            await reloadReplays()
        }
        .task {
            // A visit, for the month drawing's tip: it waits for the third.
            Task { await MonthDrawingTip.visited.donate() }
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

    // **`waitForQuietMap` and `buildDrawer` are gone with the drawer**, and the
    // measurement in them is worth keeping even though the code is not: long
    // main-actor work — `ImageRenderer` drawing a poster, the page's first
    // layout — must not land while the map is reading its own pictures. A
    // single check for quiet is not enough either; reading 320px derivatives
    // the store empties BETWEEN landings, and one such check still put a 390ms
    // frame among 86 of them. Whoever puts a map back on this screen needs both
    // halves of that again.
    /// The periods only: no poster is drawn (see the `.task` that calls it).
    private func reloadReplays() async {
        await replays.reload(context: modelContext, colorScheme: colorScheme, displayScale: displayScale,
                             now: Date(), redrawsStale: false, drawsMissing: false)
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
            // **One glass container for the header's discs** (2026-10-07,
            // the owner: "the screen just randomly glitches, very rarely
            // elements disappear or turn to black"). The map, the replay and
            // the head were three glass effects drawn apart, one of them
            // inserted and removed with a scale as replays load; iOS 26 is
            // known to drop or blacken glass drawn that way for a frame, and
            // Apple's guidance is to group neighbouring glass in one
            // container. Blend distance 0, under the gap, so they never fuse
            // (the `HeaderGlassPair` note in GlassIconButton.swift).
            GlassGroup {
            HStack(spacing: 8) {
                // **THE MAP, AS A BUTTON.** The owner: "the map would be a
                // button on the top instead of the Memories sheet being a
                // button — I think that makes more sense."
                GlassIconButton(systemName: "map", onPage: true,
                                accessibilityLabel: "Map") {
                    path.append(.map)
                }
                Spacer(minLength: 0)
                recapButton
                ProfileButton { openProfile?() }
            }
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

    /// **The month's photographs, under the calendar.** One quiet line, the
    /// count in the secondary ink, no glass and no rule: the calendar keeps
    /// the screen, and the photos are a scroll away. It was a fold with a
    /// chevron; the owner, 2026-10-03, "make the photos expanded by default...
    /// actually i dont think theres a point to closing them at all".
    /// **A past ordinary win, under this month's calendar** (`PastWin`): one
    /// line in the photo count's grey, never a card, and a tap opens that day.
    /// Only on the month you are living in; an older month is already a look
    /// back.
    private func photosCaption(_ count: Int) -> some View {
        Text(count == 1 ? "1 Photo" : "\(count) Photos")
            .font(Typography.screenSubtitle)
            .foregroundStyle(AppColors.inkSecondary)
            .frame(minHeight: 44)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .accessibilityAddTraits(.isHeader)
    }

    /// **The recap, as one glass button beside Profile.** One recap ready:
    /// it plays. A month and a week both ready: a small menu names them.
    /// Nothing ready: no button.
    ///
    /// `play`, hollow, not `play.fill` (the cohesion pass, 2026-10-05):
    /// `docs/research/visual-cohesion.md` §4.3 says "filled = selected,
    /// outline = not, everywhere", and a header button is never selected.
    /// Profile beside it went to `person` for the same reason.
    @ViewBuilder
    private var recapButton: some View {
        let rows = replayRows
        if rows.count == 1, let only = rows.first {
            GlassIconButton(systemName: "play", onPage: true,
                            accessibilityLabel: "Play \(only.title)") {
                playing = only.replay
            }
            .transition(.scale.combined(with: .opacity))
        } else if rows.count > 1 {
            Menu {
                ForEach(rows) { row in
                    Button { playing = row.replay } label: { Label(row.title, systemImage: "play") }
                }
            } label: {
                GlassIconLabel(systemName: "play", onPage: true)
            }
            .accessibilityLabel("Play a recap")
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// **The month's drawing**, in the room above its calendar: an asset
    /// named for the month, "MonthOctober", when one is in the catalogue, and
    /// nothing at all until then (the owner is drawing one for each month).
    ///
    /// The drawing and its line on the page itself, set the way HeyTea sets
    /// its illustrations (the owner, 2026-10-03: "some text like happy
    /// halloween in the clean sf pro... make it a part of the image"). It was
    /// in a card for one build; "I dont like the illustration in the block
    /// try it just blank". See `Illustration`.
    @ViewBuilder
    private var monthArt: some View {
        let month = vm.monthTitle.split(separator: " ").first.map { String($0).capitalized } ?? ""
        let key = MonthDrawingStore.key(for: vm.selectedMonth, calendar: MemoriesViewModel.mondayCalendar)
        Group {
            // **Your own drawing first, when the month has one** (spec
            // section 4). The default is never touched, so "Use Original"
            // brings it straight back, with October's dance.
            if let own = MonthDrawingStore.shared.drawing(for: key) {
                // Your line under your drawing, set as the owner's are.
                VStack(spacing: GridConstants.gapItem) {
                    InkReplay(drawing: own, height: 290, onRest: Self.artPlayed)
                        .layoutPriority(1)
                    if let line = own.line { DrawingLine(text: line) }
                }
                .modifier(MonthArtHold(month: key, hasOwn: true, editing: $drawingMonth))
            } else if UIImage(named: "Month" + month + "SkelSkull") != nil {
                // **October: the skeleton dances and the crow lands on his
                // hand** (the owner, 2026-10-06). `OctoberDance` has how.
                // The scarecrow's assets stay in the catalogue.
                OctoberDance(line: MonthLines.shared.line(for: key) ?? Self.monthLine[month], height: 290,
                             onRest: Self.artPlayed)
                    .modifier(MonthArtHold(month: key, hasOwn: false, editing: $drawingMonth,
                                           originalLine: Self.monthLine[month]))
            } else if let art = UIImage(named: "Month" + month) {
                Illustration(art: art, line: MonthLines.shared.line(for: key) ?? Self.monthLine[month], height: 290,
                             motion: UIImage(named: "Month" + month + "Crow").map {
                                 .crowLands(crow: $0,
                                            head: UIImage(named: "Month" + month + "CrowHead"),
                                            wingsDown: UIImage(named: "Month" + month + "CrowDown"),
                                            wingsOut: UIImage(named: "Month" + month + "CrowOut"),
                                            eyes: UIImage(named: "Month" + month + "Eyes"),
                                            nose: UIImage(named: "Month" + month + "Nose"),
                                            mouth: UIImage(named: "Month" + month + "Mouth"))
                             },
                             onRest: Self.artPlayed)
                    .modifier(MonthArtHold(month: key, hasOwn: false, editing: $drawingMonth,
                                           originalLine: Self.monthLine[month]))
            }
        }
        .layoutPriority(1)
        .transition(.opacity)
        .fullScreenCover(item: $drawingMonth) { which in
            MonthDrawingEditor(month: which.id, monthName: MonthName.of(which.id))
        }
        #if DEBUG
        // `-strataMonthDrawing seed|edit|still`: a drawing of the shown month
        // (`InkSamples`, brought to life, or `still` with the switch off),
        // and `edit` opens the editor on it. Long press cannot be scripted.
        .task(id: key) {
            guard let which = DebugHarness.argument("-strataMonthDrawing") else { return }
            if !MonthDrawingStore.shared.hasDrawing(for: key) {
                let canvas = CGSize(width: 300, height: 450)
                MonthDrawingStore.shared.save(
                    InkSamples.sunOverHill(in: canvas, width: InkPen.width(onCanvasOfHeight: 450, shownAt: MonthDrawingEditor.shownHeight)),
                    canvas: canvas, bringsToLife: which != "still", line: "Out by noon", for: key)
            }
            if which == "edit" {
                try? await Task.sleep(for: .seconds(1))
                MonthDrawingTip.used()
                drawingMonth = DrawingMonth(id: key)
            }
        }
        #endif
    }

    /// The month's drawing has played: the tip may now point at it.
    private static func artPlayed() { MonthDrawingTip.artPlayed = true }

    /// The line under a month's drawing. October's "Happy Halloween" came
    /// off (the owner, 2026-10-03): the drawing says it. A quote is another
    /// thing, and he asked for one (2026-10-06: "should there be like a nice
    /// quote under the scarecrow drawing"), as the crews' drawing has its
    /// "Winning is better together", and then for one that motivates ("can
    /// it be like an actually motivating quote"); his pick, "Small wins
    /// still count". A hold on the drawing changes it (`MonthLines`).
    static let monthLine: [String: String] = [
        "October": "Small wins still count",
    ]

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
                transitionNamespace: nil,
                // **Lock Journal hides what the journal holds** (the cohesion
                // pass, 2026-10-05): while it is locked, no emoji in the
                // corners and no day marked as written. An emoji is part of
                // the note, and a calendar of them is the journal's summary
                // shown to whoever is holding the phone.
                symbols: journalHidden ? [:] : vm.symbols,
                written: journalHidden ? [] : vm.writtenDays
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
            //
            // **Except under a finger** (the owner, 2026-10-03: "swiping left
            // and right on the calendar should also be a way of changing
            // months"). A swipe moves the months, so the month slides the way
            // the finger went; the picker still cross-fades.
            .id(vm.monthTitle)
            .transition(monthStep == 0 ? .opacity
                        : .push(from: monthStep > 0 ? .trailing : .leading))
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let dx = value.translation.width, dy = value.translation.height
                        guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                        stepMonth(dx < 0 ? 1 : -1)
                    }
            )
        }
    }

    /// One month on (+1) or back (-1), as far as there are months.
    /// `availableMonths` is newest first.
    private func stepMonth(_ step: Int) {
        let months = vm.availableMonths
        guard let here = months.firstIndex(where: {
            MemoriesViewModel.mondayCalendar.isDate($0, equalTo: vm.selectedMonth, toGranularity: .month)
        }) else { return }
        let next = here - step
        guard months.indices.contains(next) else {
            HapticsEngine.warning()
            return
        }
        HapticsEngine.tick()
        monthStep = step
        withAnimation(GridConstants.motionSnappy) {
            vm.select(month: months[next], context: modelContext)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            monthStep = 0
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

/// The month being drawn, by key ("2026-10").
struct DrawingMonth: Identifiable, Equatable {
    let id: String
}

/// **Hold the month's drawing to make it yours** (spec section 4, "Entry").
/// The system's own context menu: "Draw Your Own", and "Use Original" once
/// the month has a drawing of yours. No edit button and no edit mode straight
/// from the hold: the menu is the confirmation that a hold meant it. The tip
/// is the clue the gesture otherwise lacks, and Settings is its second way in.
struct MonthArtHold: ViewModifier {
    let month: String
    let hasOwn: Bool
    @Binding var editing: DrawingMonth?
    /// The original drawing's own line, to start an edit from. A drawing of
    /// your own changes its line in its editor instead.
    var originalLine: String? = nil

    @State private var changingLine = false
    @State private var draft = ""

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button("Draw Your Own", systemImage: "pencil") {
                    MonthDrawingTip.used()
                    editing = DrawingMonth(id: month)
                }
                // **Keep the drawing, change the line** (the owner,
                // 2026-10-06: "for those that want to keep the scarecrow but
                // change the quote").
                if !hasOwn {
                    Button("Change Line", systemImage: "text.cursor") {
                        draft = MonthLines.shared.line(for: month) ?? originalLine ?? ""
                        // Once the menu has closed: asked while it is still
                        // going, the alert never came up (simulator).
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            changingLine = true
                        }
                    }
                }
                if hasOwn {
                    Button("Use Original", systemImage: "arrow.uturn.backward", role: .destructive) {
                        MonthDrawingStore.shared.remove(month)
                    }
                }
            }
            .alert("Line Under the Drawing", isPresented: $changingLine) {
                TextField("Your line", text: $draft)
                Button("Save") {
                    HapticsEngine.lightTap()
                    MonthLines.shared.set(draft, for: month)
                }
                if MonthLines.shared.line(for: month) != nil {
                    Button("Use Original Line", role: .destructive) {
                        MonthLines.shared.set(nil, for: month)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .popoverTip(MonthDrawingTip(), arrowEdge: .bottom)
    }
}

