import SwiftUI

/// **One day, as the Recents row needs it.**
///
/// A value, not a query. The row is handed days that have already been
/// grouped and counted so that scrolling it cannot touch the store, and so
/// the lab can build a week out of nothing.
struct RecentDay: Identifiable, Equatable {
    /// `yyyy-MM-dd`, which is also the key the dressing is stored under.
    let id: String
    let date: Date
    let count: Int
    /// The few wins that show through the glass. Never the whole day: the
    /// folder draws five at most and a card here is under 60pt wide.
    var peek: [ScatterWin] = []
    var isToday: Bool = false

    static func == (a: RecentDay, b: RecentDay) -> Bool {
        a.id == b.id && a.count == b.count && a.isToday == b.isToday
            && a.peek.count == b.peek.count
            && zip(a.peek, b.peek).allSatisfy { $0 == $1 }
    }

    /// **What goes above the count.** The owner: "the date above it."
    ///
    /// Today and yesterday get their words, because that is what a person
    /// calls them and a date would make you do arithmetic to find out you
    /// are looking at this morning. Everything else is the weekday and the
    /// day number, which is the shortest form that is still unambiguous
    /// inside a week.
    func title(now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    var countLabel: String {
        count == 1 ? "1 win" : "\(count) wins"
    }
}

/// **The Recents row: the week as a shelf of folders.**
///
/// The owner: "the first section with a bit of horizontal scroll... we can
/// call this folder section Recents."
///
/// **Why a row and not the single folder it replaces.** He said it himself:
/// "a folder standalone doesn't look all too good." One object in the middle
/// of a page is a logo — there is nothing for it to be bigger or fuller or a
/// different colour *than*. A row gives every folder a neighbour, which is
/// what makes today's being open mean something, and it is the first thing on
/// the page that says this app has a history rather than only a today.
///
/// Today is open and the days behind it are closed, which is the owner's
/// call and is also the honest picture: the day you are in is the one you can
/// still put something into.
struct RecentsRow: View {
    var days: [RecentDay]
    var styles: (String) -> FolderStyle = { _ in .default }
    var onOpen: (RecentDay) -> Void = { _ in }
    var onCustomise: (RecentDay) -> Void = { _ in }

    /// The width of one folder tile.
    ///
    /// 150 on a 393pt screen leaves the third folder cut off at the right
    /// edge by about a third of its width, which is the amount that reads as
    /// "this scrolls" without looking like a layout accident. Measured
    /// rather than guessed: at 132 four fit with a sliver and the row reads
    /// as a grid that failed; at 168 only two fit and there is no hint.
    static let tileWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            Text("Recents")
                .font(Typography.sectionSerif)
                .foregroundStyle(AppColors.inkPrimary)
                .padding(.horizontal, GridConstants.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: GridConstants.gapItem) {
                    ForEach(days) { day in
                        DayFolderTile(day: day,
                                      style: styles(day.id),
                                      onOpen: { onOpen(day) },
                                      onCustomise: { onCustomise(day) })
                            .frame(width: Self.tileWidth)
                    }
                }
                // **Padding inside the scroll view, not outside it.**
                // Outside, the row's own edges clip the folders before they
                // reach the screen's, so a folder fades out 20pt early and
                // the shadow is cut off square. Inside, content starts on the
                // page's margin and scrolls all the way to the bezel.
                .padding(.horizontal, GridConstants.horizontalPadding)
                // Room for the folders' shadows, which fall outside their
                // frames and were being clipped flat by the scroll view.
                .padding(.vertical, 10)
            }
            .scrollClipDisabled()
        }
    }
}

/// One folder on the shelf: the object, the date, and the count under it.
///
/// The stack is the VEED reference's exactly — object, name, quiet count —
/// and it is the right order because the folder is what you are looking at
/// and the two lines are its label rather than its heading.
struct DayFolderTile: View {
    var day: RecentDay
    var style: FolderStyle
    var onOpen: () -> Void = {}
    var onCustomise: () -> Void = {}

    @State private var pressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WinFolder(title: day.title(),
                      count: day.count,
                      tint: style.tint(for: day.id),
                      contents: day.peek,
                      // **Every folder is open.** The owner: "can all the
                      // folders be open, not just the today."
                      //
                      // He is right and the closed state was my reading of
                      // his earlier note rather than his. A folder is on this
                      // row because it has wins in it, and the wins standing
                      // out of it are the only thing on the row that is
                      // actually HIS — the folder is a container the app drew
                      // and the photographs are the day. Shutting five of the
                      // six hid the content to signal a state nothing needed
                      // signalling: today is labelled "Today" and is first.
                      //
                      // `openAmount` stays a parameter because the animation
                      // between the two is real and something will want it.
                      openAmount: 1,
                      showsFace: style.faceName != nil,
                      expression: style.expression,
                      isAlive: day.isToday)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.title())
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(day.countLabel)
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkTertiary)
            }
            .lineLimit(1)
            .padding(.top, GridConstants.gapTight)
        }
        .scaleEffect(pressed ? 0.96 : 1)
        .animation(GridConstants.motionSmooth, value: pressed)
        .contentShape(Rectangle())
        // **A press that reports on the way down and acts on the way up.**
        // A plain `.onTapGesture` has nothing to drive the press state from,
        // so the folder opened with no acknowledgement at all — on a phone
        // the only thing standing in for a cursor is the thing you touched
        // moving under your finger.
        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 12) {
            HapticsEngine.lightTap()
            onCustomise()
        } onPressingChanged: { down in
            pressed = down
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticsEngine.lightTap()
                onOpen()
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.title()), \(day.countLabel)")
        .accessibilityHint(day.isToday ? "Opens today's wins" : "Opens this day's wins")
        .accessibilityAddTraits(.isButton)
    }
}
