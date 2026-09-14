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

    /// How many pixels on its longest side a photograph is decoded at, for
    /// the largest block that shows it.
    ///
    /// **Per photograph, sized to its block.** Every photograph used to be
    /// decoded two cells wide, the widest block, so a month of 300 1x1
    /// photographs held four times the pixels it could draw.
    ///
    /// - `cellPixels`: one cell's side in PIXELS (points times the display or
    ///   export scale).
    /// - `span`: the block's larger span, 1 or 2 cells.
    ///
    /// The 4/3 is the fill: a block draws its photograph aspect-FILLED, and
    /// the decode bounds the LONGEST side. A 3:4 photograph filling a square
    /// needs its short side one cell across, so its long side 4/3 of a cell;
    /// at exactly one cell it would be drawn at 0.75x and soft in the video.
    /// Capped at the two cells every photograph got before, so no block's
    /// photograph is sharper or heavier than it was, only the smaller ones
    /// lighter (a 1x1's decode is 44% of the pixels it was).
    static func decodeSide(cellPixels: CGFloat, span: Int) -> CGFloat {
        (min(cellPixels * CGFloat(span) * 4 / 3, cellPixels * 2)).rounded()
    }

    /// Decodes every photograph `replay` shows. One decode per photograph,
    /// at the size its largest block needs.
    static func load(_ replay: Replay, cellPixels: CGFloat) async -> ReplayImages {
        var spans: [ReplayPhoto: Int] = [:]
        for block in replay.blocks {
            guard let photo = block.win.photo else { continue }
            spans[photo] = max(spans[photo] ?? 0, max(block.columnSpan, block.rowSpan))
        }
        var out = ReplayImages()
        // Concurrently, as `DebugHarness.runImageBench` measured the store
        // allows: a month can hold dozens of photographs and a serial load
        // is a wait in front of the replay. Each child returns its result;
        // only this task, on the main actor, writes `out`.
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for (photo, span) in spans {
                let key = photo.key
                let decodeWidth = decodeSide(cellPixels: cellPixels, span: span)
                switch photo {
                case .bundled(let name):
                    group.addTask { (key, await decodeBundled(name, width: decodeWidth)) }
                case .stored(let name):
                    group.addTask {
                        (key, await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: decodeWidth))
                    }
                }
            }
            for await (key, image) in group {
                if let image { out.byKey[key] = image }
            }
        }
        return out
    }

    /// `UIImage(named:)` is decoded lazily, on first draw, which is exactly
    /// what `ImageRenderer` cannot wait for. Downsampled and decoded here
    /// instead, bounded on its longest side as a stored photo's decode is.
    /// Off the main actor: both calls are thread-safe.
    nonisolated private static func decodeBundled(_ name: String, width: CGFloat) async -> UIImage? {
        guard let image = UIImage(named: name) else { return nil }
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let fit = min(1, width / max(pixels.width, pixels.height, 1))
        let size = CGSize(width: (pixels.width * fit).rounded(), height: (pixels.height * fit).rounded())
        return await image.byPreparingThumbnail(ofSize: size) ?? image
    }
}
