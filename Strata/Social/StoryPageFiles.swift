import Foundation
import PencilKit
import UIKit

/// **The words page's own files** (`StoryPageEditor`, 2026-10-16): the
/// drawing as you left it, so the editor opens where you stopped; the photo
/// strip as a sticker; and the page's ink and stickers flattened into one
/// clear picture, which is what goes to the crew on the story record's
/// `sketch`, as a doodle in the chat does.
///
/// Names here start with `prefix`, so a sticker on the page that is not one
/// of yours (the strip) is found here rather than in `StickerStore`, and
/// never joins your sticker drawer.
enum StoryPageFiles {
    nonisolated static let prefix = "page-"

    nonisolated static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "StoryPages", directoryHint: .isDirectory)
    }

    /// What the editor reopens: the strokes, the stickers, and the canvas
    /// they were made on.
    struct Draft: Codable {
        var drawing: Data
        var stickers: [InkSticker]
        var width: Double
        var height: Double
        /// The wins whose photographs are in a strip on the page.
        var stripWins: [UUID]? = nil
    }

    private static var cache: [String: UIImage] = [:]

    static func draft(on day: String) -> Draft? {
        guard let data = try? Data(contentsOf: directory.appending(path: "\(prefix)draft-\(day).json")) else { return nil }
        return try? JSONDecoder().decode(Draft.self, from: data)
    }

    static func keep(_ draft: Draft, on day: String) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        write(data, named: "\(prefix)draft-\(day).json")
        prune()
    }

    /// A picture that is a sticker on the page only (the strip).
    static func addSticker(_ image: UIImage) -> String? {
        guard let png = image.pngData() else { return nil }
        let name = "\(prefix)sticker-\(UUID().uuidString).png"
        guard write(png, named: name) else { return nil }
        cache[name] = image
        return name
    }

    static func image(_ name: String) -> UIImage? {
        if let hit = cache[name] { return hit }
        guard name.hasPrefix(prefix), !name.contains("/"),
              let image = UIImage(contentsOfFile: directory.appending(path: name).path) else { return nil }
        cache[name] = image
        return image
    }

    /// The page's ink and stickers as one clear picture at the page's size,
    /// kept here; its name, or nil when there is nothing on the page. A new
    /// name each time, so a friend's phone never shows the last one cached.
    static func keepArt(drawing: PKDrawing, stickers: [InkSticker], canvas: CGSize) -> String? {
        guard let png = art(drawing: drawing, stickers: stickers, canvas: canvas) else { return nil }
        let name = "\(prefix)art-\(UUID().uuidString).png"
        return write(png, named: name) ? name : nil
    }

    /// The longest edge the page leaves at: a phone screen's, as a story is.
    static let longestEdge: CGFloat = 1600

    static func art(drawing: PKDrawing, stickers: [InkSticker], canvas: CGSize) -> Data? {
        guard canvas.width > 0, canvas.height > 0, !(drawing.strokes.isEmpty && stickers.isEmpty) else { return nil }
        let scale = InkExport.scale(fitting: canvas, longestEdge: longestEdge)
        let rect = CGRect(origin: .zero, size: canvas)
        // The ink as the editor shows it: white, PencilKit's black pen in
        // the dark (`InkCanvas.lightInk`).
        var ink = UIImage()
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            ink = drawing.image(from: rect, scale: scale)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvas, format: format).pngData { _ in
            // Under the ink, as on the canvas.
            InkStickers.draw(stickers, origin: .zero, images: InkStickers.image)
            ink.draw(in: rect)
        }
    }

    @discardableResult
    private static func write(_ data: Data, named name: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appending(path: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// A story lasts a night: anything here older than three days goes.
    private static func prune() {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-3 * 86_400)
        for url in names {
            let made = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantFuture
            if made < cutoff {
                cache[url.lastPathComponent] = nil
                try? fm.removeItem(at: url)
            }
        }
    }
}
