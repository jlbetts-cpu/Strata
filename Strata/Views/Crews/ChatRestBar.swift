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
    /// Open the chat; true when the field was what was pressed.
    var open: (_ writing: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lift: CGFloat = 0
    private var store: SocialStore { SocialStore.shared }

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
            Button { HapticsEngine.lightTap(); open(false) } label: {
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

            Button { HapticsEngine.lightTap(); open(true) } label: {
                Text(CrewChatWords.placeholder)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, GridConstants.gapItem)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(AppColors.quietFill))
                    .contentShape(Capsule())
            }
            .buttonStyle(.press)
            .accessibilityLabel("Write a message")
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapTight)
        .background {
            // The page's own glass, edge to edge, rounded only where it meets
            // the tower: a drawer pulled up from the foot of the screen.
            UnevenRoundedRectangle(topLeadingRadius: GridConstants.cornerRadius,
                                   topTrailingRadius: GridConstants.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: -lift)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in lift = max(0, min(-value.translation.height, 60)) * 0.5 }
                .onEnded { value in
                    let up = -value.translation.height
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { lift = 0 }
                    if up > Self.opensAt { HapticsEngine.lightTap(); open(false) }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open the chat") { open(false) }
    }

    /// The newest line as the Crews list says it ("Sam: see you at 6",
    /// "Sam sent a strip"), or the empty chat's own words.
    private var latestLine: String {
        guard let last = store.messages(in: crewID).last else { return CrewChatWords.quiet }
        let crew = store.crew(crewID)
        return CrewActivity.message(last).preview(name: { id in
            crew?.members.first { $0.profileID == id }?.shortName ?? "A friend"
        }, me: store.me)
    }
}

/// The chat's words that the resting bar shares with the thread.
enum CrewChatWords {
    static let placeholder = "Message"
    static let quiet = "Quiet here. Yet."
}
