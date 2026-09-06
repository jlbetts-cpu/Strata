import SwiftUI

/// The block's edge treatment, in one place.
///
/// From Figma Apollo 248:14. The rim is NOT a uniform ring — it reads crisp
/// along the top and sides, then diffuses into a soft halo at the bottom where
/// the frosted band passes over it. That soft bottom edge is the texture that
/// carries the style; a flat ring loses it.
///
/// Three layers, in order:
///   1. crisp rim, strongest at the top, fading by ~80% down
///   2. diffused rim, absent at the top, blooming at the bottom, blurred and
///      clipped inward so the white bleeds into the colour field
///   3. drop shadow
///
/// Layer 2 costs a blur, which is why it carries `.drawingGroup()` — the same
/// rasterisation the old coloured glow used.
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
                            .init(color: .white.opacity(0.55), location: 1.0)
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
                                .init(color: .white.opacity(0.0), location: 0.0),
                                .init(color: .white.opacity(0.35), location: 0.55),
                                .init(color: .white.opacity(0.75), location: 1.0)
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
/// Holds the colour field flat through the top third, then lightens low — the
/// Figma band (248:78) is bottom-anchored, so a ramp starting at the very top
/// washes out colour that should stay saturated.
struct BlockWash: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.35),
                .init(color: .white.opacity(GridConstants.blockScrimOpacity * 0.4), location: 0.70),
                .init(color: .white.opacity(GridConstants.blockScrimOpacity), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
