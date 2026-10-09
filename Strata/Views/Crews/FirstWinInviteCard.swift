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
            // Drawn by the Wins header, under the crest, where every Wins tip
            // stands (`TipStage.invite`, 2026-10-08); this decides when.
            .onChange(of: showing == nil || !crewPath.isEmpty, initial: true) { _, hidden in
                if hidden {
                    TipStage.shared.invite = nil
                    TipStage.shared.release("invite")
                } else if let showing {
                    FirstWinInvite.markShown(showing)
                    _ = TipStage.shared.take("invite")
                    TipStage.shared.invite = InviteTip(
                        hasCrew: CrewsFlag.isOn && !SocialStore.shared.crews.isEmpty,
                        invite: invite, close: close)
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
        // **Never below iOS 26** (2026-10-08): it would invite people into
        // crews this phone cannot open.
        guard FirstWinInvite.shouldShow(moment, winsEver: winsEver,
                                        crewsOn: CrewsFlag.isUsable, age: CrewAge.current) else { return }
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

/// **The invitation, as every tip is now** (`TipCard`, 2026-10-08): the line,
/// Invite or Start a Crew as its word, and the close glyph, in the one tip
/// container, under the header where it always stood.
struct FirstWinInviteCard: View {
    let hasCrew: Bool
    var invite: () -> Void
    var close: () -> Void

    var body: some View {
        TipCard(title: String(FirstWinInvite.lead.dropLast()),
                message: FirstWinInvite.ask,
                mark: "TipPersonPlus",
                actionTitle: hasCrew ? "Invite" : "Start a Crew",
                action: invite,
                close: close)
            .accessibilityHint(hasCrew ? "Invites people to your crew" : "Starts a crew")
    }
}
