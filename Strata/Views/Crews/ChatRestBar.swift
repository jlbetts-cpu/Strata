import ImageIO
import SwiftUI

/// **The crew's chat, at rest, under its tower** (the owner, 2026-10-13: the
/// chat merged into the crew tower, "a pull-up drawer", his pick; the shape
/// is `docs/qol-research-2026-10-13.md` M9).
///
/// Two heights and nothing between. At rest, this: a grabber, the newest
/// line with the ink dot while it is new to you, and the field. Open, the
/// whole thread (`CrewChatSheet`), rising from here. A tap on the line, a
/// drag up, or starting to write opens it; writing is done with the
/// conversation in view. The dot is cleared by opening, not by this line
/// showing: at rest you have read one line at most.
///
/// It replaces the bubble button that stood top right: the chat's dot is
/// now where the eye already is.
struct ChatRestBar: View {
    let crewID: CrewID
    /// Open the chat, part way up: to read, to write, or with the + row out.
    var open: (_ how: Opening) -> Void

    enum Opening: Equatable { case reading, writing, choice(ChatPlusRow.Choice) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lift: CGFloat = 0
    private var store: SocialStore { SocialStore.shared }
    /// A line started in the chat and not sent: shown in the field here, as
    /// Messages keeps a draft under a conversation.
    private var draft: String { CrewDrafts.chat(crewID) }

