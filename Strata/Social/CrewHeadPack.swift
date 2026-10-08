import Foundation
import ImageIO
import UniformTypeIdentifiers

/// **Your head, small enough to send.** Every face and its shut twin at 256px
/// instead of 600, and the manifest, in one file that becomes one `CKAsset` on
/// your Member record.
///
/// 256 because the largest a friend's head is ever drawn is the tower head's
/// side, 64pt at 3x is 192px, and the eyes are canvas fractions, so they need
/// no change at any size. A whole head comes to about 150 KB.
///
/// The receiving phone unpacks it into a folder and loads it with
/// `HeadStore.load(at:)`, exactly as its own heads are loaded: one reader, so
/// a friend's head blinks and plays faces the way yours does.
nonisolated struct CrewHeadPack: Codable, Sendable {
    static let side: CGFloat = 256

    /// File name to bytes. Names are the head folder's own (`neutral.png`,
    /// `head.json`): never a path.
    var files: [String: Data]

    static func make(from directory: URL, side: CGFloat = side) -> Data? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path),
              names.contains("head.json") else { return nil }
        var files: [String: Data] = [:]
        for name in names where isSafe(name) {
            guard let data = try? Data(contentsOf: directory.appending(path: name)) else { continue }
            if name.hasSuffix(".png") {
                guard let small = shrink(data, to: side) else { continue }
                files[name] = small
            } else if name == "head.json" {
                files[name] = data
            }
        }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try? encoder.encode(CrewHeadPack(files: files))
    }

    /// Writes a pack into `directory` and loads it. Nil when it is not a head.
    @discardableResult
    static func unpack(_ data: Data, into directory: URL) throws -> HeadRig? {
        let pack = try PropertyListDecoder().decode(CrewHeadPack.self, from: data)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, bytes) in pack.files where isSafe(name) {
            try bytes.write(to: directory.appending(path: name), options: .atomic)
        }
        return HeadStore.load(at: directory)?.rig
    }

    /// Every picture in a pack, in name order, or nil when the data is not a
    /// pack.
    static func images(in data: Data) -> [Data]? {
        guard let pack = try? PropertyListDecoder().decode(CrewHeadPack.self, from: data) else { return nil }
        return pack.files.filter { isSafe($0.key) && $0.key.hasSuffix(".png") }
            .sorted { $0.key < $1.key }.map(\.value)
    }

    /// **Whether a head may go to a crew** (the 2026-10-08 audit): every
    /// face in it passes `check`, the photo check a win's photograph passes.
    /// A head is cut out of a photograph and went unchecked. A pack that
    /// cannot be read, or holds no picture, does not pass.
    static func passes(_ data: Data, check: @Sendable (Data) async -> Bool) async -> Bool {
        guard let images = images(in: data), !images.isEmpty else { return false }
        for image in images where !(await check(image)) { return false }
        return true
    }

    /// A plain file name with one of a head's two extensions. A pack is
    /// another person's data, so nothing in it may name a path.
    static func isSafe(_ name: String) -> Bool {
        !name.contains("/") && !name.contains("..") && !name.hasPrefix(".")
            && (name.hasSuffix(".png") || name == "head.json")
    }

    private static func shrink(_ png: Data, to side: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? out as Data : nil
    }
}
