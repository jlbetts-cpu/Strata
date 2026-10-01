import SwiftUI

/// **The month's own replay, directly under the month.**
///
/// The owner, 2026-10-01: "I asked you to redesign the Memories and I haven't
/// received one redesign yet." Fair, and this is the change that was missing —
/// the page's structure rather than its spacing and its type.
///
/// **What was wrong was the page's subject.** It opened on a calendar for one
/// month and then showed four shelves that had nothing to do with that month: a
/// row of replays for every month and week there is, a row of albums, and the
/// whole camera roll. The month at the top was a filter nothing downstream
/// obeyed. Scrolling it felt like a list of features because it was one.
///
/// So the page is about the month you have chosen. The calendar shows it, THIS
/// row offers the one replay of it, and the photographs below are its
/// photographs. The shelves that browse everything come after, where browsing
/// belongs.
///
/// **A row, not a card in a shelf.** A shelf says "here are many, pick one". The
/// month's replay is singular by definition — there is exactly one September —
/// so a shelf of one was the wrong shape and a card of one is a card floating
/// with nothing beside it. A full-width row is what a single available action
/// looks like.
///
/// **It carries the page's only accent.** The design doc reserves saturated
/// colour for the blocks and the photographs, and chrome is ink — which is why
/// this page had drifted into greyscale: every caption, count and glyph on it
/// was a shade of grey. `accentPrimary` on one glyph, in the one place the page
/// offers you something to do, is the exception that keeps the rule readable.
struct MonthReplayRow: View {
    let replay: Replay
    /// The poster, once the shelf model has drawn it. Nil until then, and the
    /// row still works: the thumbnail is a well in the meantime.
    let poster: UIImage?
    let title: String
    let onPlay: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// **A WIDE CROP, NOT THE WHOLE POSTER SHRUNK.**
    ///
    /// The thumbnail followed the poster's own 360:640, which at a row's height
    /// made it 52pt across — a sliver, and the weakest object on the page. A
    /// picture 52 points wide is not a picture, it is a stripe.
    ///
    /// Wider than it is tall, with the poster scaled to FILL it, so what shows
    /// is a band across the middle of the tower rather than the whole tower
    /// made tiny. The blocks run edge to edge at a size you can see them, which
    /// is the only thing a thumbnail of a tower has to do.
    private static let height: CGFloat = 84
    private var width: CGFloat { 116 }
    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: width) }

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            onPlay()
        } label: {
            HStack(spacing: GridConstants.gapLabel) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                    Text("\(replay.count) \(replay.count == 1 ? "win" : "wins")")
                        .font(Typography.bodySmall)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                Spacer(minLength: 0)
                // The page's one piece of colour that is not a win or a
                // photograph. See the note on the type.
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppColors.accentPrimary)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Replay \(title), \(replay.count) wins")
        .accessibilityAddTraits(.isButton)
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            // The slot the poster lands in, as `ReplayShelf`'s card has one.
            shape.fill(AppColors.quietFill)
            if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: width, height: Self.height)
        .clipShape(shape)
        // The same ink hairline the shelf's posters wear: a drawing of a tower
        // on the page's own ground has no edge anywhere the tower does not
        // reach one. See `ReplayShelf`.
        .overlay { shape.strokeBorder(GridConstants.fillHairline, lineWidth: 0.5) }
    }
}
