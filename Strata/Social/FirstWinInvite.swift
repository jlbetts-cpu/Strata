import Foundation

/// **One quiet invitation, at the two moments it is wanted** (owner-approved,
/// 2026-10-05, from his Apollo research).
///
/// Right after the very first win lands on your tower, ever: "Your win is up.
/// Who else should see it?", which opens the crew invitation with a picture
/// of your tower (or offers starting a crew when you have none). Once more
/// after the first reaction anybody sends you, and then never again.
///
/// Never to under-13s, who cannot open crews, and never with Crews off.
/// Dismissible and never blocking: it is a card over the tower, not a sheet.
/// The flags are in `UserDefaults` because they are this phone's memory of
/// having asked, not data anybody would restore.
nonisolated enum FirstWinInvite {
    enum Moment { case firstWin, firstReaction }

    /// The two halves, set as a title and the line under it on the card.
    static let lead = "Your win is up."
    static let ask = "Who else should see it?"
    static var line: String { lead + " " + ask }

    static let firstWinKey = "invite.shownAfterFirstWin"
    static let firstReactionKey = "invite.shownAfterFirstReaction"

    private static func key(_ moment: Moment) -> String {
        moment == .firstWin ? firstWinKey : firstReactionKey
    }

    /// Whether the card may show now. `winsEver` is every win on this phone,
    /// counted after the one that just landed, so only a first win is 1 and a
    /// tower that existed before this shipped never sees it.
    static func shouldShow(_ moment: Moment, winsEver: Int = 0, crewsOn: Bool, age: CrewAge,
                           defaults: UserDefaults = .standard) -> Bool {
        guard crewsOn, age.opensCrews, !defaults.bool(forKey: key(moment)) else { return false }
        switch moment {
        case .firstWin:
            return winsEver == 1
        case .firstReaction:
            // "Once MORE": only someone who was asked after their first win.
            return defaults.bool(forKey: firstWinKey)
        }
    }

    /// Recorded when the line appears, not when it is answered: a line you
    /// closed has been seen.
    static func markShown(_ moment: Moment, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key(moment))
    }

    /// Someone else has reacted to a win you sent.
    static func hasReceivedReaction(wins: [CrewID: [SharedWin]], reactions: [CrewID: [Reaction]],
                                    me: UUID) -> Bool {
        for (crew, list) in reactions {
            let mine = Set((wins[crew] ?? []).filter { $0.senderProfileID == me }.map(\.winID))
            guard !mine.isEmpty else { continue }
            if list.contains(where: { $0.profileID != me && mine.contains($0.winID) }) { return true }
        }
        return false
    }
}
