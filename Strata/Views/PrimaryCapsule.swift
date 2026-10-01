import SwiftUI

/// **The app's one primary action, drawn once, in both of its states.**
///
/// Three screens had three copies of it: the walkthrough's pill, the restore
/// confirm and the store-unavailable retry. All three were 50pt capsules with
/// a page-coloured word in them, built separately, and by the time the screen
/// audit read them on the same day they had drifted into two different fills.
/// Onboarding's was `AppColors.accent`, the bright blue off the owner's
/// reference image; the other two were `inkPrimary`, a near black. So the app
/// said "this is the thing to press" in two colours depending on which screen
/// you were standing on.
///
/// **It is ink, flat, and the owner asked for that by name. 2026-10-01:**
/// "can you make the primary color black again". It was blue for an hour,
/// which is how long it took him to see it.
///
/// What the blue was fixing is still worth keeping in view, because it is the
/// thing to check if this ever moves again: the walkthrough's pill used to be
/// `AppColors.accent`, the bright blue off his reference image, and a white
/// word on it measured **2.03:1** where a 17pt word is held to 4.5. Ink does
/// not have that problem from either direction: `inkPrimary` against the page
/// is about 15:1 whichever way round the scheme is.
///
/// **`inkPrimary` and NOT a fixed black**, because it inverts with the scheme
/// and a filled pill has to. The label is `WarmBackground.top`, the page's own
/// colour, so the pill is always the page's opposite: near black with a
/// near white word in light, near white with a near black word in dark. A
/// fixed black pill with a white word would be invisible on a dark page, and
/// that is the fault this project has hit twice in other costumes.
///
/// Flat rather than lit, because the ethereal treatment lightens a fill toward
/// its rim and that makes the label's contrast depend on how long the word is.
/// A button is the one object in this app that has to measure the same
/// wherever a word lands on it.
///
/// The rim stays, because the rim is the part of the ethereal treatment that
/// reads as light and it costs the label nothing: no word reaches it.
///
/// # The waiting state
///
/// **It grew one on 2026-10-01 rather than letting the walkthrough keep its
/// own.** `OnboardingView` still had `litPill` and `waitingPill` after this
/// type existed, and that pair was the ORIGINAL rather than a drift: the
/// colour, the flat fill and the outline were all settled there and this type
/// was extracted out of them. But two implementations of one object is the
/// condition this file exists to end, and the sweep that read them side by
/// side found the filled states identical line for line bar one haptic (see
/// `filled`). So the outlined state came here, where the filled one is, and the
/// walkthrough now reads both off this type.
///
/// **THE WAITING STATE IS NOT A `Button` AND NOT A `.disabled`, AND THAT IS A
/// MEASUREMENT.** It was one Button with `.buttonStyle(.plain)` and
/// `.disabled(!canAdvance)` switching its own background, and the comment on it
/// said the label was `inkTertiary` "at 4.8:1" and the ring `inkQuiet` at
/// "3.1:1", which is what those two inks measure when they are drawn. They
/// were not being drawn. Sampled off page 2 of the 2026-10-01 screenshots,
/// where "What else" waits for you to draw a block:
///
///     ring, declared inkQuiet 0.45     rendered 188 on 243   1.71:1
///     label, declared inkTertiary 0.55 rendered 176 on 243   1.96:1
///
/// Both are exactly HALF the alpha they ask for, to three decimal places, and
/// the stems are flat runs rather than antialiased edges, so this is not
/// coverage. **A disabled plain button is dimmed by the environment**, which
/// `HeadMakerView` already found the other way round: its shutter "came out at
/// 128 of 255 during capture instead of white", and it routed around the dim by
/// not disabling the button. So the owner's complaint, made twice ("the button
/// is lowkey invisible during the onboarding flow, same colour as the
/// background, when its grey"), survived the fix written for it, because the
/// fix was being halved before it reached the glass.
///
/// An outline was the right idea: it is a different object rather than a paler
/// pill, which is what `design-system-future.md` section 10 rule 6 asks for. It
/// just has the least ink of anything on a page to carry a ratio with, so it is
/// the first thing a 0.5 multiplier kills. Hence `init(waiting:because:)`,
/// which takes no action and builds no `Button`: there is nothing inside it for
/// a `.disabled` to be put on, and that structure rather than a comment is what
/// keeps this fixed. **Do not add a `disabled` flag to the filled
/// initialiser.** That is the shape the bug had.
///
/// **The waiting numbers were sampled on the walkthrough's ground, not on every
/// ground.** Over the sampled page-2 white (243): ring `inkTertiary` 4.6:1
/// against a 3.0 floor for a shape, label `inkSecondary` 6.0:1 against 4.5 for
/// text, and the ring stays quieter than the word so the pill reads as an
/// outline with something written in it rather than as a second filled button.
/// Both inks flip with the scheme (`inkSecondary` is 0.62 black in light and
/// 0.70 white in dark, `inkTertiary` 0.55 and 0.60), so the dark page's two
/// ratios are NOT these and have not been measured. A caller putting this
/// state on a darker page, or anybody checking dark mode, has to re-sample.
/// Re-shoot walkthrough page 2 and sample `row 791` and the ring at `col 201`
/// y 766 to prove the light numbers: the only way this fix is wrong is if
/// something else is also dimming, and the figures above say what the pixels
/// have to be.
///
/// **What VoiceOver loses, and what it gets instead.** `.disabled` is what
/// makes VoiceOver say "dimmed", and there is no way to keep that and keep the
/// contrast. So the waiting pill is one accessibility element whose VALUE says
/// why it is waiting, which is more than "dimmed" ever said, and it offers no
/// activate action, so nothing lies about being pressable.
struct PrimaryCapsule: View {
    let title: String

