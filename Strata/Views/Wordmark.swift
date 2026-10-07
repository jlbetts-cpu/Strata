import SwiftUI

/// **The wordmark: the camera and "Some Wins"** (the owner, 2026-10-06: a
/// face like HeyTea's "so we can put it on the photo strips"; his pick, Zen
/// Maru Gothic).
///
/// Zen Maru Gothic Bold, bundled (`Shared/ZenMaruGothic-Bold.ttf`, subset to
/// Latin, 35KB) under the SIL Open Font License, whose text travels with it
/// (`Shared/ZenMaruGothic-OFL.txt`). Not SF Pro Rounded: Apple's licence
/// lets the system face set an app's text but not a brand's logotype, and
/// this one goes onto pictures shared to Instagram and the App Store.
struct Wordmark: View {
    /// The type's size; the camera is drawn a little taller than its capitals.
    var size: CGFloat = 17

    static let fontName = "ZenMaruGothic-Bold"

    var body: some View {
        HStack(spacing: size * 0.35) {
            if let mark = UIImage(named: "BrandCamera")?.withRenderingMode(.alwaysTemplate) {
                Image(uiImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 1.25, height: size * 1.25)
            }
            Text("Some Wins")
                .font(.custom(Self.fontName, fixedSize: size))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Some Wins")
    }
}
