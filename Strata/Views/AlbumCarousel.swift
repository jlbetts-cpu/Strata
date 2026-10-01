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
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(1)
                .padding(.top, GridConstants.gapTight)
            caption
                .padding(.top, 2)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.title), \(album.subtitle)")
    }

    /// How much is on this card: the number, then what it counts.
    ///
    /// **The number is a readout and the word is a label.** The whole string
    /// was one `Text` in `Typography.sectionLabel`, so "18 PHOTOS" set its
    /// number in the heading face and this was the one card in the app whose
    /// count was not the owner's digits. §2: counts and indices are his face,
    /// tabular; anything that reads as language is SF Rounded. The replay
    /// poster on the row above already splits them, and the two captions sit
    /// twelve points apart.
    ///
    /// **Not `CountReadout`.** That one is laid out beside a section heading,
    /// takes `inkSecondary` for its digits and carries no optical inset. Here
    /// both lines of the caption are the quiet tertiary and both have to stand
    /// on the card's leading edge, which is what the inset is for.
    ///
    /// This keeps the count the card always had rather than adding one: §7's
    /// "how much is here" is answered once per card by the thing that was
    /// already there, and the ALBUMS heading above deliberately has no count
    /// of its own.
    private var caption: some View {
        let parts = Self.splitCaption(album.subtitle)
        return HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            if let number = parts.number {
                Text(verbatim: number)
                    .font(StrataFont.relative(Self.captionSize, to: .footnote))
                    // Optical, as the replay card's count is: tabular centring
                    // puts real air to the left of every digit, so the box
                    // sits a little left of the margin to stand the name and
                    // the caption on one edge.
                    .padding(.leading, -StrataFont.opticalInset * Self.captionSize)
            }
            // Lower case, like every other caption on this page now. See
            // `ReplayShelf.countLine`.
            Text(parts.words.lowercased())
                .font(Typography.bodySmall)
        }
        .foregroundStyle(AppColors.inkTertiary)
        .lineLimit(1)
    }

    /// `Typography.sectionLabel`'s own size, so the digits and the word beside
    /// them are one line of type and not two sizes. Digits go this small
    /// safely; letters do not (`StrataFont`: his D reads O at 13).
    private static let captionSize: CGFloat = 13

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

/// How a cover answers a finger: it gives, and it is over in 0.06s.
///
/// **`ReplayShelf`'s `PosterPress`, to the point.** That is the press on the
/// row directly above this one inside the same panel, and the two are one
/// control. It is declared here rather than shared because `ReplayShelf.swift`
/// belongs to another pass; they should be one type when they can be in one
/// place.
///
/// `tapSquashSpring` is the app's press rung and `tapScaleY` the amount every
/// other pressable surface gives by, so a cover does not get a number of its
/// own. **Uniform, not the block's squash**: `tapScaleX`/`tapScaleY` together
/// are a thing landing on a floor, and this is a card being pressed into the
/// page, with its own name and caption inside the same label.
///
/// Under Reduce Motion nothing scales. The haptic on the press and the opening
/// itself still happen, so the card still answers.
private struct CardPress: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed && !reduceMotion
        return configuration.label
            .scaleEffect(down ? GridConstants.tapScaleY : 1)
            .animation(GridConstants.tapSquashSpring, value: down)
    }
}
