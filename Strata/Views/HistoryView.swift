import SwiftUI
import SwiftData

/// Everything you have done, and a way back into any of it.
///
/// This replaces Insights. Insights drew a chart of past towers and made none
/// of it reachable: photographs went into the app and never came out, and
/// yesterday was somewhere you could see but not open. The chart is still
/// here, at the top, and it is now the fastest way into a day.
///
/// Below it the record is albums — one per day, grouped into weeks — after a
/// Figma of a photo-album grid. What did not come across from that design is
/// everything social in it (search over people, friend requests, invites):
/// Strata has no account and no server, and half-built social is exactly the
/// kind of dead end this pass exists to remove. Its search did come across,
/// pointed at your own wins.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm = HistoryViewModel()
    @State private var path: [DayRoute] = []

    var openSettings: (() -> Void)?

    /// Kept as `insightsRange` on purpose. Renaming the key would silently
    /// reset every existing user's chart span for no benefit; the screen it
    /// was named after is gone, the preference is the same preference.
    @AppStorage("insightsRange") private var rangeRaw: String = TowerFilterMode.day.rawValue
    private var range: TowerFilterMode {
        get { TowerFilterMode(rawValue: rangeRaw) ?? .day }
        nonmutating set { rangeRaw = newValue.rawValue }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 24, alignment: .top),
        GridItem(.flexible(), spacing: 24, alignment: .top)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    header
                        .padding(.horizontal, GridConstants.horizontalPadding)
                        .padding(.top, 4)

                    if vm.sections.isEmpty {
                        emptyState
                    } else {
                        chart
                        searchField
                            .padding(.horizontal, GridConstants.horizontalPadding)
                            .padding(.top, 6)
                        albums
                    }
                }
                .padding(.bottom, 110)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DayRoute.self) { DayAlbumDetailView(route: $0) }
        }
        .task {
            vm.reload(context: modelContext)
            #if DEBUG
            // Screenshot hook: the day screen is behind a tap on an album.
            if let back = DebugHarness.openDayBack,
               let date = Calendar.current.date(byAdding: .day, value: -back, to: Date()) {
                path.append(DayRoute(dateString: DateUtils.dateString(from: date)))
            }
            #endif
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("\(totalWins)")
                .font(.system(size: GridConstants.tallyNumeral, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .contentTransition(.numericText())
            Text(totalWins == 1 ? "win" : "wins")
                .font(.system(size: GridConstants.tallyWord, weight: .regular, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
            Spacer(minLength: 0)
            Button {
                HapticsEngine.lightTap()
                openSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .regular)
                    .foregroundStyle(.primary.opacity(0.45))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var totalWins: Int {
        vm.sections.reduce(0) { $0 + $1.albums.reduce(0) { $0 + $1.winCount } }
    }

    // MARK: - The chart, now a way in

    private var chart: some View {
        TowerBarChart(
            columns: chartColumns,
            maxRows: max(chartColumns.map(\.rows).max() ?? 0, 4),
            maxBarHeight: 130,
            // Small enough that a whole fortnight fits on screen. At the
            // default 34pt cell each bar is 150pt wide and two days fill the
            // width, which reads as two towers rather than as a stretch of
            // time.
            maxCell: 15,
            onSelect: { column in
                guard let key = column.dateString else { return }
                HapticsEngine.lightTap()
                path.append(DayRoute(dateString: key))
            }
        )
        .padding(.top, 12)
    }

    /// The last fourteen days, newest on the right, from what is already
    /// loaded. The chart is a reading of the same albums below it, so it does
    /// not fetch anything of its own.
    private var chartColumns: [TowerBarChart.Column] {
        let byDay = Dictionary(
            vm.sections.flatMap(\.albums).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        let calendar = Calendar.current
        let df = DateFormatter(); df.dateFormat = "EEEEE"
        return (0..<14).reversed().compactMap { back in
            guard let date = calendar.date(byAdding: .day, value: -back, to: Date())
            else { return nil }
            let key = DateUtils.dateString(from: date)
            return TowerBarChart.Column(
                id: key,
                label: df.string(from: date),
                isCurrent: back == 0,
                blocks: byDay[key]?.miniBlocks ?? [],
                dateString: key
            )
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.35))
                TextField("Search your wins", text: $vm.searchText)
                    .font(Typography.bodyLarge)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !vm.searchText.isEmpty {
                    Button { vm.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 43)
            .background(GridConstants.fillWell, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(GridConstants.fillHairline, lineWidth: 1)
            }

            // A filter, not a keyword. "photo" as a search term would collide
            // with a win actually called Photo, and this is a filter anyway.
            Button {
                HapticsEngine.lightTap()
                vm.photosOnly.toggle()
            } label: {
                Image(systemName: vm.photosOnly ? "photo.fill" : "photo")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary.opacity(vm.photosOnly ? 1 : 0.35))
                    .frame(width: 44, height: 43)
                    .background(
                        vm.photosOnly ? GridConstants.fillTrack : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vm.photosOnly ? "Showing days with photos" : "Show only days with photos")
        }
    }

    // MARK: - Albums

    @ViewBuilder
    private var albums: some View {
        if vm.visibleSections.isEmpty {
            Text("Nothing matches that.")
                .font(Typography.bodySmall)
                .foregroundStyle(.primary.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else {
            ForEach(vm.visibleSections) { section in
                Text(section.title)
                    .font(Typography.caption2)
                    .kerning(0.8)
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, 28)
                    .padding(.bottom, 10)

                LazyVGrid(columns: columns, spacing: 26) {
                    ForEach(section.albums) { album in
                        NavigationLink(value: DayRoute(dateString: album.id)) {
                            AlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
            }

            // Paging sentinel: reaching it loads the next eight weeks.
            if !vm.reachedEnd && vm.searchText.isEmpty && !vm.photosOnly {
                Color.clear
                    .frame(height: 1)
                    .onAppear { vm.loadNextPage(context: modelContext) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Nothing here yet")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Days you log wins show up here.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

/// One album in the grid: the cover, the day, the date.
private struct AlbumCard: View {
    let album: DayAlbum

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                AlbumCoverView(album: album, side: geo.size.width)
                Text(album.title)
                    .font(Typography.headerLarge)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                    .padding(.top, 13)
                Text(album.dateLabel)
                    .font(Typography.caption2)
                    .kerning(0.6)
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.top, 3)
            }
        }
        .frame(height: cardHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.title), \(album.dateLabel), \(album.winCount) wins")
    }

    /// Cover (3:4) plus the two lines under it.
    private var cardHeight: CGFloat {
        let coverSide = (UIScreen.main.bounds.width - GridConstants.horizontalPadding*2 - 24) / 2
        return coverSide / AlbumCoverView.aspect + 62
    }
}
