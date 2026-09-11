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
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = MemoriesViewModel()
    @State private var path: [MemoriesRoute] = []
    @State private var viewing: ViewedPhoto?
    /// Ties each thumbnail to the viewer that opens out of it.
    @Namespace private var photoTransition
    /// How far the page is pulled up over the map. **Hidden on arrival** —
    /// the tab opens on the map, whole, and the photographs are the button in
    /// the corner.
    @State private var drawer: DrawerDetent = .hidden
    /// Whether the month tower is still on screen.
    ///
    /// The picker governs the tower and nothing else — the albums below it and
    /// the camera roll under those span every month there is. So once the
    /// tower has scrolled away the picker is a control with nothing to
    /// control, sitting at the top of a page it has no authority over. The
    /// owner put it exactly: it "is not associated with anything but the
    /// tower".
    ///
    /// It does not SCROLL away — a control that moves while you scroll the
    /// thing it controls is the bug this page already had. It goes quiet
    /// instead, and comes back when the tower does.
    @State private var towerOnScreen = true

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
                        if vm.carousel.isEmpty && vm.month.isEmpty {
                            emptyState
                        } else {
                            // The month leads. It used to open on a search
                            // field, then a shelf of photo cards, with the
                            // month tower — the one element on this page that
                            // is unmistakably this app — starting around 60%
                            // down and cut off by the tab bar.
                            monthTower
                        }
                    } header: {
                        if !(vm.carousel.isEmpty && vm.month.isEmpty) { monthHeader }
                    }

                    if !(vm.carousel.isEmpty && vm.month.isEmpty) {
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
                .padding(.bottom, GridConstants.tabBarClearance)
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
                overMap {
                    GlassIconButton(systemName: "photo.on.rectangle.angled",
                                    accessibilityLabel: "Photographs") {
                        withAnimation(GridConstants.naturalSettle) { drawer = .full }
                    }
                }
                .offset(y: (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2)
            }
            overMap {
                GlassIconButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                    openSettings?()
                }
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
                        // At AccessibilityXXXL this collapsed to a single "…"
                        // — the one control on the screen that gets you out of
                        // it, unreadable. It keeps its own width and the title
                        // beside it gives way instead.
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
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
                ForEach(Array(ghosts.enumerated()), id: \.offset) { index, g in
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
                        // They fade up in order, so the page arrives rather
                        // than appearing.
                        .opacity(0.9)
                        .animation(GridConstants.gentleReveal.delay(Double(index) * 0.06),
                                   value: vm.month.isEmpty)
                }
            }
            .frame(width: 3 * cell + 2 * gutter, height: 3 * cell + 2 * gutter)

            VStack(spacing: GridConstants.gapTight) {
                Text("Your first month starts here")
                    .font(Typography.headerMedium)
                    .foregroundStyle(.primary.opacity(0.85))
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
