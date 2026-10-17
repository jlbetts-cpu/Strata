import SwiftUI

/// **Photographs on a card, three across** (the owner, 2026-10-16: "the
/// photos should be laid out like the recent photos in the crew's profile,
/// in three containers for deep, medium and quick"). The title inside the
/// card's top, then square photographs at the tower's gap, each a tap to
/// open. The one grid of photographs on a card: Memories' month, a friend's
/// recent photos.
struct PhotoGridCard: View {
    let title: String
    let pictures: [(id: String, picture: BannerPicture)]
    /// **The Photos grid** (the owner's launch pass, 1: "the Deep, Regular
    /// and Quick photos go back to the Apple Photos look"): square photos a
    /// hairline apart, edge to edge in the card, as Photos lays its library.
    /// The columns keep the three sizes readable: a deep moment gets a
    /// bigger tile than a quick one. Nil keeps the tower's gap and corners
    /// (a friend's recent photos).
    var photosColumns: Int? = nil
    var onSelect: (String) -> Void

    private var asPhotos: Bool { photosColumns != nil }

    var body: some View {
        let gap: CGFloat = asPhotos ? 2 : GridConstants.spacing
        let corner: CGFloat = asPhotos ? 0 : GridConstants.cornerRadius
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            Text(title)
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(asPhotos ? [.horizontal, .top] : [], PageCard.inset)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: photosColumns ?? 3), spacing: gap) {
                ForEach(pictures, id: \.id) { item in
                    Button {
                        HapticsEngine.lightTap()
                        onSelect(item.id)
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                GeometryReader { geo in
                                    switch item.picture {
                                    case let .mine(file):
                                        CachedImageView(fileName: file, width: geo.size.width, height: geo.size.height,
                                                        cornerRadius: corner)
                                    case let .theirs(url):
                                        CrewPhotoView(url: url, width: geo.size.width, height: geo.size.height)
                                            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                                    }
                                }
                            }
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel("Photo")
                    .accessibilityHint("Opens it full screen.")
                }
            }
        }
        .padding(asPhotos ? 0 : PageCard.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
        .pageCard()
    }
}
