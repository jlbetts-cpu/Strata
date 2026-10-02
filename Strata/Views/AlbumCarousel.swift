import SwiftUI

/// The shelf of albums: things you keep doing, then your days.
///
/// A horizontal shelf inside the page's vertical scroll. Orthogonal axes nest
/// fine — what does not is an anchor. `.defaultScrollAnchor` takes a
/// `UnitPoint`, which always carries BOTH axes, and the y component leaks to
/// the enclosing scroll view; that is exactly how the old bar chart pulled the
/// page down under itself. The carousel wants its leading edge, which is the
// **`AlbumCarousel` is deleted** (2026-10-01). It was a horizontal shelf of
// `AlbumCard`s with its own heading, sitting directly under the replay shelf at
// the same card width — two bands doing the same job. `MemoriesShelf` draws both
// now. The card below is the part of this file worth keeping.

/// One album: the fan, its name, and what it is.
///
/// **Internal, not private** (2026-10-01): `MemoriesShelf` draws albums and
/// replays in one row now, so the card has to be reachable from outside the
/// carousel that used to own it. The carousel itself is gone; this is the part
/// of it worth keeping.
struct AlbumCard: View {
    let album: Album
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AlbumCoverView(photoFileNames: album.photoFileNames, side: width)
            // **A card's name is a caption, not a header.**
            //
            // This was `headerLarge` — the `.title3` a SCREEN uses to name
            // itself — which made "August" the largest type on the whole
            // Memories page, above the month tower it is meant to sit under.
            // Measured on the simulator, its cap matched the page title's.
            // `headerMedium` is the 17 rung the app already uses for the name
            // of one object, which is exactly what this is. (It absorbed the
            // old `blockTitle` on 2026-09-16, which is what the previous
            // version of this note was asking for.)
            //
            // **SF Rounded, and NOT the owner's drawn face**, which is where
            // this card and the replay poster beside it part company on
            // purpose. A replay's name is a period ("September", "9/7-9/13"),
            // which is the app's own noun, so the poster draws it. An album's
            // name is "Gym session" or "A year ago today": the first is a word
            // the person typed and the second is a sentence, and
            // `design-system-future.md` §2 never sets either in the display
            // face.
            Text(album.title)
                .font(Self.titleFont)
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(Self.titleLines)
                .fixedSize(horizontal: false, vertical: Self.titleLines > 1)
                .padding(.top, GridConstants.gapTight)
            caption
                .padding(.top, 2)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.title), \(album.subtitle)")
    }

    /// **Two lines, the owner's call, 2026-10-02.** At 108pt one line drew
    /// "Read a cha…"; the card cannot widen (108 is what puts three and a bit
    /// on screen, see `MemoriesShelf.albumWidth`) and `minimumScaleFactor`
    /// would take a 17pt title under the 15pt floor. He chose wrapping over
    /// truncating from `docs/design-review/memories-album-options.png`: the
    /// whole title reads, and a card with a long one stands a line taller.
    static let titleLines = 2

    private static let titleFont: Font = Typography.headerMedium

    /// How much is on this card: the number, then what it counts.
    ///
    /// **`CountReadout.split`, where this was the fourth copy of six lines**
    /// (2026-10-01, `docs/consistency-audit.md` §1.13). The note that stood here
    /// said "Not a shared count readout, and there is no longer one to reach
    /// for", and it was right at the time: the deleted `CountReadout` took
    /// `inkSecondary` for its digits, carried no optical inset and set its unit in
    /// uppercase kerned `sectionLabel`, which is the one voice the Memories pass
    /// removed. The new one is THIS shape, with the page rung's as its other
    /// setting, and the only thing between them is a boolean. `SectionHeading`
    /// held the condition for building one — "it needs both rungs above" — and
    /// §2.4 found the record of those rungs stale the same day: the caption's 13
    /// went to 15 in the type pass, so the two are one size, one face, one ink and
    /// one word tier.
    ///
    /// **The number is a readout and the word is a label.** The whole string was
    /// one `Text` in `Typography.sectionLabel`, so "18 PHOTOS" set its number in
    /// the heading face and this was the one card in the app whose count was not
    /// the owner's digits. §2: counts and indices are his face, tabular; anything
    /// that reads as language is SF Rounded.
    ///
    /// **There is no optical inset any more, and it was already a no-op.** This
    /// card pulled the digits left by `StrataFont.opticalInset * 15` so that the
    /// name and the caption stood on one edge, and that constant went to **0** on
    /// 2026-09-30 when the drawn face came off the app: SF's digits do not have
    /// the sidebearing it was correcting. The argument is kept on `CountReadout`
    /// because it is right about a drawn face and the TTF is one file away.
    ///
    /// **It does not roll.** A card in a `LazyHStack` is rebuilt when the shelf
    /// reloads rather than updated in place, so there is no transition for
    /// `.numericText()` to animate and the modifier would be a per-card cost for
    /// nothing.
    ///
    /// Lower case, like every other caption on this page. This keeps the count the
    /// card always had rather than adding one: §7's "how much is here" is answered
    /// once per card by the thing that was already there, and the heading above
    /// the shelf deliberately has none of its own.
    private var caption: some View {
        CountReadout.split(album.subtitle)
    }

    // **The private `captionSize` (15) is gone with the lines that read it.** It
    // was 15 here, 15 on the shelf's dead card and 15 on two page headers, with a
    // comment on each explaining the 15. One size, in `CountReadout`. The warning
    // its comment carried is retired rather than lost: at 13 the owner's D read as
    // an O, and at 15 it does not (`StrataFont`).

    /// A caption split into its leading number and the words after it:
    /// "18 PHOTOS" gives ("18", "PHOTOS"), "6 SEP" gives ("6", "SEP"), and a
    /// caption that opens with a letter gives no number at all.
    ///
    /// **Split here, not in `Album`.** The string is the model's statement of
    /// what the caption MEANS, and `AlbumTests` and `AlbumMomentTests` pin it
    /// ("6 PHOTOS", "3 PHOTOS"); how it is SET is this view's business. A
    /// leading figure is a readout whichever kind of album it is: a
    /// photograph count on a moment or an interest, a day number on a day,
    /// so one rule covers all three and none of them can drift.
    static func splitCaption(_ subtitle: String) -> (number: String?, words: String) {
        let digits = subtitle.prefix { $0.isNumber }
        guard !digits.isEmpty else { return (nil, subtitle) }
        let words = subtitle.dropFirst(digits.count).drop { $0 == " " }
        return (String(digits), String(words))
    }
}

// **`CardPress` is deleted** (2026-10-01). Its own note said it was
// `MemoriesShelf`'s `PosterPress` "to the point", and it was: the two bodies
// were identical to the character. The difference is that `PosterPress` is on
// two live posters and this one was on nothing: there is no `Button` left in
// this file. So the duplicate the comment apologised for was also the dead
// half of the pair, and the shared control the note asked for is the one that
// survived.

