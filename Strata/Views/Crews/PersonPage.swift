import SwiftUI

/// **A person: their profile, and your conversation with them underneath**
/// (the owner's launch pass, item 3: "a person's profile is the whole
/// screen, and messages live in it, at the bottom, in a pull-up panel, the
/// same way the crew chat drawer sits at the foot of the crew tower ... There
/// is no separate DM inbox. The conversation with someone belongs to them").
///
/// The crew tower's sibling, built of the same parts: their profile where a
/// crew has its tower (`FriendProfileSheet`, embedded), today's line resting
/// at the foot (`ChatRestBar`), and the whole conversation rising from it as
/// the crew's chat rises (`CrewChatSheet`, native), with their name over it.
/// A small line at the top always says who this is. Before you have ever
/// written, the foot is a field that starts the conversation.
///
/// Underneath it is a two-person crew (`Crew.isPersonal`): sealed, paced,
/// checked and reported as every line is, with nothing new in iCloud.
struct PersonPage: View {
    let friend: UUID
    let onBack: () -> Void

    @State private var showsChat = false
    @State private var opening: ChatRestBar.Opening = .reading
    @State private var reportingPerson = false
    @State private var blockingPerson = false
    @State private var starting = false
    @State private var failed = false
    /// Their story, played over their page (the launch pass, 3½: "the story
    /// plays on top, their profile sits underneath").
    @State private var watching = false
    private var story: StoryPerson? {
        store.storyPeople().first { $0.profileID == friend && $0.phase == .open }
    }
    private var store: SocialStore { SocialStore.shared }

    /// Who they are, as the crew you share names them.
    private var member: CrewMember? {
        guard !store.blocked.contains(friend) else { return nil }
        // A crew you share first; failing that, your conversation, which
        // names them too (the second reader, 2026-10-17).
        return store.groupCrews.lazy.compactMap { $0.member(friend) }.first
            ?? store.personalCrew(with: friend)?.member(friend)
    }
    private var shared: CrewID? { store.groupCrews.first { $0.member(friend) != nil }?.id }
    /// Your conversation with them, if there is one yet.
    private var thread: CrewID? {
        guard let crew = store.personalCrew(with: friend), store.directFriend(crew.id) != nil else { return nil }
        return crew.id
    }
    private var name: String {
        let short = member?.shortName ?? ""
        return short.isEmpty ? "A friend" : short
    }

