import SwiftUI
import UIKit

// **SF Pro, not SF Pro Rounded.**
//
// The owner, 2026-09-23: "I feel like the app would look a lot cleaner with
// SF Pro... I want the app to feel a lot more premium and cleaner."
//
// This is the second time he has made the same call: he moved the Apollo
// build off Rounded in the same words ("I want SF Pro, no SF Pro Rounded, I
// feel like that fits the editorial aesthetic more"). Rounded is friendly,
// and friendly is not the register this app is in. The design language is a
// bright 1990s Japanese future, an instrument in a well lit room, and an
// instrument is set in a neutral grotesque. It also stops the two faces
// fighting: Jaro is the character, and the text face's job is to get out of
// its way.
//
// `CLAUDE.md` still records Rounded as settled. It is superseded by this,
// and the note there says so.

enum Typography {
    // MARK: - The scale: five sizes, two weights
    //
    // 34, 17, 15, 13 and 11, at Regular and Medium (docs/research/font.md
    // (c)). Semibold came off the scale: the owner's face had one cut, and its
    // heavy drawn stem already did the job a third weight did. Every token is a
    // text STYLE, so Dynamic Type moves the lot together.
    //
    // **One exception, and it is not in this file.** This said "semibold is gone
    // from the app", and that has been false since the drawn letterforms came
    // off on 2026-09-30: `DrawnLettering` in `StrataMark.swift` sets
    // `MemoriesTitle` semibold, because that title stands over a live map and
    // the weight is what replaced the drawing's stroke. The measurement is
    // written beside it: 14.5% more stem than Medium, 3.68pt against 4.21pt at
    // the title's size, read out of SF's own `wght` axis. A claim about the
    // whole app that one screen breaks is worse than the exception itself, so
    // the exception is named.
    //
    // Merged on 2026-09-16, each into the rung it was nearest: headerLarge
    // (20) and blockTitle (16) into `headerMedium`, bodyMedium (16) into
    // `bodyLarge`, caption (12) into `bodySmall`, photoCaption (12) into
    // `sectionLabel`. Deleted with no call sites: brandLogo, brandHeader,
    // brandSubheader, brandHeroDate, brandCardTitle, appTitle,
    // miniBlockTitle, miniBlockIcon and the three kernings beside them.
    //
    // Outside the scale on purpose, because geometry solves them rather than
    // a choice: the month block's `cell * 0.16` numeral, the camera
    // countdown, the widget's counts, and symbol glyph sizes.

    /// 17 Medium. Headings, and a block's or a card's title.
    static let headerMedium = Font.system(.headline, design: .default, weight: .medium)
    /// 15 Medium. Buttons.
    static let headerSmall = Font.system(.subheadline, design: .default, weight: .medium)
    /// 17 Regular. What you read.
    static let bodyLarge = Font.system(.body, design: .default)
    /// 13 Regular. Footnotes and captions.
    static let bodySmall = Font.system(.footnote, design: .default)
    /// 11 Medium. Chart axes and the smallest labels.
    /// **No call sites, and that is deliberate now.** Its doc said "chart axes
    /// and the smallest labels", and the audit took both of its callers off it
    /// on the same day: the plan's repeat caption and the profile chart's axis,
    /// each because 11 Medium was a fourth size on a screen that already had
    /// three. Kept rather than deleted so the next person reads this line
    /// instead of reintroducing an 11pt rung on the strength of a stale
    /// comment: if a label is too small for `bodySmall`, the screen has a
    /// hierarchy problem and not a type problem.
    static let caption2 = Font.system(.caption2, design: .default, weight: .medium)

    // MARK: - The screen scale
    //
    // Three sizes for everything a screen says about itself, and no more.
    //
    // The app had drifted to a different title size per screen — Memories at
    // 48, a day at 33, an assortment of `.title3`/`.headline` elsewhere — so
    // moving between tabs meant the same kind of thing arriving at a different
    // weight each time. Less variety is the whole point: a page with one title
    // size and one label size has a hierarchy you can read without looking for
    // it.

