import SwiftUI

/// Your head, standing where you are on the Memories map.
///
/// Only when switched on in Profile — otherwise the map keeps Apple's own
/// blue dot, whose whole value is that it needs no explaining. With the head
/// on, the dot's job is done by something that is unmistakably you.
///
/// **It gets a contact shadow**, and it is the only head in the app that
/// does: in the portfolio a head casts one exactly when it is standing on
/// something, and here it is standing on the ground. Light, not heavy — a
/// soft ellipse under the chin, not a drop shadow on the whole head.
///
/// Calm: it blinks and glances. It is a marker, and a marker that pulls faces
/// pulls the eye from the wins the map is actually about (plan §5.3).
struct HeadMarker: View {
    let head: HeadRig

    /// About the size of a finger pad: big enough to read as a face at street
    /// zoom, small enough not to cover the block for the place you are in.
    ///
    /// **Bigger than the blocks are small.** It was 40, which is what a face
    /// needs to be a face, and no more: on a map of photographs it read as one
    /// more small thing. The owner: "make the head more clear on the map, it's
    /// like the player marker so it should be treated as one." A player marker
    /// is the one thing on a map that is never in question, so this is the one
    /// annotation allowed to be the biggest thing on screen at a glance.
    static let side: CGFloat = 52

    var body: some View {
        // `LivingHeadView` centres the head by its face, so the chin sits on
        // the frame's bottom edge and the shadow can sit just under it.
        LivingHeadView(rig: head, side: Self.side, liveliness: .calm)
            .background { halo }
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.26))
                    .frame(width: Self.side * 0.72, height: Self.side * 0.17)
                    .blur(radius: 2.5)
                    .offset(y: Self.side * 0.06)
            }
            .accessibilityElement()
            .accessibilityLabel("You are here")
    }

    /// **A breath of light behind the head, and nothing more.**
    ///
    /// Both map styles are dark grounds — satellite imagery and Apple's night
    /// palette — and dark hair on a dark street is where the marker was
    /// getting lost. This is the map's answer to the same problem chrome
    /// solves with a hairline: separation, not elevation. No ring, no white
    /// disc, no pin. It falls away to nothing well inside the head's own
    /// frame, so what you see is a head standing in a little light rather
    /// than a head on a badge.
    private var halo: some View {
        RadialGradient(colors: [Color.white.opacity(0.34), Color.white.opacity(0.11), .clear],
                       center: .center, startRadius: Self.side * 0.12, endRadius: Self.side * 0.58)
            .frame(width: Self.side * 1.25, height: Self.side * 1.25)
            .offset(y: -Self.side * 0.12)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}
