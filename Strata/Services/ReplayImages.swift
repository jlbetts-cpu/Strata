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
        // One decode width for every block, for the reason CLAUDE.md gives the
        // map: the widest block is a 2x2, two cells across, so one decode at
        // that size serves every smaller block without a second read.
        let decodeWidth = (width * 2).rounded()
        let photos = Set(replay.blocks.compactMap(\.win.photo))
        var out = ReplayImages()
        // Concurrently, as `DebugHarness.runImageBench` measured the store
        // allows: a month can hold dozens of photographs and a serial load
        // is a wait in front of the replay. Each child returns its result;
        // only this task, on the main actor, writes `out`.
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for photo in photos {
                let key = photo.key
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
    /// instead, to the same width a stored photo gets. Off the main actor:
    /// both calls are thread-safe.
    nonisolated private static func decodeBundled(_ name: String, width: CGFloat) async -> UIImage? {
        guard let image = UIImage(named: name) else { return nil }
        let side = min(width, image.size.width * image.scale)
        let size = CGSize(width: side, height: (side * image.size.height / max(image.size.width, 1)).rounded())
        return await image.byPreparingThumbnail(ofSize: size) ?? image
    }
}
