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
    /// On its own card, where it is not already a form's row: the surface a
    /// form's rows sit on, and the hairline round it.
    var contained = false
    /// **Quiet**: a line of facts under a name, with no card (the owner,
    /// 2026-10-16, of the carded version: "still a bit not tasteful"). The
    /// smaller words, a lighter stroke on the icons, centred when they fit.
    var quiet = false
    /// The quiet row's height: 36 under a name, less in a fixed band.
    var lineHeight: CGFloat = 36

    private static let line: CGFloat = 52
    private static let iconWidth: CGFloat = 24
    private var hairline: Color { AppColors.inkPrimary.opacity(0.1) }

    var body: some View {
        if contained {
            let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
            content
                .background(shape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
                .overlay(shape.strokeBorder(AppColors.inkPrimary.opacity(0.1), lineWidth: GridConstants.strokeThin))
                .clipShape(shape)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if !chips.isEmpty, quiet {
                // All of them when they fit, else the first two: a quiet line
                // is never cut at the edge.
                ViewThatFits(in: .horizontal) {
                    chipRow(chips)
                    chipRow(Array(chips.prefix(2)))
                    chipRow(Array(chips.prefix(1)))
                }
            } else if !chips.isEmpty {
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
                // Soft where it runs off (the owner, 2026-10-16: "a blur at the
                // end when it scrolls, for that premium look").
                .edgeFade()
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

    /// The quiet row: smaller, lighter, centred.
    private func chipRow(_ chips: [Fact]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(chips.enumerated()), id: \.element.id) { index, chip in
                if index > 0 {
                    Rectangle().fill(hairline)
                        .frame(width: GridConstants.strokeThin, height: 16)
                }
                HStack(spacing: 6) {
                    Image(systemName: chip.icon)
                        .font(Typography.headerSmall.weight(.light))
                        .foregroundStyle(AppColors.inkSecondary)
                        .accessibilityHidden(true)
                    Text(chip.text)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                        .fixedSize()
                }
                .padding(.horizontal, GridConstants.gapItem)
                .frame(minHeight: lineHeight)
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

/// **A card on the page** (2026-10-16): the surface a form's rows sit on,
/// the radius of the app's surfaces and a thin light-grey hairline round it
/// (the owner: "the thin light grey hairline around the containers, I
/// think that would make it more clean"), no shadow.
/// The profile card and the calendar card are this one card, so Memories
/// reads as two of a kind.
extension View {
    func pageCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
        return self
            .background(shape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(shape.strokeBorder(AppColors.inkPrimary.opacity(0.1), lineWidth: GridConstants.strokeThin))
    }
}

/// How far a card's contents sit from its edge: its radius less the radius
/// of the tiles inside it, so their corners run concentric.
enum PageCard {
    static let inset: CGFloat = GridConstants.radiusSurface - GridConstants.cornerRadius
    /// **Between one card and the next, everywhere** (the owner, 2026-10-16:
    /// "I liked the spacing between containers in Memories before ... the
    /// profile and everything has to feel consistent with Memories and vice
    /// versa"): Memories' own 32, on Memories, Profile, a friend's profile
    /// and Your day.
    static let gap: CGFloat = GridConstants.gapSection
}