    var body: some View {
        Group {
            if let member, let shared {
                FriendProfileSheet(member: member, crewID: shared, embedded: true,
                                   story: story.map { tonight in (fresh: !tonight.watched, open: { watching = true }) })
                    .pinnedFoot { foot }
            } else {
                // **The conversation stays yours when the crew does not**
                // (the second reader, 2026-10-17): someone who leaves your
                // last shared crew took the whole thread out of reach, though
                // its row still listed and its messages still arrived.
                VStack {
                    Spacer()
                    EmptyPageLine(thread != nil ? "Not in a crew together now" : "Not in a crew with you now",
                                  icon: "person.crop.circle",
                                  detail: thread != nil ? "Your conversation is still here."
                                                        : "You can talk again once you share a crew.")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background { WarmBackground().ignoresSafeArea() }
                .pinnedFoot { if thread != nil { foot } }
            }
        }
        // **Our soft blur under the top, as every screen has** (the owner,
        // 2026-10-17): `pinnedBar` is a bar the scroll's edge fades under;
        // the plain inset it replaces left the page stark.
        .pinnedBar { top }
        .toolbar(.hidden, for: .navigationBar)
        .applying(thread != nil) { $0.modifier(CrewLiveSync(crewID: thread ?? CrewID(rawValue: ""))) }
        .onAppear {
            if let thread { store.markSeen(thread); CrewNotifications.visibleCrew = thread }
            // A tower's errands, never this page's (the review, 2026-10-16).
            CrewRouter.shared.openWin = nil
            if CrewRouter.shared.openChat, thread != nil {
                CrewRouter.shared.openChat = false
                opening = .reading
                showsChat = true
            }
            CrewRouter.shared.openChat = false
        }
        .onDisappear { if let thread, CrewNotifications.visibleCrew == thread { CrewNotifications.visibleCrew = nil } }
        .sheet(isPresented: $showsChat) {
            if let thread {
                CrewChatSheet(crewID: thread, startsWriting: opening == .writing,
                              startsWith: { if case .choice(let c) = opening { c } else { nil } }(),
                              visible: true, native: true, close: { showsChat = false },
                              reopen: { opening = .reading })
                    .environment(\.presentAside, .direct)
                    .environment(\.chatDrawerFull, true)
                    .environment(\.chatAtRest, false)
                    .presentationDetents(NativeChat.detents)
                    .presentationDragIndicator(.visible)
                    .presentationBackground { WarmBackground().ignoresSafeArea() }
            }
        }
        .onChange(of: showsChat) { _, up in NativeChatPresence.shared.up = up }
        // Blocked from inside the conversation: nothing left to show.
        .onChange(of: thread == nil) { _, gone in if gone { showsChat = false } }
        .fullScreenCover(isPresented: $watching) {
            if let story {
                StoryViewer(people: [story], start: story.profileID, onClose: { watching = false })
            }
        }
        .alert("That didn't start", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("They may need the latest Some Wins. Try again in a moment.")
        }
    }

    /// The way back and a small line that always says who this is. Their
    /// story is the ring on their head (`ProfileTop.story`).
    private var top: some View {
        VStack(spacing: GridConstants.gapTight) {
            topBar
        }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                GlassIconButton(systemName: "chevron.left", onPage: true, accessibilityLabel: "Back", action: onBack)
                Spacer(minLength: 0)
                // **Report and Block, on the person** (the App Store audit,
                // 2026-10-17, Guideline 1.2): their page had neither.
                // Reported where you share a crew; blocked in your conversation
                // when there is one, so a block never also removes them from a
                // group you run without saying so (the second reader).
                if let member, let crew = shared ?? thread {
                    Menu {
                        Button("Report", systemImage: "exclamationmark.bubble") { reportingPerson = true }
                        if !store.blocked.contains(friend) {
                            Button("Block", systemImage: "nosign", role: .destructive) { blockingPerson = true }
                        }
                    } label: {
                        GlassIconLabel(systemName: "ellipsis", tint: .primary, onPage: true)
                    }
                    .accessibilityLabel("Options for \(name)")
                    .confirmationDialog("Report \(name)?", isPresented: $reportingPerson, titleVisibility: .visible) {
                        ForEach(CrewSafety.Reason.allCases) { reason in
                            Button(reason.words) {
                                Task { _ = await CrewSafety.report(.person(member), in: crew, reason: reason) }
                            }
                        }
                    } message: {
                        Text("Their name, photo or head. Your report goes to Some Wins and they are not told.")
                    }
                    .confirmationDialog("Block \(name)?", isPresented: $blockingPerson, titleVisibility: .visible) {
                        Button("Block", role: .destructive) {
                            Task { await CrewSafety.block(friend, from: thread ?? crew) }
                            onBack()
                        }
                    } message: {
                        if thread == nil, let group = store.crew(crew), !group.isPersonal, group.isOwner(store.me) {
                            Text("You won't see their wins, stories or messages, and they leave \(group.displayName(excluding: store.me)). Some Wins hears about it. They are not told.")
                        } else {
                            Text("You won't see their wins, stories or messages. Some Wins hears about it. They are not told.")
                        }
                    }
                }
            }
            Text(name)
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(1)
                .padding(.horizontal, 64)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.spacing)
    }

    @ViewBuilder
    private var foot: some View {
        if let thread {
            ChatRestBar(crewID: thread) { how in
                opening = how
                showsChat = true
            }
        } else if member != nil, store.canReply() {
            // **The first line starts it.** A field to tap, as the bar is,
            // until there is a conversation to rest on.
            Button(action: start) {
                HStack {
                    Text("Message \(name)")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkTertiary)
                    Spacer(minLength: 0)
                    if starting { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, GridConstants.gapLabel)
                .frame(minHeight: GlassIconButton.defaultSide)
                .glassField()
                .contentShape(Capsule())
            }
            .buttonStyle(.press)
            .disabled(starting)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, GridConstants.gapTight)
            .accessibilityLabel("Message \(name)")
        }
    }

    private func start() {
        HapticsEngine.lightTap()
        starting = true
        Task {
            let made = await store.startPersonal(with: friend)
            starting = false
            guard made != nil else { failed = true; return }
            opening = .writing
            showsChat = true
        }
    }
}
