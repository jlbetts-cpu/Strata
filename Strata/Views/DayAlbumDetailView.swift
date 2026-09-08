import SwiftUI
import SwiftData

/// One day, opened: the tower you built that day, and the photographs on it.
struct DayAlbumDetailView: View {
    let route: DayRoute

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// A SECOND tower view model, private to this screen.
    ///
    /// `buildTower` is not a pure function — it writes `placedBlocks`,
    /// `mergeGroups`, `newlyDroppedIDs`, `previousBlockIDs` and the stagger
    /// cache straight onto the instance, and schedules a cleanup task. Calling
    /// it on the live `towerVM` for a past day would leave the Wins tab
    /// showing yesterday. A fresh instance is safe: it is a plain `@Observable`
    /// class that takes logs and gives back geometry.
    ///
    /// `MiniTowerPacker` would not do here — it yields `MiniBlock`, which
    /// carries no `HabitLog`, so the block faces (photo, title, icon) cannot be
    /// drawn. It stays the right tool for the covers.
    @State private var vm = TowerViewModel()
    @State private var logs: [HabitLog] = []
    @State private var viewing: String?

    private var photos: [String] {
        logs.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap(\.imageFileName)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                tower
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                if !photos.isEmpty { photoGrid }
            }
            .padding(.bottom, 110)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let key = route.dateString
            var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == key })
            d.relationshipKeyPathsForPrefetching = [\.habit]
            logs = (try? modelContext.fetch(d)) ?? []
            _ = vm.buildTower(from: logs, filterMode: .day)
        }
        .fullScreenCover(item: Binding(
            get: { viewing.map(PhotoID.init) },
            set: { viewing = $0?.id }
        )) { photo in
            PhotoViewer(fileName: photo.id) { viewing = nil }
        }
    }

    private struct PhotoID: Identifiable { let id: String }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: GridConstants.tallyNumeral * 0.52,
                              weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                // One line. "Saturday 5 September" wrapping to two puts the
                // win count halfway down the screen and pushes the tower with
                // it; the date is a label, not a headline.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(logs.count) \(logs.count == 1 ? "win" : "wins")")
                .font(Typography.bodySmall)
                .foregroundStyle(.primary.opacity(0.35))
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
    }

    private var title: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: route.dateString) else { return route.dateString }
        let out = DateFormatter()
        out.dateFormat = "EEEE d MMMM"
        return out.string(from: date)
    }

    // MARK: - The day's tower

    /// Rendered outside the tower tab, so the two environment values the block
    /// views read have to be supplied by hand — there is nothing to inherit
    /// them from here. `TowerShare` learned this the same way.
    private var tower: some View {
        StaticTowerView(
            blocks: vm.placedBlocks,
            mergeGroups: vm.mergeGroups,
            groupedIDs: vm.groupedBlockIDs,
            coveredIDs: vm.coveredBlockIDs,
            modelContext: modelContext,
            maxCell: 74
        )
        .environment(\.towerFilterMode, .day)
        .environment(\.perfectDayDates, [])
    }

    // MARK: - Photographs

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHOTOS")
                .font(Typography.caption2)
                .kerning(0.8)
                .foregroundStyle(.primary.opacity(0.35))
                .padding(.horizontal, GridConstants.horizontalPadding)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ], spacing: 6) {
                ForEach(photos, id: \.self) { name in
                    Button { HapticsEngine.lightTap(); viewing = name } label: {
                        CachedImageView(fileName: name, width: 118, height: 118,
                                        cornerRadius: GridConstants.radiusControl)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusControl,
                                                        style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
        }
        .padding(.top, 40)
    }
}

/// One photograph, full size.
private struct PhotoViewer: View {
    let fileName: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CachedImageView(fileName: fileName, width: UIScreen.main.bounds.width,
                            height: UIScreen.main.bounds.height, cornerRadius: 0,
                            fullResolution: true)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            GlassIconButton(
                systemName: "xmark",
                tint: .white,
                glyphSize: 16,
                accessibilityLabel: "Close photo",
                action: onClose
            )
            // Clear of the status bar and the Dynamic Island — a close button
            // at y=34 in screen coordinates is not pressable, which this app
            // has already learned once.
            .padding(.top, 58)
            .padding(.trailing, 16)
        }
        .statusBarHidden()
    }
}
