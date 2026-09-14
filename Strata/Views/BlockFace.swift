import SwiftUI

/// The face of a block: its colour, its photograph, the veil under its title,
/// and the title. Drawn on `BlockSurface`.
///
/// One view for every place a block is drawn from a win, so a replay cannot
/// drift from the tower. The photograph is a slot: the tower fills it with
/// `CachedImageView`, which decodes asynchronously; a replay fills it with an
/// already decoded image, because `ImageRenderer` does not wait for a decode.
struct BlockFace<Photo: View>: View {
    let title: String
    /// The colour: `habit.displayCategory`.
    let category: HabitCategory
    /// What the title overlay is told, `habit.category`. See CLAUDE.md:
    /// colour and category are two different facts on a block.
    let iconCategory: HabitCategory
    let rowSpan: Int
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let hasPhoto: Bool
    var timeText: String? = nil
    var showOverlay: Bool = true
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        BlockSurface(
            cornerRadius: cornerRadius,
            // A white overlay floors the composite's luminance at its own alpha,
            // so the full 0.20 wash under white text caps contrast below 4.5:1
            // however dark the scrim beneath it is. The source escapes this
            // because its text sits near the TOP of the band on a 565pt block.
            washOpacity: hasPhoto ? 0.06 : GridConstants.blockScrimOpacity
        ) {
            ZStack {
            // **The colour is under everything, always.**
            //
            // It used to live only in the `else` below, so a block WITH a
            // photograph had exactly one fill: the photograph. The moment the
            // grey placeholder was turned off — on the reasoning that "the
            // block's own colour is what shows while this decodes" — there was
            // nothing left to show, and every photo block rendered as an empty
            // `BlockSurface`: a white-to-grey gradient with a title on it.
            // Photographed on a device across the tower, the day view and the
            // month tower.
            //
            // That comment is now true. A block is a coloured block that
            // becomes a photograph, so it never looks like it is loading — and
            // a win that has no photograph at all still has a colour, which is
            // what makes a tower of them read as a tower.
            category.style.baseColor

            if hasPhoto {
                photo()
                    // **Overscanned by 3%.** The category colour sits behind
                    // the photograph as the decode placeholder, and at a
                    // rounded corner the antialiased edge of a pixel-exact
                    // image lets a sliver of it through — the owner: "there is
                    // a glitch where the color shows a little sometimes on the
                    // blocks; if there is a photo added all you need to see is
                    // the photo." A hair of overscan covers the seam without
                    // touching `CachedImageView`'s cache key, which is the
                    // requested WIDTH: changing that would re-decode the same
                    // photograph at a second size.
                    .scaleEffect(1.03)

                RadialGradient(
                    colors: [
                        .clear,
                        AppColors.warmBlack.opacity(0.12)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: min(width, height) * 0.25,
                    endRadius: max(width, height) * 0.85
                )

                // Anchored to where the TEXT starts, not to a fraction of
                // height. Title + time + spacing + padding is ~40pt, so text
                // begins around 54% of an 86pt row, while a proportional ramp
                // does not reach full dark until 81% — fine on Figma's 565pt
                // block, and it leaves the title over open photo detail here.
                // Only when there is a title to protect.
                //
                // The veil exists for one reason: white text on a photograph
                // is unreadable without it. A block nobody named draws no text
                // at all, so on those it was darkening the bottom of the
                // picture to make nothing legible — which is just a dark
                // gradient across a block, and a block is meant to be one flat
                // colour.
                if !BlockContentOverlay.isUnnamed(title) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    // A veil, not a shade.
                    //
                    // This was warmBlack at 0.80 — near-opaque, so the bottom
                    // third of every photo was simply gone, and it read as a
                    // caption bar stuck on rather than as part of the block.
                    // A softer ramp holding a lighter floor keeps the photo
                    // visible under the title while still carrying it.
                    //
                    // The title above it gains its own shadow, which is what
                    // buys back the contrast the darkness used to force.
                    // Lighter again (2026-09-09). It went 0.80 -> 0.48 once
                    // already; at 0.48 it is still a dark bar across the
                    // bottom of a photograph, and a dark bar is the one thing
                    // a block never has. The block is a flat lit plane and
                    // everything on it should read as lit.
                    //
                    // The title's own shadow is what carries the contrast now,
                    // which is why this can be a veil rather than a scrim.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: AppColors.warmBlack.opacity(0.08), location: 0.40),
                            .init(color: AppColors.warmBlack.opacity(0.20), location: 0.75),
                            .init(color: AppColors.warmBlack.opacity(GridConstants.photoVeilOpacity), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(84, height * 0.95))
                }
                }

            } else {
                // Flat colour.
                //
                // This was a gradient washing lightTint at 0.7 across the top
                // quarter. Measured off a screenshot it put ~30% white into the
                // top of every block, which with the frosted band's ~20% at the
                // bottom left the colour only actually reaching full saturation
                // across the middle third. The block read as lit from two
                // directions and washed out at both ends.
                //
                // The rim is what says "lit from above" now, and it says it
                // with one crisp edge rather than a quarter-block of haze.
                //
                // The colour itself is drawn above, under every block; this
                // branch is only what a block WITHOUT a photograph adds, which
                // is nothing.
                EmptyView()
            }

            }
        }
        .frame(width: width, height: height)
        // Text above the blurred band so it stays sharp
        .overlay {
            if showOverlay {
                BlockContentOverlay(
                    title: title,
                    category: iconCategory,
                    rowSpan: rowSpan,
                    timeText: timeText,
                    hasImage: hasPhoto
                )
            }
        }
        // #495: Smart Invert — photos excluded from color inversion
        .accessibilityIgnoresInvertColors(hasPhoto)
    }
}
