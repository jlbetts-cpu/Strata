import CloudKit
import Foundation
import UIKit
import UserNotifications
import os

/// A notification for every friend's win, the way Messages does it (the
/// owner, 2026-10-02): titled with the crew, "Sam: Gym" underneath, grouped by
/// crew on the lock screen, none at all for a crew whose alerts you hid, never
/// for the crew you are looking at.
///
/// **How it arrives.** iCloud sends a silent push when a crew's zone changes
/// (`CKDatabaseSubscription`, content-available only). The app wakes, fetches,
/// and says what changed in a local notification it writes itself, with the
/// real names. No server, and nothing about a win travels in the push.
///
/// **Pings, once they are live.** A silent push does not wake a phone where
/// Some Wins was swiped away, and iOS rations them anyway. So a win or a
/// reaction also leaves a ping (`CrewPingRecord`), and iCloud sends each phone
/// a visible alert for the pings it asked for; the notification extension
/// writes the words. From then on the app's own notifications below stand
/// down (`SocialStore.pingsLive`), and they remain for a phone whose
/// subscriptions are not saved yet.
@MainActor
enum CrewNotifications {
    private static let log = Logger(subsystem: "Strata", category: "crews.notify")
    private static let seenKey = "crews.notified"
    /// The crew on screen now, which never notifies.
    static var visibleCrew: CrewID?

    // MARK: Permission and the push

    /// Asked the first time you start or join a crew, never at launch.
    static func askOnce() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        log.notice("asking for notifications")
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// The silent push from both databases: crews you started live in your
    /// private one, crews you joined in your shared one.
    static func subscribe(_ container: CKContainer) async {
        for (scope, id) in [(container.privateCloudDatabase, "crews-private"),
                            (container.sharedCloudDatabase, "crews-shared")] {
            let subscription = CKDatabaseSubscription(subscriptionID: id)
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            do {
                _ = try await scope.modifySubscriptions(saving: [subscription], deleting: [])
            } catch {
                log.error("subscription \(id, privacy: .public) not saved: \(error)")
            }
        }
    }

    // MARK: Saying what is new

    /// Wins that arrived since the last call, as notifications. Called after
    /// every refresh. The first call on a phone only remembers what is there.
    /// **How far back a notification may reach.** In the background (a push
    /// woke the app) the last six hours, so a quiet phone still hears about
    /// the day. With the app OPEN, two minutes: opening Some Wins after a while
    /// used to fire one banner for every win since, over the crews you were
    /// about to look at anyway (the 2026-10-03 audit). Open, only what is
    /// arriving now is news.
    static var reach: () async -> TimeInterval = {
        await MainActor.run { UIApplication.shared.applicationState == .active } ? 120 : 6 * 3600
    }

    static func announce(_ store: SocialStore, defaults: UserDefaults = .standard) async {
        #if DEBUG
        NSLog("[strata-crew] announce")
        #endif
        let seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        let window = await reach()
        let all = store.crews.flatMap { store.wins(in: $0.id) }
        defaults.set(all.map(\.winID.uuidString), forKey: seenKey)
        guard defaults.object(forKey: seenKey + ".started") != nil else {
            defaults.set(true, forKey: seenKey + ".started")
            return
        }
        let fresh = all.filter { win in
            !seen.contains(win.winID.uuidString)
                && win.senderProfileID != store.me
                && !store.blocked.contains(win.senderProfileID)
                && win.crewID != visibleCrew
                // Muted, as in Messages: nothing from that crew.
                && !store.isMuted(win.crewID)
                && Date().timeIntervalSince(win.createdAt) < window
        }
        // iCloud's pings say it now, even to a phone where the app was
        // swiped away; saying it here as well would say it twice.
        guard !store.pingsLive else { return }
        let center = UNUserNotificationCenter.current()
        for win in fresh {
            guard let crew = store.crew(win.crewID) else { continue }
            let text = Text.of(win, in: crew, me: store.me)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.threadIdentifier = win.crewID.rawValue
            content.userInfo = ["crew": win.crewID.rawValue, "win": win.winID.uuidString]
            content.sound = .default
            if let photo = win.photo, let attachment = attachment(photo) {
                content.attachments = [attachment]
            }
            let request = UNNotificationRequest(identifier: win.winID.uuidString, content: content, trigger: nil)
            do { try await center.add(request) } catch {
                log.error("notification not added: \(error)")
            }
        }
    }

    /// A copy of the photo for the notification to keep (it moves the file).
    private static func attachment(_ photo: URL) -> UNNotificationAttachment? {
        let copy = FileManager.default.temporaryDirectory.appending(path: "crew-note-\(UUID().uuidString).jpg")
        guard (try? FileManager.default.copyItem(at: photo, to: copy)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "photo", url: copy)
    }

