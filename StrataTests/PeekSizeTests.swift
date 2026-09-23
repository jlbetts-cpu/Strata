import Testing
import SwiftUI
@testable import Strata

/// **How big a win looks peeking out of its folder.**
///
/// The owner, 2026-09-23: "for the sizing make sure medium looks medium,
/// large looks large and small looks small."
///
/// This ladder has been wrong twice, in opposite directions, and neither
/// time did anything fail: once it came off the block's spans and a 2x1 was
/// a letterbox a third of the folder deep, and once it came off the
/// photograph and every card on the shelf was the same card. A ladder that
/// nothing checks is a ladder that drifts, so both properties are pinned
/// here — that the three are ordered, and that the deepest of them still
/// stays inside the folder.
@Suite("How big a win looks in its folder")
struct PeekSizeTests {

    /// A folder at the size the Recents row draws one. See
    /// `StickerPlacementTests`, which uses the same pair.
    private let w: CGFloat = 150
    private var h: CGFloat { w / 1.14 }

    /// Where the stack hangs from, open and closed. `WinFolder.topOfStack`
    /// is private; these are the two ends of the value it interpolates.
    private let topOpen: CGFloat = 0.135
    private let topClosed: CGFloat = 0.30

    @Test("A small looks small and a hard looks large")
    func theLadderIsOrdered() {
        let sizes: [BlockSize] = [.small, .medium, .hard]
        let depths = sizes.map { PeekSize.depth(for: $0) }
        let widths = sizes.map { PeekSize.widthShare(for: $0) }
        #expect(depths == depths.sorted(), "the depths are \(depths), which is not ordered")
        #expect(widths == widths.sorted(), "the widths are \(widths), which is not ordered")

        // The step that matters is the AREA, because that is what a glance
        // compares. Half again from the smallest to the largest.
        let area = zip(depths, widths).map { $0 * $1 }
        #expect(area[2] / area[0] >= 1.4,
                "a hard is only \(area[2] / area[0]) of a small, which nobody will see")
    }

    /// **The one thing it may never do.** A card hanging through the bottom
    /// of the folder is the illusion gone, and it is what the first attempt
    /// at this did: photographed, a pink corner under Today and Yesterday.
    ///
    /// **Proven able to fail**: a hard at 1.05 puts the card 5% of a folder
    /// past the bottom edge and this goes red.
    @Test("No card hangs out of the bottom of the folder")
    func everyCardStaysInside() {
        for size in [BlockSize.small, .medium, .hard] {
            let depth = PeekSize.depth(for: size)
            // The card is hung from the top of the stack and measured to
            // where it ends, so where it ends IS the depth. The 2% is the
            // stagger the deepest card in a fan of five carries.
            #expect(depth + 0.02 <= 1.0,
                    "a \(size) reaches \(depth + 0.02) of the way down a folder")

            // And it is still a card at both ends of the open and shut
            // animation rather than an inverted rectangle.
            #expect(h * depth - h * topOpen > 0, "a \(size) has no height open")
            #expect(h * depth - h * topClosed > 0, "a \(size) has no height closed")
        }
    }

    /// The width has to stay a share of the folder rather than growing into
    /// one: a fan of cards as wide as the pocket reads as a smudge, which is
    /// the note the folder's own documentation keeps.
    @Test("A card is a card in a folder, not the folder")
    func widthsStayInsideThePocket() {
        for size in [BlockSize.small, .medium, .hard] {
            let share = PeekSize.widthShare(for: size)
            #expect(share > 0.25 && share < 0.55,
                    "a \(size) is \(share) of the folder wide")
        }
    }
}
