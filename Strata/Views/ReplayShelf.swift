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
/// had: the same heading, the same `gapItem` step between cards, a name at the
/// 17 rung over a small uppercase caption, and the corner ladder the album
/// cover beside it takes off its own side. No rim, no hairline and no shadow
/// on the poster: the camera roll draws its pictures bare, the album cover's
/// rim is a block's, which a poster is not, and a picture lying in a slot is
/// not standing on anything. `docs/design-system-future.md` section 6 spends
/// elevation on a block, a card you can pick up and the drawer; this is a
/// picture you press, so the slot under it does the separating.
///
/// **The name and the count are the app's own; the words are not.** A card has
/// to answer what period this is and how much is in it (section 7), and those
/// two answers are the app talking about itself, which is what the owner's
/// face is for: the name is drawn when it covers the string and fits, the
/// count is his digits, and everything that reads as language stays SF
/// Rounded (section 2).
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
    /// Read here and handed to `PosterPress`: a `ButtonStyle` is not a view,
    /// so an `@Environment` read inside one is not kept up to date.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    // **A card answers the press, and nothing else.**
                    // `.plain` left the shelf inert under a finger, and
                    // section 5 asks for reaction rather than decoration:
                    // things move because a person did something, where they
                    // did it.
                    .buttonStyle(PosterPress(reduceMotion: reduceMotion))
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
        // **The block ladder at this card's size, not the flat `radiusField`.**
        // `AlbumCoverView` takes `blockCornerRadius(forCell:)` off its own
        // side, so a flat 12 here put two picture cards of the same size class
        // on one page wearing different corners. Section 3 asks a screen's
        // grid of things for the same corner radius for its size class, and
        // derived off the width it is the same radius at 132 and at 96 in
        // proportion rather than in points.
        let radius = GridConstants.blockCornerRadius(forCell: width)
        return VStack(alignment: .leading, spacing: 0) {
            poster(replay, width: width, height: height, radius: radius)
            periodName(name)
                .foregroundStyle(AppColors.inkPrimary)
                .padding(.top, GridConstants.gapTight)
            countLine(replay.count)
                .padding(.top, 2)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The picture: the slot it lands in, and the poster once it is drawn.
    private func poster(_ replay: Replay, width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            // The slot the poster lands in, as an album cover has one.
            //
            // **`quietFill`, not `warmBlack` at 4%.** This is the app's own
            // token for an empty cell and it adapts; a 4% warm black over a
            // near-black page is nothing, so on a dark shelf a poster that had
            // not been drawn yet left a hole rather than a slot. Same fault
            // `AppColors.slotInk` was made to fix.
            shape.fill(AppColors.quietFill)
            if let image = model.cards[ReplayShelfModel.key(replay, scheme: colorScheme)] {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        // **Nothing fades in when the poster arrives.** It used to cross-fade
        // on `gentleReveal` as each render landed, which is a shelf animating
        // because it appeared: section 5 keeps motion for what a person did.
        // A poster is drawn in a few milliseconds and the row is usually
        // complete before it is on screen, so the fade was a wait in front of
        // a picture that was already there.
    }

    /// The period's name: the owner's face when it can be set whole and it
    /// fits, SF Rounded when it cannot.
    ///
    /// **The two checks `DynamicScreenTitle` makes**, at a card's size rather
    /// than a screen title's. Coverage, because a missing glyph falls back one
    /// character at a time and patches the word: a week's "9/7-9/13" fails it
    /// on its own, since `/` is still a stand-in glyph
    /// (`StrataFont.placeholders`). And width, because the face runs about 19%
    /// wider than SF, so "September 2025" on a 96pt week card is the fallback's
    /// job.
    ///
    /// 17 relative to `.headline` is the drawn rung a sheet's title already
    /// uses; a card rung would be a sixth size. The drawn name never shrinks
    /// to fit, it gives way to SF: below about 17 the owner's D reads as O
    /// (`StrataFont`), so `minimumScaleFactor` belongs to the fallback only.
    @ViewBuilder
    private func periodName(_ name: String) -> some View {
        if StrataFont.covers(name) {
            ViewThatFits(in: .horizontal) {
                nameLine {
                    Text(verbatim: name)
                        .font(Typography.sheetTitleDrawn)
                        .lineLimit(1)
                        .fixedSize()
                }
                nameLine { systemName(name) }
            }
        } else {
            nameLine { systemName(name) }
        }
    }

    /// **The line is as tall as the name at full size**, whatever the name
    /// shrank to. A long name scales down to fit a week's card, and a shrunk
    /// line is a shorter line, so its count sat higher than its neighbours'. A
    /// hidden full-size line sets the height and the name sits on its
    /// baseline.
    ///
    /// **Inside each branch, not around the `ViewThatFits`.** A baseline has
    /// to be reported by whatever sits in the stack, and a layout container
    /// only carries its content's baselines if it says so (`WidthReveal` in
    /// `ReplayFrame` has to implement `explicitAlignment` for exactly this).
    /// Both branches carry the same hidden line, so they are the same height
    /// whichever one fits, and the card's caption does not move.
    ///
    /// The drawn face has SF Pro Rounded's line metrics scaled to its own em
    /// (`StrataFont`), so the hidden SF line and a drawn name share a
    /// baseline rather than needing one of their own.
    private func nameLine<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
            Text(verbatim: "Ag").hidden().font(Typography.headerMedium)
            content()
        }
    }

    private func systemName(_ name: String) -> some View {
        Text(verbatim: name)
            .font(Typography.headerMedium)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// How much is in this period: the number, then what it counts.
    ///
    /// **The number is a readout and the word is a label.** It was one string
    /// in `sectionLabel`, so the one fact on the card ("31 WINS") set its
    /// number in the heading face. Section 2: counts are the owner's digits,
    /// tabular, and anything that reads as language is SF Rounded.
    ///
    /// `StrataFont.digits`, never `Text("\(count)")`: that interpolation is a
    /// `LocalizedStringKey` and formats with the locale's grouping, so 1000
    /// would arrive as "1,000" and the face has no comma.
    private func countLine(_ count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            Text(verbatim: StrataFont.digits(count))
                .font(StrataFont.relative(Self.countSize, to: .footnote))
                // Optical, as the replay's own count is: tabular centring puts
                // real air to the left of every digit, so the box sits a
                // little left of the margin to stand the two lines of the
                // caption on one edge.
                .padding(.leading, -StrataFont.opticalInset * Self.countSize)
            Text(count == 1 ? "win" : "wins")
                .font(Typography.sectionLabel)
                .kerning(Typography.sectionKerning)
                .textCase(.uppercase)
        }
        .foregroundStyle(AppColors.inkTertiary)
        .lineLimit(1)
    }

    /// The caption rung, 13: `Typography.sectionLabel`'s own size, so the
    /// digits and the word beside them are one line and not two sizes. Digits
    /// go this small safely; letters do not (`StrataFont`).
    private static let countSize: CGFloat = 13

    /// "Your week, 7 to 13 September, 31 wins": the range in words, since
    /// VoiceOver reads "9/7-9/13" as numbers and slashes.
    static func accessibilityLabel(_ replay: Replay, now: Date) -> String {
        "\(replay.period.title), \(replay.period.spokenRange(relativeTo: now)), \(replay.count) \(replay.count == 1 ? "win" : "wins")"
    }

    /// "September", "9/7-9/13": the replay's own title, short enough for a
    /// week's narrow card as it is.
    static func name(of period: ReplayPeriod, now: Date, locale: Locale = .current) -> String {
        period.range(relativeTo: now, locale: locale)
    }
}

/// How a poster answers a finger: it gives, and it is over in 0.06s.
///
/// `tapSquashSpring` is the app's press rung and `tapScaleY` the amount every
/// other pressable surface gives by, so a poster does not get a number of its
/// own. **Uniform, not the block's squash**: `tapScaleX`/`tapScaleY` together
/// are a thing landing on a floor, and this is a card being pressed into the
/// page, with its own caption inside the same label.
///
/// Under Reduce Motion nothing scales. The haptic on the press and the opening
/// itself still happen, so the card still answers.
private struct PosterPress: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed && !reduceMotion
        return configuration.label
            .scaleEffect(down ? GridConstants.tapScaleY : 1)
            .animation(GridConstants.tapSquashSpring, value: down)
    }
}
