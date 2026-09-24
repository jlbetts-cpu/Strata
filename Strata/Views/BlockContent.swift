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
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

}


// MARK: - Shared Block Content Overlay

/// The title's shadow on a photographed block: 0.55 black, 3pt, 1pt down.
private struct PhotoTitleShadow: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)
        } else {
            content
        }
    }
}

struct BlockContentOverlay: View {
    let title: String
    /// No `category`. The icon went (see `body`) and took the only thing that
    /// read one here with it; the property, and `BlockFace.iconCategory` that
    /// fed it, were threaded through two views and a replay to reach nothing.
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
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer()
            if !isUnnamed {
                Text(title)
                    .font(Typography.bodySmall.weight(.medium))
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
                    // On a photo the scrim is a light veil now, so the type
                    // carries its own contrast instead of the block being
                    // darkened until anything would be legible on it.
                    //
                    // Only on a photo. Off one it was a shadow at zero
                    // opacity on every label on the tower, and a
                    // zero-valued effect is still an effect.
                    .modifier(PhotoTitleShadow(active: hasImage))

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
    }
}
