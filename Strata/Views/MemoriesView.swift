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

    var openSettings: (() -> Void)?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    titleRow
                        .padding(.horizontal, GridConstants.horizontalPadding)
                        // Artwork, not type: `headerArtworkTopPadding`. The
                        // other version subtracts the distance a `Text` sets
                        // its cap below its own layout box, and a drawing has
                        // no ascender to give back.
                        .padding(.top, GridConstants.headerArtworkTopPadding)

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
                        monthHeader
                        monthTower

                        // No heading over a gap. When nothing has earned a
                        // card the shelf is not drawn at all — only what there
                        // is to show gets shown.
                        if !vm.carousel.isEmpty {
                            sectionLabel("ALBUMS")
                            shelf
                        }

                        // Edge to edge. Every other thing on this page is
                        // inset to the page margin; the camera roll is the one
                        // that is not, because a photo grid with a margin is a
                        // set of cards.
                        PhotoGalleryGrid(sections: vm.gallery) { photo in
                            viewing = ViewedPhoto(id: photo.fileName, title: photo.title)
                        }
                    }
                }
                .padding(.bottom, 110)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $viewing) { photo in
                PhotoViewer(fileName: photo.id, title: photo.title) { viewing = nil }
            }
            .navigationDestination(for: MemoriesRoute.self) { route in
                switch route {
                case .day(let key):
                    DayAlbumDetailView(route: DayRoute(dateString: key))
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
            MemoriesTitle(color: .primary.opacity(0.85))
            Spacer(minLength: 0)
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
        Text(text)
            .font(Typography.sectionLabel)
            .kerning(Typography.sectionKerning)
            .foregroundStyle(.primary.opacity(0.35))
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapSection)
            .padding(.bottom, GridConstants.gapLabel)
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

    private var monthHeader: some View {
        MonthPicker(
            title: vm.monthTitle,
            canGoBack: vm.canGoBack,
            canGoForward: vm.canGoForward,
            months: vm.availableMonths,
            titleFor: { vm.title(for: $0) },
            onSelect: { month in
                withAnimation(GridConstants.crossFade) {
                    vm.select(month: month, context: modelContext)
                }
            },
            onBack: { withAnimation(GridConstants.crossFade) { vm.step(months: -1, context: modelContext) } },
            onForward: { withAnimation(GridConstants.crossFade) { vm.step(months: 1, context: modelContext) } }
        )
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapTight)
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
    case day(String)
    case curated(String)
    case moment(String)
}
