import UIKit

/// Every photograph a replay shows, decoded before it plays.
///
/// Live playback could let blocks decode as they fall, but the saved video is
/// drawn with `ImageRenderer`, which does not wait for anything. Loading first
/// is what lets the live view and the video draw the same frames.
struct ReplayImages {
    private var byKey: [String: UIImage] = [:]

    subscript(_ photo: ReplayPhoto?) -> UIImage? {
        photo.flatMap { byKey[$0.key] }
    }

    /// `width` is one CELL's side in PIXELS (points times the display or
    /// export scale).
    static func load(_ replay: Replay, width: CGFloat) async -> ReplayImages {
        var out = ReplayImages()
        // One decode width for every block, for the reason CLAUDE.md gives the
        // map: the widest block is a 2x2, two cells across, so one decode at
        // that size serves every smaller block without a second read.
        let decodeWidth = (width * 2).rounded()
        for photo in Set(replay.blocks.compactMap(\.win.photo)) {
            switch photo {
            case .bundled(let name):
                // `UIImage(named:)` is decoded lazily, on first draw, which is
                // exactly what `ImageRenderer` cannot wait for. Downsampled and
                // decoded here instead, to the same width a stored photo gets.
                guard let image = UIImage(named: name) else { continue }
                let side = min(decodeWidth, image.size.width * image.scale)
                let size = CGSize(width: side, height: (side * image.size.height / max(image.size.width, 1)).rounded())
                out.byKey[photo.key] = await image.byPreparingThumbnail(ofSize: size) ?? image
            case .stored(let name):
                out.byKey[photo.key] = await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: decodeWidth)
            }
        }
        return out
    }
}
