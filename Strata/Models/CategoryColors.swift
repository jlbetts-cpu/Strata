import SwiftUI
import UIKit

struct CategoryStyle {
    /// The single solid category color
    /// The block's colour, as the number it is written as.
    ///
    /// Stored as the raw hex rather than a `Color` so there is ONE source for
    /// it: the widget extension needs the same value as a string and cannot
    /// see `HabitCategory`, and a second copy of the palette would drift the
    /// first time anyone retuned a colour.
    let baseHex: UInt
    var baseColor: Color { Color(hex: baseHex) }
    /// `RRGGBB`, for anything outside this target.
    var baseHexString: String { String(format: "%06X", baseHex) }
    let border: Color
    let glow: Color

    /// **THE ONE APP-WIDE FAILURE THE SCREEN AUDIT FOUND AND DID NOT FIX, AND
    /// IT IS THE OWNER'S CALL.** (2026-10-01)
    ///
    /// Every category sets this to `.white`, and nothing reads it: `BlockFace`
    /// and `BlockContent` draw a block's title in a hard white of their own.
    /// So this field is the decision already sketched and never made.
    ///
    /// Measured off the built tower, a white 13pt title against the fill
    /// beside it:
    ///
    /// | block | fill | ratio |
    /// |---|---|---|
    /// | Ran 5k, orange | (255, 184, 87) | **1.71:1** |
    /// | Cooked, pink | (242, 143, 188) | 2.23:1 |
    /// | Sketch, purple | (178, 158, 254) | 2.28:1 |
    /// | Walk, green | (22, 179, 123) | 2.70:1 |
    ///
    /// against the 4.5:1 a 13pt word is held to. It is the single largest
    /// legibility failure in the app and it is on the app's central object,
    /// on every screen that draws a block.
    ///
    /// **No scrim reaches it.** White on the orange needs the ground down to
    /// luminance 0.183, and `photoVeilOpacity` at 0.26, which is the heaviest
    /// veil the app uses and is reserved for photographs, only gets it to
    /// 2.48:1. A veil dark enough would stop the block being its colour, and
    /// the colour is the content. `BlockWash` makes it worse rather than
    /// better: it lifts the bottom 26% of a block toward WHITE and the title
    /// sits in that band, so the label's local ground is the brightest part of
    /// the thing it is written on.
    ///
    /// **THE OWNER LOOKED AT BOTH AND CHOSE WHITE. 2026-10-01.** He was sent
    /// the tower rendered each way, side by side, with the numbers on it, and
    /// his answer was "I much prefered the white ink look over the dark ink".
    /// So white it is, and this note stays so the next pass does not spend an
    /// afternoon rediscovering the measurement and reaching for the same fix.
    ///
    /// What is still true is the number. Scored against all seven fills:
    ///
    /// | category | white | near black |
    /// |---|---|---|
    /// | orange `FDB54F` | **1.76** | 9.86 |
    /// | purple `AF9CFA` | **2.34** | 7.42 |
    /// | pink `EC85B4` | **2.45** | 7.11 |
    /// | blue `40A9FF` | **2.52** | 6.91 |
    /// | red `F97066` | **2.79** | 6.25 |
    /// | green `0EAD74` | **2.90** | 6.01 |
    /// | grey `9C9791` | **2.90** | 6.01 |
    ///
    /// Not one clears 4.5 with white, and every one clears it with a near
    /// black, worst case 6.01. Built and measured on the real tower, the dark
    /// version came out between 6.00 and 9.77 against white's 1.71 to 2.70.
    ///
    /// **It is a taste call over a guideline, made by the person whose app it
    /// is, with the evidence in front of him.** The thing the number does not
    /// capture is that these blocks are a picture of a day before they are a
    /// list of labels, and white type reads as part of the surface where dark
    /// type reads as writing ON it. He has said more than once that the blocks
    /// are the app.
    ///
    /// **What carries the legibility instead**, and what should be defended if
    /// anything here moves again: the title sits in `BlockWash`'s band, which
    /// lifts the bottom 26% of a block, and `BlockContent.TitleShadow` puts a
    /// dark halo under it. If a title ever becomes hard to read on a real
    /// phone in daylight, that halo is the dial, not this field.
    ///
    /// Three things were measured and do NOT work, so nobody tries them again:
    /// a heavier veil under the caption (`photoVeilOpacity` at 0.26, which is
    /// the heaviest this app uses and is reserved for photographs, only
    /// reaches 2.48 on the orange); darkening the palette (white needs the
    /// orange down to luminance 0.183, which is a different palette); and a
    /// per-category split (there are no deep categories to split off, they are
    /// all pastel).
    let text: Color

