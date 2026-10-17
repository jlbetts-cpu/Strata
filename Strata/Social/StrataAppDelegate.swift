import CloudKit
import Observation
import UserNotifications
import SwiftUI
import UIKit
import os

/// Where the app has been asked to go by something outside it: an accepted
/// crew invitation, or a tapped notification. `MainAppView` watches this and
/// pushes the crew.
@MainActor
@Observable
final class CrewRouter {
    static let shared = CrewRouter()
    /// The crew to open. Cleared by whoever opens it.
    var open: CrewID?
    /// The win to open in it, when a notification about one was tapped.
    /// Cleared by the crew's tower when it has opened it.
    var openWin: UUID?
    /// The crew's chat to open in it, when a chat notification was tapped.
    /// Cleared by the crew's tower when it has opened it.
    var openChat = false
    /// Tonight's stories to open on the Crews row (the 8pm cue, tapped).
    var openStories = false
    /// Something went wrong joining, in words a person can read.
    var joinProblem: String?
    /// The Crews list should open on New Crew: the first-win invitation was
    /// answered with no crew to invite into. Cleared by the list.
    var startsCrew = false
    /// The Crews list should open, with no crew in it: an invitation that is
    /// waiting for the rules and the age, or one this phone cannot join (too
    /// young, or below iOS 26), whose list says why. Cleared by the list.
    var opensList = false
    /// Not Now on the crew rules, from the Crews tab: back to Wins, since the
    /// tab has nothing to show behind rules that were declined.
    var leaveCrews = false
    /// **An invitation held while the rules and the age are asked**
    /// (2026-10-08). Joined the moment `CrewGate` opens; let go on Not Now,
    /// under 13, or below iOS 26. Never joined first and checked after.
    private(set) var pendingInvite: CrewInvite?

    /// **Kept across launches** (found by review, 2026-10-13). It lived in
    /// memory, so someone who came by a link, was asked the rules or was
    /// still in the first run, and closed the app, came back to a Crews
    /// page offering only New Crew, with the invitation gone. A real
    /// link only, for a week, and let go the moment it is joined or refused.
    static let pendingKey = "crews.pendingInvite"
    static let pendingDays: TimeInterval = 7 * 86_400

    func hold(_ invite: CrewInvite?, defaults: UserDefaults = .standard) {
        pendingInvite = invite
        if let invite { Self.remember(invite, defaults: defaults) } else { Self.forget(defaults: defaults) }
    }

    /// Written down, with the time it was FIRST held: opening the app
    /// again does not start its week again (found by review, 2026-10-13).
    static func remember(_ invite: CrewInvite, now: Date = Date(), defaults: UserDefaults = .standard) {
        guard CrewInviteLink.read(invite.url) != nil else { return }
        let text = invite.url.absoluteString
        let kept = defaults.dictionary(forKey: pendingKey)
        let first = (kept?["url"] as? String) == text ? kept?["at"] as? Double : nil
        defaults.set(["url": text, "at": first ?? now.timeIntervalSince1970] as [String: Any], forKey: pendingKey)
    }

