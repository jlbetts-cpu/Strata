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
            let shape = UnevenRoundedRectangle(topLeadingRadius: GridConstants.cornerRadius,
                                               topTrailingRadius: GridConstants.cornerRadius, style: .continuous)
            shape
                .fill(WarmBackground.top)
                .overlay(alignment: .top) {
                    shape.strokeBorder(TipCard.hairline, lineWidth: 1)
                        .mask(alignment: .top) { Rectangle().frame(height: GridConstants.cornerRadius * 2) }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: -lift)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in lift = max(0, min(-value.translation.height, 60)) * 0.5 }
                .onEnded { value in
                    let up = -value.translation.height
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { lift = 0 }
                    if up > Self.opensAt { HapticsEngine.lightTap(); open(.reading) }
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
    @State private var pull: CGFloat = 0

    /// The tower kept in view above the open drawer.
    private static var towerBand: CGFloat { 150 }
    /// Part way: about three fifths of the room.
    private static var partway: CGFloat { 560 }

    var body: some View {
        GeometryReader { geo in
            let room = geo.size.height
            let open = full ? room : min(Self.partway, max(room - Self.towerBand, 240))
            VStack(spacing: 0) {
                Capsule()
                    .fill(AppColors.inkTertiary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { pull = $0.translation.height }
                            .onEnded { value in
                                let dy = value.translation.height
                                withAnimation(reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.3)) {
                                    pull = 0
                                    if dy < -60 { full = true }
                                    else if dy > 80 { if full { full = false } else { isOpen = false } }
                                }
                                if abs(dy) > 60 { HapticsEngine.lightTap() }
                            })
                    .accessibilityElement()
                    .accessibilityLabel(full ? "Show Less of the Chat" : "Show All of the Chat")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { withAnimation(GridConstants.motionSnappy) { full.toggle() } }
                content()
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            // **Pinned to the top** (seen frame by frame, 2026-10-14): centred,
            // the chat measured short for a moment mid-slide and sat 100pt
            // below the panel's edge, a dark band between them.
            .frame(height: max(open - pull, 200), alignment: .top)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: GridConstants.cornerRadius,
                                       topTrailingRadius: GridConstants.cornerRadius, style: .continuous)
                    .fill(WarmBackground.top)
                    .overlay(alignment: .top) {
                        // Chrome separates with a hairline, never a shadow.
                        UnevenRoundedRectangle(topLeadingRadius: GridConstants.cornerRadius,
                                               topTrailingRadius: GridConstants.cornerRadius, style: .continuous)
                            .strokeBorder(TipCard.hairline, lineWidth: 1)
                            .mask(alignment: .top) { Rectangle().frame(height: GridConstants.cornerRadius * 2) }
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: GridConstants.cornerRadius,
                                              topTrailingRadius: GridConstants.cornerRadius, style: .continuous))
            .frame(maxHeight: .infinity, alignment: .bottom)
            // **Kept built, below the screen, when it is down** (2026-10-14):
            // the whole panel slides both ways on one curve instead of being
            // made at the moment it is asked for. On the panel, its ground
            // and all: on the contents alone the ground stayed behind.
            .offset(y: isOpen ? 0 : open + 60)
        }
        .allowsHitTesting(isOpen)
        .accessibilityHidden(!isOpen)
        .animation(reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.36), value: isOpen)
        .animation(reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.3), value: full)
        .onChange(of: isOpen) { _, open in if !open { full = false } }
    }
}
