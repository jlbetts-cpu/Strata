import SwiftUI

/// The two things the block views share: the one date formatter, and what is
/// drawn on the face.
///
/// They used to live in `HabitBlockView.swift` alongside a block view that only
/// `TowerView` rendered — and `TowerView` was referenced by nothing. Deleting
/// the dead view would have taken these with it, so they moved here first.
/// `FlippableBlockView` (the one the tower actually renders) and `BlockFace`
/// are what depend on them now.
///
/// **There is no time on a block, so there is no time formatting here.**
/// `endTime`, `format12Hour` (both of them), `timeRange`, `dateLabel` and
/// `displayText` went with the timestamps: every one of them had no caller,
/// and a helper that writes a time the app does not draw reads like a feature
/// you cannot find. `dateFormatter` is the only member left with a caller.

// MARK: - Time Formatting Helpers

enum BlockTimeFormatter {
    /// A key formatter: Gregorian and POSIX (`DateUtils.keyFormatter`).
    static let dateFormatter = DateUtils.keyFormatter("yyyy-MM-dd")

}


// MARK: - Shared Block Content Overlay

/// The shadow that keeps a block's title readable.
private struct TitleShadow: ViewModifier {
    /// Over a photograph this is `Legibility`, the app's one definition for
    /// white type on imagery it does not control.
    ///
    /// Over flat colour it is a different and much lighter job — the ground is
    /// a colour this app chose, at a brightness it knows, so the glyph only
    /// needs separating rather than defending. Two thirds of the ink, and it is
    /// the number that replaced the scrim under the label.
    let onPhoto: Bool

    func body(content: Content) -> some View {
        content.shadow(
            // Black under both, because the type is white on both. This was a
            // white halo for the hour the dark ink was in: a dark shadow under
            // a dark word thickens the word rather than separating it. The ink
            // went back to white, so the halo did too.
            //
            // **This is the dial that carries a block's legibility now**, and
            // it is the one to reach for if a title ever reads badly in
            // daylight. See `CategoryStyle.text`.
            color: .black.opacity(onPhoto ? Legibility.ink : Legibility.ink * 0.62),
            radius: Legibility.radius * (onPhoto ? 1 : 0.7),
            x: 0, y: Legibility.y)
    }
}

struct BlockContentOverlay: View {
    let title: String
    /// No `category`. It was threaded back in for an hour while a block's
    /// title was written in `category.style.text`, and it went out again with
    /// the dark ink: a property nothing reads is the thing this comment was
    /// originally written about.
    let rowSpan: Int
    /// No `timeText`. Nothing has drawn a time on a block since the tower
    /// stopped showing timestamps, and every call site was passing `nil`
    /// through two views to reach a property nothing read.
    var hasImage: Bool = false

    /// A block nobody has named carries no text at all — no title, no time.
    ///
    /// "Win" is not a name, it is the absence of one, and a block that says it
    /// is louder than the thing it describes. Its presence already says "this
    /// happened"; a label repeating that is the only part of it that could be
    /// wrong. Naming it in the card gives it its text.
    private var isUnnamed: Bool {
        Self.isUnnamed(title)
    }

    /// Shared so the block view can ask the same question before deciding
    /// whether a photograph needs a veil under text that is not there.
    static func isUnnamed(_ title: String) -> Bool {
        title == QuickWinService.untitled || title.isEmpty
    }