    /// Far enough up that it was meant; the sheet takes it from there.
    private static let opensAt: CGFloat = 36

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("ChatRestBar")
        #endif
        // Not when the newest line is yours: you have seen what came before
        // it, and the dot stood alone on the left beside your own bubble.
        let unread = store.unreadChats.contains(crewID) && store.messages(in: crewID).last?.senderProfileID != store.me
        VStack(spacing: GridConstants.gapTight) {
            Capsule()
                .fill(AppColors.inkTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, GridConstants.gapTight)
                .accessibilityHidden(true)
            Button { HapticsEngine.lightTap(); open(.reading) } label: {
                HStack(spacing: GridConstants.gapTight) {
                    if unread {
                        NewsDot().transition(NewsDot.transition(reduceMotion: reduceMotion))
                    }
                    latest
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .animation(NewsDot.motion(reduceMotion: reduceMotion), value: unread)
            .accessibilityLabel("Chat, \(latestLine)")
            .accessibilityValue(unread ? "New messages" : "")
            .accessibilityHint("Opens today's chat.")

            // **The chat's own composer, as it stands in the chat** (the
            // owner, 2026-10-14: "when i would type in message there wasnt
            // like the + button or send on that message preview bar"): the
            // +, the field and Send, so the bar is the foot of the chat
            // before it rises. Each opens the chat part way, doing its job.
            HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                if store.canReply() {
                    ChatPlusMenu(choices: store.photosAllowed() ? ChatPlusRow.Choice.offered
                                                                : ChatPlusRow.Choice.withoutPhotos) { choice in
                        open(.choice(choice))
                    }
                    // A tap on the field itself, not a Button round glass:
                    // wrapped in a Button, the glass took the press and the
                    // chat never opened (walked, 2026-10-14).
                    Text(draft.isEmpty ? CrewChatWords.placeholder : draft)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(draft.isEmpty ? AppColors.inkTertiary : AppColors.inkPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GridConstants.gapLabel)
                        .frame(minHeight: GlassIconButton.defaultSide)
                        // The chat's own field (`glassField`), so opening is
                        // one field rising.
                        .glassField()
                        .contentShape(Rectangle())
                        .onTapGesture { HapticsEngine.lightTap(); open(.writing) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Write a message")
                        .accessibilityAction { open(.writing) }
                    GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send") {
                        open(.writing)
                    }
                    .disabled(draft.isEmpty)
                } else {
                    Text("Writing here is off on this phone.")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: GlassIconButton.defaultSide)
                }
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        // Low, where the system's own bars sit (`GridConstants.barSink`),
        // and where the chat's field is when it rises.
        .modifier(BarSink())
        .background {
            // **The chat's own ground, edge to edge**, rounded only where it
            // meets the tower and set off by a hairline (the owner,
            // 2026-10-14: "on dark mode the chat around it is too bright ...
            // in the chat is dark I like that"). It was a light material.
            let shape = UnevenRoundedRectangle(topLeadingRadius: GridConstants.panelRadius,
                                               topTrailingRadius: GridConstants.panelRadius, style: .continuous)
            shape
                .fill(WarmBackground.top)
                .overlay(alignment: .top) {
                    shape.strokeBorder(TipCard.hairline, lineWidth: 1)
                        .mask(alignment: .top) { Rectangle().frame(height: GridConstants.panelRadius) }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: -lift)
        .gesture(
            // On the screen: the bar lifts under the finger, and in its own
            // space the drag chased itself.
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in lift = max(0, min(-value.translation.height, 60)) * 0.5 }
                .onEnded { value in
                    // Where it was thrown, not where it was let go: a flick
                    // opens. Opening, the bar stays lifted until the drawer
                    // has risen over it; springing it down as the drawer came
                    // up was two things moving opposite ways (fix 9).
                    if -value.predictedEndTranslation.height > Self.opensAt {
                        HapticsEngine.lightTap()
                        open(.reading)
                        Task { try? await Task.sleep(for: .milliseconds(400)); lift = 0 }
                    } else {
                        withAnimation(GridConstants.drawerMove) { lift = 0 }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open the chat") { open(.reading) }
    }

    /// **The newest line as the chat draws it** (the owner, 2026-10-14:
    /// "when collapsed the notification of last sent message lacks all
    /// flavor and look of the app"): a friend's head beside their bubble on
    /// the quiet fill, or your own in ink on the right, one line long, so the
    /// bar is the foot of the conversation it opens.
    ///
    /// **Every kind of line as itself** (2026-10-15, the owner: "everything
    /// that can be in that chat needs to be tested to the max"): a win said
    /// in the chat is its block and its title, a photo or a strip is its
    /// picture, a sticker is the sticker, a plan is what was planned. **A
    /// run of lines from one person stacks** behind the newest, as the Lock
    /// Screen stacks a run of notifications, so three texts in a row read as
    /// three without three rows.
    @ViewBuilder
    private var latest: some View {
        let lines = store.messages(in: crewID)
        if let last = lines.last {
            let mine = last.senderProfileID == store.me
            let crew = store.crew(crewID)
            let run = min(3, lines.reversed().prefix { $0.senderProfileID == last.senderProfileID }.count)
            HStack(alignment: .center, spacing: GridConstants.gapTight) {
                if mine { Spacer(minLength: GridConstants.gapWide) }
                if !mine, let crew, let member = crew.member(last.senderProfileID) {
                    CrewFace(member: member, crew: crew.id, me: store.me, side: Self.faceSide)
                }
                RestLine(line: last, mine: mine, run: run, win: winSaid(in: last))
                if !mine { Spacer(minLength: GridConstants.gapWide) }
            }
        } else {
            Text(CrewChatWords.quiet)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The win a line says, when the line is a win said in the chat.
    private func winSaid(in line: CrewMessage) -> SharedWin? {
        guard store.isWinLine(line), let id = line.quoteWinID else { return nil }
        return store.wins(in: crewID).first { $0.winID == id }
    }

    /// The thread's own face size.
    private static let faceSide: CGFloat = 28

    /// The newest line as the Crews list says it ("Sam: see you at 6",
    /// "Sam sent a strip"), or the empty chat's own words.
    private var latestLine: String {
        guard let last = store.messages(in: crewID).last else { return CrewChatWords.quiet }
        let crew = store.crew(crewID)
        return CrewActivity.message(last).preview(name: { id in
            // "A friend" for an unnamed one, as the Crews list says it.
            let name = crew?.members.first { $0.profileID == id }?.shortName ?? ""
            return name.isEmpty ? "A friend" : name
        }, me: store.me)
    }
}

/// The chat's words that the resting bar shares with the thread.
enum CrewChatWords {
    static let placeholder = "Message"
    /// **Says what is true** (the owner, 2026-10-16: a note that "quiet
    /// here. yet" doesn't make sense). The chat clears at midnight, so an
    /// empty one is a day with no messages yet, and it says so.
    static let quiet = "No messages today"
}

/// **The chat, risen from its resting bar** (the owner, 2026-10-14: "it felt
/// like it was taking me to another screen rather than just popping up
/// enough to see the chat"; and of the system's part-height sheet, "there is
/// a weird curve at the bottom").
///
/// A panel of the crew's own page, not a sheet: flush with the bottom of the
/// screen, its top corners rounded where it meets the tower, the tower
/// still there above it. Part way up by default; the grabber takes it to the
/// whole height or back down. With the keyboard up it stands on the
/// keyboard and keeps a band of the tower in view. Dark on dark: the chat's
/// own ground, never a lighter material.
struct ChatDrawer<Content: View>: View {
    @Binding var isOpen: Bool
    /// Where the resting bar's top edge is on screen, so the drawer starts
    /// from it and comes back to it: one panel, not two.
    var restTop: CGFloat = 0
    /// True from the moment the drawer starts to rise until it has come back
    /// down into the bar: the caller hides the resting bar under it.
    @Binding var covering: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var full = false
    /// Whether it was whole before the keyboard took it there, so the keys
    /// going put it back where it was.
    @State private var fullBeforeKeys: Bool?
    /// How far the keys stand over the foot of the screen. The drawer does
    /// not shrink for them (it ignores the keyboard); the chat inside is
    /// lifted by this, on the keys' pace, so the field rides on top of them.
    /// Shrinking the whole drawer with the room left the chat drawn below
    /// where it was laid out, the field under the keys (filmed, 2026-10-14).
    @State private var keysOver: CGFloat = 0
    /// How far the finger has the edge from where it rests: down is
    /// positive and 1:1, up is held back by `rubber`.
    @State private var pull: CGFloat = 0

    /// The tower kept in view above the open drawer.
    private static var towerBand: CGFloat { 150 }
    /// Part way: about three fifths of the room.
    private static var partway: CGFloat { 560 }
    /// The ground runs on this far under the panel, past the safe area,
    /// where the field sinks toward the home indicator.
    private static var groundBelow: CGFloat { 160 }

    /// The chat's field took or left the keyboard.
    private func writing(_ now: Bool) {
        if now {
            guard isOpen, fullBeforeKeys == nil else { return }
            fullBeforeKeys = full
            withAnimation(GridConstants.keyboard) { full = true }
        } else {
            guard let was = fullBeforeKeys else { return }
            fullBeforeKeys = nil
            if isOpen { withAnimation(GridConstants.keyboard) { full = was } }
        }
    }

    /// A pull past where it can go, given less and less: never a wall.
    static func rubber(_ distance: CGFloat, limit: CGFloat = 70) -> CGFloat {
        guard distance > 0 else { return 0 }
        return limit * (1 - 1 / (distance / limit * 0.55 + 1))
    }

    /// **One drawer, the bar grown tall** (the owner, 2026-10-14: "right now
    /// it kinda feels like not even the same drawer ... one drawer at the
    /// bottom and one when you click into it ... it needs to feel like the
    /// same exact drawer"). The open chat slid up from under the screen over
    /// the resting bar, a second panel. Now it starts exactly where the bar
    /// is, with the bar's ground, grabber and newest line, and its top edge
    /// rises while the field stays under the thumb; closing, the edge comes
    /// back down into the bar. The chat inside is laid out once at its open
    /// height and uncovered from the foot up, so the rise costs no layout
    /// (the probe measured a 148ms frame on opening when it was resized).
    var body: some View {
        GeometryReader { geo in
            let room = geo.size.height
            let part = min(Self.partway, max(room - Self.towerBand, 240))
            let open = full ? room : part
            let rest = max(0, min(open, geo.frame(in: .global).maxY - restTop))
            let edge = isOpen ? open : rest
            let shown = max(rest * 0.5, edge - (pull > 0 ? pull : -Self.rubber(-pull)))
            DrawerPanel(shown: shown, open: open, groundBelow: Self.groundBelow,
                        content: {
                            content()
                                .environment(\.chatDrawerFull, full)
                                .environment(\.chatDrawerWriting, ChatDrawerWriting(writing))
                                .padding(.bottom, max(0, keysOver - geo.safeAreaInsets.bottom))
                        }) {
                // The grabber rides the top edge.
                Capsule()
                    .fill(AppColors.inkTertiary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .contentShape(Rectangle())
                    .gesture(drag(room: room, part: part))
                    .accessibilityElement()
                    .accessibilityLabel(full ? "Show Less of the Chat" : "Show All of the Chat")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { withAnimation(GridConstants.drawerMove) { full.toggle() } }
            }
            // **Exactly the room, never more.** With `maxHeight: .infinity` a
            // panel taller than the room (the whole height plus the ground
            // run on below it) grew the frame and was pushed down by that
            // ground, 160 points, the field under the keys (measured,
            // 2026-10-14).
            .frame(width: geo.size.width, height: room, alignment: .bottom)
            .opacity(covering ? 1 : 0)
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screen = UIScreen.main.bounds.height
            withAnimation(GridConstants.keyboard) { keysOver = max(0, screen - end.minY) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(GridConstants.keyboard) { keysOver = 0 }
        }
        .allowsHitTesting(isOpen)
        .accessibilityHidden(!isOpen)
        .animation(GridConstants.drawerMove, value: isOpen)
        .animation(GridConstants.drawerMove, value: full)
        // **Writing takes the whole screen** (the owner, 2026-10-14: "its
        // okay for the main chat to go full screen and then the name appear
        // ... if its becoming too cramped"). Part way up with the keys under
        // it, the thread was a sliver; the keys going put it back.
        // From the chat's own field only (`chatDrawerWriting`): a sheet over
        // the chat raising its keyboard took the chat behind it to the whole
        // height too (walked, 2026-10-14).
        .onChange(of: isOpen) { _, open in
            if open {
                // Over the bar before the first frame of the rise.
                covering = true
            } else {
                full = false
                fullBeforeKeys = nil
                pull = 0
                // Back to the bar once the edge has come down into it.
                Task { @MainActor in
                    try? await Task.sleep(for: GridConstants.drawerLands)
                    if !isOpen { covering = false }
                }
            }
        }
    }

    /// **The grabber, as a sheet's**: the edge follows the finger, and where
    /// it lands is decided from where it was thrown, the nearest of shut,
    /// part way and whole, with the throw's speed carried into the settle.
    private func drag(room: CGFloat, part: CGFloat) -> some Gesture {
        // On the screen: the grabber moves with the finger, and measured in
        // its own space the drag chased itself (walked, 2026-10-14).
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                withAnimation(GridConstants.drawerFollow) { pull = value.translation.height }
            }
            .onEnded { value in
                let thrown = value.predictedEndTranslation.height
                let top = (full ? 0 : room - part) + thrown
                let rests: [(CGFloat, Int)] = [(0, 2), (room - part, 1), (room, 0)]
                let landing = rests.min { abs($0.0 - top) < abs($1.0 - top) }?.1 ?? 1
                let was = full ? 2 : 1
                withAnimation(GridConstants.drawerMove) {
                    pull = 0
                    switch landing {
                    case 2: full = true
                    case 0: isOpen = false
                    default: full = false
                    }
                }
                if landing != was { HapticsEngine.lightTap() }
            }
    }
}

/// **The drawer's panel, given its edge every frame.** `shown` is the
/// animated value: SwiftUI interpolates it and draws the ground, the
/// uncovered chat and the grabber from it on each frame. Frames and masks
/// computed inside a `GeometryReader` from a changed state jumped to their
/// end in one frame (filmed, 2026-10-14, opening and closing alike); as an
/// `Animatable` view it is handed every step, logged at 96, 205, 337, 408,
/// 463, 518, 549 and 560 points over the rise.
private struct DrawerPanel<Content: View, Grabber: View>: View, Animatable {
    var shown: CGFloat
    /// The chat's own height, animated with the edge: when the keyboard
    /// changed the room, the edge glided and the chat jumped, and with the
    /// keys up the open chat came apart (filmed, 2026-10-14).
    var open: CGFloat
    let groundBelow: CGFloat
    @ViewBuilder let content: () -> Content
    @ViewBuilder let grabber: () -> Grabber

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shown, open) }
        set { shown = newValue.first; open = newValue.second }
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: GridConstants.panelRadius,
                                           topTrailingRadius: GridConstants.panelRadius, style: .continuous)
        ZStack(alignment: .bottom) {
            // The ground, the panel's own height, on past the foot.
            shape
                .fill(WarmBackground.top)
                .overlay(alignment: .top) {
                    // Chrome separates with a hairline, never a shadow.
                    shape.strokeBorder(TipCard.hairline, lineWidth: 1)
                        .mask(alignment: .top) { Rectangle().frame(height: GridConstants.panelRadius) }
                }
                .frame(height: shown + groundBelow)
                .offset(y: groundBelow)
            // The chat at its open height, uncovered from the foot up: a
            // window whose height moves over a chat that does not, clipped by
            // a plain rounded rectangle (layer bounds and a corner, cheap to
            // draw each frame) rather than an alpha mask, which redrew the
            // whole chat and its glass on every frame of the rise.
            content()
                .padding(.top, 22)
                .frame(height: open, alignment: .top)
                .padding(.bottom, groundBelow)
                .frame(height: shown + groundBelow, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: GridConstants.panelRadius, style: .continuous))
                .offset(y: groundBelow)
            grabber()
                .offset(y: -(shown - 22))
        }
    }
}

/// Whether the chat drawer is at the whole height: its title names the crew
/// there, where the crew's own header is covered.
private struct ChatDrawerFullKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var chatDrawerFull: Bool {
        get { self[ChatDrawerFullKey.self] }
        set { self[ChatDrawerFullKey.self] = newValue }
    }
}

/// The chat telling its drawer that its own field took or left the keyboard.
struct ChatDrawerWriting {
    let call: (Bool) -> Void
    init(_ call: @escaping (Bool) -> Void) { self.call = call }
    func callAsFunction(_ now: Bool) { call(now) }
}

private struct ChatDrawerWritingKey: EnvironmentKey {
    static let defaultValue = ChatDrawerWriting { _ in }
}

extension EnvironmentValues {
    var chatDrawerWriting: ChatDrawerWriting {
        get { self[ChatDrawerWritingKey.self] }
        set { self[ChatDrawerWritingKey.self] = newValue }
    }
}

/// **The native chat, resting** (`CrewChatSheet` in the crew's own sheet,
/// 2026-10-15): at its smallest height it is the newest line and the
/// composer, nothing above them.
private struct ChatAtRestKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var chatAtRest: Bool {
        get { self[ChatAtRestKey.self] }
        set { self[ChatAtRestKey.self] = newValue }
    }
}

/// **One line of the chat, at the resting bar's size**: the bubble the
/// thread draws, cut to one line, and whatever the line carries.
private struct RestLine: View {
    let line: CrewMessage
    let mine: Bool
    /// How many lines in a row, this one included, came from this person.
    let run: Int
    let win: SharedWin?

