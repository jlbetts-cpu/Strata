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
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusPhoto,
                                     style: .continuous)
        return content
            .clipShape(shape)
            .overlay {
                if edged {
                    shape.strokeBorder(AppColors.inkPrimary.opacity(0.10),
                                       lineWidth: 1 / max(UIScreen.main.scale, 1))
                }
            }
    }
}

extension View {
    /// One corner and one edge for every photograph. See `PhotoFinish`.
    func photoFinish(edged: Bool = true) -> some View {
        modifier(PhotoFinish(edged: edged))
    }
}
