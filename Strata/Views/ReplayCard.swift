import SwiftUI
import UIKit

/// A replay's finished tower as a still: the shelf's card and the Share image.
///
/// It is the last frame of the replay, drawn by the same view, at story size.
/// No watermark, for the reason `ShareTowerCard` gives.
///
/// **Pinned, so it is one picture everywhere.** Light, because a story is
/// posted to people whose phones are set either way, and the shelf's row of
/// posters should not flip with the drawer. `.large` type, because a card
/// rendered at a large accessibility size would be a different composition
/// from the one everybody else sees, and its header would crowd the tower.
enum ReplayCard {
    static let size = CGSize(width: 360, height: 640)

    /// Clear of a story's own top bar (progress segments, the account row),
    /// which sits over the top of a posted picture.
    static let topInset: CGFloat = 48

    @MainActor
    static func image(_ replay: Replay, images: ReplayImages, scale: CGFloat, now: Date = Date()) -> UIImage? {
        let script = ReplayScript(replay: replay, metrics: .standard(frame: size), reduceMotion: false)
        let renderer = ImageRenderer(content:
            ReplayFrame(script: script, images: images, t: script.duration, now: now,
                        topInset: topInset, bottomInset: 0)
                .environment(\.colorScheme, .light)
                .dynamicTypeSize(.large)
        )
        // A hair under the whole-pixel width. `132 * 3 / 360` is 1.1, and
        // 360 * 1.1 in floating point is 396.00000000000006, so the bitmap
        // came out 397 pixels wide with its last column never drawn: opaque,
        // that column is black, and it showed as a hairline down the edge of
        // the August poster on the shelf.
        let pixels = max(1, (size.width * scale).rounded())
        renderer.scale = (pixels - 0.01) / size.width
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The cell a card's blocks are laid out at, for decoding its photographs.
    static var cell: CGFloat { ReplayScript.Metrics.standard(frame: size).cell }
}
