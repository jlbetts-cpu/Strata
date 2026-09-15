import SwiftUI
import UIKit

/// Every photograph a replay shows, decoded.
///
/// The saved video is drawn with `ImageRenderer`, which does not wait for
/// anything, so the exporter and the shelf's posters are only ever given a
/// complete set. The live replay is not: it starts once the photographs for
/// its first seconds are in and takes the rest as they come
/// (`ReplayImageLoad`). Both draw from these same decoded images, which is
/// what lets the live view and the video draw the same frames.
struct ReplayImages {
    private var byKey: [String: UIImage] = [:]

    subscript(_ photo: ReplayPhoto?) -> UIImage? {
        photo.flatMap { byKey[$0.key] }
    }

    var count: Int { byKey.count }

    mutating func insert(_ image: UIImage, for photo: ReplayPhoto) {
        byKey[photo.key] = image
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

    /// Each photograph `replay` shows once, in the order it first appears,
    /// with the largest span any block showing it has.
    static func photos(_ replay: Replay) -> [(photo: ReplayPhoto, span: Int)] {
        var order: [ReplayPhoto] = []
        var spans: [ReplayPhoto: Int] = [:]
        for block in replay.blocks {
            guard let photo = block.win.photo else { continue }
            if spans[photo] == nil { order.append(photo) }
            spans[photo] = max(spans[photo] ?? 0, max(block.columnSpan, block.rowSpan))
        }
        return order.map { ($0, spans[$0]!) }
    }

    /// How many decodes run at once. Enough to use every core, few enough
    /// that the photographs needed first are finished first instead of every
    /// photograph in a month sharing the cores equally.
    static var concurrentDecodes: Int { max(4, ProcessInfo.processInfo.activeProcessorCount) }

    /// Decodes every photograph `replay` shows, and returns once they are
    /// all in. One decode per photograph, at the size its largest block
    /// needs. For the shelf and tests; the live replay uses `ReplayImageLoad`.
    static func load(_ replay: Replay, cellPixels: CGFloat) async -> ReplayImages {
        var out = ReplayImages()
        await decode(photos(replay), cellPixels: cellPixels) { photo, image in
            out.insert(image, for: photo)
        }
        return out
    }

    /// Decodes `photos` in order, `concurrentDecodes` at a time, calling
    /// `arrived` on the calling actor as each finishes. Only this function's
    /// own task calls `arrived`, so what it writes needs no lock.
    static func decode(_ photos: [(photo: ReplayPhoto, span: Int)], cellPixels: CGFloat,
                       arrived: (ReplayPhoto, UIImage) -> Void) async {
        await withTaskGroup(of: (ReplayPhoto, UIImage?).self) { group in
            var next = 0
            func addNext() {
                guard next < photos.count else { return }
                let (photo, span) = photos[next]
                next += 1
                let width = decodeSide(cellPixels: cellPixels, span: span)
                switch photo {
                case .bundled(let name):
                    group.addTask { (photo, await decodeBundled(name, width: width)) }
                case .stored(let name):
                    group.addTask { (photo, await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: width)) }
                }
            }
            for _ in 0..<concurrentDecodes { addNext() }
            for await (photo, image) in group {
                if let image { arrived(photo, image) }
                addNext()
            }
        }
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

/// The live replay's photographs, arriving.
///
/// **The replay starts before every photograph is in** (the owner,
/// 2026-09-15: "the loading is slow"). It waits only for the photographs of
/// the blocks that appear in its first `startWindow` seconds from where it
/// starts, decoding in drop order, and the rest keep decoding while it
/// plays. A block whose photograph is not in yet draws its colour, as every
/// block does while it decodes, and the picture fades in over `fade` when it
/// lands. That fade runs on the wall clock, not the script: it is live only.
/// Save Video and Share wait for `all()`, so the video never has a blank.
@MainActor
@Observable
final class ReplayImageLoad {
    /// What has decoded so far. Published a picture at a time once the
    /// replay is playing; the frames are redrawn every tick anyway.
    private(set) var images = ReplayImages()
    /// The photographs for the first seconds are in: the clock may start.
    private(set) var canPlay = false
    /// Every photograph is in and every fade has finished, so a finished
    /// replay may stop asking for frames.
    private(set) var settled = false

    @ObservationIgnored private var arrivals: [String: Date] = [:]
    @ObservationIgnored private var started = false
    @ObservationIgnored private var playWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var allTask: Task<ReplayImages, Never>?

    /// How long ahead of the starting moment the replay's photographs must
    /// already be decoded.
    static let startWindow: Double = 2
    /// How long a photograph that arrives during playback takes to fade in.
    static let fade: Double = 0.25

    /// The photographs the replay needs before it may start at `from`: those
    /// of every block that has appeared by `from + startWindow`.
    static func required(_ script: ReplayScript, from start: Double) -> Set<String> {
        Set(script.replay.blocks.indices.compactMap { i -> String? in
            guard script.appearTime(ofBlock: i) <= start + startWindow else { return nil }
            return script.replay.blocks[i].win.photo?.key
        })
    }

    /// Begins decoding, once per load. `required` photographs gate `canPlay`.
    func start(_ replay: Replay, cellPixels: CGFloat, required: Set<String>) {
        guard !started else { return }
        started = true
        let photos = ReplayImages.photos(replay)
        var missing = required.intersection(photos.map(\.photo.key))
        if missing.isEmpty { becomePlayable() }
        // The photographs the start waits for go first, on their own: queued
        // behind the rest of a month's first window, the three a start needed
        // shared the cores with ten and took 2.1s of a 5.3s load.
        let first = photos.filter { required.contains($0.photo.key) }
        let rest = photos.filter { !required.contains($0.photo.key) }
        allTask = Task { [weak self] in
            var decoded = ReplayImages()
            for batch in [first, rest] where !batch.isEmpty {
                await ReplayImages.decode(batch, cellPixels: cellPixels) { photo, image in
                    decoded.insert(image, for: photo)
                    guard let self else { return }
                    if self.canPlay {
                        self.arrivals[photo.key] = Date()
                        self.images.insert(image, for: photo)
                    } else {
                        missing.remove(photo.key)
                        if missing.isEmpty {
                            self.images = decoded
                            self.becomePlayable()
                        }
                    }
                }
                // A photograph that failed to decode is never going to
                // arrive: start with what there is.
                if let self, !self.canPlay {
                    self.images = decoded
                    self.becomePlayable()
                }
            }
            guard let self else { return decoded }
            try? await Task.sleep(for: .seconds(Self.fade))
            self.settled = true
            return decoded
        }
    }

    private func becomePlayable() {
        canPlay = true
        let waiting = playWaiters
        playWaiters = []
        waiting.forEach { $0.resume() }
    }

    /// Returns once the replay may start.
    func untilPlayable() async {
        if canPlay { return }
        await withCheckedContinuation { playWaiters.append($0) }
    }

    /// Every photograph, once all have decoded. For the video.
    func all() async -> ReplayImages {
        await allTask?.value ?? images
    }

    /// How far `photo` has faded in at `date`: 1 for anything that was in
    /// before playback started.
    func opacity(_ photo: ReplayPhoto, at date: Date) -> Double {
        guard let arrived = arrivals[photo.key] else { return 1 }
        return min(max(date.timeIntervalSince(arrived) / Self.fade, 0), 1)
    }
}
