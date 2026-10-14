import SwiftUI

/// **What decides a friend's line is news on Wins** (the owner, 2026-10-13:
/// "chat notifications not noticeable, show message above tower").
///
/// Pure, so it can be tested without a store, a view or a clock. Fed every
/// line the crews' chats show (`SocialStore.messages(in:)`: today's, nobody
/// blocked, no muted crew) each time they change, it answers with the one
/// line to show, or nil:
///
/// - **Never the lines already there.** The first look only remembers what
///   it found: opening the app is not news about the morning's chat.
/// - **Only while you are on Wins**, with nothing over it. A line that comes
///   while you are elsewhere is remembered and never shown late: the Crews
///   tab's dot already says so.
/// - **Only a friend's, never your own**, and only one just said (two
///   minutes, the reach an open app gives its own alerts,
///   `CrewNotifications.reach`), so a fetch that brings in an hour of lines
///   at once does not replay them.
/// - **One at a time, the newest.** Several in one fetch show as the last.
nonisolated struct ChatBannerWatch: Equatable {
    private(set) var seen: Set<UUID> = []
    private(set) var started = false

    static let window: TimeInterval = 120

    mutating func arrived(_ lines: [CrewMessage], me: UUID, listening: Bool, now: Date) -> CrewMessage? {
        let fresh = lines.filter { !seen.contains($0.messageID) }
        seen.formUnion(fresh.map(\.messageID))
        guard started else {
            started = true
            return nil
        }
        guard listening else { return nil }
        return fresh
            .filter { $0.senderProfileID != me && now.timeIntervalSince($0.createdAt) < Self.window }
            .max { ($0.createdAt, $0.messageID.uuidString) < ($1.createdAt, $1.messageID.uuidString) }
    }
}

/// **Whether Wins is showing friends' lines itself.** Read by the
/// notification delegate: while it is, a chat alert is not shown as a
/// system banner too (the line comes in over the tower instead), and the
/// alert's arrival fetches the line at once. With the app closed, or on any
/// other screen, the system's notification is what you get, as before.
@MainActor
enum ChatBanner {
    static var isListening = false
}

/// **A friend's line, over your tower, for a moment** (the owner,
/// 2026-10-13: "chat notifications not noticeable, show message above
/// tower").
///
/// A small capsule slides in under the header: their face (`CrewFace`, as
/// they are drawn everywhere in Crews) and the line, in the crew list's own
/// words ("Sam: who's up for a walk", `CrewsListView.preview`). About four
/// seconds, then it goes. A tap opens that crew's chat in the Crews tab, as
/// the chat's notification does (`CrewRouter`); a swipe up puts it away.
///
/// **Quiet**: the page's still glass, no shadow (chrome separates with
/// glass, never elevation), no sound and no haptic of its own; the face and
/// the words are the only things on it. With Reduce Motion it fades in and
/// out where it stands.
struct WinsChatBanner: View {
    /// Wins is in front with nothing over it (`MainAppView.ringIsClear`).
    let isClear: Bool

    @State private var watch = ChatBannerWatch()
    @State private var shown: CrewMessage?
    @State private var hiding: Task<Void, Never>?
    @State private var lift: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long a line stays.
    static let holds: Duration = .seconds(4)
    static let faceSide: CGFloat = 28

    private var store: SocialStore { .shared }

    /// Every line the chats show now, muted crews left out, as their
    /// notifications are.
    private var lines: [CrewMessage] {
        guard CrewsFlag.isOn else { return [] }
        return store.crews.filter { !store.isMuted($0.id) }.flatMap { store.messages(in: $0.id) }
    }

    var body: some View {
        let lines = self.lines
        ZStack(alignment: .top) {
            if let shown, let crew = store.crew(shown.crewID), let member = crew.member(shown.senderProfileID) {
                banner(shown, crew: crew, member: member)
                    .offset(y: lift)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .id(shown.messageID)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, GridConstants.horizontalPadding)
        .onChange(of: lines.map(\.messageID), initial: true) {
            let listening = isClear && CrewsFlag.isOn
            if let line = watch.arrived(lines, me: store.me, listening: listening, now: Date()) {
                show(line)
            }
        }
        .onChange(of: isClear, initial: true) { _, clear in
            ChatBanner.isListening = clear && CrewsFlag.isOn
            if !clear { dismiss() }
        }
        .onDisappear { ChatBanner.isListening = false }
    }

    private func banner(_ line: CrewMessage, crew: Crew, member: CrewMember) -> some View {
        let words = CrewsListView.preview(.message(line), in: crew, me: store.me)
        let who = member.shortName.isEmpty ? "A friend" : member.shortName
        return Button { open(crew.id) } label: {
            HStack(spacing: GridConstants.gapTight) {
                CrewFace(member: member, crew: crew.id, me: store.me, side: Self.faceSide)
                said(words, who: who)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, GridConstants.gapTight / 2 + 2)
            .padding(.trailing, GridConstants.gapLabel)
            .padding(.vertical, GridConstants.gapTight / 2 + 2)
            // A 44pt target, whatever the line's size.
            .frame(minHeight: 44)
            .glassCapsule(onPage: true, interactive: false)
            .contentShape(Capsule())
        }
        .buttonStyle(.press)
        .simultaneousGesture(swipeUp)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(words)
        .accessibilityHint("Opens the chat.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open(crew.id) }
        .accessibilityAction(named: "Close") { dismiss() }
    }

    /// The name in the heading weight and the rest as said, as one line.
    private func said(_ words: String, who: String) -> Text {
        guard words.hasPrefix(who) else {
            return Text(words).font(Typography.screenSubtitle).foregroundStyle(AppColors.inkPrimary)
        }
        let name = Text(who).font(Typography.headerSmall)
        let rest = Text(String(words.dropFirst(who.count))).font(Typography.screenSubtitle)
        return Text("\(name)\(rest)").foregroundStyle(AppColors.inkPrimary)
    }

    /// Up and away; down gives a little and comes back.
    private var swipeUp: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let y = value.translation.height
                lift = y < 0 ? y : y * 0.2
            }
            .onEnded { value in
                if value.translation.height < -24 || value.predictedEndTranslation.height < -60 {
                    dismiss()
                } else {
                    withAnimation(GridConstants.cueIn) { lift = 0 }
                }
            }
    }

    private func show(_ line: CrewMessage) {
        hiding?.cancel()
        lift = 0
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cueIn) { shown = line }
        hiding = Task { @MainActor in
            try? await Task.sleep(for: Self.holds)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func dismiss() {
        hiding?.cancel()
        hiding = nil
        guard shown != nil else { return }
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cueOut) {
            shown = nil
        } completion: {
            lift = 0
        }
    }

    /// That crew's chat, in the Crews tab: the same three steps a tapped
    /// chat notification takes (`StrataAppDelegate`).
    private func open(_ crew: CrewID) {
        HapticsEngine.lightTap()
        dismiss()
        CrewRouter.shared.openWin = nil
        CrewRouter.shared.openChat = true
        CrewRouter.shared.open = crew
    }
}
