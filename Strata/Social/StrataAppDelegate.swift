import CloudKit
import Observation
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
    /// Something went wrong joining, in words a person can read.
    var joinProblem: String?
}

/// The UIKit hooks a SwiftUI app has no modifier for: an accepted CloudKit
/// share and remote notifications. Strata had neither until crews.
final class StrataAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = StrataSceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication,
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
        }
    }
}
