import Foundation
import UserNotifications
import os

/// **Answering a crew notification without opening the app** (the social
/// research, 2026-10-15, item 3: a reply should cost as little as reading).
/// The actions are named in `CrewNoteActions`, shared with the extension.
enum CrewNoteAnswers {
    private static let log = Logger(subsystem: "Strata", category: "crews.answers")

    static var categories: Set<UNNotificationCategory> {
        let reply = UNTextInputNotificationAction(identifier: CrewNoteActions.reply, title: "Reply",
                                                  options: [], textInputButtonTitle: "Send",
                                                  textInputPlaceholder: CrewChatWords.placeholder)
        let fire = UNNotificationAction(identifier: CrewNoteActions.fire, title: "🔥", options: [])
        let heart = UNNotificationAction(identifier: CrewNoteActions.heart, title: "❤️", options: [])
        return [
            UNNotificationCategory(identifier: CrewNoteActions.winCategory, actions: [fire, heart, reply],
                                   intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: CrewNoteActions.chatCategory, actions: [reply],
                                   intentIdentifiers: [], options: []),
        ]
    }

    static func handles(_ action: String) -> Bool {
        action == CrewNoteActions.reply || CrewNoteActions.reactions[action] != nil
    }

    /// The crew read first if this launch has not, then the same send the
    /// crew screen makes. A send that fails is logged and left: the person
    /// sees their crew as it is when they next open it.
    @MainActor
    static func answer(_ response: UNNotificationResponse) async {
        guard CrewsFlag.isOn else { return }
        let info = response.notification.request.content.userInfo
        guard let raw = info["crew"] as? String else { return }
        let crew = CrewID(rawValue: raw)
        let store = SocialStore.shared
        if store.crew(crew) == nil { await store.refresh() }
        guard store.crew(crew) != nil, store.canReply() else { return }
        if let emoji = CrewNoteActions.reactions[response.actionIdentifier] {
            guard let win = (info["win"] as? String).flatMap(UUID.init(uuidString:)) else { return }
            await store.react(emoji, to: win, in: crew)
            return
        }
        guard let typed = (response as? UNTextInputNotificationResponse)?.userText
            .trimmingCharacters(in: .whitespacesAndNewlines), !typed.isEmpty else { return }
        let outcome: SocialStore.ReplyOutcome
        if let win = (info["win"] as? String).flatMap(UUID.init(uuidString:)) {
            outcome = await store.reply(typed, to: win, in: crew)
        } else {
            outcome = await store.send(typed, in: crew)
        }
        if outcome != .sent { log.notice("an answer from a notification did not go: \(String(describing: outcome))") }
    }
}
