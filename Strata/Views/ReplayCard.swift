import SwiftUI
import UIKit

/// The replay at story size: every frame of the saved video, and the shelf's
/// posters. No watermark, for the reason `ShareTowerCard` gives.
///
/// **The video is pinned, so it is one picture everywhere.** Light, because
/// a story is posted to people whose phones are set either way. `.large`
/// type, because a video rendered at a large accessibility size would be a
/// different composition from the one everybody else sees, and its count
/// would crowd the tower.
///
/// **The shelf does not show the still.** Side by side, stills each fitted
/// their own tower, so a month of 86 and a month of 68 stood the same height,
/// and every poster repeated in 5pt type the name and count printed under it.
/// A poster is the tower alone, at its row's shared scale, in the page's
/// scheme.
enum ReplayCard {
    static let size = CGSize(width: 360, height: 640)
    /// Every frame of the saved video is the card at this scale: 1080x1920.
    static let shareScale: CGFloat = 3

    /// Clear of a story's own top bar (progress segments, the account row),
    /// which sits over the top of a posted picture.
    static let topInset: CGFloat = 48

    /// The script every shared picture of `replay` is drawn from: the card's
    /// frame, full motion.
    static func script(_ replay: Replay) -> ReplayScript {
        ReplayScript(replay: replay,
                     metrics: .standard(frame: size, topInset: topInset, topCopy: ReplayFrame.topCopyHeight(.large)),
                     reduceMotion: false)
    }

    /// One moment of the replay as it is shared: every frame of the saved
    /// video, and the DEBUG still an export is checked against. One
    /// function, so the two cannot drift apart in scheme, type size or
    /// insets.
    @MainActor
    static func sharedFrame(_ script: ReplayScript, images: ReplayImages, t: Double, now: Date,
                            isSample: Bool) -> some View {
        ReplayFrame(script: script, images: images, t: t, now: now,
                    showsSampleBadge: isSample,
                    topInset: topInset, bottomInset: 0)
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
    }

    /// The renderer scale that gives exactly `pixelWidth` pixels across the
    /// card.
    ///
    /// A hair under the whole-pixel width. `132 * 3 / 360` is 1.1, and
    /// 360 * 1.1 in floating point is 396.00000000000006, so the bitmap
    /// came out 397 pixels wide with its last column never drawn: opaque,
    /// that column is black, and it showed as a hairline down the edge of
    /// the August poster on the shelf.
    static func rendererScale(pixelWidth: CGFloat) -> CGFloat {
        (max(1, pixelWidth.rounded()) - 0.01) / size.width
    }

    @MainActor
    static func image(_ replay: Replay, images: ReplayImages, scale: CGFloat, now: Date, isSample: Bool) -> UIImage? {
        let script = Self.script(replay)
        let renderer = ImageRenderer(content: sharedFrame(script, images: images, t: script.duration, now: now,
                                                          isSample: isSample))
        renderer.scale = rendererScale(pixelWidth: size.width * scale)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The cell a card's blocks are laid out at, for decoding its photographs.
    static var cell: CGFloat { ReplayScript.Metrics.standard(frame: size).cell }

    // MARK: - The shelf's poster

    /// A month's poster on the shelf, in points.
    static let monthPosterWidth: CGFloat = 132
    /// A week's, smaller, in the row under the months.
    static let weekPosterWidth: CGFloat = 96

    /// Room above the row's tallest tower and below every base, in frame
    /// points (about 9pt on a month poster).
    static let posterMargin: CGFloat = 24

    /// The scale every poster in a row is drawn at: the row's tallest tower
    /// fills the poster's height less its margins, unless the grid's width
    /// runs out first. Shared, so a month of 86 wins stands visibly taller
    /// than one of 68 instead of each tower being fitted to its own card.
    static func posterScale(rowTowerHeight: CGFloat) -> CGFloat {
        let m = ReplayScript.Metrics.standard(frame: size)
        let gridWidth = GridConstants.gridWidth(cellSize: m.cell)
        let byHeight = (size.height - 2 * posterMargin) / max(rowTowerHeight, 1)
        let byWidth = (size.width - 2 * posterMargin) / max(gridWidth, 1)
        return min(byHeight, byWidth)
    }

    /// The finished tower alone: no header, no running label, no close.
    /// Drawn in the viewer's scheme, since it sits on the page; Share and
    /// the video keep the light still above.
    @MainActor
    static func poster(_ replay: Replay, images: ReplayImages, scale: CGFloat,
                       rowTowerHeight: CGFloat, colorScheme: ColorScheme, now: Date) -> UIImage? {
        let script = Self.script(replay)
        let layout = ReplayFrame.Poster(scale: posterScale(rowTowerHeight: rowTowerHeight),
                                        baseY: size.height - posterMargin)
        let renderer = ImageRenderer(content:
            ReplayFrame(script: script, images: images, t: script.duration, now: now, poster: layout)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = rendererScale(pixelWidth: size.width * scale)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
