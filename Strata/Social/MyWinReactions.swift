import Foundation

/// **Friends' reactions to your own wins, for your own tower** (the owner,
/// 2026-10-13: "reactions on main wins and memories with lots of
/// reactions").
///
/// A win of yours that went to a crew is reacted to there, on the crew's
/// copy (`SocialStore.reactionsByCrew`). This gathers them back onto the
/// win itself, across every crew it went to, so the block on Wins and in
/// Memories wears the same `ReactionBadge` the crew tower draws.
///
/// **Read, never stored.** Nothing is written to the win: no new SwiftData
/// field and no new CloudKit field. A reaction taken back in the crew comes
/// off your block at the next rebuild.
nonisolated enum MyWinReactions {
    /// Keyed by your win's id. Only reactions to wins YOU sent (so a chat
    /// line's reactions, which share the record, and a friend's win never
    /// count), never your own, never anyone you blocked. A friend in two of
    /// your crews who reacted in both counts once, with their latest.
    ///
    /// `kept`: reactions to your stories, copied onto this phone while the
    /// story was on (`SocialStore.keepStoryReactions`), so they stay on the
    /// block after the night (Tonight's Story, R12).
    static func gather(reactionsByCrew: [CrewID: [Reaction]],
                       winsByCrew: [CrewID: [SharedWin]],
                       kept: [UUID: [Reaction]] = [:],
                       me: UUID,
                       blocked: Set<UUID>) -> [UUID: [Reaction]] {
        var latest: [UUID: [UUID: Reaction]] = [:]
        for (winID, reactions) in kept {
            for reaction in reactions where reaction.profileID != me && !blocked.contains(reaction.profileID) {
                if let held = latest[winID]?[reaction.profileID], held.createdAt >= reaction.createdAt { continue }
                latest[winID, default: [:]][reaction.profileID] = reaction
            }
        }
        for (crewID, reactions) in reactionsByCrew {
            let mine = Set((winsByCrew[crewID] ?? []).filter { $0.senderProfileID == me }.map(\.winID))
            guard !mine.isEmpty else { continue }
            for reaction in reactions
            where mine.contains(reaction.winID) && reaction.profileID != me && !blocked.contains(reaction.profileID) {
                if let held = latest[reaction.winID]?[reaction.profileID], held.createdAt >= reaction.createdAt { continue }
                latest[reaction.winID, default: [:]][reaction.profileID] = reaction
            }
        }
        return latest.mapValues { $0.values.sorted { $0.createdAt < $1.createdAt } }
    }

    #if DEBUG
    /// `-strataSeedMyReactions 1`: friends' reactions on every other win of
    /// yours, so the badge can be seen without a crew: one emoji on most,
    /// seven people on every fourth (the tidy case: the most given and the
    /// total). Your real ones win where there are any.
    static func debugSeeded(_ ids: [UUID], over real: [UUID: [Reaction]]) -> [UUID: [Reaction]] {
        guard ProcessInfo.processInfo.arguments.contains("-strataSeedMyReactions") else { return real }
        let emoji = ["🔥", "🔥", "👑", "🔥", "❤️", "👑", "🔥"]
        var out = real
        for (i, id) in ids.enumerated() where i % 2 == 0 && out[id] == nil {
            let count = i % 4 == 0 ? emoji.count : 1
            out[id] = (0..<count).map { k in
                Reaction(winID: id, crewID: CrewID(rawValue: "debug"), profileID: UUID(),
                         emoji: emoji[(k + i) % emoji.count], createdAt: Date(timeIntervalSince1970: Double(k)))
            }
        }
        return out
    }
    #endif
}

extension SocialStore {
    /// Friends' reactions to your wins, every crew at once (`MyWinReactions`).
    func reactionsToMyWins() -> [UUID: [Reaction]] {
        MyWinReactions.gather(reactionsByCrew: reactionsByCrew, winsByCrew: winsByCrew, kept: keptStoryReactions,
                              me: me, blocked: blocked)
    }

    /// What a tower of your wins is handed: nothing at all while crews are
    /// off, so a phone without them never builds the store to ask.
    @MainActor
    static var reactionsForMyTower: [UUID: [Reaction]] {
        CrewsFlag.isOn ? shared.reactionsToMyWins() : [:]
    }
}
