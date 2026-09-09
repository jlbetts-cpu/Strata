import SwiftUI

/// The shelf of albums: things you keep doing, then your days.
///
/// A horizontal shelf inside the page's vertical scroll. Orthogonal axes nest
/// fine — what does not is an anchor. `.defaultScrollAnchor` takes a
/// `UnitPoint`, which always carries BOTH axes, and the y component leaks to
/// the enclosing scroll view; that is exactly how the old bar chart pulled the
/// page down under itself. The carousel wants its leading edge, which is the
/// default, so the correct amount of anchoring code here is none.
struct AlbumCarousel: View {
    let albums: [Album]
    var onSelect: (AlbumRoute) -> Void = { _ in }

    /// Two tower cells across, so a cover on the shelf is the same size as a
    /// 2x2 on the tower above it. Derived rather than typed: on any screen the
    /// shelf and the tower agree.
    private var cardWidth: CGFloat {
        let cell = GridConstants.cellSize(
            forGridWidth: UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2)
        return cell * 2 + GridConstants.spacing
    }
    /// `gapItem`, not the lowfi's 15. A shelf of cards is a set of items and
    /// takes the same step the photo grid does.
    private let gap: CGFloat = GridConstants.gapItem

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Lazy, not an HStack. Each card fans up to three photographs, so
            // an eager stack of 24 builds 72 thumbnails at once — well past
            // `ImageManager`'s cache budget, which then evicts and re-decodes
            // on every pass. Laziness is also what makes
            // `CachedImageView.onDisappear` fire and give the memory back.
            LazyHStack(alignment: .top, spacing: gap) {
                ForEach(albums) { album in
                    Button {
                        HapticsEngine.lightTap()
                        onSelect(album.route)
                    } label: {
                        AlbumCard(album: album, width: cardWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, GridConstants.horizontalPadding)
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

/// One album: the fan, its name, and what it is.
private struct AlbumCard: View {
    let album: Album
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AlbumCoverView(photoFileNames: album.photoFileNames, side: width)
            Text(album.title)
                .font(Typography.headerLarge)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
                .padding(.top, GridConstants.gapItem)
            Text(album.subtitle)
                .font(Typography.sectionLabel)
                .kerning(Typography.sectionKerning)
                .foregroundStyle(.primary.opacity(0.35))
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.title), \(album.subtitle)")
    }
}
