import SwiftUI

/// **A message to one person** (the owner, 2026-10-16: "I want just
/// message DMs added, because crew has the tower but I need just a way to
/// message individuals").
///
/// A two-person crew underneath (`Crew.isPersonal`), so it is sealed, paced,
/// checked and reported as every crew line is, and needs nothing new in
/// iCloud. On screen it is only the conversation: their head and name at
/// the top (a tap opens their profile), the thread of the last two weeks,
/// and the field. No tower, no plans, no wins: those are the crew's.
struct DirectChatView: View {
    let crewID: CrewID
    let onBack: () -> Void

    @State private var profile = false
    private var store: SocialStore { SocialStore.shared }
    private var friend: CrewMember? { store.directFriend(crewID) }
    private var name: String {
        let short = friend?.shortName ?? ""
        return short.isEmpty ? "Message" : short
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            CrewChatSheet(crewID: crewID, visible: true, direct: true, close: onBack)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .modifier(CrewLiveSync(crewID: crewID))
        .onAppear {
            store.markSeen(crewID)
            // Quiet for the conversation on screen, as a crew is (the review).
            CrewNotifications.visibleCrew = crewID
            // A tower's errands, never this page's: left set, they opened the
            // next crew's chat unasked (the review, 2026-10-16).
            CrewRouter.shared.openChat = false
            CrewRouter.shared.openWin = nil
        }
        .onDisappear { if CrewNotifications.visibleCrew == crewID { CrewNotifications.visibleCrew = nil } }
        // Ended or left from elsewhere: back to the list, not a broken page.
        .onChange(of: store.crew(crewID) == nil) { _, gone in if gone { onBack() } }
        .sheet(isPresented: $profile) {
            if let friend, let shared = sharedCrew(of: friend) {
                NavigationStack { FriendProfileSheet(member: friend, crewID: shared) }
                    .presentationBackground { WarmBackground().ignoresSafeArea() }
            }
        }
    }

    /// The crew you share with them: their profile is read from there.
    private func sharedCrew(of friend: CrewMember) -> CrewID? {
        store.groupCrews.first { $0.member(friend.profileID) != nil }?.id
    }

    private var header: some View {
        ZStack {
            HStack {
                GlassIconButton(systemName: "chevron.left", onPage: true, accessibilityLabel: "Back", action: onBack)
                Spacer(minLength: 0)
            }
            Button {
                HapticsEngine.lightTap()
                profile = true
            } label: {
                VStack(spacing: GridConstants.spacing) {
                    if let friend {
                        PersonHead(person: .member(friend, crew: crewID, me: store.me), side: 40)
                    }
                    Text(name)
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .disabled(friend.flatMap(sharedCrew(of:)) == nil)
            .accessibilityLabel(name)
            .accessibilityHint("Opens their profile.")
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapTight)
    }
}