    // No icon on the block.
    //
    // The colour already says which category it is, and the icon was repeating
    // that in the one place where two same-coloured blocks are trying to look
    // like one object — a corner mark halfway down a merged shape is the
    // clearest possible statement that it is two. Icons still name categories
    // where the colour alone cannot: the picker, the timeline rows, the plan
    // list.
    //
    // So this is one title in one stack. The `ZStack` that used to hold the
    // icon beside it went with the icon; a container with one child is a
    // container claiming there are two things here.
    /// **The label carries its own contrast, and there is no rectangle under
    /// it.**
    ///
    /// There was one for exactly one build. The glass pass drained the block's
    /// rim toward white, so white text on the bottom corner lost its ground —
    /// measured at 198 behind the label against 176 before — and a short ink
    /// gradient over the bottom third put it back. The number was right and the
    /// object was wrong, which the owner saw at once: "blocks lowkey look
    /// broken now with all the new changes."
    ///
    /// A block has no banner on it. On a MERGED RUN the damage is plain: the
    /// scrim belongs to a member, so a continuous field of one colour came out
    /// with a dark rectangle stamped under every title in it and a hard
    /// vertical seam everywhere two members met. One object, drawn as five.
    ///
    /// The contrast is bought where it is needed instead — on the glyphs, with
    /// the same shadow a title over a photograph already wears. It costs
    /// nothing anywhere the text is not, so there is nothing to seam.
    ///
    /// And the reason the rectangle was needed at all is gone: `EtherealFill`
    /// no longer drains the rim (0.82, and the gradient is sized to the object
    /// rather than to the whole grid), so the ground under a label is back
    /// where it was before any of this.

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer()
            if !isUnnamed {
                Text(title)
                    // **13 Medium, and it is the one piece of text in the app
                    // left below the 15pt floor** (2026-10-01, the type pass).
                    // The owner asked for "no tiny thin font anywhere";
                    // everything else moved and this did not, and the reason is
                    // a measurement rather than an opinion.
                    //
                    // A block's title is sized to the BLOCK, not to the page —
                    // the same family as the month block's `cell * 0.16`
                    // numeral, which `Typography` has always named as outside
                    // the scale. The live cell is `GridConstants
                    // .blockReferenceCell` 86.5, less the 12 leading and 8
                    // trailing set below, so a 1x1 block offers **66.5pt** of
                    // room on its one line.
                    //
                    // Measured with Core Text over fourteen ordinary titles,
                    // SF Medium: **4 truncate at 13 and 8 at 15.** "Inbox zero"
                    // is 64.4pt at 13 and 72.8 at 15; "Groceries" 60.1 and
                    // 68.0; "Deep work" 66.2 and 75.0. Raising this rung
                    // doubles the truncation rate on the one string the person
                    // typed, in the one place the app is meant to be a picture
                    // of what they did rather than a log of it. That is a worse
                    // trade than a 13pt label, and `minimumScaleFactor` is not
                    // the way out of it — see the note on `lineLimit` below,
                    // which is why it came off.
                    //
                    // **It is MEDIUM, which is what the instruction was really
                    // about**, and it already was. Spelled out here rather than
                    // taken from a token, because there is no 13pt token any
                    // more and there must not be one: this is the only site.
                    // If this is reopened, the lever is the CELL, not the type.
                    .font(.system(.footnote, design: .default, weight: .medium))
                    // **White, and the owner chose it over a measured
                    // alternative.** A dark ink was built, rendered on the
                    // real tower and put in front of him, because white here
                    // measures 1.71:1 on the orange against the 4.5 a 13pt
                    // word is held to and dark measures 6.00 to 9.77. He
                    // preferred white. The whole table and the three fixes
                    // that do not work are on `CategoryStyle.text`.
                    .foregroundStyle(.white)
                    // One size on every block, and an ellipsis when it does
                    // not fit.
                    //
                    // `minimumScaleFactor` shrank the type to fit, so a
                    // tower of ten blocks could carry six different text
                    // sizes and the size read as emphasis nobody had
                    // chosen — the shortest title looked the most
                    // important. Truncation is honest: same size
                    // everywhere, and the ones that run long say so.
                    .lineLimit(rowSpan > 1 ? 2 : 1)
                    .truncationMode(.tail)
                    // **On every block, not only on a photograph.**
                    //
                    // Over a picture it is what makes the veil a veil rather
                    // than a bar. Over a colour it is what replaced the scrim:
                    // the glyphs get their ground, and the block keeps its
                    // face. It is the same shadow either way, because it is
                    // the same job.
                    .modifier(TitleShadow(onPhoto: hasImage))

                // No time on the block.
                //
                // A tower of a dozen blocks was a dozen timestamps nobody
                // reads — the same information twelve times, in the one
                // place the app is meant to be a picture rather than a
                // log. What a block says is what you did; when you did it
                // is on the card if you ever want it.
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .padding(.leading, 12)
        .padding(.bottom, 12)
        .padding(.trailing, 8)
        // Behind the text and nothing else. An unnamed block has no label, so
        // it gets no scrim and keeps its colour clean to the foot.
    }
}
