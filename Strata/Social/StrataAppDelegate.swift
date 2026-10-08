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
    /// Something went wrong joining, in words a person can read.
    var joinProblem: String?
    /// The Crews list should open on New Crew: the first-win invitation was
    /// answered with no crew to invite into. Cleared by the list.
    var startsCrew = false
    /// The Crews list should open, with no crew in it: an invitation that is
    /// waiting for the rules and the age, or one this phone cannot join (too
    /// young, or below iOS 26), whose list says why. Cleared by the list.
    var opensList = false
    /// **An invitation held while the rules and the age are asked**
    /// (2026-10-08). Joined the moment `CrewGate` opens; let go on Not Now,
    /// under 13, or below iOS 26. Never joined first and checked after.
    private(set) var pendingInvite: CrewInvite?

    /// What the Wins tab watches to come to the front: a crew, or the list.
    var wantsWinsTab: Bool { open != nil || opensList }

    /// An invitation, from a link or the system's share sheet. Joined now if
    /// the gate is open; otherwise the list opens and asks what it needs.
    func join(_ invite: CrewInvite) {
        switch CrewGate.current {
        case .open:
            pendingInvite = nil
            Task { await accept(invite) }
        case .needsRules, .needsAge:
            pendingInvite = invite
            opensList = true
        case .tooYoung:
            pendingInvite = nil
            opensList = true
        case .needsNewerOS:
            pendingInvite = nil
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
            pendingInvite = nil
        }
    }

    /// Not Now on the rules: the invitation is not joined.
    func dropPendingInvite() { pendingInvite = nil }

    private static let log = Logger(subsystem: "Strata", category: "crews.invite")

    private func accept(_ invite: CrewInvite) async {
        do {
            let crew = try await SocialStore.shared.accept(invite)
            open = crew.id
        } catch let error as CrewError {
            Self.log.error("joining failed: \(String(describing: error), privacy: .public)")
            joinProblem = StrataSceneDelegate.words(for: error)
        } catch {
            Self.log.error("joining failed: \(error)")
            joinProblem = "That crew could not be opened. Try the link again in a moment."
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
        UNUserNotificationCenter.current().setNotificationCategories([DailyReminder.notificationCategory])
        // Below iOS 26 crews do not open, so nothing of them registers.
        guard CrewsFlag.isUsable else { return true }
        // The silent push that says a crew changed. Without the Push
        // capability this simply fails, and crews refresh on foreground.
        application.registerForRemoteNotifications()
        Task { @MainActor in
            if let cloud = SocialStore.shared.cloud as? CloudKitCrewCloud {
                await CrewNotifications.subscribe(cloud.container)
            }
        }
        return true
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
        return crew == onScreen ? [] : [.banner, .list, .sound]
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
        await SocialStore.shared.refresh()
        return .newData
    }
}

final class StrataSceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Opened from an invitation while the app was not running.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let metadata = options.cloudKitShareMetadata { join(metadata) }
    }

    /// Opened from an invitation while the app was running.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        join(metadata)
    }

    /// Through `CrewRouter.join`, which holds the invitation until the
    /// rules and the age are settled (2026-10-08): accepting the share is
    /// what makes you a participant, so it waits too.
    private func join(_ metadata: CKShare.Metadata) {
        guard CrewsFlag.isOn, let url = metadata.share.url else { return }
        let invite = CrewInvite(url: url, metadata: metadata)
        Task { @MainActor in CrewRouter.shared.join(invite) }
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
        }
    }
}
