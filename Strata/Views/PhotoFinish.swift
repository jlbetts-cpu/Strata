import SwiftUI

/// **How every photograph in Apollo is cut and edged, in one place.**
///
/// The owner, looking at a print beside the cards it came from: "match the
/// blocks with the polaroid, they shouldn't look different."
///
/// They did, and in three ways at once: a card inside a folder had a 16pt
/// corner, a card peeking out of one had 7, and the print worked out its own
/// 8 from a ratio — while only the print carried an edge at all. So the same
/// photograph was a different object on every surface it appeared on, which
/// is the opposite of what a format is for.
///
/// **The corner and the edge travel together**, because they are one finish
/// rather than two settings. Anything that draws a photograph applies this
/// and gets both; nothing draws its own.
///
/// **The corner is proportional**, so a thumbnail and a print read as the
/// same shape seen at two distances rather than as the same number of points
/// on two very different objects. See `GridConstants.photoCornerRatio` for
/// why that is the second answer to this question and not the first.
///
/// **The edge is a real hairline.** The Figma says 0.2px, which is a design
/// tool's number rather than a screen's: under one device pixel it renders as
/// a paler line rather than a thinner one. One device pixel is the thinnest a
/// line can honestly be, so that is what this draws — and it is the app's own
/// ink at 10% rather than the file's `#e4e4e4`, so it is still there when the
/// photograph is light and still quiet when the page is dark.
struct PhotoFinish: ViewModifier {
    /// Off for anything already inside a clip — the folder's stack sits
    /// behind glass and a hairline there reads as a scratch on the pane
    /// rather than as the edge of a print.
    var edged: Bool = true

    func body(content: Content) -> some View {
        content
            .clipShape(PhotoCorner())
            .overlay {
                if edged {
                    PhotoCorner()
                        .strokeBorder(AppColors.inkPrimary.opacity(0.10),
                                      lineWidth: 1 / max(UIScreen.main.scale, 1))
                }
            }
    }
}

/// A photograph's corner, worked out from the photograph's own width.
///
/// **A `Shape` rather than a number, because only a shape is told its size.**
/// A proportional corner cannot be a constant and cannot be read off a
/// `GeometryReader` without arriving a frame late; `path(in:)` is handed the
/// rect it is about to draw, which is exactly the information needed and
/// exactly when it is needed.
///
/// It draws a `RoundedRectangle`'s own continuous path rather than
/// reconstructing one from quad curves. A continuous corner is not an arc —
/// it is Apple's squircle — and hand-rolling it produces a shape that is
/// visibly flatter down its sides next to every other rounded thing in the
/// app. `PocketShape` exists because the folder needed a corner that a
/// `RoundedRectangle` could not give it; this one does not have that problem.
///
/// `InsettableShape`, so `strokeBorder` draws the hairline INSIDE the edge
/// rather than straddling it. A stroke centred on the boundary is half
/// outside the clip and comes out at half opacity with a soft outer side.
struct PhotoCorner: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> PhotoCorner {
        PhotoCorner(inset: inset + amount)
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        // Capped at half the short side so a very wide, very short card
        // cannot ask for a corner bigger than itself and come out a capsule.
        let radius = min(r.width * GridConstants.photoCornerRatio,
                         min(r.width, r.height) / 2)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: r)
    }
}

extension View {
    /// One corner and one edge for every photograph. See `PhotoFinish`.
    func photoFinish(edged: Bool = true) -> some View {
        modifier(PhotoFinish(edged: edged))
    }
}
