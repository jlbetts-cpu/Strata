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
        /// One cell of the place grid — see `PlaceMap.PlaceKey`.
        case place(PlaceMap.PlaceKey)
    }

    let source: Source

    @Environment(\.modelContext) private var modelContext
    @State private var sections: [GallerySection] = []
    @State private var title = ""
    /// A place whose name has not arrived yet. Set by `load()`, cleared by the
    /// task that asks for it.
    @State private var pending: WinPlace?
    @State private var viewing: ViewedPhoto?
    @Namespace private var photoTransition

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            PhotoGalleryGrid(sections: sections,
                             transitionNamespace: photoTransition) {
                viewing = ViewedPhoto(id: $0.fileName, title: $0.title)
            }
                .padding(.bottom, 110)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // **The bar gets a ground.** The grid is edge to edge, so without one
        // the photographs slide under the title and the back chevron and both
        // sit on whatever picture happens to be passing — which is what the
        // owner photographed. A navigation bar is the one place in this app
        // that is allowed a material: it is the system's own chrome, not a
        // card of ours pretending to be a block.
        .toolbarBackground(.visible, for: .navigationBar)
        .task { load() }
        // Asking is a network call and it is allowed to fail. The screen is
        // already correct without it; the name is something it gains.
        .task(id: pending.map(PlaceNames.key(for:))) {
            guard let place = pending else { return }
            await PlaceNames.shared.resolve(place)
            if let name = PlaceNames.shared.name(for: place) { title = name }
            pending = nil
        }
        .fullScreenCover(item: $viewing) { photo in
            PhotoViewer(photos: sections.flatMap(\.photos),
                        startAt: photo.id,
                        onClose: { viewing = nil },
                        onDelete: { _ in load() })
                .navigationTransition(.zoom(sourceID: photo.id, in: photoTransition))
        }
    }

    private func load() {
        // **Only rows that could possibly appear here.**
        //
        // This fetched EVERY log the store has ever held and then filtered in
        // Swift — and every screen it opens is a screen of photographs, so
        // every row without one was materialised, prefetched through its
        // relationship, and thrown away. On a year of daily wins that is
        // hundreds of objects built to show none of them. `imageFileName !=
        // nil` is the same test `MemoriesViewModel.loadCarousel` already uses
        // for the same reason.
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.imageFileName != nil && $0.completed }
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        let records = Album.records(from: logs)
        let now = Date()

        let matching: [WinRecord]
        switch source {
        case .interest(let key):
            matching = records.filter { $0.hasPhoto && Album.titleKey($0.title) == key }
            title = matching.first?.title ?? key
        case .place(let key):
            // Widened to the cell PLUS a half-cell margin. A cell is a
            // geographic identity, not a place identity, so two photographs
            // twenty metres apart can straddle a boundary — and "my two photos
            // of the same cafe are in different piles" is a bad bug. The map
            // draws crisp cells; opening one is generous.
            let names = Set(PlaceMap.members(of: key, in: PlaceMap.pins(from: records))
                .map(\.photoFileName))
            matching = records.filter { $0.photoFileName.map(names.contains) ?? false }
            // **The place's own name, once it arrives.** "12 here" is a count;
            // "Trafalgar Square" is an answer. It is a network call and it can
            // fail, so the count is what the screen opens on and the name
            // replaces it if it comes — see `PlaceNames`.
            if let place = matching.compactMap(\.place).first {
                title = PlaceNames.shared.name(for: place) ?? "\(matching.count) here"
                pending = place
            } else {
                title = "\(matching.count) here"
            }
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
