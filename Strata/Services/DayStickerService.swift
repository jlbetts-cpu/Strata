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
        /// The share of the frame's PIXELS the liftable subject covers, 0 to
        /// 1. Not the share its bounding box covers — see `coverage`.
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
    ///   outside 6% to 75% scores zero however good the rest is. Under 6% the
    ///   sticker is a speck at 50pt; over 75% the "cut-out" is the whole
    ///   photograph with its corners nibbled, which is not a sticker, it is a
    ///   badly cropped picture. This is a gate rather than a term because no
    ///   amount of significance rescues a cut-out that does not read.
    ///
    ///   **The band and the sweet spot are both set from real photographs**,
    ///   run through this exact pipeline on a Mac because a simulator cannot
    ///   run the model. Across twelve, two had nothing liftable, one measured
    ///   0.05 (a small object on a table) and the rest landed between 0.13
    ///   and 0.71 — with every photograph of people between 0.22 and 0.56.
    ///   The ceiling was 0.62 until that run, which would have thrown away a
    ///   close portrait of two people at 0.71.
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
        guard f.subjectArea >= 0.06, f.subjectArea <= 0.75 else { return 0 }
        var total = 0.0
        total += Double(min(f.faces, 2)) * 0.25
        total += f.salience * 0.19
        // Best around a third of the frame, falling off either side: that is
        // the size a sticker wants to be, and it is also what a photograph
        // taken OF something usually looks like.
        total += (1 - min(abs(f.subjectArea - 0.34) / 0.34, 1)) * 0.12
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
        // **Background, not utility.** This is the least urgent thing the
        // app ever does and the most expensive: a model on the Neural Engine
        // while somebody is looking at a photograph that has already
        // arrived. Utility competes with the decodes that put those
        // photographs on the folders in the first place.
        let made = await Task.detached(priority: .background) { () -> UIImage? in
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
        // **One subject, not everything in the foreground.**
        //
        // `allInstances` is every object Vision lifted, which on a photograph
        // of a plate of food and a hand and a corner of a table is three
        // cut-outs floating in one rectangle. A sticker is a thing, so this
        // keeps the biggest instance and anything at least a third of its
        // size — which holds two people together and drops the clutter
        // beside them.
        let (kept, coverage) = principalInstances(in: mask)
        guard !kept.isEmpty else { return nil }
        features.subjectArea = coverage
        guard let masked = try? mask.generateMaskedImage(ofInstances: kept,
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

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let finished = dieCut(cut, in: context) else { return nil }
        return (features, finished)
    }

    /// **Which of the lifted objects the sticker is of, and how much of the
    /// frame they actually cover.**
    ///
    /// `VNInstanceMaskObservation.instanceMask` is a single-channel buffer
    /// whose pixel VALUES are instance indexes — 0 for background, 1, 2, 3
    /// for the objects — so both answers come out of one pass over a small
    /// buffer rather than out of a mask generated per instance.
    ///
    /// **Coverage is counted here because the bounding box lies.** The first
    /// version measured the cropped extent against the whole frame, which is
    /// the subject's BOX, not the subject. Run on real photographs on a Mac
    /// (the simulator cannot run the model at all), three pictures of people
    /// measured 0.66, 0.95 and 0.95 — all of them past the 0.62 ceiling, so
    /// every one would have been thrown away. A standing person's box covers
    /// most of a portrait while the person covers perhaps a third of its
    /// pixels, and the whole point of the ceiling is to reject a "cut-out"
    /// that is really the entire picture. Counting the mask is the only
    /// measure that means what the gate needs it to mean.
    private nonisolated static func principalInstances(
        in mask: VNInstanceMaskObservation) -> (kept: IndexSet, coverage: Double) {
        let buffer = mask.instanceMask
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            return (mask.allInstances, 0)
        }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        var area: [Int: Int] = [:]
        for y in 0..<height {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let index = Int(row[x])
                if index > 0 { area[index, default: 0] += 1 }
            }
        }
        guard let largest = area.values.max(), largest > 0 else {
            return (mask.allInstances, 0)
        }
        var kept = IndexSet()
        var covered = 0
        for (index, size) in area where Double(size) >= Double(largest) * 0.33 {
            kept.insert(index)
            covered += size
        }
        let total = Double(width * height)
        let coverage = total > 0 ? min(Double(covered) / total, 1) : 0
        return (kept.isEmpty ? mask.allInstances : kept, coverage)
    }

    /// **The white edge that makes a cut-out a sticker.**
    ///
    /// The owner: "right now it's just an image without any cut-out... I want
    /// that to feel and look better."
    ///
    /// A subject lifted off its background is a cut-out. What turns a cut-out
    /// into a STICKER is the die line: the white border a printer leaves
    /// around the artwork so the blade has something to cut through. Without
    /// it the subject floats and its edges read as an unfinished mask — which
    /// is exactly what "just an image" means. With it, the same pixels read
    /// as a physical thing that was peeled off a sheet and pressed onto the
    /// folder.
    ///
    /// It is built from the alpha rather than from the picture: the alpha is
    /// pushed into every channel to make a white silhouette, that silhouette
    /// is dilated, and the subject is laid back over it. So the border traces
    /// the subject exactly and costs one morphology pass.
    ///
    /// The radius is 2% of the short side rather than a fixed number of
    /// pixels, so the border is the same weight whatever size the source was.
    private nonisolated static func dieCut(_ cut: CIImage, in context: CIContext) -> UIImage? {
        // **Off the LONG side, so the border is the same weight on screen.**
        //
        // It was the short side, which is the correct-looking choice and is
        // wrong: the sticker is drawn with `scaledToFit` into a fixed frame,
        // so what maps to a constant on screen is the long side. Measured on
        // the contact sheet — a tall portrait and a wide group of six, side
        // by side — the group's die line came out visibly thinner than the
        // portrait's, and they are meant to be the same sheet of vinyl.
        let long = max(cut.extent.width, cut.extent.height)
        let radius = max(long * 0.013, 2)

        // Alpha into every channel: a white shape with the subject's outline.
        guard let silhouette = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: cut,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])?.outputImage else { return nil }

        guard let spread = CIFilter(name: "CIMorphologyMaximum", parameters: [
            kCIInputImageKey: silhouette,
            kCIInputRadiusKey: radius
        ])?.outputImage else { return nil }

        // The dilation leaves a soft edge; a hard one is what a die line is.
        guard let firm = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: spread,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 2.2)
        ])?.outputImage else { return nil }

        let composed = cut.composited(over: firm)
        // The border grows outward, so the frame has to grow with it or the
        // edge is clipped square on whichever side the subject touched.
        let bounds = cut.extent.insetBy(dx: -radius * 1.2, dy: -radius * 1.2)
        guard let rendered = context.createCGImage(composed, from: bounds) else { return nil }
        return UIImage(cgImage: rendered)
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
