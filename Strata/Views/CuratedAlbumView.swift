import SwiftUI
import SwiftData

/// A thing you keep doing, and every photograph of it.
///
/// Not a tower. A curated album is not a day, so it has no packing and no
/// shape of its own — what it has is a run of photographs across weeks, which
/// is what the grid shows.
///
/// It takes a title KEY and fetches its own logs, rather than being handed the
/// album. Same reason `DayRoute` gives: a screen that depends on what the
/// carousel happens to be holding breaks the moment the carousel is rebuilt.
struct CuratedAlbumView: View {
    let titleKey: String

    @Environment(\.modelContext) private var modelContext
    @State private var photos: [String] = []
    @State private var title: String = ""
    @State private var viewing: String?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(photos, id: \.self) { name in
                    Button {
                        HapticsEngine.lightTap()
                        viewing = name
                    } label: {
                        GeometryReader { geo in
                            CachedImageView(
                                fileName: name,
                                width: geo.size.width,
                                height: geo.size.width,
                                cornerRadius: 6
                            )
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .fullScreenCover(item: Binding(
            get: { viewing.map(PhotoID.init) },
            set: { viewing = $0?.id }
        )) { photo in
            PhotoViewer(fileName: photo.id) { viewing = nil }
        }
    }

    private struct PhotoID: Identifiable { let id: String }

    private func load() {
        var d = FetchDescriptor<HabitLog>()
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? modelContext.fetch(d)) ?? []
        let matching = Album.records(from: logs)
            .filter { $0.hasPhoto && Album.titleKey($0.title) == titleKey }
            .sorted { $0.completedAt > $1.completedAt }
        photos = matching.compactMap(\.photoFileName)
        title = matching.first?.title ?? titleKey
    }
}
