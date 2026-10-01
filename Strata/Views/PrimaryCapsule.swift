import SwiftUI

/// **The app's one primary action, drawn once.**
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
/// **It is `accentPrimary`, flat.** The colour was settled by measurement
/// during that pass and the argument is written out on `OnboardingView`'s
/// `pillFill`: white on `accent` came out at **2.03:1** where a 17pt word is
/// held to 4.5, and `accentPrimary` flat measures **4.69:1** at every point
/// across the pill. Flat rather than lit, because the ethereal treatment
/// lightens a fill toward its rim and that makes the number depend on how long
/// the word is: 4.69 under "Go on" and 4.24 at the far end of "Make your head".
/// A button is the one object in this app that has to measure the same
/// wherever a word lands on it.
///
/// **And it is blue rather than black on all three now.** The near black read
/// as a label rather than as a control, which is the same fault the audit
/// found on Profile's Done and on Restore's Cancel, both of which moved to
/// this blue in the same pass. A page whose one action is ink is a page where
/// nothing says which thing to press.
///
/// The rim stays, because the rim is the part of the ethereal treatment that
/// reads as light and it costs the label nothing: no word reaches it.
struct PrimaryCapsule: View {
    let title: String
    var action: () -> Void

    /// Shared with the walkthrough's waiting pill, so the filled state and the
    /// outlined one are the same object at the same height and nothing moves
    /// between them.
    static let height: CGFloat = 50

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                // The target measured on the LABEL rather than declared on the
                // button, which is what `StoreUnavailableView` found: a frame
                // on the button does not grow the thing that takes the tap.
                .frame(height: Self.height)
                .background {
                    ZStack {
                        Capsule(style: .continuous).fill(AppColors.accentPrimary)
                        Capsule(style: .continuous)
                            .strokeBorder(BlockRim.gradient(in: colorScheme),
                                          lineWidth: GridConstants.blockRimWidth)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        // `PressResponse`: use this rather than `.plain` on anything that is
        // not already Liquid Glass, or the press has no answer at all.
        .buttonStyle(.pressWord)
    }
}
