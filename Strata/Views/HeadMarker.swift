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
    static let side: CGFloat = 40

    var body: some View {
        // `LivingHeadView` centres the head by its face, so the chin sits on
        // the frame's bottom edge and the shadow can sit just under it.
        LivingHeadView(rig: head, side: Self.side, liveliness: .calm)
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: Self.side * 0.7, height: Self.side * 0.16)
                    .blur(radius: 2)
                    .offset(y: Self.side * 0.06)
            }
            .accessibilityElement()
            .accessibilityLabel("You are here")
    }
}
