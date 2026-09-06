import SwiftUI

/// The block's edge treatment, in one place.
///
/// From Figma Apollo 248:14, where the effect is built by LAYERING, not by
/// styling one border: node 255:105 is the block carrying a solid white 5px
/// border, and node 255:106 is a separate 145pt rect — the bottom 26% — with
/// `backdrop-blur(10px)` sitting on top of it. The blur eats the border. So the
/// crisp line does not fade toward the bottom, it DISSOLVES: below the band
/// boundary there is no line left at all, only a soft white smear bleeding
/// inward. Keeping any crisp stroke down there reads as "a line at lower
/// opacity", which is exactly what it must not look like.
///
/// SwiftUI has no backdrop filter, and the only high-contrast thing inside the
/// band is the rim itself, so the smear is reproduced directly: blur the rim
/// rather than blurring what is behind the band. Same result, far cheaper than
/// re-compositing the whole block.
///
/// Three layers:
///   1. crisp rim, top-weighted, gone by the band boundary (72%)
///   2. the smear: a wide soft stroke, blurred and clipped inward
///   3. drop shadow
///
/// Layer 2 costs a blur, hence `.drawingGroup()`.
struct BlockChrome: ViewModifier {
    var cornerRadius: CGFloat
    /// Scales rim weight and bloom for small surfaces (mini previews, chips).
    var scale: CGFloat = 1.0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            // 1 — crisp rim, top-weighted
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white.opacity(0.85), location: 0.45),
                            .init(color: .white.opacity(0.0), location: 0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: GridConstants.blockRimWidth * scale
                )
            )
            // 2 — diffused rim, bottom bloom
            .overlay(
                shape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.0), location: 0.55),
                                .init(color: .white.opacity(0.50), location: 0.78),
                                .init(color: .white.opacity(0.95), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: GridConstants.blockRimGlowWidth * scale
                    )
                    .blur(radius: GridConstants.blockRimGlowBlur * scale)
                    .compositingGroup()
                    .clipShape(shape)
                    .drawingGroup()
            )
            .shadow(
                color: .black.opacity(GridConstants.blockShadowOpacity),
                radius: GridConstants.blockShadowRadius,
                x: 0,
                y: GridConstants.blockShadowY
            )
    }
}

extension View {
    /// Apollo block edge treatment: crisp rim up top, soft bloom at the bottom.
    func blockChrome(cornerRadius: CGFloat, scale: CGFloat = 1.0) -> some View {
        modifier(BlockChrome(cornerRadius: cornerRadius, scale: scale))
    }
}

/// The frosted wash over the lower portion of a block.
///
/// The band is the bottom 26% (Figma 255:106 is 145pt on a 565pt block), and its
/// own gradient runs transparent -> white 0.2 across that span. So the colour
/// field stays fully saturated down to ~74% and only lightens inside the band —
/// a ramp starting higher up quietly desaturates colour that should stay strong.
struct BlockWash: View {
    /// Fraction of block height where the frosted band begins.
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