    static func forget(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: pendingKey) }

    /// The invitation kept from an earlier launch, if it is still fresh.
    static func kept(now: Date = Date(), defaults: UserDefaults = .standard) -> CrewInvite? {
        guard let kept = defaults.dictionary(forKey: pendingKey), let text = kept["url"] as? String,
              let at = kept["at"] as? Double, now.timeIntervalSince1970 - at < pendingDays,
              let url = URL(string: text), CrewInviteLink.read(url) != nil else { return nil }
        return CrewInvite(url: url)
    }

    /// At launch: an invitation still waiting is taken up where it was left.
    func resumePending() {
        guard pendingInvite == nil, !joining, CrewsFlag.isOn, let invite = Self.kept() else { return }
        join(invite)
    }
    /// **A join on its way** (the crews audit, 2026-10-08): the list says
    /// "Joining" rather than inviting a person who came by a link to start a
    /// crew of their own while theirs is being opened.
    private(set) var joining = false
    /// **A beat for "it worked"** (the owner, 2026-10-14): a first crew
    /// joined by a link shows his thumbs up where the walking cat was, for
    /// as long as it plays, and then the crew opens.
    private(set) var justJoined = false
    static let joinedBeat = 1.2

    /// What the Wins tab watches to come to the front: a crew, or the list.
    /// A crew asked for from outside, or the list: both are on the Crews
    /// tab (Wins until 2026-10-13).
    var wantsCrewsTab: Bool { open != nil || opensList }

    /// An invitation, from a link or the system's share sheet. Joined now if
    /// the gate is open; otherwise the list opens and asks what it needs.
    func join(_ invite: CrewInvite) {
        switch CrewGate.current {
        case .open:
            // **Written down until it is answered** (found by review,
            // 2026-10-13): let go here, a join that failed with no signal
            // lost the link for good.
            pendingInvite = nil
            Self.remember(invite)
            Task { await accept(invite) }
        case .needsRules, .needsAge:
            hold(invite)
            opensList = true
        case .tooYoung:
            hold(nil)
            opensList = true
        case .needsNewerOS:
            hold(nil)
            joinProblem = CrewGate.newerOSWords
        }
    }

    /// Called whenever the rules are agreed or an age comes back: the held
    /// invitation is joined once nothing stands in the way, and let go if
    /// something always will.
    func joinPendingIfReady() {
        guard let invite = pendingInvite else { return }
        let gate = CrewGate.current
        if gate == .open {
            pendingInvite = nil
            Task { await accept(invite) }
        } else if gate.isFinal {
            hold(nil)
        }
    }

    /// Not Now on the rules: the invitation is not joined.
    func dropPendingInvite() { hold(nil) }

    private static let log = Logger(subsystem: "Strata", category: "crews.invite")

    private func accept(_ invite: CrewInvite) async {
        joining = true
        defer { joining = false }
        do {
            let first = SocialStore.shared.crews.isEmpty
            let crew = try await SocialStore.shared.accept(invite)
            Self.forget()
            if first {
                justJoined = true
                try? await Task.sleep(for: .seconds(Self.joinedBeat))
                justJoined = false
            }
            open = crew.id
        } catch {
            // An answer that will not change (a full crew, five already) is
            // an answer. One the person can mend, or no signal, keeps the
            // invitation for the next time the app opens.
            if let known = error as? CrewError, known != .notSignedIn { Self.forget() }
            joinProblem = CrewErrorWords.say(error, while: .joining)
        }
    }
}

