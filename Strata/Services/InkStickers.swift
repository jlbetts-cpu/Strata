import Foundation
import PencilKit
import UIKit

/// **A sticker on a drawing** (the owner, 2026-10-06: "make it so you can add
/// stickers to doodles when you are drawing them", for all four: a crew
/// doodle, a block's doodle, the journal's sketch and the month drawing).
///
/// One of your own stickers (`StickerStore`), placed on the canvas: its file,
/// its centre, its longest edge and its tilt, all in the canvas's own points,
/// so it rescales with the strokes when a drawing is opened on another size
/// of canvas. Kept beside the strokes wherever they are kept.
///
/// **The name is kept and the file is not.** A sticker's file lives on the
/// phone that made it; a placement whose file is missing (another phone, or a
/// sticker deleted since) is skipped without a word, never drawn broken. The
/// picture a drawing is saved as already carries every sticker in it, so
/// what is SHOWN never depends on the file; only drawing on it again does.
nonisolated struct InkSticker: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id = UUID()
    /// The sticker's file in `StickerStore`.
    var name: String
    /// The centre, in canvas points.
    var x: Double
    var y: Double
    /// The longest edge, in canvas points.
    var size: Double
    /// Radians, clockwise.
    var rotation: Double = 0

    /// **Turned a little, never upside down** (the brief: "rotated a
    /// little"). A sticker leans; it is not a dial.
    static let rotationLimit: Double = .pi / 6
    /// Never smaller than a fingertip can find again.
    static let minimumSize: Double = 36

    var center: CGPoint { CGPoint(x: x, y: y) }

    /// The same sticker on a canvas `k` times the size.
    func scaled(by k: CGFloat) -> InkSticker {
        var out = self
        out.x *= Double(k)
        out.y *= Double(k)
        out.size *= Double(k)
        return out
    }

    /// Its size before it is turned, for a picture of `image`'s shape: the
    /// longest edge is `size`.
    func drawnSize(for image: CGSize) -> CGSize {
        let longest = max(image.width, image.height)
        guard longest > 0 else { return CGSize(width: size, height: size) }
        let k = size / Double(longest)
        return CGSize(width: Double(image.width) * k, height: Double(image.height) * k)
    }

    /// The box it covers once turned, in canvas points.
    func bounds(for image: CGSize) -> CGRect {
        let drawn = drawnSize(for: image)
        let c = abs(cos(rotation)), s = abs(sin(rotation))
        let w = drawn.width * c + drawn.height * s
        let h = drawn.width * s + drawn.height * c
        return CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
    }

    /// Clamped to the limits: a pinch past them stops at them.
    func clamped(toCanvas canvas: CGSize) -> InkSticker {
        var out = self
        let largest = max(Self.minimumSize, Double(min(canvas.width, canvas.height)) * 1.5)
        out.size = min(max(size, Self.minimumSize), largest)
        out.rotation = min(max(rotation, -Self.rotationLimit), Self.rotationLimit)
        return out
    }
}

/// **A drawing as an editor hands it back**: the strokes, the stickers on
/// them, and the canvas they were made on.
struct InkDoodle {
    var drawing: PKDrawing
    var stickers: [InkSticker] = []
    var canvas: CGSize = .zero

    /// Nothing drawn and nothing stuck on.
    var isEmpty: Bool { drawing.strokes.isEmpty && stickers.isEmpty }
}

// MARK: - Drawing them

/// Stickers into a picture: the shared drawing code for every export.
enum InkStickers {
    /// The phone's sticker for a name, or nil when the file is not here.
    static func image(_ name: String) -> UIImage? { StickerStore.shared.image(name) }

    /// Draws `stickers` into the current UIKit context, `origin` being the
    /// canvas point at the context's top left. A sticker whose file is
    /// missing is skipped.
    static func draw(_ stickers: [InkSticker], origin: CGPoint,
                     images: (String) -> UIImage?) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for sticker in stickers {
            guard let image = images(sticker.name) else { continue }
            let drawn = sticker.drawnSize(for: image.size)
            context.saveGState()
            context.translateBy(x: sticker.x - origin.x, y: sticker.y - origin.y)
            context.rotate(by: sticker.rotation)
            image.draw(in: CGRect(x: -drawn.width / 2, y: -drawn.height / 2,
                                  width: drawn.width, height: drawn.height))
            context.restoreGState()
        }
    }

    /// The box every sticker here covers, or `.null` for none.
    static func bounds(of stickers: [InkSticker], images: (String) -> UIImage?) -> CGRect {
        stickers.reduce(CGRect.null) { box, sticker in
            guard let image = images(sticker.name) else { return box }
            return box.union(sticker.bounds(for: image.size))
        }
    }
}

