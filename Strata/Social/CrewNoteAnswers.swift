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
        let typed = (response as? UNTextInputNotificationResponse)?.userText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard store.crew(crew) != nil, store.canReply() else {
            // Words typed and nowhere to put them yet: never lost in silence.
            if !typed.isEmpty { await tellNotSent(crew: crew) }
            return
        }
        let win = (info["win"] as? String).flatMap(UUID.init(uuidString:))
        // **The win the alert was about is usually newer than this launch's
        // copy of the crew** (the review, 2026-10-15): read the crew's
        // changes first, or the reaction and the reply found nothing to land on.
        if let win, !store.wins(in: crew).contains(where: { $0.winID == win }) {
            _ = await store.refreshLive(crew)
        }
        if let emoji = CrewNoteActions.reactions[response.actionIdentifier] {
            guard let win else { return }
            // A reaction toggles; the same one again from a banner is not a
            // take-back.
            guard store.myReaction(to: win, in: crew) != emoji else { return }
            await store.react(emoji, to: win, in: crew)
            return
        }
        guard !typed.isEmpty else { return }
        let outcome: SocialStore.ReplyOutcome
        if let win = (info["win"] as? String).flatMap(UUID.init(uuidString:)) {
            outcome = await store.reply(typed, to: win, in: crew)
        } else {
            outcome = await store.send(typed, in: crew)
        }
        if outcome != .sent {
            log.notice("an answer from a notification did not go: \(String(describing: outcome))")
            await tellNotSent(crew: crew)
        }
    }

    /// The words did not go: said once, quietly, so a reply is never lost
    /// without a word (the review, 2026-10-15).
    private static func tellNotSent(crew: CrewID) async {
        let content = UNMutableNotificationContent()
        content.body = "Your reply didn't go. Open the crew to send it again."
        content.userInfo = ["crew": crew.rawValue]
        content.threadIdentifier = crew.rawValue
        let request = UNNotificationRequest(identifier: "crew.reply.failed.\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// **Only where answering is allowed** (the review, 2026-10-15): a phone
    /// that may not write in a crew showed Reply and the reactions on every
    /// alert, and they did nothing. Registered again as the app comes forward.
    @MainActor
    static func register() {
        var set: Set<UNNotificationCategory> = [DailyReminder.notificationCategory]
        if CrewsFlag.isOn, SocialStore.shared.canReply() { set.formUnion(categories) }
        UNUserNotificationCenter.current().setNotificationCategories(set)
    }
}