/// The UIKit hooks a SwiftUI app has no modifier for: an accepted CloudKit
/// share and remote notifications. Strata had neither until crews.
final class StrataAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // **Always installed** (the cohesion pass, 2026-10-05). It was set
        // only with Crews on, so with the flag off a tap on any of the app's
        // own notifications reached nothing and opened the Wins tower. Every
        // notification lands on its subject now (`NotificationRoute`).
        UNUserNotificationCenter.current().delegate = self
        // The reminder's Quick, Regular and Deep (`DailyReminder`).
        // The reminder's sizes, and the crews' answers only where answering
        // is allowed: a silent push launches the app in the background too.
        CrewNoteAnswers.register()
        // Below iOS 26 crews do not open, so nothing of them registers.
        guard CrewsFlag.isUsable else { return true }
        // The silent push that says a crew changed. Without the Push
        // capability this simply fails, and crews refresh on foreground.
        application.registerForRemoteNotifications()
        // The crews' own silent push is the public database's query
        // subscription, saved by `PublicCrewCloud` as the crews change.
        return true
    }

    // **The push registration's answer, kept** (`AlertCheck`): without it
    // a phone that never got a token looked the same as one that did.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AlertCheck.note(.push, ok: true)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AlertCheck.note(.push, ok: false, String(describing: error))
    }

    /// A notification tapped: open what it was about. A crew's opens that
    /// crew at its win; the app's own land where `NotificationRoute` says.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        // One of the reminder's sizes: log it where it is, and open nothing.
        if let size = DailyReminder.actions[response.actionIdentifier] {
            do { try await QuickLog.run(size) } catch {
                Logger(subsystem: "JaydenBetts.Strata", category: "Reminder")
                    .error("logging from the reminder failed: \(error)")
            }
            return
        }
        // A reaction or a reply, from the notification itself: done where it
        // is, and nothing opens (`CrewNoteAnswers`).
        if CrewNoteAnswers.handles(response.actionIdentifier) {
            await CrewNoteAnswers.answer(response)
            return
        }
        guard let route = NotificationRoute.of(identifier: request.identifier,
                                               userInfo: request.content.userInfo) else { return }
        let isChat = request.content.userInfo[CrewNotifications.chatKey] != nil
        await MainActor.run {
            if case .crew(let raw, let win) = route {
                guard CrewsFlag.isOn else { return }
                CrewRouter.shared.openWin = win
                CrewRouter.shared.openChat = isChat
                CrewRouter.shared.open = CrewID(rawValue: raw)
            } else {
                LandingRouter.shared.land(route)
            }
        }
    }

    /// In the app, a crew's notification still shows as a banner (the crew on
    /// screen never sends one). Every other notification the app makes keeps
    /// the system's behaviour from before this delegate existed: nothing
    /// while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard let crew = notification.request.content.userInfo["crew"] as? String else { return [] }
        // A ping about the crew you are looking at says nothing new.
        let onScreen = await MainActor.run { CrewNotifications.visibleCrew?.rawValue }
        guard crew != onScreen else { return [] }
        // **On Wins, a friend's line comes in over the tower instead**
        // (`WinsChatBanner`, the owner, 2026-10-13: "chat notifications not
        // noticeable, show message above tower"). Not twice: the system's
        // banner stands down, and the alert fetches the line now rather than
        // at the next refresh, so it is on screen in a moment.
        let isChat = notification.request.content.userInfo[CrewNotifications.chatKey] != nil
        if isChat, await MainActor.run(body: { ChatBanner.isListening }) {
            Task { @MainActor in await SocialStore.shared.pushed() }
            // Into Notification Center, still: the line over the tower can
            // fail to come (the fetch is slow, a new member's record is not
            // here yet, a picture is being checked), and then the alert would
            // have gone nowhere (review, 2026-10-14). No banner, no sound.
            return [.list]
        }
        return [.banner, .list, .sound]
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = StrataSceneDelegate.self
        return configuration
    }

    /// Off the main actor: the payload is not Sendable and nothing in it is
    /// read. A crew changed; fetch.
    nonisolated func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard CrewsFlag.isUsable else { return .noData }
        switch CrewPushRoute.route(userInfo: userInfo) {
        case .notCrews:
            return .noData
        case .crews:
            break
        }
        await SocialStore.shared.pushed()
        return .newData
    }
}

final class StrataSceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Opened from an invitation link while the app was not running.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        for context in options.urlContexts { Self.open(context.url) }
        if let activity = options.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb }),
           let url = activity.webpageURL { Self.open(url) }
    }

    /// Opened from an invitation link while the app was running.
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        for context in contexts { Self.open(context.url) }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL { Self.open(url) }
    }

    /// **A crew invitation is a link now** (2026-10-09): the page or the
    /// app's own `somewins://join#...`, carrying the crew and its key
    /// (`CrewInviteLink`). Through `CrewRouter.join`, which holds it until
    /// the rules and the age are settled.
    static func open(_ url: URL) {
        guard CrewsFlag.isOn, CrewInviteLink.read(url) != nil else { return }
        Task { @MainActor in CrewRouter.shared.join(CrewInvite(url: url)) }
    }

    static func words(for error: CrewError) -> String {
        switch error {
        case .tooManyCrews: "You're in five crews already. Leave one to join this one."
        case .crewFull: "That crew already has eight people."
        case .notSignedIn: "Sign in to iCloud in Settings to join a crew."
        case .flagOff, .notOwner, .unknownCrew: "That crew could not be opened. Try the link again in a moment."
        case .photoNotAllowed: "That photo stays with you."
        case .photoNeeded: "Choose a photo for the crew first."
        case .notReady: "Crews open once the crew rules and your age are set."
        case .wordsRefused: "Try other words."
        }
    }
}
