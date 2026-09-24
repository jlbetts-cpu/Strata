import SwiftUI

/// The empty slot's glass.
///
/// The owner, 2026-09-23: "I think the + square doesn't match the aesthetic of
/// things. I feel like that should be updated, maybe more liquid glass feel."
///
/// **Why this is a fourth recipe and not `glassRoundedRect`.** The two recipes
/// in `GlassIconButton.swift` both sit OVER A PHOTOGRAPH and both tint black to
/// hold their contents up against a scene: `photoOverlay` at 16% ink, and
/// `typePanel` at 30% because four rows of names need a ground. The slot sits
/// on the app's own pale ground, inside `TowerLattice`, and has nothing to hold
/// up. Either tint would draw a grey square exactly the size and shape of a
/// block, which is the one thing this rebuild has to avoid: a slot must read as
/// the ABSENCE of a block, never as a block somebody forgot to fill.
///
/// So: no tint, and `.clear` rather than `.regular`. The number is in
/// `GlassRecipe.typePanel`'s own table: `.regular` blurs out about 82% of what
/// is behind it where `.clear` removes 22 to 37, and the lattice reading
/// through the pane is the whole of the slot's claim to be empty. `.interactive()`
/// for the reason `glassCircle` includes it, which is that this is genuinely a
/// button and the press response is the affordance being bought.
///
/// **`.interactive()` is the one thing here to check on a simulator first.**
/// This is the only glass in the app applied to a view that carries its own
/// `DragGesture(minimumDistance: 0)` inside the tower's `ScrollView`, and
/// CLAUDE.md's measurement is that a recogniser on a block starves that scroll
/// outright (0.0pt of travel). If drawing a block out of the slot, or flinging
/// the tower, misbehaves after this, drop `.interactive()` here before looking
/// anywhere else: nothing depends on it, because the slot's press feedback is
/// its own recoil, recess and colour tint, which are also what the pre-26 path
/// has.
@available(iOS 26.0, *)
extension GlassRecipe {
    static var slot: Glass {
        .clear.interactive()
    }
}

extension View {
    /// Liquid Glass in a block-shaped rectangle, for the tower's empty slot.
    ///
    /// **The fallback deliberately draws no white rim.** The other three
    /// shapes in `GlassIconButton.swift` fall back to `.ultraThinMaterial`
    /// plus a white 0.18 border, which is right for a round control and wrong
    /// here: CLAUDE.md forbids giving a surface a white rim or a frosted edge
    /// because that is a block's own claim to be a lit object you built, and
    /// this surface is already block-shaped and block-sized. The material
    /// alone, and the slot draws its own ink edge on top, so the line is the
    /// same line on both paths.
    ///
    /// Layout first, glass after: the effect takes its shape from the final
    /// frame, so the caller applies this to a view that has already filled the
    /// cell it is pointing at.
    @ViewBuilder
    func glassSlot(cornerRadius r: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(GlassRecipe.slot,
                             in: .rect(cornerRadius: r, style: .continuous))
        } else {
            self.background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: r, style: .continuous))
        }
    }
}
