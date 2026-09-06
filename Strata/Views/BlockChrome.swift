import SwiftUI

/// The block's edge treatment, in one place.
///
/// Built the way the Figma builds it (Apollo 248:14), by LAYERING rather than by
/// styling one border:
///
///   255:105  the block, carrying a solid white 5px border, uniform all round
///   255:106  a separate rect over the bottom 145pt of 565 (26%), whose only
///            job is `backdrop-blur(10px)` — it blurs the border beneath it
///
/// So there is exactly ONE ring, at ONE opacity. The band decides where it is
/// seen crisp and where it is seen blurred. That is what makes the falloff read
/// as clean diffusing light: a gaussian of a uniform white line is smooth and
/// symmetrical everywhere along its length.
///
/// Modulating the ring's opacity with a vertical gradient and then blurring it —
/// the previous approach here — is not the same thing and does not look the
/// same. Density then varies along the ring, so the blur smears unevenly and
/// reads as a smudge. Overlapping a fading-out crisp ring with a fading-in
/// blurred one compounds it, carrying two partial edges through the transition.
/// Keep the ring uniform and cut it hard.
///
/// SwiftUI has no backdrop filter, so the blurred half is produced by blurring
/// the ring directly. The one behavioural difference: real backdrop blur would
/// also smear anything else sitting inside the band. Nothing does today.
struct BlockRim: View {
    var cornerRadius: CGFloat
    /// Scales rim weight and blur for small surfaces (mini previews, chips).
    var scale: CGFloat = 1.0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// The single uniform white ring. Both layers draw exactly this.
    private var ring: some View {
        shape.strokeBorder(.white, lineWidth: GridConstants.blockRimWidth * scale)
    }

    /// Crossfade between the crisp ring and the blurred one.
    /// `above == true` keeps the crisp region, `false` keeps the band.
    ///
    /// Figma cuts this hard, because backdrop-blur has a hard boundary. At its
    /// 562pt block the step is sub-pixel; at an 86pt cell it is a visible ledge,
    /// since the blurred ring carries less peak and the colour field reads wider
    /// below the cut. Feathering the handover removes it and preserves the
    /// intent — crisp above, dissolved below.
    private func bandMask(above: Bool) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: above ? .white : .clear, location: GridConstants.blockRimFeatherStart),
                .init(color: above ? .clear : .white, location: GridConstants.blockRimFeatherEnd)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            // Above the band: the ring, crisp.
            ring.mask(bandMask(above: true))
            // Inside the band: the same ring, blurred — and deliberately NOT
            // clipped to the shape.
            //
            // Clipping cuts away the outer half of the gaussian, which halves
            // the white exactly at the boundary, so the smear falls off before
            // the edge and raw colour meets the ground in a hard chroma step —
            // the silhouette stays visible as an edge. Letting the blur straddle
            // the boundary keeps the edge white, and white on the #FBFAF8 ground
            // is no edge at all: the block dissolves into the page the way glass
            // does. The spill is ~3pt against an 8pt grid gap, so it never
            // reaches a neighbouring block.
            //
            // .drawingGroup() is deliberately absent — it rasterises to the
            // view's bounds and would re-clip the spill, reinstating the edge.
            ring
                .blur(radius: GridConstants.blockRimBlur * scale)
                .mask(bandMask(above: false))
                .compositingGroup()
        }
    }
}

struct BlockChrome: ViewModifier {
    var cornerRadius: CGFloat
    var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .overlay(BlockRim(cornerRadius: cornerRadius, scale: scale))
            .shadow(
                color: .black.opacity(GridConstants.blockShadowOpacity),
                radius: GridConstants.blockShadowRadius,
                x: 0,
                y: GridConstants.blockShadowY
            )
    }
}

extension View {
    /// Apollo block edge treatment: one uniform white ring, crisp above the
    /// band and blurred inside it.
    func blockChrome(cornerRadius: CGFloat, scale: CGFloat = 1.0) -> some View {
        modifier(BlockChrome(cornerRadius: cornerRadius, scale: scale))
    }
}

/// The frosted wash inside the band.
///
/// The band is the bottom 26% (Figma 255:106 is 145pt on a 565pt block) and its
/// own gradient runs transparent -> white 0.2 across that span, so the colour
/// field stays fully saturated above it. A ramp starting higher up quietly
/// desaturates colour the source keeps strong.
struct BlockWash: View {
    /// Fraction of block height where the frosted band begins. Also where the
    /// rim stops being crisp — they are the same boundary, by construction.
    static let bandStart: Double = 0.74

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: Self.bandStart),
                .init(color: .white.opacity(GridConstants.blockScrimOpacity), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
