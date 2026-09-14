import SwiftUI
import UIKit

/// A replay's finished tower as a still: the shelf's card and the Share image.
///
/// It is the last frame of the replay, drawn by the same view, at story size.
/// No watermark, for the reason `ShareTowerCard` gives.
///
/// **The still is pinned, so it is one picture everywhere.** Light, because
/// a story is posted to people whose phones are set either way. `.large`
/// type, because a card rendered at a large accessibility size would be a
/// different composition from the one everybody else sees, and its header
/// would crowd the tower.
///
/// **The shelf does not show the still.** Side by side, stills each fitted
/// their own tower, so a month of 86 and a month of 68 stood the same height,
/// and every poster repeated in 5pt type the name and count printed under it.
/// A poster is the tower alone, at its row's shared scale, in the page's
/// scheme.
enum ReplayCard {
    static let size = CGSize(width: 360, height: 640)

    /// Clear of a story's own top bar (progress segments, the account row),
    /// which sits over the top of a posted picture.
    static let topInset: CGFloat = 48

    /// The script every shared picture of `replay` is drawn from: the card's
    /// frame, full motion.
    static func script(_ replay: Replay) -> ReplayScript {
        ReplayScript(replay: replay, metrics: .standard(frame: size), reduceMotion: false)
    }

    /// One moment of the replay as it is shared: the Share still at the end,
    /// and every frame of the saved video. One function, so the two cannot
    /// drift apart in scheme, type size or insets.
    @MainActor
    static func sharedFrame(_ script: ReplayScript, images: ReplayImages, t: Double, now: Date) -> some View {
        ReplayFrame(script: script, images: images, t: t, now: now,
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
    static func image(_ replay: Replay, images: ReplayImages, scale: CGFloat, now: Date = Date()) -> UIImage? {
        let script = Self.script(replay)
        let renderer = ImageRenderer(content: sharedFrame(script, images: images, t: script.duration, now: now))
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
                       rowTowerHeight: CGFloat, colorScheme: ColorScheme) -> UIImage? {
        let script = Self.script(replay)
        let layout = ReplayFrame.Poster(scale: posterScale(rowTowerHeight: rowTowerHeight),
                                        baseY: size.height - posterMargin)
        let renderer = ImageRenderer(content:
            ReplayFrame(script: script, images: images, t: script.duration, poster: layout)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = rendererScale(pixelWidth: size.width * scale)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
