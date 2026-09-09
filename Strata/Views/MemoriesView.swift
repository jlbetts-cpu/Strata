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
    private static let titleSize: CGFloat = 48

    @Environment(\.modelContext) private var modelContext
    @State private var vm = MemoriesViewModel()
    @State private var path: [MemoriesRoute] = []

    var openSettings: (() -> Void)?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    titleRow
                        .padding(.horizontal, GridConstants.horizontalPadding)
                        .padding(.top, GridConstants.headerTopPadding(forTitleSize: Self.titleSize))

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
                        Section {
                            monthTower
                        } header: {
                            monthHeader
                        }

                        sectionLabel("ALBUMS")
                        shelf
                    }
                }
                .padding(.bottom, 110)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MemoriesRoute.self) { route in
                switch route {
                case .day(let key):
                    DayAlbumDetailView(route: DayRoute(dateString: key))
                case .curated(let key):
                    CuratedAlbumView(titleKey: key)
                case .allAlbums:
                    AllAlbumsView(vm: vm) { path.append(.day($0)) }
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
            if DebugHarness.opensAllAlbums { path.append(.allAlbums) }
            #endif
        }
    }

    // MARK: - Title

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // No win tally. The count belongs to the tower's header; this
            // screen is about the photographs, not how many there are.
            Text("Memories")
                .font(.system(size: Self.titleSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
            Spacer(minLength: 0)
            GlassIconButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                openSettings?()
            }
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 12 }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .kerning(0.8)
            .foregroundStyle(.primary.opacity(0.35))
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, 30)
            .padding(.bottom, 12)
    }

    // MARK: - The shelf

    private var shelf: some View {
        AlbumCarousel(
            albums: vm.carousel,
            onSelect: { route in
                switch route {
                case .day(let key):     path.append(.day(key))
                case .curated(let key): path.append(.curated(key))
                }
            },
            onSeeAll: { path.append(.allAlbums) }
        )
    }

    // MARK: - The month

    private var monthHeader: some View {
        MonthPicker(
            title: vm.monthTitle,
            canGoBack: vm.canGoBack,
            canGoForward: vm.canGoForward,
            onBack: { withAnimation(GridConstants.crossFade) { vm.step(months: -1, context: modelContext) } },
            onForward: { withAnimation(GridConstants.crossFade) { vm.step(months: 1, context: modelContext) } }
        )
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 8)
        // A pinned header sits over content that scrolls beneath it, so it
        // needs an opaque ground and a hit shape of its own — without them the
        // blocks passing under it take the taps meant for the chevrons.
        .background { WarmBackground() }
        .contentShape(Rectangle())
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
            .padding(.top, 8)
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

/// Where the Memories tab can go.
enum MemoriesRoute: Hashable {
    case day(String)
    case curated(String)
    case allAlbums
}
