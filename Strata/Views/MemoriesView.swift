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
    /// 48pt, from the lowfi. Named because the header's top padding is solved
    /// from it — a title's cap sits further down its layout box the bigger it
    /// is, so the two cannot be set independently.
    @Environment(\.modelContext) private var modelContext
    @State private var vm = MemoriesViewModel()
    @State private var path: [MemoriesRoute] = []
    @State private var viewing: ViewedPhoto?
    /// Ties each thumbnail to the viewer that opens out of it.
    @Namespace private var photoTransition
    /// How far the page is pulled up over the map. **Hidden on arrival** —
    /// the tab opens on the map, whole, and the photographs are the button in
    /// the corner.
    @State private var drawer: DrawerDetent = .hidden

    /// Which ground the map draws on. Two are possible and MapKit allows no
    /// third, so the choice is made by looking rather than by arguing —
    /// `-strataMapStyle satellite` renders the other one.
    private var mapStyle: MemoriesMapView.Style {
        #if DEBUG
        return DebugHarness.mapStyle
        #else
        return .quiet
        #endif
    }

    var openSettings: (() -> Void)?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
            // **The map is the tab.**
            //
            // The page used to be the screen and the map a route off it. The
            // owner's call is that the map is the feature, so it is the ground
            // now and everything the tab used to be is a drawer over it —
            // Apple Maps' own anatomy, and the only arrangement that gives the
            // map the whole screen without losing anything.
            MemoriesMapView(pins: vm.pins, style: mapStyle) { key in
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
                    LinearGradient(
                        colors: [AppColors.warmBlack.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 190)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }

            MemoriesDrawer(detent: $drawer) {
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
                LazyVStack(alignment: .leading, spacing: 0) {
                    if vm.carousel.isEmpty && vm.month.isEmpty {
                        emptyState
                    } else {
                        // The month leads.
                        //
                        // It used to open on a search field, then a shelf of
                        // photo cards, and the month tower — the one element
                        // on the page that is unmistakably this app — started
                        // around 60% down and was cut off by the tab bar. The
                        // page now opens on the thing worth looking at, and
                        // the photographs sit under it.
                        monthTower

                        // No heading over a gap. When nothing has earned a
                        // card the shelf is not drawn at all — only what there
                        // is to show gets shown.
                        if !vm.carousel.isEmpty {
                            sectionLabel("ALBUMS")
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
                .padding(.bottom, 110)
                .id("MemoriesContent")
            }
            #if DEBUG
            .task {
                guard DebugHarness.scrollsMemories else { return }
                try? await Task.sleep(for: .seconds(3))
                withAnimation(nil) {
                    proxy.scrollTo(DebugHarness.scrollsMemories && DebugHarness.scrollTarget == "shelf"
                                   ? "MemoriesShelf" : "MemoriesContent", anchor: .top)
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
            }
            .ignoresSafeArea(edges: .bottom)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $viewing) { photo in
                // The whole roll, so the next photograph is a swipe away.
                PhotoViewer(photos: vm.gallery.flatMap(\.photos),
                            startAt: photo.id,
                            onClose: { viewing = nil },
                            onDelete: { _ in vm.reload(context: modelContext) })
                    // Out of the thumbnail, not up from the bottom.
                    .navigationTransition(.zoom(sourceID: photo.id, in: photoTransition))
            }
            .navigationDestination(for: MemoriesRoute.self) { route in
                switch route {
                case .map:
                    MemoriesMapView(pins: vm.pins, style: mapStyle) { key in
                        path.append(.place(key))
                    }
                    .ignoresSafeArea()
                    .toolbar(.hidden, for: .navigationBar)
                case .day(let key):
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
        .task {
            vm.reload(context: modelContext)
            #if DEBUG
            if let detent = DebugHarness.openDrawer { drawer = detent }
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
                          ? .primary.opacity(0.85)
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
                GlassIconButton(systemName: "photo.on.rectangle.angled",
                                accessibilityLabel: "Photographs") {
                    withAnimation(GridConstants.naturalSettle) { drawer = .full }
                }
                .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
            }
            GlassIconButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                openSettings?()
            }
            // Centred on the title's cap. It overhangs the row upwards, into
            // the safe-area gap, which is empty — the alternative is a row as
            // tall as the button with the title floating inside it.
            .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        SectionHeading(text: text)
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

    /// The page's own header: what this is, how to leave, and which month.
    ///
    /// The title used to live only on the map, so the page you pulled up over
    /// it was unnamed — the owner's call is that "that section also needs the
    /// memories title", and it is right: a screen that fills the display and
    /// says nothing about itself is a screen you have to remember your way
    /// out of. `Done` is the way out, stated rather than implied by a drag.
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                MemoriesTitle(color: .primary.opacity(0.85))
                Spacer(minLength: 0)
                Button {
                    HapticsEngine.lightTap()
                    withAnimation(GridConstants.naturalSettle) { drawer = .hidden }
                } label: {
                    Text("Done")
                        .font(Typography.headerMedium)
                        .foregroundStyle(.primary.opacity(0.85))
                        // Layout first, glass after.
                        .padding(.horizontal, 18)
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

            monthHeader
        }
    }

    private var monthHeader: some View {
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
        // Aligned to the page margin, less the menu label's own 10pt inset,
        // so the WORD lines up with the title above it and with every heading
        // below it rather than the tap target's edge doing.
        .padding(.horizontal, GridConstants.horizontalPadding - 10)
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

    @ViewBuilder
    private var monthTower: some View {
        if vm.month.isEmpty {
            Text("No wins in \(vm.monthTitle.capitalized).")
                .font(Typography.bodySmall)
                .foregroundStyle(.primary.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        } else {
            MonthTowerView(
                packed: vm.month,
                width: UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2,
                onSelect: { path.append(.day($0)) }
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, GridConstants.gapTight)
            // The month is REPLACED, not moved, so it cross-fades. A spring
            // would claim the blocks travelled somewhere.
            .id(vm.monthTitle)
            .transition(.opacity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Nothing here yet")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Photos you take show up here.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
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
    /// One place, and everything you did there. A `PlaceKey` is three `Int`s,
    /// so this is a route rather than a payload — `PhotoCollectionView`
    /// re-derives the photographs from the store, which is the contract that
    /// file already documents.
    case place(PlaceMap.PlaceKey)
    case day(String)
    case curated(String)
    case moment(String)
}
