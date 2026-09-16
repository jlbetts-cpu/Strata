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

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(StoreUnavailableCopy.title)
                .font(Typography.screenTitle)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)

            Text(StoreUnavailableCopy.body)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
                .multilineTextAlignment(.center)

            if triedAgain {
                Text(StoreUnavailableCopy.stillFailing)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(AppColors.inkTertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Spacer()

            Button {
                HapticsEngine.tick()
                if onRetry() { return }
                withAnimation(GridConstants.crossFade) { triedAgain = true }
            } label: {
                Text("Try Again")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(maxWidth: .infinity)
                    // 44pt minimum target, measured on the label rather than
                    // declared on the button.
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.quietFill)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tries to open your wins again.")
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview("Store unavailable") {
    StoreUnavailableView { false }
}