    /// **The dark ink that was tried and turned down**, kept as one line so
    /// the comparison can be rebuilt in a minute rather than rederived. See
    /// `text` above. Nothing reads it.
    static let blockInk = Color(red: 0.10, green: 0.10, blue: 0.10)

    /// Lighter tint for gradient top (simulates light hitting the surface)
    let lightTint: Color
    /// Darker shade for gradient bottom (simulates ambient occlusion)
    let darkShade: Color

    // Legacy accessors
    var gradientTop: Color { lightTint }
    var gradientBottom: Color { darkShade }

    /// Flat fill (was previously a 3-color gradient for clay effect)
    var gradient: LinearGradient {
        LinearGradient(
            colors: [baseColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Flat fill using base color (for contexts where gradient isn't appropriate)
    var flatFill: Color { baseColor }
}

extension HabitCategory {
    var style: CategoryStyle {
        switch self {
        case .health:
            return CategoryStyle(
                baseHex: 0x0EAD74,   // Deeper for WCAG contrast
                border: Color(hex: 0x0B9362),
                glow: Color(hex: 0x0EAD74).opacity(0.20),
                text: .white,
                lightTint: Color(hex: 0x30C494),
                darkShade: Color(hex: 0x0B9362)
            )
        case .work:
            return CategoryStyle(
                baseHex: 0x40A9FF,
                border: Color(hex: 0x2E8BE6),
                glow: Color(hex: 0x40A9FF).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0x6DC0FF),
                darkShade: Color(hex: 0x2E8BE6)
            )
        case .creativity:
            return CategoryStyle(
                baseHex: 0xAF9CFA,
                border: Color(hex: 0x826DD0),
                glow: Color(hex: 0xAF9CFA).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xC4B5FF),
                darkShade: Color(hex: 0x826DD0)
            )
        case .focus:
            return CategoryStyle(
                baseHex: 0xFDB54F,
                border: Color(hex: 0xD99A3A),
                glow: Color(hex: 0xFDB54F).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xFEC873),
                darkShade: Color(hex: 0xD99A3A)
            )
        case .social:
            return CategoryStyle(
                baseHex: 0xF97066,   // Coral — 153° from Health, ADHD-safe
                border: Color(hex: 0xD45E55),
                glow: Color(hex: 0xF97066).opacity(0.20),
                text: .white,
                lightTint: Color(hex: 0xFB8E86),
                darkShade: Color(hex: 0xD45E55)
            )
        case .unlabeled:
            // Warm grey, sitting in the same family as the ground rather than
            // competing with the six category colours.
            return CategoryStyle(
                baseHex: 0x9C9791,
                border: Color(hex: 0x857F79),
                glow: Color(hex: 0x9C9791).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xB5B0AA),
                darkShade: Color(hex: 0x857F79)
            )
        case .mindfulness:
            return CategoryStyle(
                baseHex: 0xEC85B4,
                border: Color(hex: 0xC86B98),
                glow: Color(hex: 0xEC85B4).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xF2A0C8),
                darkShade: Color(hex: 0xC86B98)
            )
        }
    }
}

// MARK: - App Colors

enum AppColors {
    static let warmBlack = Color(hex: 0x403D39)

    // MARK: - Ink
    //
    // **`.primary.opacity(x)` is not a colour, it is a colour in light mode.**
    //
    // A quiet grey was tuned against a white page: 0.45 for a heading, 0.40
    // for a caption. Flip the ground and the SAME number is 45% white on
    // near-black, which measures 4.4:1 — under WCAG AA for body text — and
    // reads exactly as the owner described it, "a bit of contrast issues in
    // places". Grey on white and grey on black are not the same problem: dark
    // grounds need MORE of the ink, not the same amount inverted.
    //
    // Dynamic colours, so a call site cannot get it wrong by being written on
    // the wrong day. Measured after: heading 7.1:1, caption 5.6:1.

