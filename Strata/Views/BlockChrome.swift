import SwiftUI

/// A block's surface: colour, frosted band, white rim, and the blurred bottom
/// edge. Text is NOT part of this — it goes on top, sharp.
///
/// This refines the treatment already in HabitBlockView rather than replacing
/// it. That version had the frosted white gradient and a flat 5pt white strip
/// along the bottom — the right idea, read literally off the Figma. In the
/// source the white is a real border on all four sides (node 255:105), and a
/// separate rect over the bottom 26% (255:106) applies `backdrop-blur(10px)` to
/// it. So the rim is uniform, and the band decides where it is seen crisp and
/// where it is seen blurred; the bottom edge is not a strip, it is the same
/// border out of focus.
///
/// Two things this got wrong before arriving here, both worth not repeating:
///
/// - Compositing a blurred ring ON TOP of a sharp block adds a white highlight
///   inside the colour field and leaves the silhouette crisp. The source has
///   neither. The sharp surface has to be REPLACED by the blurred one, not
///   decorated with it.
/// - The two copies must not crossfade symmetrically. Two masked opaque layers
///   at 50% each composite to 75% alpha, so the block goes translucent through
///   the handover and the page shows through as a milky cast. The blurred copy
///   therefore reaches full opacity BEFORE the sharp one starts to fade.
///
/// SwiftUI has no backdrop filter, so the surface is duplicated rather than
/// sampled. It must stay free of state and gestures — those belong on the
/// caller, outside this view.
struct BlockSurface<Fill: View>: View {
    var cornerRadius: CGFloat = GridConstants.blockCornerRadius
    /// Scales rim weight and blur for small surfaces (mini previews, chips).
    var scale: CGFloat = 1.0
    /// Wash strength. Photo blocks pass less — a white overlay floors the
    /// composite's luminance at its own alpha, and 0.20 under white text caps
    /// contrast below 4.5:1 however dark the scrim beneath it is.
    var washOpacity: Double = GridConstants.blockScrimOpacity
    /// Sides that continue into a same-colour neighbour. Those corners go
    /// square and those edges lose their rim, so the two blocks read as one
    /// piece. The caller is responsible for growing the frame across the gap.
    var merged: MergedEdges = .none
    @ViewBuilder var fill: () -> Fill

