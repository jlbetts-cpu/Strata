import SwiftUI

/// **Acknowledgements**, a page in Settings (the owner, 2026-10-18: "add the
/// Solar CC BY 4.0 credit in Settings, About"). The tab icons are drawn from
/// Solar by 480 Design, which is licensed CC BY 4.0: a credit, a link to the
/// licence, and a word that they were changed are what it asks for.
///
/// The same document shape as `WhyItWorksView`, the page beside it.
struct AcknowledgementsView: View {
    static let title = "Acknowledgements"
    static let solar = "Icons based on Solar by 480 Design, redrawn for Some Wins."
    static let licence = URL(string: "https://creativecommons.org/licenses/by/4.0/")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                FormSectionLabel("Icons")
                Text(Self.solar)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                Link(destination: Self.licence) {
                    Text("Creative Commons Attribution 4.0")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkSecondary)
                        .underline()
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GridConstants.horizontalPadding)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle(Self.title, drawn: false)
    }
}
