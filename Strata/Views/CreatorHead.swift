import SwiftUI

/// The owner's head, from his portfolio, on the thank-you page beside his
/// photograph.
///
/// **Not an engine of its own any more.** It is `HeadRig.creatorRig` played
/// by `TappableHead`, the same `LivingHeadView` every made head plays in, and
/// its behaviour is the standard those heads are held to (owner, 2026-09-16).
/// The research behind how it moves, and why it does not stare, lives with
/// the beats in `HeadBeat.swift`.
///
/// No shadow. In the portfolio a head casts one only when it is standing on
/// something, and here it is not.
struct CreatorHead: View {
    /// The height of the head itself, crown to chin.
    var side: CGFloat = 44
    /// Eyebrow flash and a wink when it arrives.
    var greets: Bool = false
    /// Where the thing it is curious about lies, as a direction from the head
    /// (-1...1 each way, negative is left and up). A turn looks there — on the
    /// thank-you page, the photograph.
    var lookTarget: CGPoint = CGPoint(x: -1, y: -0.5)
    /// DEBUG: the name this head's lines carry under `-strataHeadTrace`.
    var traceID: String? = nil

    var body: some View {
        if let rig = HeadRig.creatorRig {
            TappableHead(rig: rig, side: side, greets: greets, lookTarget: lookTarget, traceID: traceID)
        }
    }
}
