import SwiftUI

/// A block's surface: colour, frosted wash, white rim, and the blurred band at
/// the bottom. Text is NOT part of this — it goes on top, sharp.
///
/// Built the way the Figma builds it (Apollo 248:14). Layer order there:
///
///   255:104  the off-white plate behind
///   255:105  the block, with a solid white 5px border, uniform all round
///   255:106  a rect over the bottom 145pt of 565 (26%) doing `backdrop-blur(10px)`
///   255:107  title      ─┐ drawn after the band, so they stay sharp
///   255:108  time       ─┘
///
/// The band blurs its BACKDROP — the block's fill, its border, and its silhouette
/// — so at the bottom the whole thing goes soft together, and the text placed
/// above it sits cleanly on a soft ground.
///
/// This matters because the obvious reading is wrong. Compositing a blurred ring
/// on top of a sharp block adds a white highlight INSIDE the colour field and
/// leaves the block's own edge crisp; the source has neither. There is no inner
/// glow in it, and its bottom corners are soft, because nothing is being added —
/// the sharp version is being replaced.
///
/// So the surface is drawn twice and masked: sharp above the band, blurred
/// inside it. The two never overlap, so nothing is added anywhere and the border
/// keeps constant weight; it simply goes out of focus along with everything else.
///
/// SwiftUI has no backdrop filter, so the surface is duplicated rather than
/// sampled. It must therefore stay free of state and gestures — those belong on
/// the caller, outside this view.
struct BlockSurface<Fill: View>: View {
    var cornerRadius: CGFloat
    /// Scales rim weight and blur for small surfaces (mini previews, chips).
    var scale: CGFloat = 1.0
    /// Wash strength. Photo blocks pass a lower value — see
    /// blockScrimOpacityOverPhoto for the contrast arithmetic.
    var washOpacity: Double = GridConstants.blockScrimOpacity
    @ViewBuilder var fill: () -> Fill

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Colour + wash + rim. One uniform border at one opacity, all round.
    private var surface: some View {
        fill()
            .overlay(BlockWash(opacity: washOpacity))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white, lineWidth: GridConstants.blockRimWidth * scale)
            )
    }

    /// Sharp copy on top: full down to the boundary, then fades away.
    private var sharpMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: GridConstants.blockBandFeatherStart),
                .init(color: .clear, location: GridConstants.blockBandFeatherEnd)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Blurred copy underneath: ramps to FULL before the sharp copy starts
    /// fading, so the two never sum to less than opaque. See
    /// blockBandBlurRampStart — mirrored masks make the block translucent.
    private var blurredMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: GridConstants.blockBandBlurRampStart),
                .init(color: .white, location: GridConstants.blockBandFeatherStart)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            // Blurred copy underneath, sharp copy over it. Order matters: the
            // sharp one is opaque wherever the blurred one is still ramping in,
            // so nothing translucent is ever exposed.
            surface
                .blur(radius: GridConstants.blockRimBlur * scale)
                .mask(blurredMask)
            surface.mask(sharpMask)
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(GridConstants.blockShadowOpacity),
            radius: GridConstants.blockShadowRadius,
            x: 0,
            y: GridConstants.blockShadowY
        )
    }
}

/// The incomplete state: the same object, not yet filled.
///
/// There is no ghost variant in the Figma, so this is a design decision rather
/// than a transcription — but it is built from the same anatomy so the two
/// states read as one thing in two conditions:
///
/// - White fill, brighter than the #FBFAF8 ground, so it reads as a clean empty
///   card. The previous grey (#EBE8E6) sat darker than the page and read as a
///   muddy slab competing with the saturated blocks around it.
/// - The rim carries the category colour instead of white. A white rim would be
///   invisible here — it separates a saturated block from a pale ground, and
///   there is no saturation to separate.
/// - A tint of the category colour sits exactly where the filled block's frosted
///   band sits, previewing the colour the block becomes on completion.
/// - No shadow and no blurred band. brand.md's ghost tier has no shadow, and
///   blurring a near-white surface with no white rim beneath produces nothing
///   visible — it would be cost with no image.
///
/// Positive-only, per coordination.md: this is "waiting", not "failed". Nothing
/// here is dimmed, crossed, or desaturated as a penalty.
struct BlockGhostSurface: View {
    var category: HabitCategory
    var cornerRadius: CGFloat
    var scale: CGFloat = 1.0

    private var style: CategoryStyle { category.style }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            Color.white
            LinearGradient(
                stops: [
                    .init(color: .clear, location: BlockWash.bandStart),
                    .init(color: style.baseColor.opacity(GridConstants.blockGhostTint), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                style.baseColor.opacity(GridConstants.blockGhostRimOpacity),
                lineWidth: GridConstants.blockGhostRimWidth * scale
            )
        )
    }
}

/// The frosted wash inside the band.
///
/// The band is the bottom 26% (Figma 255:106 is 145pt on a 565pt block) and its
/// own gradient runs transparent -> white 0.2 across that span, so the colour
/// field stays fully saturated above it.
struct BlockWash: View {
    /// Fraction of block height where the frosted band begins — the same
    /// boundary the blur uses, by construction.
    static let bandStart: Double = 0.74

    var opacity: Double = GridConstants.blockScrimOpacity

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: Self.bandStart),
                .init(color: .white.opacity(opacity), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
