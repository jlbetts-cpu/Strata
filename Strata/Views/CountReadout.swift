import SwiftUI

/// **How much is here: the number in the owner's digits, the unit in SF.**
///
/// One component, four call sites, where there were four copies of six lines.
///
/// # Why this exists now when `SectionHeading` says not to build it
///
/// `SectionHeading.swift` carries the refusal and it was right when it was
/// written: "If one shared component is wanted it needs both rungs above, and
/// that is the owner's call rather than a rename of the unused one." The two
/// rungs it names were
///
///     a count under a screen title    15pt, no optical inset
///     a count in a card's caption     13pt, WITH -opticalInset * 13
///
/// and `docs/consistency-audit.md` §2.4 found that record stale within the day:
/// the caption rung went to 15 in the same type pass (`AlbumCarousel.swift`,
/// "It was 13 and is 15"; `MemoriesShelf.swift`, "It was 13 and moved with
/// everything else off that rung"). So the two rungs are now **one size, one
/// face, one ink, one word tier**, and the only thing left between them is a
/// boolean. That is the condition the refusal set, met.
///
/// It is NOT the deleted `CountReadout` brought back. That one was 13pt with no
/// inset, `inkSecondary` digits, and its unit in uppercase kerned
/// `sectionLabel` — a seventh variant, and the shouted voice the Memories pass
/// removed on the owner's reading ("'46 WINS' under a card and '46 wins' in
/// `MonthReplayRow` is the same fact set two ways on one screen, and the shouted
/// one is the one nobody asked for"). This is the shape the three live call
/// sites already drew, with their measurements kept.
///
/// # The numbers, carried forward from the sites this replaces
///
/// **`StrataFont.digits`, never `Text("\(n)")`.** Interpolation is a
/// `LocalizedStringKey` and groups 1000 as "1,000"; the face has no comma, and
/// the map badge once showed "1,0" over "00".
///
/// **15, the app's label tier.** `Typography.headerSmall` / `screenSubtitle` /
/// `sectionLabel` are all one size since 2026-10-01, so the digits and the word
/// beside them are one line of type and not two sizes agreeing by accident. At
/// 13 the owner's D read as an O (`StrataFont`); at 15 it does not.
///
/// **`inkTertiary`, and it is a contrast failure rather than a preference.**
/// Measured off a build on the light page: ground rgb(249,247,244), `inkQuiet`
/// (black 0.45) composites to rgb(137,136,134) and gives **3.31:1** against the
/// 4.5 text is held to; `inkTertiary` (0.55) lands at rgb(112,111,110) and
/// **4.69:1**. `inkQuiet`'s own doc says it is "held to 3:1, not 4.5:1, and
/// deliberately: these are UI elements and decorative glyphs rather than text
/// somebody has to read", and it names a count as the thing it is never for.
///
/// **Lower case.** Small caps are a LABEL's voice and belong over a form group,
/// which is where `FormSectionLabel` still uses them. A count under a title or a
/// picture is a sentence fragment.
struct CountReadout: View {
    let count: Int
    /// The word after the number, singular. Pluralised by adding an "s", which
    /// is true of every unit this app counts ("win", "photo"); a unit that does
    /// not pluralise that way should be passed through `plural` instead.
    let unit: String
    let plural: String

    // MARK: - There is NO optical inset, and that is the whole shape of this type
    //
    // **The parameter was written, built, and then measured away within the
    // hour.** `docs/consistency-audit.md` §1.13 says "the only thing left that
    // separates the two pairs is the optical inset", and §2.4 says the record of
    // the two rungs is stale because the caption's 13 went to 15. Both are true
    // and both are already behind the real answer:
    //
    //     Shared/StrataFont.swift:50   static let opticalInset: CGFloat = 0
    //
    // with its own note — "**Zero now.** This was 0.0712, the mean left
    // sidebearing of the drawn digits, which had real air to the left of every
    // glyph ... SF's digits do not have that problem, and a negative pad
    // compensating for a bearing that is gone would pull every count a point and
    // a half off its margin." The drawn face came off the app on 2026-09-30 and
    // `StrataFont` is a shim over SF now.
    //
    // So the inset was a no-op at every one of its call sites before this pass
    // began, the shelf's and the album card's arguments for it were arguments
    // about a face that is no longer set, and a parameter for it would be a
    // switch between zero and zero. **The two rungs are one readout with no
    // options**, which is more than `SectionHeading`'s condition asked for.
    //
    // Both arguments are kept, because they are correct about the thing they
    // were about and will be correct again if the TTF goes back (it is still in
    // `Shared/`, still registered, and `StrataFont`'s header says reinstating it
    // is one file): a count in a CARD's caption wants the bearing corrected so
    // the name and the count stand on one edge, and a count under a SCREEN TITLE
    // does not, because 1pt off a 16pt page margin is check 11d and a card has no
    // margin to be off.

