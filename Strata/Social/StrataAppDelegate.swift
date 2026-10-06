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
    /// Something went wrong joining, in words a person can read.
    var joinProblem: String?
    /// The Crews list should open on New Crew: the first-win invitation was
    /// answered with no crew to invite into. Cleared by the list.
    var startsCrew = false
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
        guard CrewsFlag.isOn else { return true }
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
        guard let route = NotificationRoute.of(identifier: request.identifier,
                                               userInfo: request.content.userInfo) else { return }
        await MainActor.run {
            if case .crew(let raw, let win) = route {
                guard CrewsFlag.isOn else { return }
                CrewRouter.shared.openWin = win
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
        guard CrewsFlag.isOn else { return .noData }
        await SocialStore.shared.refresh()
        return .newData
    }
}

final class StrataSceneDelegate: NSObject, UIWindowSceneDelegate {
    private static let log = Logger(subsystem: "Strata", category: "crews.invite")

    /// Opened from an invitation while the app was not running.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let metadata = options.cloudKitShareMetadata { join(metadata) }
    }

    /// Opened from an invitation while the app was running.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        join(metadata)
    }

    private func join(_ metadata: CKShare.Metadata) {
        guard CrewsFlag.isOn, let url = metadata.share.url else { return }
        let invite = CrewInvite(url: url, metadata: metadata)
        Task { @MainActor in
            do {
                let crew = try await SocialStore.shared.accept(invite)
                CrewRouter.shared.open = crew.id
            } catch let error as CrewError {
                Self.log.error("joining failed: \(String(describing: error), privacy: .public)")
                CrewRouter.shared.joinProblem = Self.words(for: error)
            } catch {
                Self.log.error("joining failed: \(error)")
                CrewRouter.shared.joinProblem = "That crew could not be opened. Try the link again in a moment."
            }
        }
    }

    static func words(for error: CrewError) -> String {
        switch error {
        case .tooManyCrews: "You're in five crews already. Leave one to join this one."
        case .crewFull: "That crew already has eight people."
        case .notSignedIn: "Sign in to iCloud in Settings to join a crew."
        case .flagOff, .notOwner, .unknownCrew: "That crew could not be opened. Try the link again in a moment."
        case .photoNotAllowed: "That photo stays with you."
        case .photoNeeded: "Choose a photo for the crew first."
        }
    }
}
