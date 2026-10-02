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
    // MARK: - The scale: THREE sizes, ONE weight
    //
    // **34, 17, 15. Medium. That is the whole scale** (2026-10-01).
    //
    // The owner, looking at the built app: "I dont like the tiny text lets
    // remove it focus on the bigger text making it more clear and thicker like
    // a premium font instead of thin... on everypage the weight should be
    // similar no tiny thin font anywhere", and "I hate when there is like one
    // type of font next to another... I like the text that is there to feel
    // like a medium weight and be consistent guiding the user no tiny text
    // under or anythign like that I want it to be controlled."
    //
    // So two things went in this pass, and they are the two he named:
    //
    // 1. **The 13 and the 11 are gone, tokens and all.** `caption2` (11) had
    //    no call sites and `bodySmall` (13) had 29: one of those was deleted
    //    outright, four went to 17 because they are consequences rather than
    //    captions, and the other 24 went to 15. Both tokens are deleted, so
    //    there is no 13 or 11 left for anyone to reach for by accident.
    //    `sectionLabel` was 13 and is 15.
    // 2. **Regular is gone.** `bodyLarge` and `screenSubtitle` were Regular and
    //    are Medium. Nothing a person reads is set lighter than Medium now.
    //
    // What that costs, and it is the honest price: **17 and 15 are now one
    // weight as well as one face, so size is the only thing separating a
    // heading from the line under it.** That is the look he asked for — "the
    // thicker font with less font around it" — and the way it is kept readable
    // is ink, not weight: a heading takes `inkPrimary` and the line under it
    // `inkSecondary`. Measured on SF's own `wght` axis at `opsz` 17, upem 2048:
    // a capital's stem goes 0.0879 em Regular to 0.1097 Medium, 1.50pt to
    // 1.87pt, 24.8% more stroke on every body line in the app.
    //
    // **The three tiers are the only numbers here, and they are the drop-in
    // point for the custom face.** Every token below is `tier(_:)` or the
    // owner's digits; none of them names a size of its own. When the typeface
    // arrives it replaces the one `.system` call inside `tier(_:)` with
    // `.custom(name, relativeTo:)`, and `StrataFont` beside it, and nothing
    // else in the app has to be found.
    //
    // **Three EXCEPTIONS survive below 15, each named where it lives**, because
    // in each case the measurement argues against the instruction and
    // `CLAUDE.md` says to report the number rather than narrow the ask:
    //
    // - **A block's title, 13 Medium** (`BlockContent`). It is sized to the
    //   BLOCK, not to the page. Measured with Core Text at the live 86.5pt cell
    //   (66.5pt of room after the 12/8 padding), over fourteen ordinary
    //   titles: 4 truncate at 13 and 8 at 15. "Inbox zero" is 64.4pt at 13 and
    //   72.8 at 15. Doubling the truncation rate on the one string the person
    //   typed is a worse trade than a 13pt label.
    // - **Geometry-solved numerals** (`numeral(_:)`): the month block's
    //   `cell * 0.16`, the camera's 96pt countdown, and the map's cluster badge
    //   at 13. These are a fraction of an object, not a rung on a scale, and
    //   they always were. Only the badge is actually under the floor, and its
    //   own comment carries the number: at 15 a two-digit capsule goes 24.3pt
    //   to 27.1, 55% of the 44pt block to 62%, re-inflating a badge that was
    //   deliberately measured down to 16.7% of it on the same day.
    // - **`MemoriesStill`'s tab bar**, 11 and 20 at a scale factor `s` < 1. It
    //   is a PICTURE of the phone inside the onboarding device frame, and the
    //   numbers in it are iOS's own tab-bar metrics, not this app's type.
    //
    // An SF Symbol's weight is still a separate axis on a separate kind of
    // object (`IconStyle.iconSize(_:weight:)`). A previous pass counted the
    // symbols into the weight ladder, concluded the app had five cuts, and was
    // wrong. Count them in their own column or not at all.
    //
    // Merged on 2026-09-16, each into the rung it was nearest: headerLarge
    // (20) and blockTitle (16) into `headerMedium`, bodyMedium (16) into
    // `bodyLarge`, caption (12) into `bodySmall`, photoCaption (12) into
    // `sectionLabel`. Deleted with no call sites: brandLogo, brandHeader,
    // brandSubheader, brandHeroDate, brandCardTitle, appTitle,
    // miniBlockTitle, miniBlockIcon and the three kernings beside them.
    //
    // **`caption2` is deleted** (2026-10-01). It was 11 Medium, kept with a
    // comment saying it had no call sites on purpose. A token nothing uses is
    // a value somebody reuses by accident, and 11 is now off the scale anyway.

    /// **The one weight.** Every tier, every title, every label.
    ///
    /// It used to be only the title's weight, because the titles were the two
    /// places the app disagreed with itself. It is now the whole scale's: the
    /// app sets nothing in Regular, Light or Thin, and nothing in Semibold or
    /// Bold either.
    ///
    /// If "the type is too thin" ever comes back, **this line is the lever and
    /// it moves everything at once** — which is the point of it being one line.
    /// Measured at `opsz` 33.55 (a screen title): Medium's stem is 3.68pt,
    /// Semibold's 4.21 (+14.5%), Bold's 4.95 (+34.4%).
    ///
    /// **Not reachable from the widget**, which is a separate target and does
    /// not see this file. `StrataFont` in `Shared/` carries its own Medium and
    /// has a note pointing back here, so a change made in this line has to be
    /// made there too or the tally and the title stop matching.
    static let titleWeight: Font.Weight = .bold

    /// **What a header is set in, against what a line of body is set in.**
    ///
    /// The owner, 2026-10-01 evening: "the text reads as premium not dull a
    /// nice thicker font for headers."
    ///
    /// He is right and the measurement says why. Earlier the same day the whole
    /// scale went to Medium, to answer "no tiny thin font anywhere ... the
    /// weight should be similar". Taken to one weight it answered the first half
    /// and overshot the second: a page where the title, the headings and the
    /// body are the same stem has nothing to look at first. Similar is not
    /// identical.
    ///
    /// **Two weights, and the step between them is measurable.** At `opsz`
    /// 33.55, which is a screen title: Medium's stem is 3.68pt, Semibold's 4.21
    /// (+14.5%), **Bold's 4.95 (+34.4%)**.
    ///
    /// **It ships Bold, and it shipped Semibold for an hour because I stopped
    /// one step short on my own judgement.** The note here said Bold "is where a
    /// header stops being a header and becomes a shout", which is a taste
    /// dressed as a measurement — the stem width is a fact and where it becomes
    /// a shout is not. The owner asked for "a nice thicker font for headers",
    /// was shown Semibold, and said: "why no bold i mean thats what I asked."
    /// His call, and it was always his call.
    ///
    /// The thing that made stopping short feel justified was reading
    /// heytea.com the same evening and finding **weight 400 everywhere, no bold
    /// on the page** (`docs/reference-board.md` §9). That is true of their
    /// system and it is not an argument about this one: they separate a heading
    /// from body with a second FACE and +0.10 em of tracking, and this app has
    /// one face. With one face the only lever left is the stroke, and a lever
    /// used half way is a lever nobody can see being used.
    ///
    /// **It is still one face.** `bodyWeight` and `titleWeight` are the same
    /// family at two cuts, which is the rule this project has kept for a year
    /// and which the owner restated as "I hate when there is like one type of
    /// font next to another".
    static let bodyWeight: Font.Weight = .medium

    /// **The three tiers, and the only place a size is named.**
    ///
    /// A text STYLE, never a point size, so Dynamic Type moves the lot
    /// together — `.system(size:)` is fixed and ignores the single most-used
    /// accessibility setting on iOS, and this app is meant to be handed to
    /// someone's grandmother.
    ///
    /// `.body` and `.headline` have the SAME ramp (17 at Large, 19/21/23 up,
    /// 28/33/40/47/53 at the accessibility sizes) and differ only in their
    /// default weight, which this overrides. So the 17 tier is one style, not
    /// two that happen to agree.
    ///
    /// **This function is where the custom face lands.** One `.custom(_,
    /// relativeTo:)` here and one in `StrataFont.relative` and the app has
    /// changed typeface.
    private static func tier(_ style: Font.TextStyle, _ weight: Font.Weight = titleWeight) -> Font {
        .system(style, design: .default, weight: weight)
    }

    /// The three tiers as text styles, so a test can read their point sizes out
    /// of `UIFont` and fail when one of them drops below 15 or a fourth
    /// appears. `TypographyTests` is that test.
    static let tierStyles: [Font.TextStyle] = [.largeTitle, .body, .subheadline]

    // MARK: - Tier 1 · 34

    /// The one screen title. Every page that names itself uses this.
    ///
    /// 34pt at the default size is the platform's own large title, not a
    /// number picked to look impressive. The 48 it replaced came from a lowfi
    /// and made the title the loudest thing on a page whose subject is
    /// photographs and blocks.
    static let screenTitle = tier(.largeTitle)

    /// The same title through `DynamicScreenTitle`, where the words are data.
    ///
    /// **It resolves to exactly the same font as `screenTitle`** and is kept
    /// rather than collapsed for one reason that is not inertia: `titleWeight`
    /// is a real lever, and the two have to move together. `StrataTitle.swift`
    /// is the file that branches on it.
    static let screenTitleDrawn = StrataFont.relative(screenTitleSize, to: .largeTitle)

    /// The metric behind it, for layout that has to do arithmetic — the
    /// header's cap-height padding, and the tally numeral. Fixed, because a
    /// layout constant cannot be a font.
    static let screenTitleSize: CGFloat = 34

    /// The CAP HEIGHT of a screen title, for artwork that has to match one.
    ///
    /// A `Font.system(size:)` is an em size and its cap is a fraction of that:
    /// 1443/2048, read out of a font's own table rather than eyeballed. The
    /// fraction did not change when the face did, which is luck and worth
    /// writing down: `SFNSRounded.ttf` and `SFNS.ttf` both declare
    /// `sCapHeight` 1443. What did NOT survive is the DRAWN side of the same
    /// conversion — see `capOverEm` in `StrataMark.swift`. A drawing's `size`
    /// IS its cap, so handing a drawn title the 34 would set it 41% taller than
    /// the type it replaced: "Memories" came out with a 33.3pt cap against the
    /// tower tally's 23.3pt.
    static let screenTitleCap: CGFloat = screenTitleSize * 1443 / 2048

    /// Any number the app states as a fact about your day: the win tally, a
    /// day's numeral on a month block, a photo count. The owner's own digits
    /// — see `StrataFont`.
    ///
    /// **Numbers, never words.** The face has ten glyphs and a space; a
    /// `Text` in it that contains a letter renders `.notdef`. Anything with a
    /// word in it stays on `screenTitle` / `headerSmall`.
    static let tally = StrataFont.relative(screenTitleSize, to: .largeTitle)

    // MARK: - Tier 2 · 17

    /// **17 Semibold. A heading, a block's or a card's title, a sheet's one
    /// word.** The thing you are meant to read first.
    static let headerMedium = tier(.body)

    /// **17 Medium. Prose — a sentence somebody reads rather than scans.**
    ///
    /// It was Regular until 2026-10-01 and Semibold never: a paragraph set in a
    /// heading's weight is a paragraph that shouts, and the owner's objection
    /// was to DULL rather than to quiet. The step from this to `headerMedium` is
    /// 14.5% of stroke at the same size, which is what makes a page have an
    /// order to read it in.
    static let bodyLarge = tier(.body, bodyWeight)

    /// A sheet's title in the owner's face. See `View.sheetTitle(_:drawn:)`.
    static let sheetTitleDrawn = StrataFont.relative(17, to: .body)

    // MARK: - Tier 3 · 15

    /// 15 Medium. Buttons, a row's value, a look's name.
    static let headerSmall = tier(.subheadline)

    /// 15 Medium. The line under a heading or a screen title: "2 wins", a
    /// date, a count, an empty screen's one sentence.
    ///
    /// **It was Regular until 2026-10-01**, and it is Medium rather than the
    /// heading's Semibold: what separates it from the line above it is size,
    /// ink AND now weight, which is three ways of saying the same thing and is
    /// why you never have to work out which one to read first.
    static let screenSubtitle = tier(.subheadline, bodyWeight)

    /// Uppercase section labels — ALBUMS, SEPTEMBER, a month in the gallery.
    /// One style for all of them, so a heading is recognisable as a heading.
    ///
    /// **15, not the 13 it was.** It is the same font as `headerSmall` now and
    /// the kerning plus `.textCase(.uppercase)` at the call site is what makes
    /// it a label.
    static let sectionLabel = tier(.subheadline)
    static let sectionKerning: CGFloat = 0.8

    // MARK: - Outside the scale, on purpose

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
// **Its `UIAppFonts` entry is gone, and so is the 145 KB** (2026-10-01). The
// registration is off `Info.plist`, where the proof is written out, and the TTF
// is excluded from the app target by a membership exception in
// `project.pbxproj`, which the plist alone would not have done: the target is a
// file-system-synchronized group, so every non-source file under `Strata/`
// ships unless it is excepted. Nothing outside Swift named the family: no
// `.custom(`, no `UIFont(name:)` beyond `StrataFont`'s own two, no .xib or
// .storyboard in the repo, nothing in the asset catalogue, and the widget's own
// plist registers Strata-Regular alone.
