import CoreImage
import Foundation
import Observation
import UIKit
import Vision

/// **Your own stickers** (the owner, 2026-10-06: "I want the app to feel more
/// personal... personal stickers you can use as reactions sticking on your
/// journal and calendar"; his pick, "From your photos"). Lifted out of a
/// photograph of yours, the way iOS lifts a subject, with the white rim a
/// sticker has, and kept on this phone.
///
/// A sticker stands where the day's emoji stands (`MoodLog.symbol`), written
/// as "sticker:<file>", so the calendar corner and the journal's button carry
/// it with no new field to sync. **The name syncs and the file does not**, as
/// a sketch's: another phone shows the day as written, never a broken image.
/// Apple gives no app its own sticker library, so these are made here.
@MainActor
@Observable
final class StickerStore {
    static let shared = StickerStore(directory: StickerStore.defaultDirectory)

    nonisolated static let prefix = "sticker:"
    /// Enough to choose from at a glance; the oldest goes first.
    static let limit = 48
    /// The longest edge a sticker is kept at, in pixels: sharp in the
    /// journal's corner and on a calendar day, small on disk.
    static let longestEdge: CGFloat = 512

    @ObservationIgnored let directory: URL
    /// Newest first.
    private(set) var names: [String] = []
    @ObservationIgnored private var cache: [String: UIImage] = [:]

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        names = (try? JSONDecoder().decode([String].self,
                                           from: Data(contentsOf: directory.appending(path: "index.json"))))?
            .filter { FileManager.default.fileExists(atPath: directory.appending(path: $0).path) } ?? []
    }

    nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Stickers", directoryHint: .isDirectory)
    }

    // MARK: - The day's mark

    nonisolated static func symbol(for name: String) -> String { prefix + name }

    /// The sticker's file in a day's symbol, or nil for an emoji.
    nonisolated static func name(in symbol: String?) -> String? {
        guard let symbol, symbol.hasPrefix(prefix) else { return nil }
        let name = String(symbol.dropFirst(prefix.count))
        return name.isEmpty ? nil : name
    }

    // MARK: - Keeping them

    /// Keeps a sticker and returns its name, newest first.
    @discardableResult
    func add(_ sticker: UIImage) -> String? {
        guard let png = sticker.pngData() else { return nil }
        let name = "sticker-\(UUID().uuidString.prefix(8)).png"
        do { try png.write(to: directory.appending(path: name), options: .atomic) } catch {
            NSLog("[sticker] did not save: \(error)")
            return nil
        }
        cache[name] = sticker
        names.insert(name, at: 0)
        // Past the limit the oldest leaves the PICKER; its file stays, since a
        // day, a sketch or a strip may be wearing it (the 2026-10-08 audit).
        while names.count > Self.limit { names.removeLast() }
        writeIndex()
        return name
    }

    /// **Takes a sticker out of your stickers; never off what it is on.**
    /// The file stays: a day marked with it, a sketch, a month drawing or a
    /// strip it was placed on all keep showing it, as a sent sticker stays in
    /// a conversation. It used to delete the file, which left an empty
    /// smiley in the journal, a dot on the calendar and a gap in every
    /// drawing the next time it was saved.
    func remove(_ name: String) {
        names.removeAll { $0 == name }
        cache[name] = nil
        writeIndex()
    }

    /// **Every sticker, file and all: Reset All Data only** (2026-10-08).
    /// Unlike `remove`, the files go too, because after a reset there is no
    /// day, sketch or strip left for them to be on.
    func removeAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "png" && file.lastPathComponent.hasPrefix("sticker-") {
            try? FileManager.default.removeItem(at: file)
        }
        names = []
        cache = [:]
        writeIndex()
    }

    func image(_ name: String) -> UIImage? {
        if let hit = cache[name] { return hit }
        guard let image = UIImage(contentsOfFile: directory.appending(path: name).path) else { return nil }
        cache[name] = image
        return image
    }

    /// Stickers restored from a backup, whose files are now in the folder:
    /// added after the ones already here, never past the limit, never twice.
    func adopt(_ restored: [String]) {
        for name in restored where !names.contains(name) && names.count < Self.limit
            && FileManager.default.fileExists(atPath: directory.appending(path: name).path) {
            names.append(name)
        }
        writeIndex()
    }

    private func writeIndex() {
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? data.write(to: directory.appending(path: "index.json"), options: .atomic)
    }
}

/// **The lift**: everything iOS sees as the photograph's subject, cut out,
/// cropped to it, and given a white rim (`HeadCaptureEngine.lift` is the same
/// request for one person). Off the main thread; nil when there is nothing
/// to lift (a landscape, a wall).
enum StickerMaker {
    nonisolated static func lift(_ photo: UIImage) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { make(photo) }.value
    }

    nonisolated private static func make(_ photo: UIImage) -> UIImage? {
        guard let cg = normalised(photo) else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              !observation.allInstances.isEmpty,
              let masked = try? observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                                from: handler, croppedToInstancesExtent: true)
        else { return nil }
        let lifted = CIImage(cvPixelBuffer: masked)
        return outlined(lifted)
    }

    /// Upright and no bigger than the sticker needs, so the lift is quick.
    nonisolated private static func normalised(_ photo: UIImage) -> CGImage? {
        let longest = max(photo.size.width, photo.size.height)
        guard longest > 0 else { return nil }
        let k = min(1, 1024 / longest)
        let size = CGSize(width: (photo.size.width * k).rounded(), height: (photo.size.height * k).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    /// The white rim: the cut-out's shape grown by a few percent, painted
    /// white, under the cut-out. Padded first, so the rim is never clipped.
    nonisolated static func outlined(_ lifted: CIImage) -> UIImage? {
        let extent = lifted.extent
        guard extent.width > 1, extent.height > 1 else { return nil }
        let rim = max(6, max(extent.width, extent.height) * 0.035)
        let pad = rim * 2
        let canvas = CGRect(x: 0, y: 0, width: extent.width + pad * 2, height: extent.height + pad * 2)
        let clear = CIImage(color: .clear).cropped(to: canvas)
        let placed = lifted
            .transformed(by: CGAffineTransform(translationX: pad - extent.minX, y: pad - extent.minY))
            .composited(over: clear)
        let grown = placed
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: rim])
            .cropped(to: canvas)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        let white = grown.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": zero, "inputGVector": zero, "inputBVector": zero,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0),
        ])
        let sticker = placed.composited(over: white)
        let k = min(1, StickerStore.longestEdge / max(canvas.width, canvas.height))
        let scaled = sticker.transformed(by: CGAffineTransform(scaleX: k, y: k))
        guard let out = CIContext().createCGImage(scaled, from: scaled.extent.integral) else { return nil }
        return UIImage(cgImage: out)
    }
}

#if DEBUG
extension StickerMaker {
    /// `-strataSticker seed`: the subject lift does not run in the simulator
    /// (`HeadCaptureEngine.lift` says the same), so a drawn sunflower stands
    /// in for a lifted subject and goes through the same rim.
    static func sample() -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            ("\u{1F33B}" as NSString).draw(in: CGRect(origin: .zero, size: size),
                                          withAttributes: [.font: UIFont.systemFont(ofSize: 240)])
        }
        guard let cg = drawn.cgImage else { return nil }
        return outlined(CIImage(cgImage: cg))
    }
}
#endif
