import SwiftUI

/// What the app shows when it could not open the store.
///
/// **Instead of the app, never over it.** The old behaviour was an alert on
/// top of a working-looking tower: "you can still use the app, but nothing
/// will be saved between sessions". Somebody taps OK, logs four wins, and
/// loses all four. An app that cannot save is not an app you should be allowed
/// to type into, so this takes the whole window the way onboarding does.
///
/// The words, in Strata's voice: no long dash, nothing that blames the person,
/// and no jargon. It does not say "container", "SwiftData", "migration" or
/// "persistent store", because none of those are things a person can act on.
/// It says the one thing they need to know, which is that nothing has been
/// deleted, and the one thing they can do.
struct StoreUnavailableView: View {
    /// Walks the ladder again. Returns whether it opened this time.
    let onRetry: () -> Bool

    @State private var triedAgain = false

    /// **The same grid as the walkthrough, because it is the same KIND of
    /// screen.** (2026-10-01)
    ///
    /// Measured on the 2026-10-01 screenshot, this page agreed with nothing else
    /// in the app. Its copy sat on a **32pt** margin where every other screen in
    /// Strata is on `horizontalPadding` (16); it was the only centred body text
    /// in the app, against six walkthrough pages and every tab that hang their
    /// title off the left margin; and its action's bottom edge was at 808 where
    /// the walkthrough's is at 816 on all six of its pages. Three small
    /// disagreements, and together they are why somebody meeting this screen
    /// would not place it as the same app it is apologising for.
    ///
    /// So: the page margin, left-aligned, and the action `gapWide` above the
    /// safe area, which is where onboarding's pill sits. Seven screens now land
    /// a primary action in one place.
    ///
    /// **One `Spacer`, not two.** It was Spacer / copy / Spacer / button, which
    /// floated the message in 258pt of nothing above it and 263 below. That is
    /// not a composition, it is two springs, and it makes the biggest gap on the
    /// page a number nobody chose. One band of air under the copy IS a section
    /// break, which is what the biggest gap on a page is supposed to be, and it
    /// leaves the room `docs/illustrations.md` asks for instead of spending it
    /// on centring.
    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapWide) {
            Text(StoreUnavailableCopy.title)
                .font(Typography.screenTitle)
                .foregroundStyle(AppColors.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(StoreUnavailableCopy.body)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if triedAgain {
                Text(StoreUnavailableCopy.stillFailing)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            Spacer(minLength: GridConstants.gapSection)

            retry
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, GridConstants.gapSection)
        .padding(.bottom, GridConstants.gapWide)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // **The app's ground, not the system's.** `Color(.systemBackground)` is
        // pure white and pure black; `WarmBackground` is the faint cool lift
        // every other page in Strata stands on, and its dark value is a warm
        // charcoal on purpose. This screen is the first thing somebody sees when
        // the store will not open, so it was the one page that did not look like
        // the app it is apologising for.
        .background { WarmBackground().ignoresSafeArea() }
    }

    /// The one thing a person can do here, shaped like the one thing a person
    /// can do anywhere else in Strata.
    ///
    /// **It was a 12-radius slab of `quietFill` and you could not see it.**
    /// Sampled on the 2026-10-01 shot: the fill rendered 227 on a 243 page,
    /// which is **1.15:1**, against the 3:1 the guideline asks of a shape. The
    /// only thing drawing the button was the word inside it, on the one screen
    /// in the app where the person is stuck and looking for something to press.
    ///
    /// It is the same filled capsule `RestoreBackupView` uses, which is the
    /// app's other non-walkthrough primary action: `inkPrimary`, the page's
    /// ground for the word, `PrimaryCapsule.height` tall. Computed over the sampled page:
    /// the capsule is 14.0:1 against the ground, where the slab was 1.15, and
    /// its label 15.3:1 against the capsule. Nothing new was invented and there
    /// is one fewer primary action in the app.
    ///
    /// **It IS the walkthrough's capsule now, because the question is
    /// answered.** The note here used to say adopting it would spread a
    /// failure, and it was right at the time: its white label measured 2.03:1
    /// on `AppColors.accent`. The pill is `accentPrimary` flat now, 4.69:1
    /// across its whole width, so the reason to keep a private copy is gone
    /// and all three are one component. See `PrimaryCapsule`.
    private var retry: some View {
        // **`PrimaryCapsule`.** This was a private capsule in `inkPrimary`,
        // and so was the restore's, and the walkthrough's was the blue: three
        // copies of one control that had drifted into two colours. The screen
        // where somebody is stuck and looking for something to press is the
        // last place the one action should be ink.
        PrimaryCapsule(title: "Try Again") {
            if onRetry() { return }
            withAnimation(GridConstants.crossFade) { triedAgain = true }
        }
        .accessibilityHint("Tries to open your wins again.")
    }
}

#Preview("Store unavailable") {
    StoreUnavailableView { false }
}