    /// Reactions to YOUR wins since the last call: "Sam reacted 🔥 to Gym",
    /// and replies, "Sam: so proud of you". Each crew's own switch, and its
    /// mute, decide.
    ///
    /// **A reply is announced under its own key** (`announceKeys`), so a
    /// friend who reacted first and wrote a line later is heard both times,
    /// and one who did both at once is heard once, for the words.
    static func announceReactions(_ store: SocialStore, defaults: UserDefaults = .standard) async {
        let key = "crews.notifiedReactions"
        // The replies' memory is its own list with its own first run, so the
        // first build that knows about replies only remembers the ones
        // already there rather than announcing a day's worth of them at once.
        let replyKey = "crews.notifiedReplies"
        let seen = Set(defaults.stringArray(forKey: key) ?? [])
        let seenReplies = Set(defaults.stringArray(forKey: replyKey) ?? [])
        let window = await reach()
        var now: [String] = []
        var nowReplies: [String] = []
        var fresh: [(reaction: Reaction, isReply: Bool)] = []
        for crew in store.crews {
            let mine = Dictionary(uniqueKeysWithValues: store.wins(in: crew.id)
                .filter { $0.senderProfileID == store.me }.map { ($0.winID, $0) })
            for reaction in store.reactionsByCrew[crew.id] ?? [] where mine[reaction.winID] != nil {
                // By who and which win, not by emoji: a friend changing ❤️ to
                // 🔥 is not a second reaction, and it notified again.
                let keys = announceKeys(reaction)
                now.append(keys.reaction)
                if let reply = keys.reply { nowReplies.append(reply) }
                let isNewReply = keys.reply.map { !seenReplies.contains($0) } ?? false
                let isNewReaction = !seen.contains(keys.reaction)
                if isNewReply || isNewReaction, reaction.profileID != store.me, !store.blocked.contains(reaction.profileID),
                   store.reactionAlerts(crew.id), !store.isMuted(crew.id), crew.id != visibleCrew,
                   Date().timeIntervalSince(reaction.createdAt) < window {
                    fresh.append((reaction, isNewReply))
                }
            }
        }
        defaults.set(now, forKey: key)
        defaults.set(nowReplies, forKey: replyKey)
        let started = defaults.bool(forKey: key + ".started")
        let repliesStarted = defaults.bool(forKey: replyKey + ".started")
        defaults.set(true, forKey: key + ".started")
        defaults.set(true, forKey: replyKey + ".started")
        guard started else { return }
        guard !store.pingsLive else { return }
        for item in fresh {
            // Before the replies had a memory, a new key there is not news.
            if item.isReply && !repliesStarted && seen.contains(item.reaction.id) { continue }
            let reaction = item.reaction
            guard let crew = store.crew(reaction.crewID),
                  let win = store.wins(in: crew.id).first(where: { $0.winID == reaction.winID }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = crew.displayName(excluding: store.me)
            content.body = item.isReply ? Text.replied(reaction, in: crew) : Text.reacted(reaction, to: win, in: crew)
            content.threadIdentifier = crew.id.rawValue
            content.userInfo = ["crew": crew.id.rawValue, "win": win.winID.uuidString]
            content.sound = .default
            let id = item.isReply ? (announceKeys(reaction).reply ?? reaction.id) : "reaction-" + reaction.id
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: id, content: content, trigger: nil))
        }
    }

    /// The keys a reaction record is remembered by: the reaction's own, and,
    /// when it carries a line, the reply's (`"reply-…"`), which is the same
    /// shape as the reply's ping key (`SocialStore.pingKey`).
    nonisolated static func announceKeys(_ reaction: Reaction) -> (reaction: String, reply: String?) {
        let line = reaction.line?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (reaction.id, line.isEmpty ? nil : "reply-" + reaction.id)
    }

    /// A crew you left or that ended: its notifications go from the lock
    /// screen and Notification Center too.
    static func removeDelivered(for crew: CrewID) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let ids = delivered.filter { $0.request.content.threadIdentifier == crew.rawValue }.map(\.request.identifier)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// The words, kept apart so a test can read them.
    enum Text {
        static func of(_ win: SharedWin, in crew: Crew, me: UUID) -> (title: String, body: String) {
            let name = crew.member(win.senderProfileID)?.shortName ?? ""
            let who = name.isEmpty ? "A friend" : name
            let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let body: String
            // **The person tagged is told so** (the cohesion pass,
            // 2026-10-05): "Sam added you to Morning run", not the same
            // "Sam: Morning run" everyone else gets, because for you it is
            // a question waiting (Keep, or Not This One) and the tap lands
            // on the crew where it is asked.
            if win.withPeople.contains(me), win.senderProfileID != me {
                body = title.isEmpty ? "\(who) added you to a win" : "\(who) added you to \(title)"
            } else if title.isEmpty {
                body = win.photo != nil ? "\(who) added a photo" : "\(who) added a win"
            } else {
                body = "\(who): \(title)"
            }
            return (crew.displayName(excluding: me), body)
        }

        /// A reply, as Messages says one: "Sam: so proud of you".
        static func replied(_ reaction: Reaction, in crew: Crew) -> String {
            let name = crew.member(reaction.profileID)?.shortName ?? ""
            let who = name.isEmpty ? "A friend" : name
            let line = reaction.line?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return line.isEmpty ? "\(who) reacted \(reaction.emoji) to your win" : "\(who): \(line)"
        }

        static func reacted(_ reaction: Reaction, to win: SharedWin, in crew: Crew) -> String {
            let name = crew.member(reaction.profileID)?.shortName ?? ""
            let who = name.isEmpty ? "A friend" : name
            let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "\(who) reacted \(reaction.emoji) to your win"
                                 : "\(who) reacted \(reaction.emoji) to \u{201C}\(title)\u{201D}"
        }
    }
}
