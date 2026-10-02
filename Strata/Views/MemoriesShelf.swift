import SwiftUI

/// **The one shelf on the Memories page: the collections, in a row.**
///
/// **The header that stood here described the replay posters, and they left this
/// file in October** (rewritten 2026-10-01, with the dead card they belonged to;
/// see the MARK at the bottom for what went and where the parts of it live now).
/// It opened "The Replays section in Memories" and ran four paragraphs on fitting
/// every poster in a row to the TALLEST tower, on a name set in the owner's face
/// over an uppercase caption, and on why a poster wears no rim. None of that is
/// on screen: `ReplayRow` offers the replays as full-width rows under the
/// calendar, and this draws `AlbumCard`.
///
/// What is left is the row, and the two decisions in it are both the owner's.
///
/// **ONE SHELF, NOT TWO.** Replays and albums were two bands of cards, one
/// directly under the other, at what became the same card width — and his read
/// of the page was that it was still four stacked lists. They are the same KIND
/// of thing: something the app made out of wins you already logged, that you open
/// by pressing a picture of it. A replay plays and an album opens, which is a
/// difference of one tap rather than of category. Then the replays became rows,
/// because a shelf says "here are many, pick one" and there is exactly one
/// September; so what is left in the row is the albums, which is the only route
/// in the app to a moment or a repeated interest, and that is what earns it the
/// space.
///
/// **AND THE HEADING IS GONE.** `docs/copy-audit.md` cut 2. It read
/// "Collections" over a row of cards that each draw `album.title` at
/// `Typography.headerMedium` — "Gym session", "A year ago today" — with a count
/// under that. On a page that already carries a title, a month picker, a replay
/// row and a photo grid, it was a fifth label introducing the one band that
/// introduces itself.
///
/// **The WORD went and the AIR stayed, and that is the whole move.**
/// `SectionHeading` was carrying `gapSection * 2` above it, which is `gapPage` —
/// the one unambiguous break on this page and the reason `docs/space.md` calls
/// Memories the best-distributed screen in the app (17% of its emptiness in one
/// run, both ends of the ladder present). Delete the heading naively and that
/// break goes with it and the shelf lands a `gapTight` under the calendar. So the
/// break moved onto the row itself. Subtraction here is one band fewer at the
/// same rhythm, not a tighter page.
///
/// The `.id` moved with it: `-strataScrollMemories replays` scrolls to
/// `"MemoriesReplays"`, and that id has to still be on something drawn.
struct MemoriesShelf: View {
    /// **The albums, in the same row as the replays** (2026-10-01).
    ///
    /// They were two shelves, one directly under the other, at what became the
    /// same card width — and the owner's read of the page was that it was still
    /// four stacked bands of cards. They are the same KIND of thing: something
    /// the app made out of wins you already logged, that you open by pressing a
    /// picture of it. A replay plays and an album opens, which is a difference
    /// of one tap rather than of category.
    ///
    /// One shelf, one heading, one scroll. Replays first because they expire in
    /// a way albums do not: a week's replay is only interesting for a while.
    let albums: [Album]
    let onOpenAlbum: (AlbumRoute) -> Void

    /// The card's width. Not `ReplayCard.posterWidth` (132), which was the size a
    /// replay poster had to be to show a whole tower: an album card shows one
    /// photograph and its name, and at 132 three of them were the loudest thing
    /// on a page whose subject is the month above them. 108 puts three and a bit
    /// on screen, which also says the row scrolls without a chevron telling you
    /// so.
    static let albumWidth: CGFloat = 108

