import SwiftUI

/// An album's cover: its photographs, fanned like a stack of prints.
///
/// The fan is measured off the Figma (`V5Wzqyca2nwllAtzeHjLnm`, node
/// `13603:10375`) rather than eyeballed — the back layer turned 2.27° and
/// dropped to half opacity, the middle a hair under level at 0.8, and the
/// front square and fully opaque. Small rotations: this is a stack someone set
/// down, not a hand of cards. The card's own proportions come from the
/// Memories lowfi instead, and are stated on `aspect` below.
///
/// The Figma is a dark screen and this is not — Strata is light everywhere but
/// the camera. The rotations, offsets, radii and shadows carry over unchanged
/// because they are what make it read as prints, and they are palette-neutral.
///
/// **A print's edge is a hairline, not a white rim.** The Figma gives each
/// photo a light border; CLAUDE.md reserves a white rim for blocks, because
/// that rim is the block's claim to be an object you built. So the edge here
/// is `fillHairline` and a soft shadow, which separates the layers without
/// borrowing something that means a different thing.
///
/// It takes filenames rather than an album, because there are now two kinds of
/// album — a day, and a thing you keep doing — and a cover is the same object
/// for both. There is no photoless branch any more: an album with no
/// photographs is not built at all, since a card showing a little tower is a
/// card about nothing.
struct AlbumCoverView: View {
    /// Cover order; the fan takes the first three. Already de-collided by
    /// `Album.carousel`, so this draws what it is given.
    let photoFileNames: [String]
    let side: CGFloat

    /// 156 : 254, from the Memories lowfi (`KZsjpiFjwv3pgAwRCht4gU`, node
    /// `611:109`). The earlier 155.4 : 205 was the older grid's 3:4 card; the
    /// carousel's cards are taller and narrower. The fan's own offsets scale
    /// off the width, so they carry over unchanged.
    static let aspect: CGFloat = 156.0 / 254.0

    private var height: CGFloat { side / Self.aspect }
    private var radius: CGFloat { 20 * (side / 156.0) }

    /// Back to front, so the top photo is the most recent.
    private var layers: [String] { Array(photoFileNames.prefix(3)).reversed() }

    var body: some View {
        ZStack {
            ForEach(Array(layers.enumerated()), id: \.element) { index, name in
                let depth = layers.count - 1 - index      // 0 = front
                photo(name, depth: depth)
            }
        }
        .frame(width: side, height: height)
    }

    // MARK: - Photographs

    @ViewBuilder
    private func photo(_ name: String, depth: Int) -> some View {
        let spec = Self.spec(forDepth: depth)
        CachedImageView(fileName: name, width: side, height: height, cornerRadius: radius)
            .frame(width: side, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(GridConstants.fillHairline, lineWidth: 1)
            }
            .opacity(spec.opacity)
            .rotationEffect(.degrees(spec.rotation))
            .offset(x: spec.dx * (side / 156.0), y: spec.dy * (side / 156.0))
            .shadow(color: .black.opacity(spec.shadow), radius: spec.shadowRadius,
                    y: spec.shadowY)
    }

    private static func spec(forDepth depth: Int)
        -> (rotation: Double, opacity: Double, dx: CGFloat, dy: CGFloat,
            shadow: Double, shadowRadius: CGFloat, shadowY: CGFloat) {
        switch depth {
        case 0:  return (0,     1.0,  0,    3.55, 0.15, 6,  4)
        case 1:  return (-0.06, 0.8,  5.69, 2.25, 0.15, 16, 4)
        default: return (2.27,  0.5,  6.71, 0,    0,    0,  0)
        }
    }
}
