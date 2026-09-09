import SwiftUI
import SwiftData

/// A run of photographs, opened from a card on the shelf.
///
/// One screen for both kinds of card, because they differ only in which
/// photographs they gather: a repeated interest gathers by title, a moment
/// gathers by date. Neither is a day, so neither has a tower — what a card
/// promised was pictures, and this is the pictures.
///
/// It takes a SOURCE, not a list. Handing it the album would tie the screen to
/// whatever the shelf happened to be holding when you tapped; re-deriving from
/// the store is the same reason `DayRoute` carries a date string.
struct PhotoCollectionView: View {
    enum Source: Hashable {
        /// A normalised win title — see `Album.titleKey`.
        case interest(String)
        /// An `AlbumMoment` id.
        case moment(String)
    }

    let source: Source

    @Environment(\.modelContext) private var modelContext
    @State private var sections: [GallerySection] = []
    @State private var title = ""
    @State private var viewing: String?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            PhotoGalleryGrid(sections: sections) { viewing = $0.fileName }
                .padding(.bottom, 110)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .fullScreenCover(item: Binding(
            get: { viewing.map(Viewed.init) },
            set: { viewing = $0?.id }
        )) { photo in
            PhotoViewer(fileName: photo.id) { viewing = nil }
        }
    }

    private struct Viewed: Identifiable { let id: String }

    private func load() {
        var descriptor = FetchDescriptor<HabitLog>()
        descriptor.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        let records = Album.records(from: logs)
        let now = Date()

        let matching: [WinRecord]
        switch source {
        case .interest(let key):
            matching = records.filter { $0.hasPhoto && Album.titleKey($0.title) == key }
            title = matching.first?.title ?? key
        case .moment(let id):
            guard let moment = AlbumMoment(id: id) else { sections = []; return }
            matching = records.filter {
                $0.hasPhoto && moment.contains($0.completedAt, calendar: calendar, now: now)
            }
            title = moment.title(calendar: calendar, now: now)
        }

        sections = Album.gallerySections(Album.gallery(from: matching),
                                         calendar: calendar, now: now)
    }
}
