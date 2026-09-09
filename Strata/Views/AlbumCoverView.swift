import SwiftUI

/// An album's cover: one photograph, on a block.
///
/// It used to fan three prints, rotated a degree or two and dropped to half
/// opacity behind each other, after a Figma of a photo-album grid. The owner's
/// call (2026-09-09) is one image, and it is the right one: three overlapping
/// rectangles is a *photo app's* idea of an album, and it fights the one thing
/// this app is made of. A block is a single flat plane. Stacking translucent
/// copies of it behind itself is the opposite of that — it is clutter dressed
/// as depth.
///
/// So the cover is the newest photograph, on a block, and the only motion is
/// the picture arriving: it fades up when it has loaded rather than snapping
/// in. Nothing rotates, nothing overlaps, nothing is at 50%.
struct AlbumCoverView: View {
    /// Cover order; the first is the one shown. Already de-collided by
    /// `Album.carousel`, so this draws what it is given.
    let photoFileNames: [String]
    let side: CGFloat

    /// A block's proportions. Square, because every block in Strata is square
    /// or wider, and at the block's own radius ratio so it scales like one.
    static let aspect: CGFloat = 1.0

    @State private var loaded = false

    private var height: CGFloat { side / Self.aspect }
    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: side) }

    var body: some View {
        ZStack {
            // The slot the picture lands in, so an album that is still loading
            // is an empty block rather than a hole in the page.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(AppColors.warmBlack.opacity(0.04))

            if let name = photoFileNames.first {
                CachedImageView(fileName: name, width: side, height: height,
                                cornerRadius: radius)
                    .frame(width: side, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .opacity(loaded ? 1 : 0)
                    .task(id: name) {
                        // A fade, not a pop. The image is decoded off the main
                        // thread and can arrive at any point; arriving by
                        // fading is the difference between a page that settles
                        // and a page that flickers.
                        loaded = false
                        try? await Task.sleep(for: .milliseconds(60))
                        withAnimation(GridConstants.gentleReveal) { loaded = true }
                    }
            }
        }
        .frame(width: side, height: height)
        .overlay {
            // A block with a photograph on it wears the block's rim.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.55),
                              lineWidth: GridConstants.blockRimWidth
                                  * (side / GridConstants.blockReferenceCell))
        }
    }
}
