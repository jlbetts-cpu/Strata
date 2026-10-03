import CloudKit
import UIKit

/// Inviting people: the system's own share sheet, set up for collaboration.
///
/// **Not a contact picker and a message composer of our own.** iOS already
/// does this better: the share sheet puts the people you message most at the
/// top, and sent through Messages the invitation arrives as a collaboration
/// bubble with the crew's name, which joins with one tap. Contacts never pass
/// through the app and nothing is uploaded (spec 2.3, revised 2026-10-02).
///
/// Only the people sent the link can join (`specifiedRecipientsOnly`), and on
/// iOS 26 anyone in the crew may invite (the owner's call: everyone edits,
/// like Messages).
@MainActor
enum CrewSharing {
    static let message = "Join my crew on Sturdy"

    static func invite(_ crewID: CrewID) async {
        let store = SocialStore.shared
        do {
            if let cloud = store.cloud as? CloudKitCrewCloud {
                let share = try await cloud.share(for: crewID)
                if let crew = store.crew(crewID) {
                    share[CKShare.SystemFieldKey.title] = crew.displayName(excluding: store.me)
                }
                let options = CKAllowedSharingOptions(allowedParticipantPermissionOptions: .readWrite,
                                                      allowedParticipantAccessOptions: .specifiedRecipientsOnly)
                if #available(iOS 26.0, *) { options.allowsParticipantsToInviteOthers = true }
                let provider = NSItemProvider()
                provider.registerCKShare(share, container: cloud.container, allowedSharingOptions: options)
                present(UIActivityViewController(activityItemsConfiguration:
                    UIActivityItemsConfiguration(itemProviders: [provider])))
            } else {
                let url = try await store.inviteURL(for: crewID)
                present(UIActivityViewController(activityItems: [message, url], applicationActivities: nil))
            }
        } catch {
            CrewRouter.shared.joinProblem = (error as? CrewError) == .crewFull
                ? "This crew already has eight people."
                : "The invitation could not be made: \(error.localizedDescription)"
        }
    }

    private static func present(_ controller: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        guard var top = window?.rootViewController else { return }
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        if let popover = controller.popoverPresentationController, let window {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: 80, width: 1, height: 1)
        }
        top.present(controller, animated: true)
    }
}