    /// **Why the replays are not in here, kept because it is the finding rather
    /// than the change.**
    ///
    /// The owner: "I dont see what the point of the more is." Two faults
    /// compounded. It DUPLICATED the month picker: the row led with every
    /// finished month and week as a poster, and the page already has a picker
    /// above it whose whole job is choosing a month, plus that month's own replay
    /// in a full width row under it, so a person who wanted September had three
    /// routes to it on one screen and the shelf was the slowest and least
    /// labelled of the three. And the duplication pushed the UNIQUE content off
    /// the screen: the albums came after the replays in the same row, so on a
    /// phone they sat past the right edge — three tower posters that look alike at
    /// 132pt, and the one thing in the row that is not reachable any other way
    /// was the thing you could not see.
    ///
    /// The route to a month is the picker. The route to a month's replay is the
    /// row under it. The route to a place is the map. This row is the rest.
    var body: some View {
        if !albums.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: GridConstants.gapLabel) {
                    // **ONE ROW, AND IT WAS THREE.** Months ran at 132pt,
                    // weeks at 96 on a second row under them, and the albums
                    // carousel at a third size under that: three horizontal
                    // strips of cards, none of them siblings. That is most of
                    // what the owner means by the page needing to be remade
                    // rather than tweaked — the page had no rhythm because
                    // nothing on it was the same size as anything else.
                    //
                    // The width, and why it is 108, is on `albumWidth`.
                    row(width: Self.albumWidth)
                        .id("MemoriesReplays")
                }
            }
            // The break the heading used to carry, now on the band itself. See
            // the note on `body`.
            .padding(.top, GridConstants.gapPage)
            // **The word goes to VoiceOver, exactly as the tab bar's three
            // labels did on the same day.** A sighted reader has the cards,
            // which name themselves; somebody navigating by rotor had a heading
            // and would otherwise have a row of unannounced buttons between a
            // calendar and a photo grid. `.contain`, not `.combine`, so each
            // card stays its own element.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Collections")
        }
    }

    private func row(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: GridConstants.gapItem) {
                // **A card answers the press, and nothing else.** `.plain`
                // left the shelf inert under a finger, and section 5 asks for
                // reaction rather than decoration: things move because a
                // person did something, where they did it.
                ForEach(albums) { album in
                    Button {
                        HapticsEngine.lightTap()
                        onOpenAlbum(album.route)
                    } label: {
                        AlbumCard(album: album, width: width)
                    }
                    .buttonStyle(.pressSurface)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(album.title), \(album.subtitle)")
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, GridConstants.horizontalPadding)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: - The replay card is deleted, and it took five properties with it
    //
    // **About 170 lines, with no caller** (2026-10-01,
    // `docs/consistency-audit.md` §1.13). `card(_:width:)` drew a replay poster
    // with a name and a count under it, and `body` has called `row(width:)` —
    // which draws `AlbumCard` — since the replays came out of this shelf and
    // moved to `ReplayRow`. Nothing reached `card`, so nothing reached `poster`,
    // `periodName`, `nameLine`, `systemName`, `countLine` or `countSize` either,
    // and five of the type's seven properties existed only to feed them:
    // `model`, `now`, `excluding`, `transitionNamespace` and `onPlay`, all of
    // which `MemoriesView` was still filling in at the call site, plus the
    // `colorScheme` and `displayScale` environment reads.
    //
    // **`SectionHeading` cited `MemoriesShelf.countLine` as one of the app's two
    // live count readouts and that citation was stale when it was written.** It
    // was checked before this was deleted, which is the thing CLAUDE.md's water
    // entry asks for: a dangling doc comment for a deleted function reads exactly
    // like a feature you cannot find.
    //
    // **What was worth keeping, and where it went.**
    //
    // The count readout is `CountReadout` now, which is this card's own shape —
    // the owner's tabular digits, the unit in SF at the label tier, lower case,
    // `inkTertiary` — with the optical inset as the one parameter, because the
    // inset was the only thing left separating the two live rungs once the
    // caption's 13 went to 15. `AlbumCard` right above draws it.
    //
    // The optical argument, which `CountReadout` carries: tabular centring puts
    // real air to the left of every digit, so a caption's number sits a little
    // left of the margin to stand the two lines of the caption on one edge.
    //
    // The lower-case decision, which the owner's reading settled: "'46 WINS'
    // under a card and '46 wins' in `MonthReplayRow` is the same fact set two
    // ways on one screen, and the shouted one is the one nobody asked for."
    // Small caps are a LABEL's voice and belong over a form group, which is
    // where `FormSectionLabel` still uses them.
    //
    // The two Swift lessons in the drawn name, kept because the next card that
    // sets a period in the owner's face will need both. `DynamicScreenTitle`
    // makes two checks and a card has to make them at its own size: COVERAGE,
    // because a missing glyph falls back one character at a time and patches the
    // word, so a week's "9/7-9/13" fails on its own since `/` is a placeholder;
    // and WIDTH, because the face runs about 19% wider than SF. And the hidden
    // full-size line that set the row's height had to sit INSIDE each
    // `ViewThatFits` branch rather than around it, because a layout container
    // only carries its content's baselines if it says so — the same reason
    // `WidthReveal` in `ReplayFrame` implements `explicitAlignment`.
    //
    // `name(of:)` and `accessibilityLabel(_:now:)` below are statics and both
    // have live callers (`MemoriesView.replayRows`, `ReplayShelfModelTests`), so
    // they stay.

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

// **`PosterPress` is deleted** (2026-10-01). It was this file's private copy of
// `PressResponse`, which exists so that "every button acknowledges the press, in
// one place", and `docs/motion-audit.md` found it: the app had four different
// answers to a press and thirty-one buttons with none. Its numbers survive as
// `.pressSurface`, and the one thing it did better than the original — honouring
// Reduce Motion — is now in the original.