    /// Per-corner radii, square wherever an edge is shared.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: merged.topLeadingSquare ? 0 : cornerRadius,
            bottomLeadingRadius: merged.bottomLeadingSquare ? 0 : cornerRadius,
            bottomTrailingRadius: merged.bottomTrailingSquare ? 0 : cornerRadius,
            topTrailingRadius: merged.topTrailingSquare ? 0 : cornerRadius,
            style: .continuous
        )
    }

    /// Hides the rim along shared edges only.
    ///
    /// The rim is stroked around the whole shape, so on a merged edge it would
    /// draw a white line straight down the middle of what is meant to be one
    /// piece. Masking the STROKE (not the block) with a rectangle inset on the
    /// shared sides removes it there and leaves the fill continuous.
    private var rimMask: some View {
        // Generous: the stroke's corner ends sit slightly proud of the edge, and
        // a mask sized exactly to the rim width left a tick of them showing at
        // each end of a seam.
        let w = GridConstants.blockRimWidth * scale * 3.5
        return Rectangle()
            .padding(.top, merged.contains(.top) ? w : 0)
            .padding(.bottom, merged.contains(.bottom) ? w : 0)
            .padding(.leading, merged.contains(.leading) ? w : 0)
            .padding(.trailing, merged.contains(.trailing) ? w : 0)
    }

    /// The rim, brightest along the top edge.
    ///
    /// The Figma border is one flat white. Drawn flat at this weight it reads
    /// as an outline around a sticker; a block is a solid object lit from
    /// above, and the edge facing the light is the one that catches it. Same
    /// single border, unequal along its length — which is what a real edge
    /// does, and it lets the top read clearly without the sides shouting.
    private var rim: LinearGradient {
        // The rim brightens toward the lit edge — but only where there IS a lit
        // edge. A block that continues upward has another block's body above
        // it, not the sky, so its side rims must pick up exactly where the
        // block above left off.
        //
        // This was the thing that kept a merged pair reading as two. The
        // gradient restarted at full white on every block's top, so the lower
        // block's side rims were bright precisely where the upper block's had
        // faded to the falloff value — a hard brightness step running down both
        // sides, at exactly the join.
        let top: Color = merged.contains(.top)
            ? .white.opacity(GridConstants.blockRimFalloff)
            : .white
        return LinearGradient(
            stops: [
                .init(color: top, location: 0.0),
                .init(color: .white.opacity(GridConstants.blockRimFalloff), location: merged.contains(.top) ? 0.0 : 0.55),
                .init(color: .white.opacity(GridConstants.blockRimFalloff), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The frosted band lives at the block's bottom edge. When the block
    /// continues downward there IS no bottom edge, so the band would draw a
    /// pale step across the middle of what should be one piece.
    private var continuesDown: Bool { merged.contains(.bottom) }

    private var surface: some View {
        fill()
            .overlay(BlockWash(opacity: continuesDown ? 0 : washOpacity))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(rim, lineWidth: GridConstants.blockRimWidth * scale)
                    .mask(rimMask)
            )
    }

    /// Sharp copy on top: full down to the band, then fades away.
    private var sharpMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: GridConstants.blockBandFeatherEnd),
                .init(color: .clear, location: min(1.0, GridConstants.blockBandFeatherEnd + 0.12))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Blurred copy underneath: full BEFORE the sharp one fades, so the two
    /// never sum to less than opaque.
    private var blurredMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: GridConstants.blockBandFeatherStart),
                .init(color: .white, location: GridConstants.blockBandFeatherEnd)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Group {
            if continuesDown {
                // No bottom edge to soften, so no sharp/blurred handover — the
                // two-copy mask exists to put the rim out of focus inside the
                // band, and there is no band here.
                surface
            } else {
                ZStack {
                    surface
                        .blur(radius: GridConstants.blockRimBlur * scale)
                        .mask(blurredMask)
                    surface.mask(sharpMask)
                }
            }
        }
        .compositingGroup()
        // A block that continues downward must not cast onto the block it
        // continues into, or the join reads as a crease.
        .shadow(
            color: .black.opacity(continuesDown ? 0 : GridConstants.blockShadowOpacity),
            radius: GridConstants.blockShadowRadius,
            x: 0,
            y: GridConstants.blockShadowY
        )
    }
}

/// The incomplete state: the same object, not yet filled.
///
/// There is no ghost variant in the Figma, so this is a design decision rather
/// than a transcription — but it is built from the same anatomy as `BlockSurface`
/// so the two states read as one thing in two conditions:
///
/// - White fill, brighter than the warm ground, so it reads as a clean empty
///   card. What it replaces sat DARKER than the page — `Color.primary.opacity(0.08)`
///   on the unscheduled chips — and read as a muddy slab competing with the
///   saturated blocks around it.
/// - The rim carries the category colour instead of white. A white rim would be
///   invisible here: on a filled block it separates saturated colour from a pale
///   ground, and there is no saturation here to separate.
/// - A tint of the category colour sits exactly where the filled block's frosted
///   band sits, previewing the colour the block becomes on completion.
/// - No shadow and no blurred band. Blurring a near-white surface with no white
///   rim beneath it produces nothing visible — cost with no image.
///
/// Positive-only: this is "waiting", not "failed". Nothing here is dimmed,
/// crossed or desaturated as a penalty.
struct BlockGhostSurface: View {
    var category: HabitCategory
    var cornerRadius: CGFloat = GridConstants.blockCornerRadius
    /// Scales the rim for small surfaces (chips, mini previews).
    var scale: CGFloat = 1.0

    private var style: CategoryStyle { category.style }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        // A clean white card, and nothing else.
        //
        // There was a tint of the category colour ramped in across the bottom
        // quarter, meant to preview the colour the block becomes. It read as a
        // gradient smudged along the bottom edge rather than as a preview, and
        // it put the one dirty-looking thing on a surface whose whole job is to
        // look clean and unfilled. The rim already says which category this is.
        Color.white
            .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                style.baseColor.opacity(GridConstants.blockGhostRimOpacity),
                lineWidth: GridConstants.blockGhostRimWidth * scale
            )
        )
    }
}

/// The frosted wash inside the band — the gradient already used inline, moved
/// here so the band's start is one number instead of several.
struct BlockWash: View {
    var opacity: Double = GridConstants.blockScrimOpacity

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: GridConstants.blockBandStart),
                .init(color: .white.opacity(opacity), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
