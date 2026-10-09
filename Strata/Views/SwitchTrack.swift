import SwiftUI

// MARK: - The ON track of every switch in the app
//
// **This belongs in `Strata/Models/CategoryColors.swift` beside `switchOn`, and
// it is here because another worker held that file for the whole of this
// session.** Move it there; it is one `static let` and a comment. `AppColors` is
// a type, so `AppColors.switchTrack` resolves identically wherever the extension
// lives — the palette is still one namespace — but a colour token outside the
// palette's own file is exactly the kind of thing this audit is about, so it
// should not stay here.

extension AppColors {

    /// The ON track of a switch: **one fixed warm grey, in both schemes.**
    ///
    /// # What this replaces, and why BOTH of the two colours it replaces were wrong
    ///
    /// `docs/consistency-audit.md` §1.3 found the app saying "on" in two
    /// colours one push apart: `ProfileView`'s four `Toggle`s were tinted
    /// `AppColors.switchOn` (#138BC2) and `SettingsView`'s six were tinted
    /// `AppColors.inkPrimary`, on two screens whose own doc comments say they are
    /// built the same way "so that pushing from one to the other reads as one
    /// place". The audit's verdict was ink, on the strength of `switchOn`'s own
    /// header, which says in capitals that nothing reads it any more and the app
    /// is monochrome.
    ///
    /// **That verdict is wrong in dark mode, and `switchOn`'s own measurement
    /// table is the proof.** The rule it carries is the one from `CLAUDE.md`'s
    /// "An ink is not a surface":
    ///
    /// > **A switch has a white thumb, so its track cannot be white.**
    /// > `accentWarm` is a warm near-white in dark mode — deliberately, so every
    /// > piece of ink in the app inverts together — and a `Toggle` tints its ON
    /// > track with the accent. The result in dark mode was white on white: "the
    /// > switch in the setthing in dark mode it doesnt even look like a switch
    /// > its like white on white just looks like a pill."
    ///
    /// `inkPrimary` is `white.opacity(0.92)` in dark mode. Over the night ground
    /// that composites to rgb(237), and against the switch's white thumb that is
    /// **1.17:1** — the same fault, a tenth off the 1.07:1 the owner complained
    /// about, and `SettingsView` has been shipping it on six switches since the
    /// monochrome pass. So moving Profile onto ink would have made the app
    /// consistent by spreading a bug, which is the worst way to pass an audit.
    ///
    /// And `switchOn` is blue, which is the thing the owner removed: "I think I
    /// prefer if the primary color was the black and white button for dark mode
    /// instead of this blue color we are going with right now lets just do the
    /// basic."
    ///
    /// # So: monochrome, and FIXED
    ///
    /// Three ratios have to clear 3:1 at once, and `switchOn`'s header is the
    /// specification — "one colour in both schemes, chosen to contrast with the
    /// white thumb AND with either ground". Computed from the token's real RGB
    /// rather than looked at, which is what `CLAUDE.md` asks for ("Contrast is
    /// arithmetic, so compute it rather than looking"):
    ///
    ///                              thumb   light page   dark page
    ///     accentWarm, dark mode     1.07       —            —      <- the original bug
    ///     system green 34C759       2.22       —            —
    ///     accent, as drawn          1.96      1.83         8.66
    ///     the green, 0B9362         3.91      3.65         4.34
    ///     switchOn, 138BC2          3.82      3.56         4.45    <- blue, and retired
    ///     inkPrimary, light        15.47     14.44         —       <- fine
    ///     inkPrimary, dark          1.17       —          14.40    <- the bug, shipping
    ///     THIS, rgb(124, 118, 111)  4.49      4.19         3.76
    ///
    /// The window a fixed neutral has to sit in is narrow and it is arithmetic:
    /// above rgb(104) or it cannot clear 3:1 against the rgb(29) night ground,
    /// below rgb(144) or it cannot clear 3:1 against the white thumb. 124 is the
    /// middle of that window, so there is as much headroom on each side as the
    /// window allows, and that is the whole reason for the number.
    ///
    /// **Warm, at the app's own ratio.** The channels are the warm black's
    /// (0.251, 0.239, 0.224) scaled to that luminance, so this is the same grey
    /// the rest of the chrome is made of rather than a neutral the palette does
    /// not otherwise contain.
    ///
    /// # What this costs, measured on both built screens, and it needs his eye
    ///
    /// **A grey ON track is not what a phone user has learnt.** iOS draws it
    /// green, and colour is most of how anybody reads a switch at a glance.
    ///
    /// Sampled off the built Settings screen in both schemes
    /// (`/tmp/c2/light/s0-settings.png`, `/tmp/c2/dark/s0-settings.png`), where
    /// this renders exactly rgb(124, 118, 111) in both, as designed:
    ///
    ///                                 light          dark
    ///     the white knob              4.49           4.49
    ///     the ground behind it        4.49 (card)    3.10 (card rgb 44)
    ///     iOS's OFF track             2.60 (rgb 197) 1.29 (rgb 101)
    ///
    /// The first two are the specification `switchOn` wrote down — "one colour
    /// in both schemes, chosen to contrast with the white thumb AND with either
    /// ground" — and this clears both in both, which neither of the colours it
    /// replaces did. It also beats both of them on the first row: `switchOn`
    /// measures 3.82 against the knob and the system green 2.22.
    ///
    /// **The third row is the cost and it cannot be designed away.** iOS draws
    /// its OFF track at rgb(197) in light and rgb(101) in dark — 96 levels
    /// apart — so one fixed colour cannot sit 3:1 from both of them AND 3:1 from
    /// a white knob. Swept in 4-level steps between rgb(96) and rgb(176), the
    /// best any fixed grey can do on its WORST of those five ratios is **1.82,
    /// at about rgb(152)**, and at 152 the knob falls to 3.14, on the floor. So
    /// the table above is not this value being wrong; it is the shape of the
    /// problem.
    ///
    /// **What carries it instead is the knob's position**, which is what a
    /// person actually reads and what VoiceOver says. Photographed in dark mode
    /// with two ON switches and one OFF in the same column, the three are
    /// tellable apart at a glance — but by where the white disc sits, not by the
    /// track.
    ///
    /// **This is the argument to put to him**, with both renders: a monochrome
    /// switch is the instruction he gave ("lets just do the basic") and it is
    /// measurably the most legible of the three options against the knob and the
    /// ground; the one thing it gives up is a strong difference between its own
    /// two states in dark mode, and `switchOn`'s blue gives that up too (2.22 in
    /// light against this 2.60). Only a saturated colour recovers it, and that
    /// is the thing he removed.
    ///
    ///
    /// **Two colours since 2026-10-08** (the night polish pass: on device the
    /// fixed taupe read as a disabled switch in light and sat 1.3:1 from the
    /// OFF track in dark, so ON and OFF looked alike). `MemoriesConsistencyTests`
    /// proves no ONE grey can clear the knob and both OFF tracks; per scheme,
    /// it can. Light: the app's ink, near black, the black-and-white switch
    /// the owner asked for (14:1 on the knob, 9:1 on OFF). Dark: the brightest
    /// warm grey that still holds 3:1 against the white knob, 1.8:1 above OFF.
    static let switchTrack = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 149 / 255, green: 143 / 255, blue: 136 / 255, alpha: 1)
            : UIColor(red: 42 / 255, green: 39 / 255, blue: 36 / 255, alpha: 1)
    })
}
