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
    /// How far the page is pulled up over the map. **Hidden on arrival** —
    /// the tab opens on the map, whole, and the photographs are the button in
    /// the corner.
    @State private var drawer: DrawerDetent = .hidden
    /// Whether the drawer's page has been built. **Not while the tab is
    /// arriving.** The drawer rests hidden, and hiding it is only an offset,
    /// which does not affect layout: the lazy stack inside built its first
    /// screen with the tab — the month tower with a slideshow running in every
    /// photographed day, the replay shelf, the first rows of the gallery —
    /// under a map nobody had pulled anything up over.
    ///
    /// **But before the first raise, not during it.** Built by the raise
    /// itself, the page's construction landed in the spring's first frames:
    /// filmed on a year of seeded history, the first raise held the screen
    /// for 1.8s and the drawer appeared already at the top, its page fading in
    /// over the map. So it is built once the page has its data AND the map's
    /// camera has been still for `prebuildDelay`, off screen, with its
    /// slideshows paused (`memoriesDrawerVisible`) and no poster redrawn; and a
    /// raise that comes sooner builds first and waits for the built page to
    /// appear before sliding. Once built it stays built, so lowering and
    /// raising again keeps its place.
    @State private var drawerIsBuilt = false
    private static let prebuildDelay: Duration = .milliseconds(1500)
    /// When the map's camera last moved, so the build waits for it to be
    /// still. See `MapMotion`.
    @State private var mapMotion = MapMotion()
    /// A raise waiting for the page to exist. See `raiseDrawer`.
    @State private var raiseWhenBuilt = false
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
            ZStack {
            // **The map is the tab.**
            //
            // The page used to be the screen and the map a route off it. The
            // owner's call is that the map is the feature, so it is the ground
            // now and everything the tab used to be is a drawer over it —
            // Apple Maps' own anatomy, and the only arrangement that gives the
            // map the whole screen without losing anything.
            MemoriesMapView(pins: vm.pins, hasLoaded: vm.hasLoaded, motion: mapMotion,
                            style: mapStyle) { key in
                path.append(.place(key))
            }
            .ignoresSafeArea()

            // **The chrome floats on the map, and the drawer slides over it.**
            //
            // The title is the screen's name, so it belongs on the screen —
            // which is now the map. It sits UNDER the drawer in z so raising
            // the page covers it rather than fighting it, exactly as Apple
            // Maps' own search field is covered by its card. At `.full` you
            // are looking at photographs, and a title over photographs is the
            // same argument the tower's header already lost.
            VStack(spacing: 0) {
                titleRow
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, GridConstants.headerArtworkTopPadding)
                Spacer(minLength: 0)
            }
            // **A legibility wash only where one is needed.**
            //
            // Over imagery the ground is a photograph of the Earth and cannot
            // be relied on to be anything, so the title is white on a short
            // gradient from the app's own black — the same move the camera
            // makes for its wordmark. Over the pale ground it is ink, with no
            // wash at all: a dark smear laid across a pale map to hold up a
            // title that did not need holding up is exactly the kind of chrome
            // this screen is trying not to have.
            .background(alignment: .top) {
                if mapStyle != .quiet {
                    // **Faint.** It was 0.55 over 190pt, which is not a wash,
                    // it is a bar — the owner called it "overwhelming on the
                    // top", and on the night map, whose tiles are already
                    // dark, almost all of that was being spent on a problem
                    // that no longer existed. A legibility wash only has to
                    // guarantee the worst case: a white building or a cloud
                    // directly under the title. 0.28, fading out by 130pt,
                    // does that and is not visible as an object.
                    LinearGradient(
                        stops: [
                            .init(color: AppColors.warmBlack.opacity(0.28), location: 0.0),
                            .init(color: AppColors.warmBlack.opacity(0.16), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 130)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }

            MemoriesDrawer(detent: $drawer, raise: { raiseDrawer() }) {
            if drawerIsBuilt {
            // **The header is above the scroll, and the scroll fades into
            // it.**
            //
            // Three owner calls, and the third settles the shape. The picker
            // must not travel with the photographs. The page must not sit on
            // "a seprete white background" — "it should just have a light
            // gradient behind it on scroll like how apple does it". And: "the
            // september drop down should not be on the scroll container".
            //
            // The middle one alone pointed at an overlay — header floating,
            // content passing under it. The third rules that out, and rightly:
            // photographs sliding beneath a menu make the menu look like it is
            // riding on them. So the header sits ABOVE the scroll view and
            // owns its own band, and the SOFTNESS is bought inside the scroll
            // view instead — a short, light, semi-transparent fade at its top
            // edge, so content dissolves as it reaches the header rather than
            // being guillotined by the clip.
            //
            // The fade belongs to the scrolling content. The header does not
            // move, is not translucent, and nothing passes over it.
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
                    } header: {
                        if !pageIsEmpty && !pageIsUndecided { monthHeader }
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
                            SectionHeading(text: "ALBUMS")
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
            // The scroll edge, and nothing else. Light and semi-transparent —
            // it is there to take the hard cut off the top of the content, not
            // to draw a band across it.
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [WarmBackground.top.opacity(0.85),
                             WarmBackground.top.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
                .allowsHitTesting(false)
            }
            }
            // Arrives as it is. Inserted inside a raise's animation, the
            // default would fade the page in while it slides: filmed on the
            // first raise, the page's title half-transparent over the map's.
            .transition(.identity)
            // Built and laid out: a raise waiting on it can start now.
            .onAppear { raiseNowThatItIsBuilt() }
            }
            }
            // Lowered, or covered by a photograph, a replay or a pushed page:
            // nobody can see the month, so its slideshows hold still.
            .environment(\.memoriesDrawerVisible,
                         drawer != .hidden && viewing == nil && playing == nil && path.isEmpty)
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: drawer) { _, detent in
                // Every raise goes through `raiseDrawer`; this is the net.
                if detent != .hidden, !drawerIsBuilt { buildDrawer() }
            }
            }
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
        // Its own task: drawing the cards yields between each, and the
        // drawer's reload and the launch flags below must not wait on it.
        // Keyed by scheme and scale: posters are drawn in the page's scheme,
        // so a switch draws (once) the set for the other. And by whether the
        // drawer is up: a poster that is merely STALE is redrawn only when
        // the shelf can be seen, and the old one stays up until then.
        .task(id: "\(colorScheme)-\(displayScale)-\(drawer != .hidden)") {
            // **A MISSING card is drawn while the drawer is down, but only
            // once the map is quiet** (fix round 2). Drawn straight away, it
            // put 1.27s of `ImageRenderer` on the main actor under the map's
            // first frames. Drawn only when the drawer rose (round 1), that
            // same 1.3s landed under the moving panel on the first raise and
            // the slots filled in one by one. So: find the periods now, draw
            // the missing cards behind the same gate as the drawer's
            // prebuild (the camera still, the image store quiet for 500ms,
            // the page built first), and keep drawing on the raise only as a
            // fallback for anything still missing. A STALE card still waits
            // for the drawer and the spring, as before.
            if drawer == .hidden {
                await reloadReplays(redrawsStale: false, drawsMissing: false)
                while !Task.isCancelled, !vm.hasLoaded || !drawerIsBuilt {
                    try? await Task.sleep(for: .milliseconds(200))
                }
                await waitForQuietMap()
                guard !Task.isCancelled, drawer == .hidden else { return }
                await reloadReplays(redrawsStale: false, drawsMissing: true)
                return
            }
            await reloadReplays(redrawsStale: false, drawsMissing: true)
            try? await Task.sleep(for: Self.springSettle)
            guard !Task.isCancelled else { return }
            await reloadReplays(redrawsStale: true)
        }
        // **The off-screen build, and only while nothing is moving.** A
        // `.task` so leaving the tab cancels it — an unstructured one built
        // the page after the map had already gone, landing its frame on
        // another tab — and it restarts its wait every time the map's camera
        // moves, so the build never takes a frame out of a pan.
        .task(id: "\(drawerIsBuilt)-\(vm.hasLoaded)") {
            // Not before the page has anything to build from, and not while
            // the map is moving: the store's read lands first, the map frames
            // itself on the pins (a camera move), and the build waits for
            // `prebuildDelay` of stillness after that.
            #if DEBUG
            defer { if Task.isCancelled { PerfProbe.emit("[PERF-MARK] drawer prebuild cancelled") } }
            #endif
            guard !drawerIsBuilt, vm.hasLoaded else { return }
            // The data landing counts as a move: the map is about to frame
            // itself on the new pins, and the camera having been still while
            // the store was read is not the quiet this is waiting for.
            mapMotion.movedAt = .now
            await waitForQuietMap()
            guard !Task.isCancelled, !drawerIsBuilt else { return }
            #if DEBUG
            let buildStart = CACurrentMediaTime()
            PerfProbe.mark("drawer prebuild")
            #endif
            buildDrawer()
            #if DEBUG
            PerfProbe.duration("MemoriesView.buildDrawer (state set)", since: buildStart)
            #endif
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
            if let detent = DebugHarness.openDrawer { drawer = detent }
            if let after = DebugHarness.raiseDrawerAfter {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(after))
                    PerfProbe.mark("drawer raise")
                    PerfProbe.window("Drawer raise", seconds: 1.5)
                    raiseDrawer()
                }
            }
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

    /// The Photographs button, and the drawer's own accessibility action.
    /// See `drawerIsBuilt`.
    ///
    /// **A raise before the page exists builds first and waits for it.** Not
    /// for a run-loop turn — `DispatchQueue.main.async` can still land the
    /// build and the spring in one update — but for the page's own
    /// `onAppear`, which cannot run until it has been laid out.
    private func raiseDrawer() {
        guard drawerIsBuilt else {
            raiseWhenBuilt = true
            buildDrawer()
            return
        }
        withAnimation(GridConstants.naturalSettle) { drawer = .full }
    }

    /// The page is on screen (off the bottom of it): now it can slide up.
    private func raiseNowThatItIsBuilt() {
        guard raiseWhenBuilt else { return }
        raiseWhenBuilt = false
        withAnimation(GridConstants.naturalSettle) { drawer = .full }
    }

    /// How long `naturalSettle` takes to come to rest, near enough.
    private static let springSettle: Duration = .milliseconds(700)

    /// Returns once the map's camera has been still for `prebuildDelay` AND
    /// the image store has had no visible work for 500ms, restarting either
    /// wait when it is broken. The gate for long main-actor work the person
    /// cannot see yet: the drawer's prebuild and the replay cards.
    ///
    /// Not while the map's own pictures are still being read: that work is a
    /// long main-actor frame, and landing it in the middle of a cold map's
    /// first reads is what held the blocks' pictures back by seconds. **Quiet
    /// for half a second, not quiet for an instant**: reading 320px
    /// derivatives, the store empties between landings, and a single check
    /// found it empty mid-load (measured: the build still landed a 390ms frame
    /// among 86 landings).
    private func waitForQuietMap() async {
        await mapMotion.waitUntilStill(for: Self.prebuildDelay)
        var quietSince = ContinuousClock.now
        while !Task.isCancelled, ContinuousClock.now - quietSince < .milliseconds(500) {
            if ThumbnailStore.shared.hasVisibleWork { quietSince = .now }
            try? await Task.sleep(for: .milliseconds(100))
            if mapMotion.stillFor < Self.prebuildDelay {
                await mapMotion.waitUntilStill(for: Self.prebuildDelay)
                quietSince = .now
            }
        }
    }

    /// Builds the page, never inside an animation.
    private func buildDrawer() {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) { drawerIsBuilt = true }
    }

    private func reloadReplays(redrawsStale: Bool, drawsMissing: Bool = true) async {
        await replays.reload(context: modelContext, colorScheme: colorScheme, displayScale: displayScale,
                             now: Date(), redrawsStale: redrawsStale && drawer != .hidden,
                             drawsMissing: drawsMissing)
    }

    // MARK: - Title

    private var titleRow: some View {
        // Top-aligned, not baseline-aligned.
        //
        // A `Text` and the gear are within a few points of each other in
        // height, so a baseline rule put both near the row's top. A DRAWING
        // is only as tall as its cap — 24pt against the gear's 44 — so the
        // row's top became the gear's top and the title fell 7.6pt below the
        // line every other header sits on. Measured. Aligning to the top
        // makes the title's top the row's top, which is what the shared
        // padding is measured against, and the gear is centred on the cap by
        // hand.
        HStack(alignment: .top, spacing: 8) {
            // No win tally. The count belongs to the tower's header; this
            // screen is about the photographs, not how many there are.
            // The owner's own letterforms, like the app's name on the
            // camera — see `MemoriesTitle`. Ink, not pink: the tally is the
            // one number the app states and it takes the brand colour, but a
            // page title in the same pink would put two shouts on a screen
            // whose subject is photographs.
            // Ink on the pale ground, white on imagery — see the wash below.
            MemoriesTitle(color: mapStyle == .quiet
                          ? AppColors.inkPrimary
                          : .white)
            Spacer(minLength: 0)
            // Shown when there are PHOTOGRAPHS, not when there are pins.
            //
            // Gating it on pins was a closed loop: the map only appeared once
            // wins had places, places only arrive once location is granted,
            // and the only screen that asks is the map. Nobody could ever get
            // in, so nobody would ever be asked, so the map would stay empty
            // forever. It opens on its own empty state instead, which is where
            // the asking belongs.
            // **The page, as a button.** It used to be the screen and the map
            // a route off it; both are inverted. There is nothing to open when
            // there are no photographs, and the map's own empty state is
            // already saying so.
            if !vm.gallery.isEmpty {
                overMap {
                    GlassIconButton(systemName: "photo.on.rectangle.angled",
                                    accessibilityLabel: "Photographs") {
                        raiseDrawer()
                    }
                }
                .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
            }
            // You, where the gear was. Settings lives inside Profile now, so
            // the header keeps the same number of buttons.
            overMap {
                ProfileButton { openProfile?() }
            }
            // Centred on the title's cap. It overhangs the row upwards, into
            // the safe-area gap, which is empty — the alternative is a row as
            // tall as the button with the title floating inside it.
            .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
        }
    }

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
                Button {
                    HapticsEngine.lightTap()
                    withAnimation(GridConstants.naturalSettle) { drawer = .hidden }
                } label: {
                    Text("Done")
                        .font(Typography.headerMedium)
                        // At AccessibilityXXXL this collapsed to a single "…"
                        // — the one control on the screen that gets you out of
                        // it, unreadable. It keeps its own width and the title
                        // beside it gives way instead.
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(AppColors.inkPrimary)
                        // Layout first, glass after.
                        .padding(.horizontal, GridConstants.gapLabel)
                        .frame(height: GlassIconButton.defaultSide)
                        .glassCapsule()
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                // Centred on the title's cap by hand. A drawn title is only as
                // tall as its cap, so a baseline or centre rule against a 44pt
                // control puts the title 7.6pt below the line every other
                // header sits on — measured, and recorded in CLAUDE.md.
                .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapItem)
            .padding(.bottom, GridConstants.gapTight)
        }
    }

    /// The chrome that floats on the map.
    ///
    /// **Always light, in both appearances.** These are `GlassIconButton`s, and
    /// glass follows the system — so in dark mode they became near-black discs
    /// sitting on a near-black map and effectively disappeared. The owner:
    /// "I cant see the place block thing at all in dark mode."
    ///
    /// The rule the camera already follows settles it: chrome over an IMAGE is
    /// light regardless of what the phone is set to, because the thing behind
    /// it is not the app's ground and does not flip with it. A map is that
    /// kind of surface. So the buttons are pinned to the light scheme and stay
    /// white on both the pale map and the night one.
    private func overMap<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content().environment(\.colorScheme, .light)
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
            MonthTowerView(
                packed: vm.month,
                width: monthGridWidth,
                onSelect: { path.append(.day($0)) },
                transitionNamespace: photoTransition
            )
            // **The slots the days sit in.**
            //
            // The same surface the Wins tab's tower stands on, from the same
            // shape, for the reason the owner gave for building it (2026-09-23,
            // about the tower): "they just don't feel like they fit when there
            // is a bunch of images... the easy fix would be to add structure
            // to the background, like a grid of some sort that helps structure
            // the screen." A month with photographs in half its days is that
            // same collage, and it was the last grid in the app still floating
            // on the bare page rather than filling cells.
            //
            // **`TowerLatticeShape`, not `TowerLattice`.** The view carries
            // three rows of overhang above its content and spends its fade in
            // them, which is right for a tower standing at the bottom of a
            // viewport and wrong inside a scrolling page: here the overhang
            // would reach up through the month picker and the page header. A
            // month is a CLOSED block of days, so its lattice is exactly its
            // own grid, every empty cell of the rectangle the days pack into
            // and nothing above it. Strength and fill are the lattice's own
            // tokens, so the two surfaces cannot drift apart.
            //
            // Safe as a background because `MonthTowerView`'s frame IS its
            // grid (`gridWidth` x `gridHeight`, with no cell cap), so the
            // cells this draws are the cells the blocks land in by
            // construction. `StaticTowerView` centres a capped grid inside a
            // wider frame, which is why the day screen's tower cannot be given
            // one from outside; that one belongs in the view itself.
            .background {
                TowerLatticeShape(cellSize: monthCell,
                                  spacing: GridConstants.spacing,
                                  columns: GridConstants.columnCount)
                    .fill(AppColors.quietFill.opacity(TowerLattice.strength))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, GridConstants.gapTight)
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
