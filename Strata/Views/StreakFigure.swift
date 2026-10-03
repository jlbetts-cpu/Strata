import SwiftUI

/// "8 days / Current": one streak figure. Profile's, and a crew's
/// (2026-10-02), one view so both read the same.
struct StreakFigure: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapTight) {
                // **`Typography.tally`, which is the token for this.** It was
                // `StrataFont.relative(28, to: .title)`, and 28 is not one of
                // the sizes `Typography` has: the scale is 34, 17 and 15 since
                // 2026-10-01, and this was a rung invented for one screen.
                // The token's own doc names this exact case, "any number the app
                // states as a fact about your day: the win tally, a day's
                // numeral on a month block, a photo count".
                //
                // Measured: the figure's cap goes 20.0pt to 23.8pt, and the
                // streak card grows about 5pt. That is the right direction as
                // well as the tidy one. The streak is the one fact on this page
                // and it was set smaller than the screen's own title.
                Text(verbatim: StrataFont.digits(value))
                    .font(Typography.tally)
                    .foregroundStyle(AppColors.inkPrimary)
                    .contentTransition(.numericText())
                Text(value == 1 ? "day" : "days")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            Text(label)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) streak, \(value) \(value == 1 ? "day" : "days")")
    }
}
