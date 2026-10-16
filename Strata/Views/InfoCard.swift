import SwiftUI

/// **Facts, organised** (the owner, 2026-10-16, after Hinge's profile: "I
/// love how they organize information using icons and clean hairline
/// dividers ... there is a lot of information in the profile that isn't
/// really organized, just floating"). One card: a row of short facts across
/// the top, each an icon and its value with a hairline between them, which
/// scrolls sideways when there are more than fit; then one fact a line, an
/// icon and its words, hairlines between. The one component for loose facts
/// about a person, so every profile reads alike. Ink only; the icons are the
/// system's (`docs/` icon split: tools and facts stay SF).
struct InfoCard: View {
    struct Fact: Identifiable {
        let icon: String
        let text: String
        var id: String { icon + text }
    }

    var chips: [Fact] = []
    var rows: [Fact] = []

    private static let line: CGFloat = 52
    private static let iconWidth: CGFloat = 24
    private var hairline: Color { AppColors.inkPrimary.opacity(0.1) }

    var body: some View {
        VStack(spacing: 0) {
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(chips.enumerated()), id: \.element.id) { index, chip in
                            if index > 0 {
                                Rectangle().fill(hairline)
                                    .frame(width: GridConstants.strokeThin, height: Self.line * 0.6)
                            }
                            HStack(spacing: GridConstants.gapTight) {
                                icon(chip.icon)
                                Text(chip.text)
                                    .font(Typography.bodyLarge)
                                    .foregroundStyle(AppColors.inkPrimary)
                                    .monospacedDigit()
                                    .fixedSize()
                            }
                            .padding(.horizontal, GridConstants.horizontalPadding)
                            .frame(height: Self.line)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                if !rows.isEmpty { divider }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { divider }
                HStack(spacing: GridConstants.gapItem) {
                    icon(row.icon)
                    Text(row.text)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
                .frame(minHeight: Self.line)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(hairline)
            .frame(height: GridConstants.strokeThin)
            .padding(.horizontal, GridConstants.horizontalPadding)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(Typography.bodyLarge)
            .foregroundStyle(AppColors.inkPrimary)
            .frame(width: Self.iconWidth)
            .accessibilityHidden(true)
    }
}