    /// Why it is waiting, for VoiceOver. Non-nil IS the waiting state. It is
    /// set only by `init(waiting:because:)`, which stores no action, so the
    /// outlined state cannot be built out of a `Button` by accident.
    private let reason: String?
    private let action: () -> Void

    /// Shared with the waiting state and with the walkthrough's LinkedIn
    /// capsule, so every 50pt capsule in the app is provably one object rather
    /// than several 50s that agree today, and nothing moves between the two
    /// states of this one.
    static let height: CGFloat = 50

    @Environment(\.colorScheme) private var colorScheme

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.reason = nil
        self.action = action
    }

    /// The outlined state, for an action that is not available yet. Read the
    /// waiting-state section above before changing anything about it.
    init(waiting title: String, because reason: String) {
        self.title = title
        self.reason = reason
        self.action = {}
    }

    var body: some View {
        if let reason {
            waiting(reason)
        } else {
            filled
        }
    }

    private var filled: some View {
        Button {
            // **`lightTap`, not `tick`.** This type was extracted carrying
            // `HapticsEngine.tick()`, which is `selectionChanged`, the
            // feedback for a value moving inside a picker. Both pills it was
            // extracted from were `lightTap()` beforehand, and so is
            // `GlassIconButton`. Pressing "Restore" or "Go on" is not a
            // selection changing, and this is the regression the walkthrough
            // would have inherited by adopting this type as written.
            HapticsEngine.lightTap()
            action()
        } label: {
            face(ink: WarmBackground.top) {
                ZStack {
                    Capsule(style: .continuous).fill(AppColors.inkPrimary)
                    Capsule(style: .continuous)
                        .strokeBorder(BlockRim.gradient(in: colorScheme),
                                      lineWidth: GridConstants.blockRimWidth)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        // `PressResponse`: use this rather than `.plain` on anything that is
        // not already Liquid Glass, or the press has no answer at all.
        // `pressWord` is its own variant for a control whose label is a word:
        // "a word at 6% reads as a wobble, so it moves less and dims more".
        .buttonStyle(.pressWord)
    }

    private func waiting(_ reason: String) -> some View {
        face(ink: AppColors.inkSecondary) {
            // `Capsule(style: .continuous)`, where the walkthrough's waiting
            // pill was a plain `Capsule()`. Its own filled state was already
            // `.continuous`, so the two states had different corner profiles on
            // the one page that shows both, which is this file's whole subject
            // in miniature.
            Capsule(style: .continuous)
                .strokeBorder(AppColors.inkTertiary,
                              lineWidth: GridConstants.strokeThin)
        }
        // No `contentShape`: there is nothing here to hit.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(reason)
    }

    /// The word and the ground under it, shared by both states so the filled
    /// pill and the outlined one are the same object at the same height.
    ///
    /// The target is measured on the LABEL rather than declared on the button,
    /// which is what `StoreUnavailableView` found: a frame on the button does
    /// not grow the thing that takes the tap.
    private func face<Ground: View>(ink: Color,
                                    @ViewBuilder ground: () -> Ground) -> some View {
        Text(title)
            .font(Typography.headerMedium)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background(ground())
    }
}
