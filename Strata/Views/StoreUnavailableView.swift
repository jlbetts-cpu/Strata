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
        // **One layout for every drawn moment** (`DrawnMoment`, the owner,
        // 2026-10-14: "there needs to be consistency"). His cat in the
        // middle, the words centred under it, Try Again at the foot.
        DrawnMoment(title: StoreUnavailableCopy.title, line: StoreUnavailableCopy.body,
                    action: (title: "Try Again", run: {
                        if onRetry() { return }
                        withAnimation(GridConstants.crossFade) { triedAgain = true }
                    })) {
            ErrorCat()
        } extra: {
            if triedAgain {
                Text(StoreUnavailableCopy.stillFailing)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .accessibilityHint("Try Again tries to open your wins again.")
        .background { WarmBackground().ignoresSafeArea() }
    }
}

#Preview("Store unavailable") {
    StoreUnavailableView { false }
}
