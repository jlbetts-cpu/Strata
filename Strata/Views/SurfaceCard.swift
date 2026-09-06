import SwiftUI

/// A chrome surface, built from the same anatomy as a block.
///
/// The blocks look designed because they all go through one component; the rest
/// of the app looked like iOS defaults because it was iOS defaults with
/// opacities sprinkled on — nine corner radii and around seventy hand-picked
/// greys, none of them shared. This is the chrome half of `BlockSurface`: same
/// warm ground, same radius, a hairline instead of a white rim.
///
/// A card is NOT a block. It carries no white rim, no frosted band and no
/// blurred edge — those say "this is a thing you built and it is standing on
/// something". A card holds content; it separates with a hairline, which is the
/// quieter half of the same language.
struct SurfaceCard<Content: View>: View {
    var radius: CGFloat = GridConstants.cornerRadius
    var padding: CGFloat = 16
    /// Cards on the warm ground read as white. Set false for a well or an inset
    /// group, which sits *into* the page rather than on top of it.
    var raised: Bool = true
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(raised ? AnyShapeStyle(Color.white) : AnyShapeStyle(GridConstants.fillWell), in: shape)
            .overlay(shape.strokeBorder(GridConstants.fillHairline, lineWidth: 1))
    }
}

/// A form field's ground — the well that a TextField or picker sits in.
///
/// Was written as `Color.primary.opacity(0.04)` or `0.05` with a radius of 12,
/// 14 or 10 depending on the file.
struct SurfaceWell: ViewModifier {
    var radius: CGFloat = GridConstants.radiusField

    func body(content: Content) -> some View {
        content.background(
            GridConstants.fillWell,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }
}

extension View {
    /// Put this control in a form well.
    func surfaceWell(radius: CGFloat = GridConstants.radiusField) -> some View {
        modifier(SurfaceWell(radius: radius))
    }
}
