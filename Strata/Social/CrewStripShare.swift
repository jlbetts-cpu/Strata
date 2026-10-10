import Foundation
import SwiftUI
import UIKit

// MARK: - Your strip, sent into a crew

/// **The goal's photo strip, into a crew** (the unification pass,
/// 2026-10-09: "extend the shareable strip to the crew social component,
/// shareable into the crew and out to Instagram").
///
/// **Out** was already there: the strip's Story card hands a PNG to the
/// system share sheet, which is where Instagram, Messages and the rest live.
/// **In** is the same sheet: each of your crews is a destination in it, next
/// to the apps, so there is still one Share button and no new control.
///
/// **It travels as a chat picture, marked**, for the reasons a toss does
/// (`CrewMessage.tossMarker`): no new record type and no new field, so no
/// schema deploy, and the crew's day, the photo check both ways, blocking,
/// Report and the writer's midnight delete all come with the message. Like
/// every line in a crew's chat, it is gone when the crew's day ends.
///
/// The marker is two INVISIBLE SEPARATORs (U+2063 U+2063), which nobody
/// types and `CrewWords` folds to nothing. A build from before this reads
/// one as a doodle and tints it as ink, which is the honest fallback: it is
/// still the friend's picture, in the crew it was sent to.
extension CrewMessage {
    nonisolated static let stripMarker = "\u{2063}\u{2063}"

    /// A photo strip in the chat, drawn as the picture it is.
    nonisolated var isStrip: Bool { sketch != nil && text == Self.stripMarker }
}

/// One crew as a destination in the strip's share sheet: "Roommates", with
/// the crew's photo, or two people for a crew without one.
final class CrewStripActivity: UIActivity {
    private let crew: Crew
    private let png: Data
    private let sent: (Bool) -> Void

    init(crew: Crew, png: Data, sent: @escaping (Bool) -> Void) {
        self.crew = crew
        self.png = png
        self.sent = sent
    }

    override class var activityCategory: UIActivity.Category { .share }
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("JaydenBetts.Strata.crewStrip.\(crew.id.rawValue)")
    }
    override var activityTitle: String? { crew.displayName(excluding: SocialStore.shared.me) }
    override var activityImage: UIImage? { Self.icon(for: crew) }
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool { true }

    override func perform() {
        let crewID = crew.id
        let png = png
        let sent = sent
        Task { @MainActor in
            let outcome = await SocialStore.shared.sendStrip(png, in: crewID)
            if outcome == .sent {
                HapticsEngine.success()
                Analytics.shared.signal(.stripShared, [.destination(.crew)])
            }
            sent(outcome == .sent)
            self.activityDidFinish(outcome == .sent)
            // **A strip that did not go says so** (found 2026-10-10 by
            // review): the sheet closed the same way either way, and a
            // strip held back by the pace or the photo check simply never
            // arrived.
            if outcome != .sent {
                HapticsEngine.warning()
                let alert = UIAlertController(title: Self.words(for: outcome), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                try? await Task.sleep(for: .milliseconds(450))
                CrewSharing.present(alert)
            }
        }
    }

    /// Why a strip did not reach the crew, in the chat's own words
    /// (`CrewChatSheet`: "That sticker stays with you").
    static func words(for outcome: SocialStore.ReplyOutcome) -> String {
        switch outcome {
        case .sent: ""
        case .refusedSketch: "That strip stays with you"
        case .dailyLimit: "The chat takes more from you when the crew's day starts again."
        case .throttled: "Give it a second, then send it again."
        case .notAllowed, .refusedWords: "The strip didn't send. Try again."
        }
    }

    /// The crew's photo, filling the app-icon square the sheet masks it to;
    /// without one, the people glyph in ink on the page's ground.
    private static func icon(for crew: Crew) -> UIImage {
        let side: CGFloat = 120
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            if let url = crew.photo, let photo = UIImage(contentsOfFile: url.path) {
                let scale = max(side / photo.size.width, side / photo.size.height)
                let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
                photo.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                                      width: size.width, height: size.height))
            } else {
                UIColor.systemBackground.setFill()
                context.fill(rect)
                let glyph = UIImage(systemName: "person.2.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold))?
                    .withTintColor(UIColor(AppColors.inkPrimary), renderingMode: .alwaysOriginal)
                if let glyph {
                    glyph.draw(at: CGPoint(x: (side - glyph.size.width) / 2, y: (side - glyph.size.height) / 2))
                }
            }
        }
    }
}

/// A strip in the crew's chat: the picture itself, a strip's width, on no
/// bubble. A photograph in a speech bubble reads as a message about a
/// photograph; this is the thing.
struct CrewStripPicture: View {
    let url: URL

    static let width: CGFloat = 120

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear.frame(height: Self.width * 3)
            }
        }
        .frame(width: Self.width)
        .task(id: url) {
            image = await Task.detached(priority: .userInitiated) { [url] in
                UIImage(contentsOfFile: url.path)
            }.value
        }
        .accessibilityLabel("A photo strip")
    }
}
