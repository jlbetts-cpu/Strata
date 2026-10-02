import SwiftUI

/// **A replay, offered as a row under the month.**
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
/// **It was `MonthReplayRow` and only the NAME was ever month-specific**
/// (renamed 2026-10-01). It has always taken a `replay`, a `poster`, a `title`
/// and an `onPlay`, so it could already draw a week; nothing on this page would
/// offer it one. That was a real hole: the Wins tab's `headerReplayPill` was
/// deleted the same day and it was the only route to the open WEEK's replay, so
/// a week replay was briefly unreachable from anywhere in the app. The owner's
/// call, with the cost named, was that all replays live in Memories — so the
/// page stacks this row twice when it has two periods to offer. See
/// `MemoriesView.replayRows` for which two, and `ReplayShelfModel.live` for the
/// rule that picks the second.
///
/// **A row, not a card in a shelf.** A shelf says "here are many, pick one". The
/// replays this page offers are singular — there is exactly one September, and
/// exactly one week whose window is open — so a shelf of one was the wrong shape
/// and a card of one is a card floating with nothing beside it. A full-width row
/// is what a single available action looks like, and two of them are a short
/// list rather than a strip you have to scroll.
///
/// **One line of type, and the count is gone** (2026-10-01). It drew
/// "46 wins" in `inkSecondary` under the title, which is the pattern the owner
/// named twice in one afternoon: "no tiny text under or anythign like that I
/// want it to be controlled". Two things make it affordable to lose here and
/// nowhere else on this page. The replay's own first act IS that count — the
/// odometer rolls it up one landing at a time across the whole build — and the
/// thumbnail beside the title is a picture of those very wins. So the row says
/// which period it is and that it plays, the replay says how much is in it, and
/// the figure stays in the accessibility label, where nothing is lost.
/// `docs/copy-audit.md` classes that line as a Fact and did not cut it; this is
/// the typographic instruction rather than the word count, and the fact it
/// carried is one tap away.
///
/// **The play glyph is INK, not the accent.** The comment that stood here said
/// this row "carries the page's only accent" and named `accentPrimary`; the code
/// has drawn `inkPrimary` the whole time, so the file was claiming a colour it
/// did not use. Ink is the right answer and the reason is check 5: saturated
/// colour on this page means a win or a photograph, and the page has thirty of
/// both. A blue disc among them would be the only piece of chrome on the screen
/// competing for the one thing colour is reserved for.
struct ReplayRow: View {
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
            // **Centred on the thumbnail, now that there is one line.** With
            // two lines the stack filled most of the 84pt picture beside it; a
            // single line pinned to the top of an 84pt thumbnail reads as a
            // caption that slipped, so the row centres on it.
            HStack(spacing: GridConstants.gapLabel) {
                thumbnail
                Text(title)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                    // The one thing in the row that gives way, and only so
                    // far: a week's name is a date range and must not wrap.
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .contentShape(Rectangle())
        }
        // The same press as the album posters beside it. It was `.plain`,
        // which draws the label and nothing else, so this row was one of three
        // things on the Memories tab that did not answer a finger while the
        // poster between them did. `docs/motion-audit.md` §5.1.
        .buttonStyle(.pressSurface)
        // **The count lives here now.** It came off the screen, not out of the
        // app: VoiceOver reads exactly what it read before.
        .accessibilityLabel("Replay \(title), \(replay.count) \(replay.count == 1 ? "win" : "wins")")
        .accessibilityAddTraits(.isButton)
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            // The slot the poster lands in, as `MemoriesShelf`'s card has one.
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
        // reach one. See `MemoriesShelf`.
        .overlay { shape.strokeBorder(GridConstants.fillHairline, lineWidth: 0.5) }
    }
}
