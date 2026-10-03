import CloudKit
import Foundation
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
/// The limit, stated: a phone where Sturdy was swiped away from the app
/// switcher is not woken by a silent push, so its notifications wait until
/// it is next opened. A notification service extension lifts that; it needs
/// its own app ID with the iCloud container, which is a step in the developer
/// portal (`docs/superpowers/specs/2026-10-02-crews-design.md`, 5).
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
    static func announce(_ store: SocialStore, defaults: UserDefaults = .standard) async {
        #if DEBUG
        NSLog("[strata-crew] announce")
        #endif
        let seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
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
                && Date().timeIntervalSince(win.createdAt) < 6 * 3600
        }
        let center = UNUserNotificationCenter.current()
        for win in fresh {
            guard let crew = store.crew(win.crewID) else { continue }
            let text = Text.of(win, in: crew, me: store.me)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.threadIdentifier = win.crewID.rawValue
            content.userInfo = ["crew": win.crewID.rawValue]
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

    /// Reactions to YOUR wins since the last call: "Sam reacted 🔥 to Gym".
    /// Each crew's own switch, and its mute, decide.
    static func announceReactions(_ store: SocialStore, defaults: UserDefaults = .standard) async {
        let key = "crews.notifiedReactions"
        let seen = Set(defaults.stringArray(forKey: key) ?? [])
        var now: [String] = []
        var fresh: [Reaction] = []
        for crew in store.crews {
            let mine = Dictionary(uniqueKeysWithValues: store.wins(in: crew.id)
                .filter { $0.senderProfileID == store.me }.map { ($0.winID, $0) })
            for reaction in store.reactionsByCrew[crew.id] ?? [] where mine[reaction.winID] != nil {
                let tag = reaction.id + reaction.emoji
                now.append(tag)
                if !seen.contains(tag), reaction.profileID != store.me, !store.blocked.contains(reaction.profileID),
                   store.reactionAlerts(crew.id), !store.isMuted(crew.id), crew.id != visibleCrew,
                   Date().timeIntervalSince(reaction.createdAt) < 6 * 3600 {
                    fresh.append(reaction)
                }
            }
        }
        defaults.set(now, forKey: key)
        guard defaults.bool(forKey: key + ".started") else {
            defaults.set(true, forKey: key + ".started")
            return
        }
        for reaction in fresh {
            guard let crew = store.crew(reaction.crewID),
                  let win = store.wins(in: crew.id).first(where: { $0.winID == reaction.winID }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = crew.displayName(excluding: store.me)
            content.body = Text.reacted(reaction, to: win, in: crew)
            content.threadIdentifier = crew.id.rawValue
            content.userInfo = ["crew": crew.id.rawValue]
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "reaction-" + reaction.id + reaction.emoji, content: content, trigger: nil))
        }
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
            if title.isEmpty {
                body = win.photo != nil ? "\(who) added a photo" : "\(who) added a win"
            } else {
                body = "\(who): \(title)"
            }
            return (crew.displayName(excluding: me), body)
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
