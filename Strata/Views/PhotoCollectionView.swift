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
        /// One block on the map — see `PlaceMap.PlaceKey`.
        case place(PlaceMap.PlaceKey)
    }

    let source: Source

    @Environment(\.modelContext) private var modelContext
    @State private var sections: [GallerySection] = []
    @State private var title = ""
    /// Whether `title` is the fallback count rather than a name, so the header
    /// does not state the same number twice. Only a place can be in that
    /// state, and only until its name arrives.
    @State private var titleIsCount = false
    /// A place whose name has not arrived yet. Set by `load()`, cleared by the
    /// task that asks for it.
    @State private var pending: WinPlace?
    @State private var viewing: ViewedPhoto?
    @Namespace private var photoTransition

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                // The heading would have carried the gap; without it, the
                // grid keeps the same distance from the header on its own.
                if PhotoGalleryGrid.headingRepeatsTitle(sections, title: title) {
                    Color.clear.frame(height: GridConstants.gapWide)
                }
                PhotoGalleryGrid(sections: sections,
                                 transitionNamespace: photoTransition,
                                 onSelect: { viewing = ViewedPhoto(id: $0.fileName, title: $0.title) },
                                 screenTitle: title)
            }
                .padding(.bottom, GridConstants.tabBarClearance)
        }
        .background { WarmBackground().ignoresSafeArea() }
        // **The Day page's header, not a system inline title.** Both screens
        // open from the same Albums shelf, and one put a 34pt title under the
        // back button while the other put a 17pt one beside it, with its cap
        // 46pt higher. One header for every album.
        .navigationTitle("")
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
            if let name = PlaceNames.shared.name(for: place) {
                title = name
                titleIsCount = false
            }
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

    // MARK: - Header

    /// `DayAlbumDetailView.header`'s shape: the screen title, and a count
    /// under it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // A place name: the owner's face only when it covers every
            // letter and fits (`DynamicScreenTitle`), SF otherwise.
            DynamicScreenTitle(text: title)
                .foregroundStyle(AppColors.inkPrimary)
            // **The count is a readout**, line for line the way
            // `DayAlbumDetailView` sets its own: the digits are the owner's
            // face, tabular, and the word beside them is SF at the subtitle
            // size (`design-system-future.md` §2). It was one interpolated
            // string in SF, so the only number on this screen was the only
            // count in the app that was not his digits, sitting above a grid
            // opened from the same shelf as the day page, whose count is.
            //
            // `StrataFont.digits`, never `Text("\(n)")`: interpolation is a
            // `LocalizedStringKey` and groups 1000 as "1,000", and the face
            // has no comma. No optical inset, for the day page's reason: at
            // 15pt the face's mean left bearing works out near 1pt.
            HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
                Text(verbatim: StrataFont.digits(photoCount))
                    .font(StrataFont.relative(Self.countSize, to: .subheadline))
                Text(photoCount == 1 ? "photo" : "photos")
                    .font(Typography.screenSubtitle)
            }
            .foregroundStyle(AppColors.inkQuiet)
            .accessibilityElement(children: .combine)
            // **Hidden when the title is already the count.** A place whose
            // name has not arrived is titled "12 here" (see `load()`), and
            // under it this line said "12 photos": one number twice, ten
            // points apart, in two different faces. §7 asks a screen to say
            // how much is here once. The name replaces the title when it
            // lands, and the line comes back with it.
            //
            // Opacity rather than an `if`, so the box stays reserved and the
            // title does not move when the name arrives.
            .opacity(sections.isEmpty || titleIsCount ? 0 : 1)
            .accessibilityHidden(sections.isEmpty || titleIsCount)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
    }

    /// The subheadline's own default size, so the digits and the word beside
    /// them are one line of type rather than two sizes agreeing by accident.
    /// `DayAlbumDetailView`'s number, and the two have to stay the same.
    private static let countSize: CGFloat = 15

    private var photoCount: Int { sections.reduce(0) { $0 + $1.photos.count } }

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
        titleIsCount = false
        switch source {
        case .interest(let key):
            matching = records.filter { $0.hasPhoto && Album.titleKey($0.title) == key }
            title = matching.first?.title ?? key
        case .place(let key):
            // Exactly the photographs the block stood for — see
            // `PlaceMap.members(of:in:)`.
            let names = Set(PlaceMap.members(of: key, in: PlaceMap.pins(from: records))
                .map(\.photoFileName))
            matching = records.filter { $0.photoFileName.map(names.contains) ?? false }
            // **The place's own name, once it arrives.** "12 here" is a count;
            // "Trafalgar Square" is an answer. It is a network call and it can
            // fail, so the count is what the screen opens on and the name
            // replaces it if it comes — see `PlaceNames`.
            if let place = matching.compactMap(\.place).first {
                if let name = PlaceNames.shared.name(for: place) {
                    title = name
                } else {
                    title = "\(matching.count) here"
                    titleIsCount = true
                }
                pending = place
            } else {
                title = "\(matching.count) here"
                titleIsCount = true
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