    @Environment(\.displayScale) private var displayScale
    @State private var picture: UIImage?

    private static let thumb: CGFloat = 26
    private static let stickerSide: CGFloat = 34

    private var isSticker: Bool {
        line.isSticker
    }

    var body: some View {
        Group {
            if isSticker {
                // A sticker is its own shape, never in a bubble.
                pictureView(side: Self.stickerSide, corner: 0, fit: true)
            } else {
                bubble
            }
        }
        .task(id: line.sketch) { await load() }
    }

    private var bubble: some View {
        HStack(spacing: GridConstants.gapTight) {
            if let win {
                // The win's own block, small, in its colour.
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(win.colour.style.baseColor)
                    .frame(width: 12, height: 12)
            } else if line.sketch != nil {
                pictureView(side: Self.thumb, corner: 6, fit: false)
            }
            Text(words)
                .font(Typography.bodyLarge)
                .foregroundStyle(mine ? AppColors.myLineInk : AppColors.inkPrimary)
                .lineLimit(1)
        }
        .padding(.leading, line.sketch != nil && win == nil ? GridConstants.spacing + 2 : GridConstants.gapItem)
        .padding(.trailing, GridConstants.gapItem)
        .padding(.vertical, GridConstants.spacing + 2)
        .frame(minHeight: 36)
        .background {
            let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
            shape.fill(mine ? AppColors.myLine : AppColors.quietFill)
                // The run, stacked behind: each one a little narrower and a
                // little higher, as notifications stack.
                .background(alignment: .top) {
                    ZStack(alignment: .top) {
                        ForEach(Array((1..<max(run, 1)).reversed()), id: \.self) { depth in
                            shape.fill(mine ? AppColors.myLine : AppColors.quietFill)
                                .opacity(depth == 1 ? 0.55 : 0.3)
                                .padding(.horizontal, CGFloat(depth) * 7)
                                .offset(y: -CGFloat(depth) * 4)
                        }
                    }
                }
        }
        .animation(GridConstants.motionSnappy, value: run)
    }

    /// What the bubble says.
    private var words: String {
        if let win { return win.title.isEmpty ? "A win" : win.title }
        if line.isStrip { return "Today's strip" }
        if let plan = line.groupPlan { return "Planned \(plan.title)" }
        if line.isPicture { return line.caption.isEmpty ? "Photo" : line.caption }
        let words = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.sketch != nil, words.isEmpty { return "Doodle" }
        return words.isEmpty ? "Something" : words
    }

    @ViewBuilder
    private func pictureView(side: CGFloat, corner: CGFloat, fit: Bool) -> some View {
        Group {
            if let picture {
                Image(uiImage: picture)
                    .resizable()
                    .aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                AppColors.quietFill
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    /// Small, off the main thread: the bar is on screen whenever the crew is.
    private func load() async {
        guard let url = line.sketch else { picture = nil; return }
        let pixels = Self.stickerSide * displayScale
        picture = await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceThumbnailMaxPixelSize: pixels * 2,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }
}
