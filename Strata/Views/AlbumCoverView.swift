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
///
/// **That fade is `CachedImageView`'s, and it was two fades for a while.**
/// This view held a second one of its own: a `loaded` flag set true 60ms after
/// the VIEW appeared, which faded the whole image view up on `gentleReveal`.
/// It did not do what the paragraph above says. It was keyed to the cover
/// appearing rather than to the picture landing, so a cold decode faded in an
/// EMPTY frame and then popped the photograph in with no fade at all, while a
/// warm one, which is the common case on a shelf you have already scrolled,
/// was held back for 60ms and then eased in over 0.22s in front of a picture
/// that was already decoded. `design-system-future.md` §5: nothing animates
/// because a screen appeared, and speed is the motto. `ReplayShelf` took its poster's
/// arrival fade off for the same reason on the row above.
///
/// `CachedImageView` already fades a decoded photograph in on `imageFadeIn`,
/// keyed to the picture itself arriving, which is the fade this was meant to
/// be. Its placeholder is off here: the cover draws its own slot, so the
/// built-in one would be a second `quietFill` rectangle on top of it, and it
/// is the one that carries the looping shimmer, which §5 refuses. The picture
/// comes up over the cover's opaque slot, so the crossfade rule holds: at
/// every instant something opaque is covering what must not show through.
struct AlbumCoverView: View {
    /// Cover order; the first is the one shown. Already de-collided by
    /// `Album.carousel`, so this draws what it is given.
    let photoFileNames: [String]
    let side: CGFloat

    /// A block's proportions. Square, because every block in Strata is square
    /// or wider, and at the block's own radius ratio so it scales like one.
    static let aspect: CGFloat = 1.0

    private var height: CGFloat { side / Self.aspect }
    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: side) }

    var body: some View {
        ZStack {
            // The slot the picture lands in, so an album that is still loading
            // is an empty block rather than a hole in the page.
            //
            // `quietFill`, the app's own token for an empty cell, rather than
            // 4% of the app's black. `warmBlack` is fixed and does not invert,
            // so in dark mode a cover still waiting for its picture was a
            // near-black patch on a near-black page. The design language's §4
            // puts chrome on the ink and grey tokens and §8 refuses a colour
            // that is not one of them; `TowerLattice` fills its empty cells
            // from this same token, so a slot looks like a slot wherever it
            // turns up.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(AppColors.quietFill)

            if let name = photoFileNames.first {
                CachedImageView(fileName: name, width: side, height: height,
                                cornerRadius: radius,
                                showsPlaceholder: false)
                    .frame(width: side, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
        .frame(width: side, height: height)
        .overlay {
            // A block with a photograph on it wears the block's rim.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(AppColors.onDarkQuiet,
                              lineWidth: GridConstants.blockRimWidth
                                  * (side / GridConstants.blockReferenceCell))
        }
    }
}
