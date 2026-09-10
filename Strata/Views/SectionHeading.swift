import SwiftUI

/// The one heading on a page that is not the page's title.
///
/// **This exists because the intent was already written down and the code had
/// drifted from it.** `Typography.sectionLabel`'s own doc comment says
/// "uppercase section labels — ALBUMS, SEPTEMBER, a month in the gallery. One
/// style for all of them, so a heading is recognisable as a heading." It was
/// then used at THREE different inks (0.35 on the shelf's label, 0.55 on the
/// gallery's month, 0.55 on the month picker) with the case decided by
/// whatever string each caller happened to pass — so "ALBUMS" and "September"
/// sat one above the other on the same screen, at the same rank, looking like
/// two different ranks.
///
/// A token is not a style. A token is a font; a style is a font AND its ink
/// AND its case AND the space around it, and every one of those has to come
/// from one place or they drift again. That is what this is.
///
/// The ink is 0.45 — between the two it replaces, and deliberately not either.
/// At 0.35 a heading over a page of photographs disappeared; at 0.55 it
/// competed with the content under it. A heading is a signpost: you should be
/// able to find it without ever looking at it.
struct SectionHeading: View {
    let text: String

    /// Whether it will be pinned to the top of a scroll view. A pinned header
    /// that is not opaque has the grid scrolling through the type behind it —
    /// so it takes the page's own ground, and only when it needs it.
    var pinned = false

    var body: some View {
        Text(text)
            .font(Typography.sectionLabel)
            .kerning(Typography.sectionKerning)
            // **Case comes from the style, not from the caller.** This is the
            // whole bug: "ALBUMS" was uppercase because somebody typed it that
            // way and "September" was not because it is a month's name.
            .textCase(.uppercase)
            .foregroundStyle(.primary.opacity(0.45))
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapSection)
            .padding(.bottom, GridConstants.gapLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { if pinned { WarmBackground() } }
            .accessibilityAddTraits(.isHeader)
    }
}
