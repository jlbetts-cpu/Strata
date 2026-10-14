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

    enum Opening { case reading, writing, plus }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lift: CGFloat = 0
    private var store: SocialStore { SocialStore.shared }
    /// A line started in the chat and not sent: shown in the field here, as
    /// Messages keeps a draft under a conversation.
    private var draft: String { CrewDrafts.chat(crewID) }

    /// Far enough up that it was meant; the sheet takes it from there.
    private static let opensAt: CGFloat = 36

    var body: some View {
        let unread = store.unreadChats.contains(crewID)
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
                    Text(latestLine)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(unread ? AppColors.inkPrimary : AppColors.inkSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    GlassIconButton(systemName: "plus", onPage: true, accessibilityLabel: "More to send") {
                        open(.plus)
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
    static let quiet = "Quiet here. Yet."
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
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var full = false
    /// How far the finger has the panel from where it rests: down is
    /// positive and 1:1, up is held back by `rubber`.
    @State private var pull: CGFloat = 0

    /// The tower kept in view above the open drawer.
    private static var towerBand: CGFloat { 150 }
    /// Part way: about three fifths of the room.
    private static var partway: CGFloat { 560 }
    /// The ground runs on this far under the panel, so a pull upward never
    /// shows a gap beneath it.
    private static var groundBelow: CGFloat { 160 }

    /// A pull past where it can go, given less and less: never a wall.
    static func rubber(_ distance: CGFloat, limit: CGFloat = 70) -> CGFloat {
        guard distance > 0 else { return 0 }
        return limit * (1 - 1 / (distance / limit * 0.55 + 1))
    }

    var body: some View {
        GeometryReader { geo in
            let room = geo.size.height
            let part = min(Self.partway, max(room - Self.towerBand, 240))
            let open = full ? room : part
            let shown = pull > 0 ? pull : -Self.rubber(-pull)
            let shape = UnevenRoundedRectangle(topLeadingRadius: GridConstants.panelRadius,
                                               topTrailingRadius: GridConstants.panelRadius, style: .continuous)
            VStack(spacing: 0) {
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
                content()
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            // **Moved, not resized** (the motion pass, 2026-10-14, fix 1):
            // its height changes only between part and whole. Resized under
            // the finger, the whole chat was laid out again every frame and
            // its lines slid inside the panel on the way down.
            .frame(height: open, alignment: .top)
            // Rounded where it meets the tower and open at the foot: the field
            // sinks toward the home indicator (`BarSink`), and a clip on the
            // whole panel cut its glass in half.
            .mask(alignment: .top) { shape.padding(.bottom, -Self.groundBelow) }
            .background(alignment: .top) {
                // Chrome separates with a hairline, never a shadow.
                shape
                    .fill(WarmBackground.top)
                    .overlay(alignment: .top) {
                        shape.strokeBorder(TipCard.hairline, lineWidth: 1)
                            .mask(alignment: .top) { Rectangle().frame(height: GridConstants.panelRadius) }
                    }
                    .padding(.bottom, -Self.groundBelow)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            // **Kept built, below the screen, when it is down** (2026-10-14):
            // the whole panel slides both ways on one curve, its ground and
            // all. Under Reduce Motion it fades where it stands (fix 8).
            .offset(y: reduceMotion ? 0 : (isOpen ? shown : open + 60))
            .opacity(reduceMotion && !isOpen ? 0 : 1)
        }
        .allowsHitTesting(isOpen)
        .accessibilityHidden(!isOpen)
        .animation(GridConstants.drawerMove, value: isOpen)
        .animation(GridConstants.drawerMove, value: full)
        .onChange(of: isOpen) { _, open in if !open { full = false; pull = 0 } }
    }

    /// **The grabber, as a sheet's**: the panel follows the finger, and
    /// where it lands is decided from where it was thrown, the nearest of
    /// shut, part way and whole, with the throw's speed carried into the
    /// settle (fix 2). Closing, the panel slides on from where the finger
    /// left it; it no longer grew back to its height while it left (fix 3).
    private func drag(room: CGFloat, part: CGFloat) -> some Gesture {
        // On the screen: the grabber moves with the finger now, and measured
        // in its own space the drag chased itself, so a slow pull read as a
        // throw (walked, 2026-10-14).
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                withAnimation(GridConstants.drawerFollow) { pull = value.translation.height }
            }
            .onEnded { value in
                let thrown = value.predictedEndTranslation.height
                // Where the panel's top would come to rest, measured down
                // from the top of the room.
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