extension InkExport {
    /// **The drawing with its stickers, as one picture** (`InkLayers`): the
    /// stickers in their own colours, under the ink, the ink black as every
    /// export's is. With no sticker to draw it is exactly `png(of:in:scale:)`.
    static func png(of drawing: PKDrawing, stickers: [InkSticker], in rect: CGRect, scale: CGFloat,
                    images: (String) -> UIImage? = InkStickers.image) -> Data? {
        let placed = stickers.filter { images($0.name) != nil }
        guard !placed.isEmpty else { return png(of: drawing, in: rect, scale: scale) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let whole = CGRect(origin: .zero, size: rect.size)
        // Redrawn through the one renderer, so all three are the same pixels.
        let pen = drawing.strokes.isEmpty ? nil : image(of: drawing, in: rect, scale: scale)
        let ink = renderer.image { _ in pen?.draw(in: whole) }
        let layer = renderer.image { _ in InkStickers.draw(placed, origin: rect.origin, images: images) }
        let composite = renderer.image { _ in
            layer.draw(in: whole)
            ink.draw(in: whole)
        }
        return InkLayers.encode(composite: composite, ink: ink, stickers: layer)
    }

    /// A doodle for a crew with its stickers: cropped to the ink AND the
    /// stickers, at most 1080px on its longest edge. Nil for nothing drawn.
    ///
    /// The crew chat hands this back what the doodle sheet sends
    /// (`DoodleSheet.send`), so a sticker reaches the chat with no change to
    /// how a doodle is sent.
    static func doodlePNG(_ doodle: InkDoodle, images: (String) -> UIImage? = InkStickers.image) -> Data? {
        let placed = doodle.stickers.filter { images($0.name) != nil }
        guard !placed.isEmpty else { return doodlePNG(doodle.drawing) }
        var rect = InkStickers.bounds(of: placed, images: images)
        if !doodle.drawing.strokes.isEmpty { rect = rect.union(inkBounds(of: doodle.drawing)) }
        rect = rect.integral
        return png(of: doodle.drawing, stickers: placed, in: rect,
                   scale: scale(fitting: rect.size, longestEdge: doodleLongestEdge), images: images)
    }
}

// MARK: - One file, two layers

/// **A saved drawing with stickers is one PNG that knows which pixels are
/// ink.**
///
/// Every place a drawing is shown tints it (`InkImage`, `BlockDoodleImage`:
/// a template image in the page's ink, white on a block), so the black ink
/// follows dark mode. A sticker tinted is a flat silhouette. So the picture
/// is the drawing as it looks, stickers in colour under black ink, and it
/// carries a private PNG chunk ("laYr") with two masks: which pixels are ink
/// and which are sticker. Where it is shown, the stickers are drawn as they
/// are and the ink is tinted over them.
///
/// **Why the masks ride inside the picture** (2026-10-06). A crew doodle is
/// sent as one PNG and the chat that shows it is not this file's to change,
/// so a second file could not travel with it. And the photo check a doodle
/// passes (`SocialStore.sendDoodle`, `CrewSafety.photoIsFine`) reads the
/// picture's own pixels: those are the whole drawing, stickers included, and
/// what is shown is CUT from them by the masks, never added, so nothing can
/// be shown that the check did not see. A reader that does not know the
/// chunk (any decoder skips an unknown ancillary chunk) shows the picture as
/// it always showed a doodle.
nonisolated enum InkLayers {
    /// Ancillary, private, safe to copy: decoders that do not know it skip it.
    static let chunkType: [UInt8] = Array("laYr".utf8)
    private static let version: UInt8 = 1

    /// The picture as shown, with the two masks inside it.
    static func encode(composite: UIImage, ink: UIImage, stickers: UIImage) -> Data? {
        guard let png = composite.pngData(), let cg = composite.cgImage,
              let inkAlpha = alpha(of: ink, width: cg.width, height: cg.height),
              let stickerAlpha = alpha(of: stickers, width: cg.width, height: cg.height) else { return nil }
        var planes = [UInt8](repeating: 0, count: cg.width * cg.height * 2)
        for i in 0..<(cg.width * cg.height) {
            planes[2 * i] = inkAlpha[i]
            planes[2 * i + 1] = stickerAlpha[i]
        }
        guard let packed = try? (Data(planes) as NSData).compressed(using: .zlib) as Data else { return nil }
        var payload = Data([version])
        payload.append(contentsOf: bigEndian(UInt32(cg.width)))
        payload.append(contentsOf: bigEndian(UInt32(cg.height)))
        payload.append(packed)
        return inserting(payload, into: png)
    }

    /// The picture's two layers: the ink to tint, and the stickers as they
    /// are (nil when it has none, which is every drawing made before them).
    static func decode(_ data: Data, scale: CGFloat) -> InkPicture? {
        guard let image = UIImage(data: data, scale: scale) else { return nil }
        guard let payload = chunk(in: data), payload.count > 9, payload[payload.startIndex] == version,
              let cg = image.cgImage else { return InkPicture(ink: image, stickers: nil) }
        let bytes = [UInt8](payload)
        let width = Int(readBigEndian(bytes, at: 1)), height = Int(readBigEndian(bytes, at: 5))
        guard width == cg.width, height == cg.height,
              let planes = try? (Data(bytes[9...]) as NSData).decompressed(using: .zlib) as Data,
              planes.count == width * height * 2,
              let split = split(cg, planes: [UInt8](planes)) else { return InkPicture(ink: image, stickers: nil) }
        return InkPicture(ink: UIImage(cgImage: split.ink, scale: scale, orientation: .up),
                          stickers: UIImage(cgImage: split.stickers, scale: scale, orientation: .up))
    }

    /// The ink: black, as opaque as the ink mask says but never more than the
    /// picture itself is. The stickers: the picture's own pixels wherever a
    /// sticker is, so a line drawn over one is still under the tinted ink.
    private static func split(_ cg: CGImage, planes: [UInt8]) -> (ink: CGImage, stickers: CGImage)? {
        let width = cg.width, height = cg.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let picture = rgba(width: width, height: height, space: space),
              let ink = rgba(width: width, height: height, space: space),
              let stickers = rgba(width: width, height: height, space: space) else { return nil }
        picture.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let source = picture.data?.assumingMemoryBound(to: UInt8.self),
              let inkOut = ink.data?.assumingMemoryBound(to: UInt8.self),
              let stickerOut = stickers.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        planes.withUnsafeBufferPointer { mask in
            for i in 0..<(width * height) {
                let p = 4 * i
                inkOut[p + 3] = min(mask[2 * i], source[p + 3])
                if mask[2 * i + 1] > 0 {
                    stickerOut[p] = source[p]
                    stickerOut[p + 1] = source[p + 1]
                    stickerOut[p + 2] = source[p + 2]
                    stickerOut[p + 3] = source[p + 3]
                }
            }
        }
        guard let inkImage = ink.makeImage(), let stickerImage = stickers.makeImage() else { return nil }
        return (inkImage, stickerImage)
    }

    private static func rgba(width: Int, height: Int, space: CGColorSpace) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// One byte a pixel: how opaque `image` is there.
    private static func alpha(of image: UIImage, width: Int, height: Int) -> [UInt8]? {
        guard let cg = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = rgba(width: width, height: height, space: space) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        return (0..<(width * height)).map { data[4 * $0 + 3] }
    }

    // MARK: The chunk

    /// The layers' chunk, if the PNG carries one.
    static func chunk(in png: Data) -> Data? {
        let bytes = [UInt8](png)
        var at = 8
        while at + 12 <= bytes.count {
            let length = Int(readBigEndian(bytes, at: at))
            let type = Array(bytes[(at + 4)..<(at + 8)])
            guard at + 12 + length <= bytes.count else { return nil }
            if type == chunkType { return Data(bytes[(at + 8)..<(at + 8 + length)]) }
            at += 12 + length
        }
        return nil
    }

    /// `payload` as a chunk just before the PNG's end.
    static func inserting(_ payload: Data, into png: Data) -> Data? {
        // IEND is the last twelve bytes of every PNG.
        guard png.count > 20 else { return nil }
        var chunk = Data(bigEndian(UInt32(payload.count)))
        var typed = Data(chunkType)
        typed.append(payload)
        chunk.append(typed)
        chunk.append(contentsOf: bigEndian(crc32(typed)))
        var out = png.prefix(png.count - 12)
        out.append(chunk)
        out.append(png.suffix(12))
        return Data(out)
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private static func readBigEndian(_ bytes: [UInt8], at i: Int) -> UInt32 {
        UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16 | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3])
    }

    private static let crcTable: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in data { c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

/// A saved drawing's two layers, decoded once and kept (`InkImageCache`).
nonisolated final class InkPicture: @unchecked Sendable {
    /// Black ink on nothing, to be tinted where it is shown.
    let ink: UIImage
    /// The stickers in their own colours, the same size as `ink`.
    let stickers: UIImage?

    init(ink: UIImage, stickers: UIImage?) {
        self.ink = ink
        self.stickers = stickers
    }
}
