import SwiftUI

#if DEBUG
/// **The title face, set against the mark it has to live with.**
///
/// Reached with `-strataTypeLab 1`. The owner: "what is the font we are using
/// for the titles, and are we able to get a serif with a slightly thicker
/// weight, just to look better but also match the Apollo mark better."
///
/// The weight question is answerable by looking; the MARK question is not
/// answerable at all in prose, because the mark is not a font. It is his own
/// drawn artwork (`Apollowordmark.svg`, outlined vectors), so no family will
/// ever "be" it — the most a title face can do is not argue with it. This
/// puts the two on one screen at the same cap height so that can be judged
/// rather than asserted.
///
/// Not shipped: `#if DEBUG` and a launch argument.
struct TypeSpecimenView: View {
    private static let weights: [(String, Font.Weight)] = [
        ("Regular (now)", .regular),
        ("Medium", .medium),
        ("Semibold", .semibold),
        ("Bold", .bold)
    ]

    var body: some View {
        ZStack {
            HomeGround.top.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // The mark, at the size Home's title is, so the two are
                    // compared at the same scale rather than at their own.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("THE MARK")
                            .font(Typography.sectionLabel)
                            .kerning(Typography.sectionKerning)
                            .foregroundStyle(AppColors.inkTertiary)
                        ApolloWordmark(height: 50)
                    }

                    Divider()

                    ForEach(Self.weights, id: \.0) { name, weight in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.uppercased())
                                .font(Typography.sectionLabel)
                                .kerning(Typography.sectionKerning)
                                .foregroundStyle(AppColors.inkTertiary)
                            Text("Home")
                                .font(.system(.largeTitle, design: .serif, weight: weight))
                                .tracking(-0.6)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text("Recents")
                                .font(.system(.title3, design: .serif, weight: weight))
                                .tracking(-0.2)
                                .foregroundStyle(AppColors.inkPrimary)
                        }
                    }

                    Divider()

                    // The one that matters: each weight sitting directly
                    // under the mark, which is how they appear on the camera
                    // and Home one tab apart.
                    Text("AGAINST THE MARK")
                        .font(Typography.sectionLabel)
                        .kerning(Typography.sectionKerning)
                        .foregroundStyle(AppColors.inkTertiary)
                    ForEach(Self.weights, id: \.0) { name, weight in
                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            ApolloWordmark(height: 34)
                            Text("Home")
                                .font(.system(.largeTitle, design: .serif, weight: weight))
                                .tracking(-0.6)
                                .foregroundStyle(AppColors.inkPrimary)
                            Spacer()
                            Text(name)
                                .font(Typography.bodySmall)
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                    }
                }
                .padding(GridConstants.gapWide)
                .padding(.bottom, 80)
            }
        }
        .preferredColorScheme(.light)
    }
}
#endif
