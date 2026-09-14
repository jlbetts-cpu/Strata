import SwiftUI

/// The Replays section in Memories.
///
/// Months side by side as posters, so the row is a set of towers you can
/// compare by eye. Weeks under them, smaller. Nothing is drawn when there is
/// nothing finished: no heading over a gap.
///
/// **One scale per row.** Each poster is the finished tower alone, and every
/// poster in a row is drawn at the scale that fits the row's TALLEST tower,
/// on a shared base. Fitted one by one, a month of 86 wins and one of 68
/// stood exactly the same height, which is the one comparison the row exists
/// to make.
///
/// **Set like the albums under it**, so it reads as a shelf this page always
/// had: the same heading, the same `gapItem` step between cards, the name in
/// `blockTitle` and the count as the album's small uppercase caption. No rim
/// and no hairline on the poster: the camera roll draws its pictures bare, and
/// the album cover's rim is a block's, which a poster is not.
struct ReplayShelf: View {
    let model: ReplayShelfModel
    /// The `now` the shelf's periods were chosen against, so a name is worded
    /// against the same moment (`ReplayShelfModel.now`).
    let now: Date
    /// Where the replay grows from, the way a photograph opens out of its
    /// thumbnail.
    var transitionNamespace: Namespace.ID?
    let onPlay: (Replay) -> Void

    /// Posters are drawn in the page's scheme and cached per scheme.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if !model.months.isEmpty || !model.weeks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(text: "REPLAYS")
                    .id("MemoriesReplays")
                VStack(alignment: .leading, spacing: GridConstants.gapLabel) {
                    if !model.months.isEmpty { row(model.months, width: ReplayCard.monthPosterWidth) }
                    if !model.weeks.isEmpty { row(model.weeks, width: ReplayCard.weekPosterWidth) }
                }
            }
        }
    }

    private func row(_ replays: [Replay], width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: GridConstants.gapItem) {
                ForEach(replays) { replay in
                    Button {
                        HapticsEngine.lightTap()
                        onPlay(replay)
                    } label: {
                        card(replay, width: width)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Self.accessibilityLabel(replay, now: now))
                    .accessibilityHint("Plays the replay")
                    .accessibilityAddTraits(.isButton)
                    .matchedTransitionSource(id: replay.id, in: transitionNamespace)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, GridConstants.horizontalPadding)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func card(_ replay: Replay, width: CGFloat) -> some View {
        let height = width * ReplayCard.size.height / ReplayCard.size.width
        let name = Self.name(of: replay.period, now: now)
        let count = "\(replay.count) \(replay.count == 1 ? "win" : "wins")"
        let radius = GridConstants.radiusField
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                // The slot the poster lands in, as an album cover has one.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.warmBlack.opacity(0.04))
                if let image = model.cards[ReplayShelfModel.key(replay, scheme: colorScheme)] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .animation(GridConstants.gentleReveal,
                       value: model.cards[ReplayShelfModel.key(replay, scheme: colorScheme)] != nil)
            // **The line is as tall as the name at full size**, whatever the
            // name shrank to. "31 Aug to 6 Sep" scales down to fit a week's
            // card, and a shrunk line is a shorter line, so its count sat
            // higher than its neighbours'. A hidden full-size line sets the
            // height and the name sits on its baseline.
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
                Text(verbatim: "Ag").hidden()
                Text(name)
                    .minimumScaleFactor(0.8)
            }
            .font(Typography.blockTitle)
            .foregroundStyle(AppColors.inkPrimary)
            .lineLimit(1)
            .padding(.top, GridConstants.gapTight)
            Text(count)
                .font(Typography.photoCaption)
                .kerning(Typography.sectionKerning)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.inkTertiary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "Your week, 7 to 13 September, 31 wins": the range in full, since
    /// VoiceOver has no narrow card to fit.
    static func accessibilityLabel(_ replay: Replay, now: Date) -> String {
        "\(replay.period.title), \(replay.period.range(relativeTo: now)), \(replay.count) \(replay.count == 1 ? "win" : "wins")"
    }

    /// "September", "7 to 13 Sep": the week's card is narrow, so its months
    /// are cut to three letters.
    static func name(of period: ReplayPeriod, now: Date) -> String {
        let full = period.range(relativeTo: now)
        guard period.kind == .week else { return full }
        let months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"]
        return months.reduce(full) { $0.replacingOccurrences(of: $1, with: String($1.prefix(3))) }
    }
}
