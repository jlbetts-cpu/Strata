import CoreImage
import Foundation
import UIKit
import Vision

/// **The one thing out of a day, lifted off its background and stuck on the
/// folder.**
///
/// The owner: "for fun the folders should auto cut out like an image from
/// that day and put it on the outside of the folder, kinda as like a small
/// sticker marking the day. Make it automatic so you don't really have to set
/// it, but make sure it detects for significance and a memory that they would
/// actually want to remember."
///
/// **Automatic is the hard half, not the cut-out.** `Vision` will lift a
/// subject out of almost anything; the question is which photograph out of a
/// day deserves to be the one on the front. A wrong pick is worse than no
/// sticker, because the folder then says "this is what that day was" about a
/// blurry shot of a table.
///
/// So nothing is stuck on until a photograph clears a bar, and a day with
/// nothing above the bar gets no sticker at all. That is the design: the
/// sticker is a remark, and a remark about every day is not a remark.
///
/// **What it never does.** It does not name anybody, count anybody, or say
/// anything to the user about what it found. A face raises a score inside
/// this file and leaves no trace anywhere else — no label, no "people" album,
/// nothing that reads as the app watching. `Vision` runs entirely on device
/// and nothing here touches the network.
@MainActor
final class DayStickerService {
    static let shared = DayStickerService()

    /// What a candidate photograph is worth, as numbers a test can hold.
    ///
    /// Kept as a value separate from the Vision calls that fill it in, so the
    /// judgement — which is the part with an opinion in it — can be exercised
    /// without a photograph, a GPU or a simulator.
    struct Features: Equatable {
        /// Faces found in the frame, capped where more stops meaning more.
        var faces: Int = 0
        /// How confident Vision is that the frame has one thing it is about,
        /// 0 to 1.
        var salience: Double = 0
        /// The share of the frame the liftable subject covers, 0 to 1.
        var subjectArea: Double = 0
        /// The win was given a name rather than left as it was logged.
        var named: Bool = false
        /// 1 for a small block, 2 for a medium, 3 for a hard.
        var weight: Int = 1
        /// The app knew where the photograph was taken.
        var located: Bool = false
    }

    /// **The bar, and why each term is here.**
    ///
    /// - **A subject that cuts out cleanly, or nothing.** `subjectArea`
    ///   outside 6% to 62% scores zero however good the rest is. Under 6% the
    ///   sticker is a speck at 50pt; over 62% the "cut-out" is the whole
    ///   photograph with its corners nibbled, which is not a sticker, it is a
    ///   badly cropped picture. This is a gate rather than a term because no
    ///   amount of significance rescues a cut-out that does not read.
    /// - **People, weighted hardest.** A frame with somebody in it is the
    ///   single strongest signal that a photograph will be looked at again;
    ///   it is what Photos and Memories both lean on. Capped at two, because
    ///   the difference between nobody and somebody is enormous and the
    ///   difference between four people and six is nothing.
    /// - **Salience.** A photograph Vision can say is *about* something is
    ///   one that was taken on purpose.
    /// - **Deliberateness, from the app's own record.** A win somebody named
    ///   and sized up is one they thought about. This is the term the phone
    ///   cannot see and the app can, and it is why this is not just a
    ///   photo-quality score.
    /// - **Place**, a small nudge: a win with a location on it happened
    ///   somewhere, which is most of what makes a day memorable.
    ///
    /// The weights are stated rather than learned and are meant to be argued
    /// with. What matters is that they are all in one function with a test
    /// beside it, not spread through a view.
    ///
    /// **They sum to exactly 1.** The first set summed to 1.35, which
    /// `scoreIsBounded` caught: with an unbounded top the bar stops being "a
    /// fraction of the best possible photograph" and becomes a number that
    /// has to be re-tuned by hand every time a term is added. Normalised, the
    /// bar is readable as what it is — 40% of perfect.
    nonisolated static func score(_ f: Features) -> Double {
        guard f.subjectArea >= 0.06, f.subjectArea <= 0.62 else { return 0 }
        var total = 0.0
        total += Double(min(f.faces, 2)) * 0.25
        total += f.salience * 0.19
        // Best around a third of the frame, falling off either side: that is
        // the size a sticker wants to be, and it is also what a photograph
        // taken OF something usually looks like.
        total += (1 - min(abs(f.subjectArea - 0.32) / 0.32, 1)) * 0.12
        total += f.named ? 0.08 : 0
        total += Double(f.weight - 1) * 0.04
        total += f.located ? 0.03 : 0
        return total
    }