    // The values are DERIVED from the contrast target, not chosen by eye.
    // Against the page's ground the measured ratios are:
    //
    //              light   dark    WCAG AA needs
    //   secondary   6.0     8.4    4.5:1  (text)
    //   tertiary    4.8     6.6    4.5:1  (text)
    //   quiet       3.1     4.3    3.0:1  (UI element, not text)
    //
    // The old light values failed: headings measured 3.34:1 and captions
    // 2.8:1 against a 246 ground. That is not a dark-mode regression, it was
    // always there — flipping the ground is just what made it obvious.

    /// The empty slot's ink: its outline, its recess and its `+`.
    ///
    /// **This was `warmBlack` and the slot disappeared in dark mode.** The
    /// owner: "the block is still not visible in dark mode, like how am i
    /// supposed to know where to hold to drag". It is the app's primary
    /// action — the one place you press to log a win — drawn in near-black on
    /// a near-black ground.
    ///
    /// A warm white rather than pure, so the socket still belongs to a page
    /// whose black has brown in it.
    static let slotInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1)
            : UIColor(red: 0.251, green: 0.239, blue: 0.224, alpha: 1)
    })

    /// A title: the strongest ink the app writes with, short of the slot's.
    ///
    /// **Written as `.primary.opacity(0.85)` in eight places before this.**
    /// CLAUDE.md's rule is that `.primary.opacity(x)` is not a colour, it is a
    /// colour in light mode: the same number is 85% BLACK on a near-white page
    /// and 85% WHITE on a near-black one, and the two are not equally strong.
    /// Made adaptive and measured: 14.3:1 on the light page, 13.9:1 on the
    /// dark one, which is the same weight of voice in both.
    static let inkPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.92)
            : UIColor(white: 0, alpha: 0.85)
    })

    /// **The ink a drawing is in** (the owner, 2026-10-06, "Warm ink"): a
    /// deep warm black on the page and a warm paper white in dark mode, in
    /// place of `inkPrimary`'s neutral grey. Ink on paper rather than pixels.
    /// Opaque, so a line crossing itself does not darken where it overlaps.
    /// Every drawing takes it: his, yours, sketches, months and doodles.
    static let drawingInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.949, green: 0.925, blue: 0.886, alpha: 1)  // #F2ECE2
            : UIColor(red: 0.149, green: 0.129, blue: 0.114, alpha: 1)  // #26211D
    })

    /// The white ink of a doodle on a block: warm, so it sits on the
    /// colour as chalk does rather than as a cut-out.
    static let drawingInkOnBlock = Color(red: 1, green: 0.98, blue: 0.94)  // #FFFAF0

    /// A quiet surface: a well, an empty cell, a hairline's fill. Not text,
    /// and not held to a text ratio (1.14:1 light, 1.19:1 dark) — it is there
    /// to be a shape rather than to be read.
    static let quietFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.06)
            : UIColor(white: 0, alpha: 0.06)
    })

    /// Headings, labels, and anything that names a run of content.
    ///
    /// **The greys are one warm family now** (the owner, 2026-10-06: "use
    /// that same light greying throughout the app... it will help elevate
    /// some elements"; his pick, "Same warm grey family"). Each is the tab
    /// grey's hue (`tabIdle`, #9E9A95), opaque, at the darkness its job
    /// needs, chosen to sit where the old neutral grey sat so nothing got
    /// harder to read. Measured on the page (#FDFDFD light, #1D1C1C dark):
    ///
    /// | | light | dark | needs |
    /// |---|---|---|---|
    /// | `inkSecondary` | #5C5853, 6.9:1 | #B2AEA9, 7.7:1 | text |
    /// | `inkTertiary` | #74706B, 4.8:1 | #94908B, 5.4:1 | 4.5:1 |
    /// | `inkQuiet` | #8E8A85, 3.3:1 | #7C7873, 3.9:1 | 3:1 |
    ///
    /// They were black and white at an opacity, which is a neutral grey
    /// that picks up whatever is under it; these are the warm grey wherever
    /// they stand, the same grey as an idle tab.
    static let inkSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.698, green: 0.682, blue: 0.663, alpha: 1)  // #B2AEA9
            : UIColor(red: 0.361, green: 0.345, blue: 0.325, alpha: 1)  // #5C5853
    })

    /// **A tab you are not on: grey, as Luma's are** (the owner, 2026-10-06:
    /// "make the icons grey like luma that arent selected"). Opaque and warm,
    /// so a filled drawing reads as one even grey on the glass rather than
    /// letting the bar show through it.
    static let tabIdle = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.553, green: 0.541, blue: 0.525, alpha: 1)  // #8D8A86
            : UIColor(red: 0.620, green: 0.604, blue: 0.584, alpha: 1)  // #9E9A95
    }

    /// Captions: a count under a card, a subtitle, a unit.
    static let inkTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.580, green: 0.565, blue: 0.545, alpha: 1)  // #94908B
            : UIColor(red: 0.455, green: 0.439, blue: 0.420, alpha: 1)  // #74706B
    })

    /// The quietest ink the app uses: a chevron, a divider glyph, a disclosure.
    ///
    /// **It said "a placeholder, a hint" until 2026-10-02**, which contradicts the
    /// paragraph below: a placeholder is a sentence. Seven pieces of text had read
    /// it at its word and measured 3.32 to 3.35:1 in light, under the 4.5 text is
    /// held to, invisible in dark where the same ink is 6.0. They are
    /// `inkTertiary` now, and the list here no longer invites the next one.
    ///
    /// **Held to 3:1, not 4.5:1**, and deliberately: these are UI elements and
    /// decorative glyphs rather than text somebody has to read, which is the
    /// line the guideline itself draws. Pushed to text contrast they stop
    /// being quiet, and the quiet is the point.
    ///
    /// **Never a sentence, a count or a subtitle.** Those are `inkTertiary`,
    /// which clears 4.5:1 on the page. The screen audit found this used for
    /// running text on two screens at once: the day album's win count, which
    /// is the only thing on that page that says how big the day was, and its
    /// empty state, which is that page's one sentence. Both composited to
    /// rgb(137, 136, 134) on rgb(249, 247, 244), which is 3.31:1. The token
    /// was behaving exactly as documented; the callers had read "quiet" as a
    /// volume rather than as a category.
    static let inkQuiet = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.486, green: 0.471, blue: 0.451, alpha: 1)  // #7C7873
            : UIColor(red: 0.557, green: 0.541, blue: 0.522, alpha: 1)  // #8E8A85
    })

    /// The app's accent: what a switch, a link and a selected control wear.
    ///
    /// **It has to flip.** It was a fixed warm black, which is the right
    /// accent on a light page and invisible on a dark one — the owner: "in
    /// dark mode the main accent... the switches are like not noticably on in
    /// the settings." A switch whose on-state is near-black on a near-black
    /// ground is a switch with no on-state.
    ///
    /// The dark value is the same warm white the empty slot and the primary
    /// buttons use, so every piece of ink in the app inverts together rather
    /// than one control at a time.
    /// **The app's accent, and it is properly dark now.**
    ///
    /// The owner, 2026-09-23: "I would prefer the primary colour to be like
    /// actually dark", after saying of the onboarding button that it "isn't
    /// like black".
    ///
    /// It was 0.251, 0.239, 0.224, which is the warm black the tower's
    /// blocks are drawn against. On a pale page that reads as dark grey
    /// rather than as black, and a primary action that reads as grey reads
    /// as disabled. This is 0.110, 0.102, 0.094: the same warmth, a quarter
    /// of the luminance, and **it is the app icon's own black**, which is
    /// `0x1C1A18` in `tools/make_app_icon.py`. The icon and the app's primary
    /// action were two different blacks until now, four and a half times
    /// apart in relative luminance, which is a thing nobody sees and
    /// everybody feels.
    ///
    /// The dark mode value is unchanged: a warm near-white, so every piece of
    /// ink in the app still inverts together.
    static let accentWarm = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1)
            : UIColor(red: 0.110, green: 0.102, blue: 0.094, alpha: 1)
    })
    // MARK: - Ink on the camera's own dark

    /// **Three levels, on a ground that never changes.**
    ///
    /// The camera, the head maker and the photo review are dark whatever the
    /// phone is set to, so the adaptive inks above are wrong there and every
    /// screen reached for a white opacity of its own: an audit counted more
    /// than twenty distinct ones across the app. These are the whole set.
    /// Anything that needs a fourth is asking the wrong question.
    ///
    /// **The values are the ones the app already used most**, not new ones:
    /// converting to a scale should leave the screens looking exactly as they
    /// did and only stop the next one inventing a twenty-first grey.
    ///
    /// Measured against the viewfinder's ground: strong 18.8:1, secondary
    /// 12.0:1, quiet 6.7:1. Faint is a hairline rather than text and is not
    /// held to a text ratio.
    static let onDarkStrong = Color.white.opacity(0.95)
    /// **The app's one accent, and it is an exception the owner chose.**
    ///
    /// 2026-09-30. `docs/design-system-future.md` §4 says chrome is ink and
    /// grey and that a tint is only ever borrowed from content. This is neither
    /// — it is a brand accent painted onto a control, which that section
    /// forbids. The owner sent the reference, was told the rule it broke and the
    /// two alternatives that would have kept it, and chose this. The rule is
    /// amended in the doc rather than quietly ignored here.
    ///
    /// **Sampled, not invented.** Read off the reference image: the core of the
    /// pill measures hue 0.552, saturation 0.698, brightness 0.988, and the rim
    /// falls to about 0.06 saturation at the same hue. `EtherealFill` derives
    /// the rim itself, so only the core is stored.
    ///
    /// It has ONE job: the primary action. It is not a palette, it does not
    /// appear on chrome elsewhere, and if it starts showing up on labels and
    /// icons then §4 has been lost rather than amended.
    static let accent = Color(hue: 0.552, saturation: 0.698, brightness: 0.988)

    static let onDarkSecondary = Color.white.opacity(0.75)
    static let onDarkQuiet = Color.white.opacity(0.55)
    static let onDarkFaint = Color.white.opacity(0.14)

    /// The ON track of a switch, which is NOT the app's accent.
    ///
    /// **A switch has a white thumb, so its track cannot be white.**
    /// `accentWarm` is a warm near-white in dark mode — deliberately, so every
    /// piece of ink in the app inverts together — and a `Toggle` tints its ON
    /// track with the accent. The result in dark mode was white on white:
    /// "the switch in the setthing in dark mode it doesnt even look like a
    /// switch its like white on white just looks like a pill."
    ///
    /// So this is one colour in both schemes, chosen to contrast with the
    /// white thumb AND with either ground.
    ///
    /// **BLUE, NOT GREEN** (2026-09-30). The owner: "make sure you are changing
    /// the primary to the blue, because I notice in the settings it is still
    /// green." The brand's primary is `accent`, sampled off his reference, and
    /// a switch is the most-repeated piece of accent in the app — six of them in
    /// Settings alone — so a green one was the palette disagreeing with itself
    /// on the screen where it repeats most.
    ///
    /// **It is the accent's HUE taken down, not the accent.** `accent` as drawn
    /// is a bright sky blue and measures 1.96:1 against a switch's white thumb,
    /// which is worse than the system green this already refused. Same hue
    /// (0.552), saturation and brightness moved until it lands where the green
    /// was. Measured against the white thumb, the light page and the dark one:
    ///
    ///     accentWarm, dark mode   1.07  —  —        <- the original bug
    ///     system green 34C759     2.22  —  —
    ///     accent, as drawn        1.96  1.83  8.66  <- the obvious swap
    ///     the green, 0B9362       3.91  3.65  4.34  <- what this replaces
    ///     this, 138BC2            3.82  3.56  4.45
    ///
    /// So all three relationships still clear the 3:1 WCAG asks of a UI element,
    /// within a tenth of what the green managed. Apple's own switch green does
    /// not clear it, which is worth knowing before anyone "corrects" this.
    /// **NOTHING READS THIS ANY MORE, AND THAT IS THE DECISION. 2026-10-01.**
    ///
    /// The owner: "I think I prefer if the primary color was the black and
    /// white button for dark mode instead of this blue color we are going with
    /// right now lets just do the basic." So the app is monochrome: every
    /// action, every switch and every link is `inkPrimary`, which inverts with
    /// the scheme, and the only saturated colour left on any screen is a win
    /// or a photograph.
    ///
    /// **That is the app's own rule, finally obeyed.** Check 5 of the screen
    /// audit says colour is content and chrome is ink and light, with one
    /// accent allowed for the primary action. The blue was that one allowance,
    /// and it had spread to six places: a Form tint, a Done, a Cancel, a Save,
    /// a play glyph and six switches. An allowance that reaches six places is
    /// not an accent, it is a second palette.
    ///
    /// Kept rather than deleted because the measurement on it is the one that
    /// retired green and it is worth not rediscovering: Apple's own switch
    /// green does not clear 3:1 against a white thumb.
    static let switchOn = Color(hex: 0x138BC2)

    // **`accentPrimary` (0x007BB2) is deleted** (2026-10-01), zero call sites.
    //
    // It was the primary action's colour where it had to read as ink on white,
    // measured at 4.38:1 light and 3.62:1 dark, and it reached six places before
    // the owner looked at it: "I think I prefer if the primary color was the
    // black and white button for dark mode instead of this blue color we are
    // going with right now lets just do the basic." Every one of those sites
    // went to `inkPrimary` that day and this token has been unread since.
    //
    // **Five doc comments across the app still say the word.** They are prose,
    // not code, and each one describes a thing that is now ink:
    // `StoreUnavailableView`, `ProfileView`, `RestoreBackupView` (twice),
    // `ReplayRow` and `HeadMakerView`. A comment naming a colour the file does
    // not use is how `switchOn` ended up with six call sites arguing with its
    // own header, so they are being corrected rather than left.

    /// **The one red a destructive word is written in.**
    ///
    /// Promoted here 2026-10-02 from `AddWinSheet.destructiveTint`, where it was
    /// a colour living on a view that three other files reached across for. The
    /// full argument — why 4.5:1 is unreachable for a `.bordered` destructive
    /// button, and why the number to beat was the 2.20:1 it replaced rather than
    /// the 4.5 — is still on that site, because it is about the BUTTON STYLE and
    /// not about the colour.
    ///
    /// **Measured on the light Form card, which is where the app's other two
    /// deletes live:** this is **5.65:1**, `warmRed` is **2.71:1** and the
    /// system red is **2.79:1**. Settings' "Reset All Data" and Profile's
    /// "Delete head" were shipping at 2.71 against the 4.5 a 17pt word is held
    /// to, which is the one press in each of those screens that destroys work.
    ///
    /// Adaptive, because a fixed red is a colour in one scheme: rgb(179, 0, 15)
    /// on the light page and rgb(255, 92, 84) on the night one, which is the
    /// brightest red that still reads as a red rather than as a salmon.
    static let destructiveInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.361, blue: 0.329, alpha: 1)
            : UIColor(red: 0.702, green: 0.0, blue: 0.059, alpha: 1)
    })

    /// **Not a destructive colour.** This is the warm red a BLOCK is filled
    /// with. It was reached for twice as a delete's ink and measures **2.71:1**
    /// on a Form card; `destructiveInk` above is what a word that destroys
    /// something is written in.
    static let warmRed = Color(hex: 0xE85D4A)

    // MARK: - Four colours deleted, 2026-10-01
    //
    // All four had zero call sites, and each one is a trap rather than a record:
    // a reader who found it would have taken it for a sanctioned colour.
    //
    // **`accentPurple` (#A689FA), a "secondary accent", and there is no such
    // thing here.** `accent` three dozen lines up is the app's one accent, and
    // its own doc is as narrow as a doc gets: "It has ONE job: the primary
    // action. It is not a palette, it does not appear on chrome elsewhere, and if
    // it starts showing up on labels and icons then §4 has been lost rather than
    // amended." A second accent token is the first step of exactly that.
    //
    // **`healthGreen` (#34C48B), the retired one.** The owner, 2026-09-30:
    // "make sure you are changing the primary to the blue, because I notice in
    // the settings it is still green." `switchOn` above carries the whole
    // measurement that settled it, including the part worth knowing before
    // anybody "corrects" it: Apple's own switch green does not clear 3:1 against
    // a white thumb. So the record exists, in the token that replaced it, and
    // what was left here was a green named for success states on a screen that
    // has none. That is how a palette ends up disagreeing with itself again.
    //
    // **`ghostBase` and `ghostBaseDark`, a feature AND a measurement that both
    // expired.** They were the ground of an incomplete habit's block on the
    // Today/timeline tab, which is gone. Worse, `ghostBase`'s own comment claimed
    // "12% luminance contrast to warm background", and the warm background is
    // gone too (see `WarmBackground` and `EtherealControls`, where this app's
    // grounds were taken off warm and onto clean white). A stale measurement
    // reads exactly like a current one.
    //
    // The four hex values are recorded in `docs/design-system.md` §1 and
    // `tasks/brand.md` if any of them is ever wanted back.
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