    /// **Text STYLES, not point sizes.**
    ///
    /// These were `.system(size:)`, which is a fixed size and does not move
    /// when somebody turns Dynamic Type up. That is the single most-used
    /// accessibility setting on iOS and this app is meant to be handed to
    /// someone's grandmother, so a title that ignores it is not a small
    /// omission.
    ///
    /// Each style below is the one whose DEFAULT size is the number that was
    /// there before, so nothing moves at the default setting and everything
    /// moves together at any other: large title 34, subheadline 15, footnote
    /// 13, caption 12.

    /// The one screen title. Every page that names itself uses this.
    ///
    /// 34pt at the default size is the platform's own large title, not a
    /// number picked to look impressive. The 48 it replaced came from a lowfi
    /// and made the title the loudest thing on a page whose subject is
    /// photographs and blocks.
    static let screenTitle = Font.system(.largeTitle, design: .default, weight: .medium)

    /// The same title in the owner's face (`StrataFont`), for a title that
    /// names the screen, through `DynamicScreenTitle` where the words are data.
    static let screenTitleDrawn = StrataFont.relative(screenTitleSize, to: .largeTitle)

    /// A sheet's title in the owner's face, 17 relative to `.headline`. See
    /// `View.sheetTitle(_:drawn:)`.
    static let sheetTitleDrawn = StrataFont.relative(17, to: .headline)

    /// The metric behind it, for layout that has to do arithmetic — the
    /// header's cap-height padding, and the tally numeral. Fixed, because a
    /// layout constant cannot be a font.
    static let screenTitleSize: CGFloat = 34

    /// The CAP HEIGHT of a screen title, for artwork that has to match one.
    ///
    /// A `Font.system(size:)` is an em size and its cap is a fraction of that
    /// — 1443/2048 for SF Pro Rounded, read out of `SFNSRounded.ttf`'s own
    /// `OS/2` table rather than eyeballed. A drawing's `size` IS its cap, so
    /// handing a drawn title the 34 would set it 41% taller than the type it
    /// replaced. Measured before this existed: "Memories" came out with a
    /// 33.3pt cap against the tower tally's 23.3pt, on two screens that are
    /// meant to have the same title.
    static let screenTitleCap: CGFloat = screenTitleSize * 1443 / 2048

    /// The line under a screen title: "2 wins", a date, a count.
    static let screenSubtitle = Font.system(.subheadline, design: .default)

    /// Uppercase section labels — ALBUMS, SEPTEMBER, a month in the gallery.
    /// One style for all of them, so a heading is recognisable as a heading.
    static let sectionLabel = Font.system(.footnote, design: .default, weight: .medium)
    static let sectionKerning: CGFloat = 0.8

    /// Any number the app states as a fact about your day: the win tally, a
    /// day's numeral on a month block, a photo count. The owner's own digits
    /// — see `StrataFont`.
    ///
    /// **Numbers, never words.** The face has ten glyphs and a space; a
    /// `Text` in it that contains a letter renders `.notdef`. Anything with a
    /// word in it stays on `screenTitle` / `screenSubtitle`.
    static let tally = StrataFont.relative(screenTitleSize, to: .largeTitle)

    /// The same digits, at a size the caller solves for — a month block's
    /// numeral scales off its cell, not off the type scale.
    static func numeral(_ points: CGFloat) -> Font { StrataFont.size(points) }
}

// MARK: - Jaro
//
// **`JaroFont` is deleted** (2026-10-01), with zero call sites, for the second
// time: `tasks/overnight-report.md` records it going on 2026-09-09 and it came
// back. `docs/research/visual-cohesion.md` lists it twice as dead ("registered
// at launch and used nowhere"). Nothing in the app set a word in Jaro: the
// wordmark went on 2026-09-30 and the mark is the pre-drawn `StrataSMark`
// asset, which carries no font at all.
//
// **The TTF stays and must stay.** `Strata/Resources/Jaro.ttf` (145,616 bytes)
// is what `tools/make_app_icon.py` and `tools/make_logo.py` derive the icon and
// the `S` from, offline, and `Jaro-OFL.txt` ships beside it because the SIL
// licence requires it.
//
// **Its `UIAppFonts` entry is left alone, and it is now registering a face no
// Swift reads.** `Info.plist:7` loads Jaro.ttf at every launch; the only reader
// was this enum. Dropping that line is the remaining 145 KB and needs a launch
// to confirm nothing in the asset catalogue resolves through it, which this pass
// could not run.