    /// Below this, a day gets no sticker.
    ///
    /// **Set so that a clean subject alone is not enough.** A perfectly
    /// composed photograph of nobody, on a win nobody named, scores 0.31 —
    /// under the bar however good the picture is. It needs a person in it,
    /// or a name on it and a size and a place. That is the difference
    /// between "this photograph is fine" and "this is what that day was",
    /// and it is checked by `aPrettyNothingIsNotAMemory`.
    nonisolated static let bar: Double = 0.40

    // MARK: - Cache

    /// One sticker per day, on disk, beside the photographs.
    ///
    /// **Keyed by the day AND by what was in it.** A day's winner can change
    /// when a win is added, renamed or deleted, so the key carries a hash of
    /// the day's win ids; a stale file is simply never asked for again and is
    /// swept with the rest.
    private var memory: [String: UIImage?] = [:]
    private var running: Set<String> = []

    private var folder: URL {
        ImageManager.shared.imageDirectory.appendingPathComponent("stickers", isDirectory: true)
    }

    private func url(for key: String) -> URL {
        folder.appendingPathComponent("\(key).png")
    }

    /// The cache key for a day and the wins it currently holds.
    nonisolated static func key(day: String, winIDs: [String]) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for id in winIDs.sorted() {
            for byte in id.utf8 { h ^= UInt64(byte); h = h &* 0x100000001b3 }
        }
        return "\(day)-\(String(h, radix: 36))"
    }

    /// What is already known, with no work started. A view calls this in its
    /// body; it must never touch the disk or Vision.
    func cached(key: String) -> UIImage? {
        memory[key] ?? nil
    }

    /// **Asks for a day's sticker, at most once.**
    ///
    /// Returns nil for a day that has no photograph worth lifting, and
    /// remembers that answer so the day is not re-examined on every scroll.
    /// The work runs off the main actor; only the result comes back to it.
    @discardableResult
    func sticker(key: String, candidates: [Candidate]) async -> UIImage? {
        if let known = memory[key] { return known }
        guard !running.contains(key) else { return nil }
        running.insert(key)
        defer { running.remove(key) }

        if let onDisk = await Self.read(url(for: key)) {
            memory[key] = onDisk
            return onDisk
        }

        let directory = ImageManager.shared.imageDirectory
        let destination = url(for: key)
        let made = await Task.detached(priority: .utility) { () -> UIImage? in
            await Self.make(candidates, in: directory, saveTo: destination)
        }.value
        memory[key] = made
        return made
    }

    /// A photograph in the running, with everything the APP knows about it.
    /// The rest comes from looking at the pixels.
    struct Candidate: Sendable, Equatable {
        var fileName: String
        var named: Bool
        var weight: Int
        var located: Bool
    }

    // MARK: - The work

    private nonisolated static func read(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }

    /// **Four candidates at most, and that is a budget not a shortcut.**
    ///
    /// A foreground-instance mask is the most expensive thing this app asks
    /// of the phone. Running it over a twelve-win day, for fourteen days, on
    /// a scroll, is how an app becomes the one that gets warm in your hand.
    /// The shortlist is ordered by what the app already knows — named, sized
    /// up, located — so the four examined are the four most likely to win
    /// before a single pixel is read.
    private nonisolated static func make(_ candidates: [Candidate],
                                         in directory: URL,
                                         saveTo destination: URL) async -> UIImage? {
        let shortlist = candidates.sorted { a, b in
            let sa = (a.named ? 2 : 0) + a.weight + (a.located ? 1 : 0)
            let sb = (b.named ? 2 : 0) + b.weight + (b.located ? 1 : 0)
            return sa == sb ? a.fileName < b.fileName : sa > sb
        }.prefix(4)

        var best: (score: Double, image: UIImage)?
        for candidate in shortlist {
            let url = directory.appendingPathComponent(candidate.fileName)
            guard let source = downsampled(url, to: 1024) else {
                #if DEBUG
                NSLog("[strata-sticker] %@ could not be decoded", candidate.fileName)
                #endif
                continue
            }
            guard let looked = examine(source) else {
                #if DEBUG
                NSLog("[strata-sticker] %@ has no liftable subject", candidate.fileName)
                #endif
                continue
            }
            var features = looked.features
            features.named = candidate.named
            features.weight = candidate.weight
            features.located = candidate.located
            let score = DayStickerService.score(features)
            #if DEBUG
            NSLog("[strata-sticker] %@ faces=%d salience=%.2f area=%.3f named=%d weight=%d -> %.3f (bar %.2f)",
                  candidate.fileName, features.faces, features.salience, features.subjectArea,
                  features.named ? 1 : 0, features.weight, score, bar)
            #endif
            guard score >= bar else { continue }
            if best == nil || score > best!.score {
                best = (score, looked.cutout)
            }
        }

        guard let winner = best?.image else { return nil }
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = winner.pngData() { try? data.write(to: destination, options: .atomic) }
        return winner
    }

    /// **1024 on the long edge, not the original.**
    ///
    /// Vision's masks are generated at a fixed internal resolution anyway, so
    /// handing it a 48-megapixel frame buys nothing and costs the decode. The
    /// cut-out is drawn at about 50pt, so 1024 is already twenty times what
    /// is shown.
    private nonisolated static func downsampled(_ url: URL, to side: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: side
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Looks at one photograph: what is in it, and what the cut-out would be.
    ///
    /// **The subject mask goes first and alone, and both of those matter.**
    ///
    /// *Alone*, because `perform` takes a batch and a batch fails as a unit:
    /// one request the device cannot serve takes the other two down with it,
    /// and the reason is lost inside a `try?`.
    ///
    /// *First*, because it is both the expensive one and the one that can
    /// veto: a photograph with nothing liftable in it cannot become a
    /// sticker however many faces are in it, so running face detection and
    /// saliency before knowing that is work spent on a photograph that has
    /// already lost. Measured on the simulator at 60 to 300ms per image for
    /// the batch; this ordering skips the rest of it entirely for anything
    /// that fails.
    ///
    /// **This cannot be checked in the simulator, and that is not a bug in
    /// it.** `VNGenerateForegroundInstanceMaskRequest` is a CoreML model that
    /// wants the Neural Engine, and a simulator has none: every call returns
    /// `NSOSStatusErrorDomain -1, "Failed to create espresso context"`. The
    /// path above it is exercised by `DayStickerTests` and the cut-out itself
    /// is a device check, like the camera.
    private nonisolated static func examine(_ image: CGImage) -> (features: Features, cutout: UIImage)? {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        var features = Features()

        let subject = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([subject])
        } catch {
            #if DEBUG
            NSLog("[strata-sticker] no subject mask on this machine: %@",
                  String(describing: error))
            #endif
            return nil
        }
        guard let mask = subject.results?.first, !mask.allInstances.isEmpty else { return nil }
        guard let masked = try? mask.generateMaskedImage(ofInstances: mask.allInstances,
                                                         from: handler,
                                                         croppedToInstancesExtent: true)
        else { return nil }

        // Only now, on a photograph that can actually become a sticker.
        let faces = VNDetectFaceRectanglesRequest()
        let salience = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([faces])
        try? handler.perform([salience])
        features.faces = faces.results?.count ?? 0
        if let observation = salience.results?.first {
            features.salience = Double(observation.confidence)
        }

        let cut = CIImage(cvPixelBuffer: masked)
        // The share of the ORIGINAL frame the subject covers. Cropping to the
        // subject's extent is what makes this measurable: the ratio of the
        // two areas is exactly how much of the picture the subject was.
        let whole = Double(image.width) * Double(image.height)
        let part = Double(cut.extent.width) * Double(cut.extent.height)
        features.subjectArea = whole > 0 ? min(part / whole, 1) : 0

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let rendered = context.createCGImage(cut, from: cut.extent) else { return nil }
        return (features, UIImage(cgImage: rendered))
    }

    /// Drops stickers for days that are no longer on the row, and for wins
    /// that have changed since one was made.
    nonisolated static func prune(keeping keys: Set<String>, in directory: URL) -> Int {
        let folder = directory.appendingPathComponent("stickers", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder,
                                                                      includingPropertiesForKeys: nil)
        else { return 0 }
        var removed = 0
        for file in files where !keys.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
            removed += 1
        }
        return removed
    }
}
