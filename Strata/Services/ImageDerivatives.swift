import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Small JPEG copies of every photograph, made once, so no thumbnail ever
/// decodes the 2560px original. (2026-09-16, `research-image-loading.md`.)
///
/// **Why.** Every thumbnail in the app — eighty map blocks, every gallery
/// cell, every tower block — used to open the stored original: a 2560px HEIC,
/// decoded in full and then scaled down to a few hundred pixels. That decode
/// is the whole of "the images can't keep up". A 320px JPEG holds about a
/// fiftieth of the pixels and JPEG decodes about twice as fast as HEIC.
///
/// **Two tiers, in a `derived/` folder beside the originals.**
///
///     strata-images/
///       <name>.heic                the original, never touched by this file
///       derived/
///         <name>.heic@320.jpg      tier S: baked at save, and by `migrate`
///         <name>.heic@640.jpg      tier M: baked the first time it is asked for
///
/// The derivative is named after the WHOLE original file name, extension
/// included, so two originals that differ only by extension can never share
/// one. A derivative is a pure function of its original: invalidated by the
/// original's deletion (`pruneOrphans` and `deleteImage` sweep it) and by the
/// original being newer than it (checked on read).
///
/// **SAFETY — read this before "optimising" anything here.** CLAUDE.md:
/// "Never delete or rewrite image files on a code path that only meant to read
/// them." Everything in this type only ever CREATES files under `derived/`. It
/// never writes to an original, never deletes one, never moves one, and never
/// touches `HabitLog.imageFileName`. An original is opened read-only by
/// `CGImageSourceCreateWithURL` and nothing else. The only deletions it makes
/// are of its own derivatives, and only of ones whose original is already
/// gone or of tier-M files over their byte cap.
nonisolated enum ImageDerivatives {
    /// The folder under the image directory. `pruneOrphans` must skip it by
    /// this name; see that function.
    static let folderName = "derived"

    /// Longest side, in pixels, of each tier.
    ///
    /// 320 covers the map (271px asked), the tower 1x1 (260), the month
    /// block (255) and the filmstrip (222) with no upscaling. 640 covers the
    /// gallery on every phone width (371-436), the tower 2x2 (531) and album
    /// covers. Above 640 the original is read, which is the viewer, sharing
    /// and a replay's largest blocks.
    static let small = 320
    static let medium = 640
    static let tiers = [small, medium]

    /// Tier M is a cache, not a record: evicted oldest-read first past this.
    static let mediumByteCap: Int64 = 96 * 1024 * 1024

    /// JPEG quality for both tiers. At 320px a derivative is ~20KB.
    static let quality: CGFloat = 0.8

    // MARK: - Pure

    /// The tier a read of `pixels` on its longest side comes from, or nil for
    /// the original. Rounded UP, so a derivative is never smaller than asked.
    static func tier(forPixels pixels: CGFloat) -> Int? {
        let wanted = Int(pixels.rounded(.up))
        return tiers.first { wanted <= $0 }
    }

    /// `<original>@<tier>.jpg`.
    static func derivedName(for original: String, tier: Int) -> String {
        "\(original)@\(tier).jpg"
    }

    /// The original a derivative was made from, or nil if the name is not one
    /// of ours. The inverse of `derivedName`.
    static func original(ofDerived name: String) -> (original: String, tier: Int)? {
        guard name.hasSuffix(".jpg"), let at = name.lastIndex(of: "@") else { return nil }
        let tierText = name[name.index(after: at)..<name.index(name.endIndex, offsetBy: -4)]
        guard let tier = Int(tierText), tiers.contains(tier) else { return nil }
        let original = String(name[..<at])
        return original.isEmpty ? nil : (original, tier)
    }

    /// Whether a directory entry is an original photograph, rather than a
    /// hidden file or a folder (ours or anyone's).
    static func isOriginal(_ url: URL) -> Bool {
        guard !url.lastPathComponent.hasPrefix(".") else { return false }
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return !isDirectory
    }

    static func folder(in imageDirectory: URL) -> URL {
        imageDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    static func url(for original: String, tier: Int, in imageDirectory: URL) -> URL {
        folder(in: imageDirectory).appendingPathComponent(derivedName(for: original, tier: tier))
    }

    /// Originals that have no tier-S derivative yet, which is the migration's
    /// whole work list. **There is no cursor.** The list is recomputed from
    /// the directory every time, so a run killed half way resumes exactly
    /// where it stopped and nothing can be baked twice or skipped.
    static func unbaked(in imageDirectory: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        let baked = Set((try? fm.contentsOfDirectory(atPath: folder(in: imageDirectory).path)) ?? [])
        return items.filter(isOriginal)
            .map(\.lastPathComponent)
            .filter { !baked.contains(derivedName(for: $0, tier: small)) }
            .sorted()
    }

    /// Originals with no tier-M derivative, NEWEST first, for as many as fit
    /// under the tier's byte cap alongside what is already baked. The gallery
    /// and the 2x2 blocks read tier M, and a camera roll is scrolled from the
    /// top, so the photographs most likely to be looked at are baked first
    /// and the oldest are left to bake on first read.
    static func unbakedMedium(in imageDirectory: URL, cap: Int64 = mediumByteCap,
                              estimatedBytes: Int64 = 90_000) -> [String] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        guard let items = try? fm.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: keys)
        else { return [] }
        let derived = folder(in: imageDirectory)
        var existingBytes: Int64 = 0
        var baked = Set<String>()
        for url in (try? fm.contentsOfDirectory(at: derived, includingPropertiesForKeys: [.fileSizeKey])) ?? [] {
            baked.insert(url.lastPathComponent)
            if original(ofDerived: url.lastPathComponent)?.tier == medium {
                existingBytes += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        let room = Int(max(0, (cap - existingBytes) / max(estimatedBytes, 1)))
        var candidates: [(name: String, date: Date)] = []
        for url in items where isOriginal(url) {
            let name = url.lastPathComponent
            guard !baked.contains(derivedName(for: name, tier: medium)) else { continue }
            let date = (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? Date.distantPast
            candidates.append((name, date))
        }
        candidates.sort { lhs, rhs in
            lhs.date != rhs.date ? lhs.date > rhs.date : lhs.name < rhs.name
        }
        return candidates.prefix(room).map { $0.name }
    }

    // MARK: - Reading

    /// The file a read of `pixels` should decode: a fresh derivative if one
    /// exists, else nil (the caller reads the original). A derivative older
    /// than its original is stale and is not used.
    static func existing(for original: String, pixels: CGFloat, in imageDirectory: URL) -> URL? {
        guard let tier = tier(forPixels: pixels) else { return nil }
        let derived = url(for: original, tier: tier, in: imageDirectory)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let dDate = try? derived.resourceValues(forKeys: keys).contentModificationDate else { return nil }
        let source = imageDirectory.appendingPathComponent(original)
        if let sDate = try? source.resourceValues(forKeys: keys).contentModificationDate, sDate > dDate {
            return nil
        }
        return derived
    }

    // MARK: - Baking

    /// Bakes one tier from the original on disk. Reads the original, writes a
    /// NEW file under `derived/`. Returns the derivative's URL, or nil if the
    /// original is missing or unreadable.
    @discardableResult
    static func bake(_ original: String, tier: Int, in imageDirectory: URL) -> URL? {
        let source = imageDirectory.appendingPathComponent(original)
        guard FileManager.default.fileExists(atPath: source.path),
              let image = decode(source, maxPixels: tier) else { return nil }
        return write(image, original: original, tier: tier, in: imageDirectory)
    }

    /// Bakes tier S from a picture already in memory — the save path, which
    /// holds the resized photograph and should not decode what it just
    /// encoded.
    @discardableResult
    static func bake(from image: UIImage, original: String, tier: Int, in imageDirectory: URL) -> URL? {
        guard let cg = image.cgImage else { return nil }
        let longest = max(cg.width, cg.height)
        let scale = min(1, CGFloat(tier) / CGFloat(max(longest, 1)))
        let width = max(1, Int((CGFloat(cg.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(cg.height) * scale).rounded()))
        guard let resized = eightBit(cg, width: width, height: height) else { return nil }
        return write(resized, original: original, tier: tier, in: imageDirectory)
    }

    /// A read-only decode of `url` at `maxPixels` on its longest side,
    /// orientation applied.
    static func decode(_ url: URL, maxPixels: Int) -> CGImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// **Eight bits a channel, always.** A 16-bit wide-gamut original decodes
    /// to a 16-bit image, which doubles decode time and memory, and
    /// `ImageManager.cost(of:)` charges four bytes a pixel — so a 16-bit
    /// thumbnail was silently charged half of what it held. Wide-gamut
    /// sources keep Display P3; everything else is sRGB.
    static func eightBit(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let wide = image.colorSpace?.isWideGamutRGB ?? false
        guard let space = CGColorSpace(name: wide ? CGColorSpace.displayP3 : CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                                        | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Encodes and writes one derivative atomically: to a temporary name in
    /// `derived/`, then renamed into place, so a reader never sees half a
    /// file and a kill mid-write leaves only a temp file `pruneOrphans` sweeps.
    private static func write(_ image: CGImage, original: String, tier: Int, in imageDirectory: URL) -> URL? {
        let fm = FileManager.default
        let dir = folder(in: imageDirectory)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let flat: CGImage
        if image.bitsPerComponent == 8 {
            flat = image
        } else if let converted = eightBit(image, width: image.width, height: image.height) {
            flat = converted
        } else {
            return nil
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, flat,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        let target = url(for: original, tier: tier, in: imageDirectory)
        do {
            try (data as Data).write(to: target, options: .atomic)
            return target
        } catch {
            return nil
        }
    }

    // MARK: - Housekeeping

    /// Removes derivatives whose original is no longer on disk, and any
    /// leftover that is not a derivative name at all (an interrupted atomic
    /// write). Only ever looks inside `derived/`.
    ///
    /// - Parameter originals: every original file name currently on disk.
    @discardableResult
    static func pruneOrphans(originals: Set<String>, in imageDirectory: URL) -> [String] {
        let fm = FileManager.default
        let dir = folder(in: imageDirectory)
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        var removedOriginals: [String] = []
        for name in names {
            if let parsed = original(ofDerived: name) {
                guard !originals.contains(parsed.original) else { continue }
                removedOriginals.append(parsed.original)
            }
            try? fm.removeItem(at: dir.appendingPathComponent(name))
        }
        return removedOriginals
    }

    /// Removes every derivative of one original. For `deleteImage`, which has
    /// already removed the original.
    static func removeDerivatives(of original: String, in imageDirectory: URL) {
        for tier in tiers {
            try? FileManager.default.removeItem(at: url(for: original, tier: tier, in: imageDirectory))
        }
    }

    /// Keeps tier M under its byte cap, evicting the least recently read.
    /// Tier S is never evicted: it is the map's and the tower's only source.
    static func trimMedium(in imageDirectory: URL, cap: Int64 = mediumByteCap) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey]
        guard let items = try? fm.contentsOfDirectory(at: folder(in: imageDirectory),
                                                      includingPropertiesForKeys: keys) else { return }
        var medium: [(url: URL, size: Int64, used: Date)] = []
        for url in items {
            guard let parsed = original(ofDerived: url.lastPathComponent), parsed.tier == Self.medium,
                  let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let used = values.contentAccessDate ?? values.contentModificationDate ?? .distantPast
            medium.append((url, Int64(values.fileSize ?? 0), used))
        }
        var total = medium.reduce(0) { $0 + $1.size }
        guard total > cap else { return }
        for entry in medium.sorted(by: { $0.used < $1.used }) where total > cap {
            try? fm.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}
