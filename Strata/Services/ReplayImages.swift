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
            if let image { out.insert(image, for: photo) }
        }
        return out
    }

    /// Decodes `photos` in order, `concurrentDecodes` at a time, calling
    /// `arrived` on the calling actor as each finishes, with nil for one that
    /// could not be decoded. Only this function's own task calls `arrived`,
    /// so what it writes needs no lock. Stops starting new decodes when its
    /// task is cancelled.
    static func decode(_ photos: [(photo: ReplayPhoto, span: Int)], cellPixels: CGFloat,
                       arrived: (ReplayPhoto, UIImage?) -> Void) async {
        await withTaskGroup(of: (ReplayPhoto, UIImage?).self) { group in
            var next = 0
            func addNext() {
                guard next < photos.count, !Task.isCancelled else { return }
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
                arrived(photo, image)
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
/// starts, decoding those first, and the rest keep decoding while it plays.
///
/// **A block that will show a photograph is drawn as one from its first
/// frame** (`expects`): its veil, vignette and title shadow are there at
/// once, and only the picture fades in when it lands. Switching those on
/// with the picture's arrival darkened the block in one frame.
///
/// **The fade runs on the replay's clock, not the wall's**, so a hold pauses
/// it with everything else. A photograph that lands while the replay is not
/// running (held, frozen or finished) has nothing to fade against and shows
/// at once; after Replay, one that arrived later in the first play shows
/// whole. The fade is live only: Save Video and Share wait for `all()`, so
/// the video never has a blank or a half-faded picture.
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
    /// Photographs that could not be decoded: their blocks are drawn as
    /// plain colour, as a block without a photograph is.
    private(set) var failed: Set<String> = []

    /// The replay's time and whether it is running, read as a photograph
    /// lands. Set by the view that owns the clock.
    @ObservationIgnored var clock: (() -> (t: Double, running: Bool))?
    /// Replay time each late photograph landed at.
    @ObservationIgnored private var arrivals: [String: Double] = [:]
    @ObservationIgnored private var started = false
    @ObservationIgnored private var playWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var allTask: Task<ReplayImages, Never>?

    /// How long ahead of the starting moment the replay's photographs must
    /// already be decoded.
    static let startWindow: Double = 2
    /// How long, in replay time, a photograph that lands during playback
    /// takes to fade in.
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
                    if let image { decoded.insert(image, for: photo) }
                    guard let self else { return }
                    if image == nil { self.failed.insert(photo.key) }
                    if self.canPlay {
                        guard let image else { return }
                        if let now = self.clock?(), now.running { self.arrivals[photo.key] = now.t }
                        self.images.insert(image, for: photo)
                    } else {
                        missing.remove(photo.key)
                        if missing.isEmpty {
                            self.images = decoded
                            self.becomePlayable()
                        }
                    }
                }
                // Cancelled, or a photograph never arrived: start with what
                // there is, so nothing waits for ever.
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

    /// The replay closed: stop decoding. A month's photographs no longer
    /// decode behind a screen that has gone.
    func cancel() {
        allTask?.cancel()
    }

    /// Replay restarted: every photograph already in shows whole, instead of
    /// blinking out when the second play reaches the time it landed at in
    /// the first and fading in again.
    func forgetArrivals() {
        arrivals = [:]
    }

    /// Whether a block showing `photo` should be drawn as a photograph: its
    /// picture is in or on its way.
    func expects(_ photo: ReplayPhoto) -> Bool {
        !failed.contains(photo.key)
    }

    /// How far `photo` has faded in at replay time `t`: 1 for anything that
    /// was in before playback started, landed while the replay was not
    /// running, or landed later than `t` in an earlier play.
    func opacity(_ photo: ReplayPhoto, at t: Double) -> Double {
        guard let arrived = arrivals[photo.key], t >= arrived else { return 1 }
        return min(max((t - arrived) / Self.fade, 0), 1)
    }
}
