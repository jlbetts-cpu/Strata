import SwiftUI

/// **The app's one raised surface, for everything that is not a block.**
///
/// The owner, 2026-09-30: "make sure the whole app has the same vocabulary —
/// please focus on every page and make it feel like a cohesive experience."
///
/// The tower had been given a vocabulary this week and nothing else had: a
/// ground with light in it, panes you can see through, a lit edge on every
/// object, one lamp, one shadow ladder. Photographed side by side, Profile and
/// Settings were a stock SwiftUI `Form` sitting on top of that — opaque white
/// rows with square shoulders and no edge, which is a different material
/// entirely and reads as a different app. The screens were not inconsistent in
/// their numbers; they were made of different stuff.
///
/// So this is the non-block half of the vocabulary, and it is the SAME three
/// ideas the blocks are made of, which is the whole point of it existing:
///
/// 1. **Translucent, not opaque.** The ground has light in it and a surface
///    that blocks the light completely is a hole in the page. `.regularMaterial`
///    lets it through the way a lattice pane does.
/// 2. **A lit edge**, from `BlockRim` — literally the same definition a block
///    uses, so the light in this app falls on one kind of edge rather than two.
/// 3. **One rung off the page**, from `Elevation.floating`, rather than a
///    shadow chosen per screen.
///
/// It deliberately does NOT take `BlockLight`'s aim. A card is not standing in
/// the tower; the lamp hangs over the stack, and a sheet that tilted its
/// highlight to match a tower it is covering would be claiming to be part of it.
struct PageSurface: View {
    var cornerRadius: CGFloat = GridConstants.radiusSurface
    /// Chrome that floats over content — a drawer, a pill — carries the shadow.
    /// A row inside a scrolling list does not: forty of them would stack forty
    /// shadows down the page, which is the mistake the blocks just had undone.
    var raised: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(.regularMaterial)
            .overlay {
                shape.strokeBorder(BlockRim.gradient(in: colorScheme),
                                   lineWidth: GridConstants.blockRimWidth)
            }
            .modifier(SurfaceLift(raised: raised, scheme: colorScheme))
    }
}

/// The shadow, applied conditionally as a MODIFIER rather than as a zero value.
/// CLAUDE.md, on `.gesture(cond ? g : nil)`: a zero-valued effect is still an
/// effect, and a list of forty rows each carrying a clear shadow is forty
/// compositing groups for nothing.
private struct SurfaceLift: ViewModifier {
    let raised: Bool
    let scheme: ColorScheme

    func body(content: Content) -> some View {
        if raised {
            content.elevation(.floating, in: scheme)
        } else {
            content
        }
    }
}

extension View {
    /// Puts this view on the app's one raised surface.
    func pageSurface(cornerRadius: CGFloat = GridConstants.radiusSurface,
                     raised: Bool = false) -> some View {
        background { PageSurface(cornerRadius: cornerRadius, raised: raised) }
    }
}

/// **A category's colour, as the same object a block is.**
///
/// Every swatch in the app was a flat `Circle().fill(baseColor)` — the add
/// sheet's picker, Profile's background chooser, the map's pins. A block is a
/// body with a light in it and a lit edge; a swatch of the same colour, drawn
/// flat and square-edged a screen away, says the colour is a label rather than
/// the thing you are about to build with.
///
/// Same fill, same rim, same light. Picking a colour now looks like picking a
/// block, because that is what it is.
struct ColourSwatch: View {
    var colour: Color
    var side: CGFloat = 34

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(EtherealFill.fill(colour))
            .frame(width: side, height: side)
            .overlay {
                // **Scaled, with a floor.** A block's 1.9pt rim is 2% of an
                // 86pt side; drawn at that weight on a 34pt swatch it is 6%,
                // which stops being a lit edge and becomes a white ring drawn
                // around a dot. `BlockSurface` scales its rim for exactly this
                // reason wherever the cell is not the tower's. The floor is
                // because half a point of white on a saturated circle is
                // antialiasing rather than an edge.
                Circle().strokeBorder(
                    BlockRim.gradient(in: colorScheme),
                    lineWidth: max(1, GridConstants.blockRimWidth
                                      * side / GridConstants.blockReferenceCell))
            }
    }
}
