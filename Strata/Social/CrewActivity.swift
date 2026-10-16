import Foundation

/// **The newest thing in a crew, whatever it is** (the owner, 2026-10-13,
/// from his phone: "when someone says something or reacts to your post it
/// never shows up as a message in the preview like it only does the wins").
/// A crew's row in the list said its newest WIN and when, so a message or a
/// reaction lit the dot while the row went on saying "Sam: Gym". The row
/// says the newest of the three now, as Messages says the last line, and
/// the list is ordered by it.
nonisolated enum CrewActivity: Equatable {
    case win(SharedWin)
    case message(CrewMessage)
    /// A reaction, and the win it is on if that win is in the crew (nil for
    /// one on a chat line, or on a win gone since).
    case reaction(Reaction, on: SharedWin?)

    var date: Date {
        switch self {
        case .win(let win): win.createdAt
        case .message(let message): message.createdAt
        case .reaction(let reaction, _): reaction.createdAt
        }
    }

    /// The newest of a crew's wins, its visible chat lines and its
    /// reactions. Reactions you made yourself are not news to you and are
    /// left out; your own wins and lines are kept, as a chat's last line is
    /// yours when you sent it.
    static func newest(wins: [SharedWin], messages: [CrewMessage], reactions: [Reaction], me: UUID) -> CrewActivity? {
        var best: CrewActivity?
        func consider(_ candidate: CrewActivity) {
            if best.map({ candidate.date > $0.date }) ?? true { best = candidate }
        }
        if let win = wins.max(by: { $0.createdAt < $1.createdAt }) { consider(.win(win)) }
        if let message = messages.max(by: { $0.createdAt < $1.createdAt }) { consider(.message(message)) }
        if let reaction = reactions.filter({ $0.profileID != me }).max(by: { $0.createdAt < $1.createdAt }) {
            consider(.reaction(reaction, on: wins.first { $0.winID == reaction.winID }))
        }
        return best
    }

    /// The row's line, in the app's voice: who, then what, plainly.
    func preview(name: (UUID) -> String, me: UUID) -> String {
        switch self {
        case .win(let win):
            let who = win.senderProfileID == me ? "You" : name(win.senderProfileID)
            let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty { return win.photo != nil ? "\(who) added a photo" : "\(who) added a win" }
            // As the alert says it (`CrewNotifications.Text.of`).
            return "\(who) added \(title)"
        case .message(let line):
            let who = line.senderProfileID == me ? "You" : name(line.senderProfileID)
            if line.isStrip { return "\(who) sent a strip" }
            if let plan = line.groupPlan { return "\(who) planned \(plan.title)" }
            if line.isPicture {
                let caption = line.caption.trimmingCharacters(in: .whitespacesAndNewlines)
                // A sticker is a picture captioned "Sticker" (`sendSticker`),
                // or none: it said "Sam: Sticker" (walked, 2026-10-15).
                return caption.isEmpty || caption == SocialStore.stickerWord ? "\(who) sent a sticker" : "\(who): \(caption)"
            }
            if line.sketch != nil { return "\(who) sent a doodle" }
            let words = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return words.isEmpty ? "\(who) said something" : "\(who): \(words)"
        case .reaction(let reaction, let win):
            let who = name(reaction.profileID)
            guard let win else { return "\(who) reacted \(reaction.emoji) to a message" }
            if win.senderProfileID == me { return "\(who) reacted \(reaction.emoji) to your win" }
            let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "\(who) reacted \(reaction.emoji) to a win" : "\(who) reacted \(reaction.emoji) to \(title)"
        }
    }
}

@MainActor
extension SocialStore {
    /// The newest thing in a crew (`CrewActivity`).
    func activity(in crewID: CrewID) -> CrewActivity? {
        CrewActivity.newest(wins: winsByCrew[crewID] ?? [], messages: messages(in: crewID),
                            reactions: reactionsByCrew[crewID] ?? [], me: me)
    }
}
