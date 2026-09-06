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
    @ViewBuilder var fill: () -> Fill

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var surface: some View {
        fill()
            .overlay(BlockWash(opacity: washOpacity))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white, lineWidth: GridConstants.blockRimWidth * scale)
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
        ZStack {
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
