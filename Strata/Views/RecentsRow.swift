import SwiftUI

/// Where each folder is on screen, so opening one can start from it rather
/// than from nowhere. See `HomeView.openAnchor`.
struct FolderFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// The coordinate space the frames above are measured in. Named rather than
/// `.global`, because a named space is the page and `.global` is the device:
/// the same folder would report a different rect under a status bar of a
/// different height.
///
/// A plain constant rather than an extension on `CoordinateSpace`: the
/// `.coordinateSpace(_:)` modifier and `frame(in:)` take a
/// `NamedCoordinateSpace`, which is a different type, and an extension on
/// one does not reach the other.
enum HomeSpace {
    static let name = "apollo.home"
    static let space: NamedCoordinateSpace = .named(HomeSpace.name)
}

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

    /// **A day with nothing in it does not get a nought.**
    ///
    /// "0 wins" is a score, and a score of zero is a mark against you. This
    /// app's whole position is that state changes because somebody did
    /// something, never because they did not — so the empty folder says what
    /// is true and nothing more. Today's folder starts here every morning.
    var countLabel: String {
        switch count {
        case 0: return "Nothing yet"
        case 1: return "1 win"
        default: return "\(count) wins"
        }
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
    /// The day's cut-out, when there is one. See `DayStickerService`.
    var stickers: (String) -> UIImage? = { _ in nil }
    var onOpen: (RecentDay) -> Void = { _ in }
    var onCustomise: (RecentDay) -> Void = { _ in }

    /// The width of one folder tile at the default text size.
    ///
    /// 150 on a 393pt screen leaves the third folder cut off at the right
    /// edge by about a third of its width, which is the amount that reads as
    /// "this scrolls" without looking like a layout accident. Measured
    /// rather than guessed: at 132 four fit with a sliver and the row reads
    /// as a grid that failed; at 168 only two fit and there is no hint.
    ///
    /// **It went to 196 for one build and came straight back.** I had read
    /// "make Recents carry the page" as "make the folders bigger", and the
    /// owner's answer was the correct one: "there will be more, don't change
    /// the size of anything, I just want you to refine it." Sizing a section
    /// up to fill a page it is not meant to fill is a decision that has to be
    /// undone the moment the next section lands.
    static let tileWidth: CGFloat = 150

    /// **It grows with Dynamic Type.** Two lines of text sit under every
    /// folder, and at an accessibility size they were being truncated inside
    /// a frame that could not move — "Yesterday" became "Yester…" on a screen
    /// with nothing else on it. `@ScaledMetric` ties the tile to the body
    /// size, so the folder and its label grow together and the row simply
    /// scrolls further. Capped at 1.6x: past that the folder stops fitting
    /// beside its neighbour and the row is one folder at a time, which is
    /// worse than a slightly tight label.
    @ScaledMetric(relativeTo: .body) private var scaledTile: CGFloat = RecentsRow.tileWidth
    private var tile: CGFloat { min(scaledTile, RecentsRow.tileWidth * 1.6) }

    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        #if DEBUG
        PerfProbe.count("RecentsRow")
        #endif
        return VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            // **On the camera's margin, not the page's old one.**
            //
            // The owner: "make sure everything aligns with the grid set with
            // the camera that we took long to build." The camera's chrome
            // sits on `gapWide` (24) — its controls row, its look tray and
            // its review all do — and so does the inside of a folder. Home
            // was on `horizontalPadding` (16), which is the margin the tower
            // grid used, and the tower is gone. Measured: the section label
            // and the first folder both start 8pt further in now, and line up
            // with the shutter row you see when you switch tabs.
            Text("Recents")
                .font(Typography.sectionSerif)
                // The same correction, scaled: a third of the title's size
                // takes about a third of its tightening.
                .tracking(-0.2)
                .foregroundStyle(AppColors.inkPrimary)
                .padding(.horizontal, GridConstants.gapWide)

            ScrollView(.horizontal, showsIndicators: false) {
                // **Eager, and that is the measured choice rather than the
                // lazy default.**
                //
                // `LazyHStack` looks obviously right here — fourteen folders,
                // two on screen, each carrying a live `ultraThinMaterial` —
                // and it made the scroll worse. Measured with
                // `-strataPerfProbe` over an identical drag: eager had a
                // worst display-link gap of 59ms, lazy had 221ms and 164ms.
                //
                // Lazy does not remove the work, it MOVES it: a folder is
                // built, its stack rasterised and its material created at the
                // moment it scrolls into view, which is the one moment a
                // finger is on the glass. Eager pays for all fourteen once,
                // at launch, where nothing is moving. At a fortnight's worth
                // that is the right trade; if Recents ever reaches into
                // months, it stops being, and this note is the reason to
                // re-measure rather than assume.
                HStack(alignment: .top, spacing: GridConstants.gapItem) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        DayFolderTile(day: day,
                                      style: styles(day.id),
                                      sticker: stickers(day.id),
                                      onOpen: { onOpen(day) },
                                      onCustomise: { onCustomise(day) })
                            .frame(width: tile)
                            // **They arrive, once.**
                            //
                            // The row appeared fully formed, which is correct
                            // and says nothing. A short stagger from the left
                            // does two things: it reads the row in the order
                            // it should be read, newest first, and it makes
                            // the shelf feel like objects being set down
                            // rather than an image loading.
                            //
                            // Capped at four steps, so a fortnight of folders
                            // does not take half a second to finish, and only
                            // on the first appearance — a stagger that
                            // replays every time you come back from the
                            // camera is a tax on the thing you do most.
                            .opacity(arrived ? 1 : 0)
                            .offset(y: arrived ? 0 : 14)
                            .animation(.spring(response: 0.48, dampingFraction: 0.86)
                                .delay(Double(min(index, 4)) * 0.045),
                                value: arrived)
                    }
                }
                // **Snapping, and it is the right kind.** A free-scrolling
                // shelf leaves a folder half off the screen wherever the
                // finger happened to stop, which on a row of six objects
                // reads as sloppy rather than as free. `.viewAligned` rests
                // on a folder's own edge, so the row always looks composed
                // when it stops — and because a flick can still cross
                // several, it costs nothing in speed.
                .scrollTargetLayout()
                // **Padding inside the scroll view, not outside it.**
                // Outside, the row's own edges clip the folders before they
                // reach the screen's, so a folder fades out 20pt early and
                // the shadow is cut off square. Inside, content starts on the
                // page's margin and scrolls all the way to the bezel.
                .padding(.horizontal, GridConstants.gapWide)
                // Room for the folders' shadows, which fall outside their
                // frames and were being clipped flat by the scroll view.
                .padding(.vertical, 10)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .onAppear {
                guard !arrived else { return }
                if reduceMotion { arrived = true; return }
                // One hop, so the first frame is drawn before the springs
                // start. Setting it inside `onAppear` directly makes the
                // whole row animate from its initial state on the same frame
                // it is created, which SwiftUI resolves as no animation.
                Task { @MainActor in arrived = true }
            }
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
    var sticker: UIImage? = nil
    var onOpen: () -> Void = {}
    var onCustomise: () -> Void = {}

    var body: some View {
        #if DEBUG
        PerfProbe.count("DayFolderTile")
        #endif
        return Button(action: onOpen) { label }
            // **A real `Button`, not a hand-rolled gesture pair.**
            //
            // This was an `onLongPressGesture` for the press state with a
            // simultaneous `TapGesture` for the open, which is two gesture
            // recognisers arguing over one finger: a tap that drifted a few
            // points did nothing at all, and the scale did not always come
            // back on a cancelled touch. A `Button` with a `ButtonStyle` gets
            // touch-down, drag-off, cancel and the accessibility traits from
            // the system, which is four behaviours nobody has to write.
            .buttonStyle(FolderPress())
            // **A context menu rather than a secret long press.**
            //
            // Holding a folder opened the customise sheet with nothing on
            // screen to say so, which is a feature that exists only for
            // whoever was told about it. A context menu is the same gesture
            // and the platform's own answer: it lifts the folder, blurs the
            // page behind it and names what it can do.
            .contextMenu {
                Button {
                    onCustomise()
                } label: {
                    Label("Change the folder", systemImage: "paintpalette")
                }
            }
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: FolderFrames.self,
                        value: [day.id: geo.frame(in: HomeSpace.space)])
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.title()), \(day.countLabel)")
            .accessibilityHint(day.isToday ? "Opens today's wins" : "Opens this day's wins")
    }

    private var label: some View {
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
                      isAlive: day.isToday,
                      sticker: sticker,
                      stickerSeed: day.id)

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
        .contentShape(Rectangle())
    }
}

/// **How a folder answers a finger.**
///
/// Scale alone is the cheap version and it reads as a button. A folder is an
/// object on a page, so it does what an object does when you press it: it
/// goes down a little AND its shadow tightens, because the shadow is the gap
/// between it and the page and pressing closes the gap. The shadow is on the
/// folder itself, so what this can reach is the scale and the tiny drop —
/// together they are enough for the eye to read contact.
///
/// A haptic on the way DOWN, not on the action. A tap that fires its haptic
/// when the finger lifts feels like a confirmation; one that fires on contact
/// feels like touching something.
struct FolderPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.spring(response: 0.26, dampingFraction: 0.72),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticsEngine.lightTap() }
            }
    }
}
