import SwiftData
import SwiftUI

/// **The first-win invitation, on the Wins tab** (`FirstWinInvite` holds the
/// rule and the reasons).
///
/// A modifier so `MainAppView`, already at the type-checker's ceiling, gains
/// one line. It watches the tower's block count for a first win and the
/// crews for a first reaction, and when the rule says so it raises one quiet
/// line under the header. Never a sheet, never in the way of the
/// slot or the win it is about: the line hangs in the empty air above the
/// tower, closes with its own ✕, and leaves when you go anywhere else.
struct FirstWinInvitePrompt: ViewModifier {
    /// Today's blocks on the tower. A rise is a win landing.
    let blockCount: Int
    @Binding var crewPath: [CrewRoute]
    /// The tower as a 9:16 picture, drawn only when the card is answered.
    var towerCard: () -> UIImage?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showing: FirstWinInvite.Moment?

    /// Read only with Crews on: with the flag off nothing of Crews is touched.
    private var receivedReaction: Bool {
        guard CrewsFlag.isOn else { return false }
        let store = SocialStore.shared
        return FirstWinInvite.hasReceivedReaction(wins: store.winsByCrew,
                                                 reactions: store.reactionsByCrew, me: store.me)
    }

    func body(content: Content) -> some View {
        content
            // **Under the header, not at the foot.** The foot was asked for
            // and built first, and photographed it stood exactly over the
            // bottom row, which on a first-win tower IS the win: "Your win is
            // up" printed over the win. The tower grows from the bottom, so
            // the air under the header is the one place on Wins that is
            // always empty, and the line hangs there, on the header's own
            // line arithmetic (`towerHeader`): its top padding, a 44pt
            // control, `gapWide`.
            .overlay(alignment: .top) {
                if showing != nil, crewPath.isEmpty {
                    FirstWinInviteCard(hasCrew: CrewsFlag.isOn && !SocialStore.shared.crews.isEmpty,
                                       invite: invite, close: close)
                        // Recorded when it is SEEN, not when it is decided:
                        // the first launch after onboarding rebuilds the tab
                        // under a pending card, and a card marked shown at
                        // the decision was lost with that state and never
                        // came back (photographed, 2026-10-05).
                        .onAppear { if let showing { FirstWinInvite.markShown(showing) } }
                        .padding(.leading, GridConstants.horizontalPadding)
                        .padding(.trailing, GridConstants.spacing)
                        .padding(.top, GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral)
                                     + GlassIconButton.defaultSide + GridConstants.gapWide)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: showing)
            .task {
                if blockCount > 0 { consider(.firstWin) }
                if receivedReaction { consider(.firstReaction) }
                #if DEBUG
                // `-strataInviteCard 1` raises the card on launch, so it can
                // be photographed without a first win on a fresh phone.
                if DebugHarness.argument("-strataInviteCard") == "1" {
                    try? await Task.sleep(for: .seconds(2))
                    showing = .firstWin
                }
                #endif
            }
            .onChange(of: blockCount) { old, new in
                if new > old { consider(.firstWin) }
            }
            .onChange(of: receivedReaction) { _, got in
                if got { consider(.firstReaction) }
            }
    }

    private func consider(_ moment: FirstWinInvite.Moment) {
        guard showing == nil else { return }
        let winsEver = moment == .firstWin
            ? ((try? modelContext.fetchCount(FetchDescriptor<HabitLog>())) ?? 0) : 0
        guard FirstWinInvite.shouldShow(moment, winsEver: winsEver,
                                        crewsOn: CrewsFlag.isOn, age: CrewAge.current) else { return }
        Task {
            // After the block has landed, not over its fall.
            try? await Task.sleep(for: .milliseconds(1400))
            showing = moment
        }
    }

    private func invite() {
        let card = towerCard()
        showing = nil
        let store = SocialStore.shared
        if let crew = store.crews.first {
            Task { await CrewSharing.invite(crew.id, card: card) }
        } else {
            // No crew yet: start one. The list stands behind the crew rules
            // and the age question, and opens New Crew once those are done.
            CrewSharing.nextCard = card
            CrewRouter.shared.startsCrew = true
            crewPath = [.list]
        }
    }

    private func close() {
        HapticsEngine.lightTap()
        showing = nil
    }
}

/// **One quiet line and one word to press, on the page itself.** No panel
/// and no glass: glass is for controls, and the Wins header already carries
/// the three glass controls a screen is allowed (`GlassIconButton.swift`'s
/// budget). The sentence in the secondary ink, Invite as a sheet's confirm
/// word, and a hollow close glyph. Air around it, no line under it.
struct FirstWinInviteCard: View {
    let hasCrew: Bool
    var invite: () -> Void
    var close: () -> Void

    private static let tapTarget: CGFloat = 44

    var body: some View {
        HStack(spacing: GridConstants.gapTight) {
            Text(FirstWinInvite.line)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            Button(action: invite) {
                Text(hasCrew ? "Invite" : "Start a Crew").sheetAction()
            }
            .buttonStyle(.pressWord)
            .accessibilityHint(hasCrew ? "Invites people to your crew" : "Starts a crew")

            Button(action: close) {
                Image(systemName: "xmark")
                    .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityLabel("Close")
        }
        .accessibilityElement(children: .contain)
    }
}
