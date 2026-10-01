import SwiftUI

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
