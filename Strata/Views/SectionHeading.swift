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

    /// **A TITLE OVER A SHELF, NOT A LABEL OVER A FORM GROUP.** (2026-10-01)
    ///
    /// The owner, on the Memories page: "the UI still feels very cramped, and a
    /// lot looks like it should be remade and redesigned, not just tweaked."
    ///
    /// This was 13pt kerned small caps in `inkSecondary` — the iOS settings
    /// label, and the right thing above a group of switches. Above a shelf of
    /// photographs it is wrong in a way that compounds: the page's own title is
    /// 34pt ink, and every band under it was introduced by a mark two whole
    /// tiers quieter, so the page read as one title followed by four footnotes,
    /// each announcing something large. Nothing in the middle, which is what
    /// "cramped" means when the spacing is already generous — there was no
    /// hierarchy for the eye to rest on between the title and the pictures.
    ///
    /// It is the app's middle tier now, in ink, in title case: the same weight
    /// the month picker beside it wears, so the page reads title, then month,
    /// then sections. Which is what Photos does, and what this page is.
    ///
    /// **Only three callers**, all of them shelves on this page —
    /// `FormSectionLabel` is the separate component Profile and Settings use
    /// and it keeps the small caps, because a label over a form group and a
    /// title over a shelf of pictures are different jobs.
    var body: some View {
        Text(text)
            .font(Typography.headerMedium)
            // Wraps before it shrinks, and shrinks before it clips.
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .foregroundStyle(AppColors.inkPrimary)
            .padding(.horizontal, GridConstants.horizontalPadding)
            // **Air above, and the owner asked for it twice**: "make the white
            // space a big part of the designs." A section break on this page is
            // the biggest gap on it — `gapSection` plus the grid's own 8 —
            // because the thing it separates is one kind of content from
            // another, not one row from the next.
            // **THE PAGE'S BIGGEST GAP, AND IT WAS 40.** The owner,
            // 2026-10-01: "make sure there is a lot of white space I think
            // thats what hey tea does the best." HEYTEA's one move, the one
            // `docs/illustrations.md` records as rule 5, is enormous negative
            // space: the figure sits small in a big empty field.
            //
            // A section heading is where a page changes subject, so it is the
            // one place the page can afford to stop. `gapSection * 2` is 64,
            // which is the biggest gap on any screen by a clear margin and
            // therefore unmistakably a break rather than a wide gap. It stays
            // on the ladder because it is a rung doubled, not a fifth value.
            .padding(.top, GridConstants.gapSection * 2)
            .padding(.bottom, GridConstants.gapItem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - There is no heading-with-a-count, and that is the decision
//
// **If you came here looking for one, do not build it.** `SectionHeadingCount`
// and `CountReadout` lived in `MemoriesView.swift` with a note saying they
// belonged in this file. They had zero call sites and they are deleted
// (2026-10-01) rather than moved here. The reasoning, written down so the next
// pass does not rediscover it:
//
// **§7's "how much is here" is answered once per PAGE, not once per section.**
// `PhotoGalleryGrid.heading` records what the other reading costs: three agents
// applied the per-section rule to their own band on the same day and the page
// ended up answering it six times on one scroll, four of them with the word
// PHOTOS. A heading with a count on it is the component that produces that, and
// the owner's general instruction covers it: "no unnecessary greyscale
// elements, fairly minimal." `AlbumCarousel` makes the same call in as many
// words: the ALBUMS heading above its shelf deliberately has no count, because
// each card already says how much is on it.
//
// **The page-level count IS built, twice, and neither is `CountReadout`'s
// shape.** Two rungs, differing for reasons each one measured off a build:
//
//   - a count under a screen title: 15pt `StrataFont.relative(_, to: .subheadline)`,
//     NO optical inset ("at 15pt the face's mean left bearing works out near
//     1pt, under the size worth correcting"), `inkTertiary`, word in
//     `Typography.screenSubtitle`. `DayAlbumDetailView`, `PhotoCollectionView`.
//   - a count in a card's caption: 13pt relative to `.footnote`, WITH
//     `-StrataFont.opticalInset * 13` of leading so the digits stand on the
//     card's edge, `inkTertiary`, word at the label tier, lower case.
//     (It said `Typography.bodySmall`; that token is deleted — 2026-10-01.)
//     `MemoriesShelf.countLine`, `AlbumCarousel.caption`.
//
// `CountReadout` is 13pt with no inset, `inkSecondary` digits, and its unit in
// uppercase kerned `sectionLabel`: a seventh variant, and the one voice the
// Memories pass removed on the owner's reading: "'46 WINS' under a card and '46
// wins' in `MonthReplayRow` is the same fact set two ways on one screen, and the
// shouted one is the one nobody asked for." Adopting it would be a visual
// regression at every site and would move the ink off a measured number
// (`inkQuiet` 0.45 gave **3.31:1** and failed; `inkTertiary` 0.55 gives 4.69).
//
// If one shared component is wanted it needs both rungs above, and that is the
// owner's call rather than a rename of the unused one.

// MARK: - The ground under a pinned heading

extension View {
    /// The wash a heading needs when it is PINNED to the top of a scroll view.
    ///
    /// A pinned header that is not opaque has the content scrolling through the
    /// type behind it. A flat fill fixes that and draws a box around the word
    /// instead, so this is the page header's own wash: the ground at full
    /// strength under the type, gone 12pt below it. Fading INTO
    /// `WarmBackground.top` rather than into a second copy of that colour is the
    /// whole reason `top` is a named token (see `WarmBackground`).
    ///
    /// **It was a `pinned` boolean on `SectionHeading` that nothing ever passed.**
    /// A flag with one value in the whole app is a decision nobody made, and the
    /// wash could never have served the app's one real pinned header anyway,
    /// because that header is a `MonthPicker` (a `Menu`) and not a
    /// `SectionHeading`. `PhotoGalleryGrid` had meanwhile settled the gallery's
    /// month headings the other way and written down that they are deliberately
    /// NOT pinned. So the capability is a modifier now, callable by whatever
    /// actually pins, and the flag is gone.
    ///
    /// **Apply it OUTSIDE the padding of the thing that pins**, never inside it:
    /// a wash that stops short of the header's own top and bottom insets leaves
    /// a strip of content showing above and below the word, which reads worse
    /// than no wash at all.
    func pinnedHeaderWash() -> some View {
        background {
            LinearGradient(
                stops: [
                    .init(color: WarmBackground.top, location: 0.0),
                    .init(color: WarmBackground.top.opacity(0.92), location: 0.70),
                    .init(color: WarmBackground.top.opacity(0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -12)
            .allowsHitTesting(false)
        }
    }
}