    /// `.numericText()` on the number alone, so a count that changes while you
    /// are looking at it rolls rather than cutting.
    ///
    /// **It was on one of five readouts.** The day album had it and the place
    /// collection, drawn from the same template five lines apart, did not. It
    /// belongs wherever the count can change under a finger — deleting a
    /// photograph from the viewer calls `load()` on both of those pages — and it
    /// is `true` by default for that reason: a readout that cuts is the odd one
    /// out, not the norm. A card in a shelf is rebuilt rather than updated, so
    /// it passes `false` and spends nothing.
    var rolls: Bool = true

    /// The app's label tier. `Typography.headerSmall` / `screenSubtitle` /
    /// `sectionLabel` are all this size, so the digits and the word beside them
    /// are one line of type rather than two sizes agreeing by accident.
    ///
    /// Not `private`, so `ConsistencyTests` can hold the one-size rule without a
    /// simulator — the same reason `HeadPickerRow.ringInk` is not private.
    static let size: CGFloat = 15

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            Text(verbatim: StrataFont.digits(count))
                .font(StrataFont.relative(Self.size, to: .subheadline))
                .modifier(NumericRoll(on: rolls))
            Text(count == 1 ? unit : plural)
                .font(Typography.screenSubtitle)
        }
        .foregroundStyle(AppColors.inkTertiary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

extension CountReadout {
    /// The two units this app counts, so a caller cannot misspell a plural.
    static func wins(_ count: Int, rolls: Bool = true) -> CountReadout {
        CountReadout(count: count, unit: "win", plural: "wins", rolls: rolls)
    }

    static func photos(_ count: Int, rolls: Bool = true) -> CountReadout {
        CountReadout(count: count, unit: "photo", plural: "photos", rolls: rolls)
    }
}

/// `.contentTransition` behind a flag, because a modifier cannot be applied
/// conditionally inside a `ViewBuilder` without changing the view's identity —
/// and a count whose identity changes is a count that cuts rather than rolls,
/// which is the behaviour this exists to control.
private struct NumericRoll: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        content.contentTransition(on ? .numericText() : .identity)
    }
}

// MARK: - The album card's caption, which is a count with a word it does not own
//
// `AlbumCard` draws `album.subtitle` — "18 PHOTOS", "6 SEP" — which is the
// MODEL's statement of what the caption means, pinned by `AlbumTests` and
// `AlbumMomentTests`. Its unit is therefore not a word this file knows, so the
// card keeps `AlbumCard.splitCaption` and hands the halves to
// `CountReadout.split`, below. Everything else about it is this component's.

extension CountReadout {
    /// A caption that arrives as one string with its number already in it.
    ///
    /// The count is parsed back out so the digits can be set in the owner's
    /// face, which is the whole reason this is not one `Text`: set as a single
    /// string in `sectionLabel`, "18 PHOTOS" was the one card in the app whose
    /// count was not his digits.
    static func split(_ subtitle: String) -> some View {
        let parts = AlbumCard.splitCaption(subtitle)
        return HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            if let number = parts.number {
                Text(verbatim: number)
                    .font(StrataFont.relative(size, to: .subheadline))
            }
            Text(parts.words.lowercased())
                .font(Typography.screenSubtitle)
        }
        .foregroundStyle(AppColors.inkTertiary)
        .lineLimit(1)
    }
}
