import LinkPresentation
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
    static let message = "Join my crew on Some Wins"

    /// A picture of the inviter's tower for the next invitation made, when
    /// the invitation is made somewhere else: the first-win card hands it
    /// over and opens New Crew, and New Crew's own invite picks it up.
    /// Consumed by the next `invite`.
    static var nextCard: UIImage?

    /// **`card`: a picture of your tower** (`TowerShare`, the 9:16 card),
    /// for the first-win invitation (`FirstWinInvite`): the link's preview.
    ///
    /// **A link, not an iCloud share** (2026-10-09, crews moved to the public
    /// database). The system share sheet sends `CrewInviteLink`'s page with
    /// a rich preview (the crew's name and your tower), so Messages shows a
    /// card a friend taps to open the app straight into the crew.
    static func invite(_ crewID: CrewID, card: UIImage? = nil) async {
        let card = card ?? nextCard
        nextCard = nil
        let store = SocialStore.shared
        do {
            let url = try await store.inviteURL(for: crewID)
            // Only a name somebody typed. An unnamed crew is shown by its
            // people, so a pair's invite read "Join Sam on Some Wins" and a
            // new one "Join New Crew on Some Wins".
            let name = store.crew(crewID)?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = name.isEmpty ? message : "Join \(name) on Some Wins"
            let sheet = UIActivityViewController(activityItems: [InviteItem(url: url, title: title, card: card)],
                                                 applicationActivities: nil)
            // **Counted when it went, not when the sheet opened** (the invites
            // research, 2026-10-13): opened-and-closed counted as an invite,
            // so the one number that says whether invites work could not be
            // read.
            sheet.completionWithItemsHandler = { _, completed, _, _ in
                if completed { Analytics.shared.signal(.crewInviteSent) }
            }
            present(sheet)
        } catch {
            CrewRouter.shared.joinProblem = CrewErrorWords.say(error, while: .inviting)
        }
    }

    /// Over whatever is on top, from anywhere: the invite here, and the
    /// strip's share sheet (`StripStoryComposer`).
    static func present(_ controller: UIViewController) {
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

/// The invitation as the share sheet carries it: the link, titled with the
/// crew, previewed with your tower or, without one, the app's icon.
private final class InviteItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let card: UIImage?

    init(url: URL, title: String, card: UIImage?) {
        self.url = url
        self.title = title
        self.card = card
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { url }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType type: UIActivity.ActivityType?) -> Any? { url }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType type: UIActivity.ActivityType?) -> String { title }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        if let card { metadata.imageProvider = NSItemProvider(object: card) }
        return metadata
    }
}
