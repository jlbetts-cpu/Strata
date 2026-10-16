import SwiftUI
import UIKit

/// **Your story, to Instagram, in one tap** (the owner, 2026-10-16, his pick:
/// "build one-tap share"). Instagram lets no app post to a personal account's
/// story by itself; it takes a picture handed over on the pasteboard and
/// opens on it, and the person presses Share there. That is Meta's own
/// documented way (Sharing to Stories): the pasteboard keys below and the
/// `instagram-stories` scheme, with the app's Meta App ID as the source.
///
/// **Off until the App ID is set** (`appID`, from the owner's checklist): with
/// none, Instagram refuses the hand-over, so the button is not shown at all.
@MainActor
enum InstagramShare {
    /// The Meta App ID. Empty: the share is not offered.
    static let appID = ""

    static var isReady: Bool {
        guard !appID.isEmpty, let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// What goes on the pasteboard for Instagram: the picture as the story's
    /// background, and whose it is. Five minutes, then it is gone.
    nonisolated static func items(background: Data, appID: String) -> [[String: Any]] {
        [["com.instagram.sharedSticker.backgroundImage": background,
          "com.instagram.sharedSticker.appID": appID]]
    }

    /// Hands the card to Instagram and opens it. False when it could not.
    @discardableResult
    static func share(_ card: UIImage) async -> Bool {
        guard isReady, let png = card.pngData(),
              let url = URL(string: "instagram-stories://share?source_application=\(appID)") else { return false }
        UIPasteboard.general.setItems(items(background: png, appID: appID),
                                      options: [.expirationDate: Date().addingTimeInterval(300)])
        return await UIApplication.shared.open(url)
    }

    /// Your story as one 9:16 card: its picture, your line, the app's name.
    static func card(picture: UIImage?, line: String?) -> UIImage? {
        let renderer = ImageRenderer(content: StoryShareCard(picture: picture, line: line))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// **The card Instagram is handed**: the warm page, your story's picture as
/// a print, your line in quotes under it, and the app's name, quiet. 360 by
/// 640 points, drawn at 3x: 1080 by 1920, a story's own size.
struct StoryShareCard: View {
    let picture: UIImage?
    let line: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            Group {
                if let picture {
                    Image(uiImage: picture).resizable().scaledToFill()
                } else {
                    AppColors.quietFill
                }
            }
            .frame(width: 280, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
            if let line, !line.isEmpty {
                Text("\u{201C}\(line)\u{201D}")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer(minLength: 0)
            Text("Some Wins")
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkSecondary)
                .padding(.bottom, 36)
        }
        .frame(width: 360, height: 640)
        .background(WarmBackground())
        .environment(\.colorScheme, .light)
    }
}
