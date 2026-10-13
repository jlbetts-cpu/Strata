import MessageUI
import UIKit

/// **The strip, to one person** (the owner's Launch Pack, 2026-10-12).
///
/// Two channels, on purpose. A post takes the strip alone: no link, nothing
/// on it but the wordmark, and the share sheet still hands it over that way.
/// A message to a friend is three things, each with one job:
///
/// - the strip, as the picture it is;
/// - a line in the sender's own voice, theirs to change before it goes;
/// - a link, last and on its own line, which Messages draws as its own card.
///
/// They cannot ride the share sheet together: a picture sent with words and
/// a link stops being offered to the apps that take a picture alone, which
/// is the other channel. So this is its own row in that sheet.
///
/// **The link is the app's page, never a crew's invite.** An invite link is
/// the crew's key. A strip goes to anyone, and would have carried a way
/// into the sender's crew with it.
///
/// **Unseen on a phone.** The simulator sends no messages. Whether Messages
/// draws the link as a card of its own is the thing to look at.
final class StripMessageActivity: UIActivity, MFMessageComposeViewControllerDelegate {
    /// His line, and the one he kept in reserve (`docs/voice.md`).
    static let line = "Today was a good one. Some of it's in here."
    /// The app's own page (`docs/index.html`), until somewins.xyz points at it.
    static let page = "https://jlbetts-cpu.github.io/Strata/"
    /// What goes in the field: the line, then the link alone on the last
    /// line, which is where Messages makes a card of one.
    static let body = "\(line)\n\(page)"

    private let png: URL
    private let day: String

    init(png: URL, day: String) {
        self.png = png
        self.day = day
    }

    override class var activityCategory: UIActivity.Category { .share }
    override var activityType: UIActivity.ActivityType? { UIActivity.ActivityType("JaydenBetts.Strata.stripMessage") }
    override var activityTitle: String? { "Text a Friend" }
    override var activityImage: UIImage? { UIImage(systemName: "message") }
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        MFMessageComposeViewController.canSendText() && MFMessageComposeViewController.canSendAttachments()
    }

    override var activityViewController: UIViewController? {
        let compose = MFMessageComposeViewController()
        compose.messageComposeDelegate = self
        compose.body = Self.body
        if let data = try? Data(contentsOf: png) {
            compose.addAttachmentData(data, typeIdentifier: "public.png", filename: "Some Wins \(day).png")
        }
        return compose
    }

    nonisolated func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                                  didFinishWith result: MessageComposeResult) {
        let sent = result == .sent
        Task { @MainActor in
            if sent {
                HapticsEngine.success()
                Analytics.shared.signal(.stripShared, [.destination(.other)])
            }
            self.activityDidFinish(sent)
        }
    }
}
