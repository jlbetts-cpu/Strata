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
    ///
    /// **Fails closed.** If the file system cannot say whether it is a folder,
    /// it is treated as one: this answer decides what `pruneOrphans` may
    /// delete, and `removeItem` on a folder takes everything inside it.
    static func isOriginal(_ url: URL) -> Bool {
        guard !url.lastPathComponent.hasPrefix(".") else { return false }
        guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else {
            return false
        }
        return !isDirectory
    }

    /// The original an iCloud eviction placeholder stands for, or nil.
    ///
    /// A photograph iCloud has evicted to save space is on disk as
    /// `.<name>.icloud`. It is still the user's photograph and still has
    /// derivatives worth keeping, but it is hidden, so `isOriginal` says no.
    /// Without this, the derivative sweep would delete a photograph's copies
    /// every time it was evicted and the next read would re-bake them.
    static func placeholderOriginal(_ name: String) -> String? {
        guard name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > ".icloud".count + 1 else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    /// Creates `derived/` if needed and marks it excluded from the device
    /// backup: it is a cache the app remakes from the originals, and backing
    /// it up would spend the owner's iCloud storage on copies of copies.
    static func ensureFolder(in imageDirectory: URL) {
        var dir = folder(in: imageDirectory)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
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
                              estimatedBytes: Int64 = mediumEstimate) -> [String] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        guard let items = try? fm.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: keys)
        else { return [] }
        let baked = Set((try? fm.contentsOfDirectory(atPath: folder(in: imageDirectory).path)) ?? [])
        // Newest first, as many as the cap could ever hold. Whether each one
        // is actually kept is `admitsMedium`'s call at bake time: a newer
        // photograph displaces an older one's copy, never the reverse.
        let room = Int(max(0, cap / max(estimatedBytes, 1)))
        var candidates: [(name: String, date: Date)] = []
        for url in items where isOriginal(url) {
            let name = url.lastPathComponent
            let date = (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? Date.distantPast
            candidates.append((name, date))
        }
        candidates.sort { lhs, rhs in
            lhs.date != rhs.date ? lhs.date > rhs.date : lhs.name < rhs.name
        }
        return candidates.prefix(room)
            .map { $0.name }
            .filter { !baked.contains(derivedName(for: $0, tier: medium)) }
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

    /// What one bake did. The migration stops on `outOfSpace` rather than
    /// decoding every photograph on a full disk for nothing.
    enum Outcome: Equatable {
        case baked(URL)
        /// Tier M, and the photograph is older than everything the cap keeps.
        case notAdmitted
        case unreadable
        case outOfSpace
        case failed
        var url: URL? { if case .baked(let url) = self { return url } else { return nil } }
    }

    /// Bakes one tier from the original on disk. Reads the original, writes a
    /// NEW file under `derived/`. Returns the derivative's URL, or nil if the
    /// original is missing or unreadable.
    @discardableResult
    static func bake(_ original: String, tier: Int, in imageDirectory: URL) -> URL? {
        bakeReporting(original, tier: tier, in: imageDirectory).url
    }

    static func bakeReporting(_ original: String, tier: Int, in imageDirectory: URL) -> Outcome {
        let source = imageDirectory.appendingPathComponent(original)
        guard FileManager.default.fileExists(atPath: source.path) else { return .unreadable }
        guard tier != medium || admitsMedium(original, in: imageDirectory) else { return .notAdmitted }
        guard let decoded = decode(source, maxPixels: tier) else { return .unreadable }
        return write(prepared(decoded), original: original, tier: tier, in: imageDirectory)
    }

    /// Bakes one tier from a picture already in memory.
    @discardableResult
    static func bake(from image: UIImage, original: String, tier: Int, in imageDirectory: URL) -> URL? {
        guard let cg = image.cgImage, let resized = scaled(cg, toLongest: tier) else { return nil }
        return write(resized, original: original, tier: tier, in: imageDirectory).url
    }

    /// Both tiers from the picture the save path already holds: M from the
    /// photograph, then S from M, so the full-size picture is drawn from once
    /// rather than once per tier.
    static func bakeTiers(from image: UIImage, original: String, in imageDirectory: URL) {
        guard let cg = image.cgImage, let m = scaled(cg, toLongest: medium) else { return }
        if admitsMedium(original, in: imageDirectory) {
            _ = write(m, original: original, tier: medium, in: imageDirectory)
        }
        if let s = scaled(m, toLongest: small) {
            _ = write(s, original: original, tier: small, in: imageDirectory)
        }
    }

    /// An 8-bit copy no longer than `longest` on its longest side.
    static func scaled(_ cg: CGImage, toLongest longest: Int) -> CGImage? {
        let current = max(cg.width, cg.height)
        let scale = min(1, CGFloat(longest) / CGFloat(max(current, 1)))
        let width = max(1, Int((CGFloat(cg.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(cg.height) * scale).rounded()))
        return eightBit(cg, width: width, height: height)
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

    /// **A picture that is really decoded, drawn off the main thread.**
    ///
    /// `kCGImageSourceShouldCacheImmediately` does not make a HEIF decode
    /// happen at the call. Sampled on the iOS 26.3 simulator during viewer
    /// page turns, 54% of the MAIN thread was inside Core Animation's commit
    /// (`CA::Render::copy_image`) running `HEIFReadPlugin::decodeImageImp` —
    /// the decode had been deferred to the first draw, which is on the main
    /// thread, and it waited there on the HEVC decoder's semaphores. That is
    /// also how the app froze outright on a HEIC library: the commit blocked
    /// on an ImageIO mutex a background decode held. Drawing into a bitmap
    /// context here forces the pixels into memory on the calling (background)
    /// thread, so what reaches a view is pixels and nothing is left to decode.
    /// For a 320px thumbnail the copy is a fraction of a millisecond.
    static func prepared(_ image: CGImage) -> CGImage {
        eightBit(image, width: image.width, height: image.height) ?? image
    }

    /// The same guarantee for a full-resolution picture, without a second
    /// full-size copy: `preparingForDisplay` decodes synchronously into
    /// whatever backing the display wants, on the calling thread.
    static func preparedForDisplay(_ image: CGImage) -> UIImage {
        UIImage(cgImage: image).preparingForDisplay() ?? UIImage(cgImage: prepared(image))
    }

    /// Encodes and writes one derivative atomically, so a reader never sees
    /// half a file. A tier-M write is recorded against its byte cap, and the
    /// cap is enforced then and there, not only at the next launch.
    private static func write(_ image: CGImage, original: String, tier: Int, in imageDirectory: URL) -> Outcome {
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder(in: imageDirectory).path) { ensureFolder(in: imageDirectory) }
        let flat: CGImage
        if image.bitsPerComponent == 8 {
            flat = image
        } else if let converted = eightBit(image, width: image.width, height: image.height) {
            flat = converted
        } else {
            return .failed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return .failed }
        CGImageDestinationAddImage(destination, flat,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return .failed }
        let target = url(for: original, tier: tier, in: imageDirectory)
        do {
            try (data as Data).write(to: target, options: .atomic)
        } catch {
            return isOutOfSpace(error) ? .outOfSpace : .failed
        }
        if tier == medium {
            recordMedium(original, bytes: Int64(data.length), in: imageDirectory)
        }
        return .baked(target)
    }

    static func isOutOfSpace(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteOutOfSpaceError { return true }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOSPC) { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { return isOutOfSpace(underlying) }
        return false
    }

    // MARK: - Tier M's cap

    /// **Tier M keeps the NEWEST photographs** (fix round 1). It is baked
    /// newest first, so it must be evicted oldest first, by the ORIGINAL's
    /// date: evicting by the derivative file's own date threw away the copies
    /// just baked for this week's photographs, and a full cap then refused to
    /// bake them again. Kept per image directory, in memory, loaded from disk
    /// once; every write and every removal goes through it, so the cap holds
    /// within a session and not only at launch.
    private final class MediumLedger: @unchecked Sendable {
        let lock = NSLock()
        var byDirectory: [String: [String: (bytes: Int64, date: Date)]] = [:]
    }
    private static let ledger = MediumLedger()
    /// What a tier-M file is assumed to weigh before it exists.
    static let mediumEstimate: Int64 = 90_000

    private static func originalDate(_ original: String, in imageDirectory: URL) -> Date {
        let url = imageDirectory.appendingPathComponent(original)
        if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            return date
        }
        // An evicted iCloud placeholder still dates the photograph.
        let placeholder = imageDirectory.appendingPathComponent(".\(original).icloud")
        return (try? placeholder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }

    /// Call with `ledger.lock` held.
    private static func mediumEntries(in imageDirectory: URL) -> [String: (bytes: Int64, date: Date)] {
        let key = imageDirectory.standardizedFileURL.path
        if let loaded = ledger.byDirectory[key] { return loaded }
        var entries: [String: (bytes: Int64, date: Date)] = [:]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder(in: imageDirectory), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        for url in items {
            guard let parsed = original(ofDerived: url.lastPathComponent), parsed.tier == medium else { continue }
            let bytes = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            entries[parsed.original] = (bytes, originalDate(parsed.original, in: imageDirectory))
        }
        ledger.byDirectory[key] = entries
        return entries
    }

    private static func isOlder(_ a: (name: String, date: Date), than b: (name: String, date: Date)) -> Bool {
        a.date != b.date ? a.date < b.date : a.name < b.name
    }

    /// Whether a tier-M copy of this photograph would be kept: there is room,
    /// or it is newer than the oldest one kept. An old photograph asked for
    /// with the cap full is served from its original instead, rather than
    /// baked and immediately evicted on every read.
    static func admitsMedium(_ original: String, in imageDirectory: URL,
                             cap: Int64 = mediumByteCap) -> Bool {
        ledger.lock.lock(); defer { ledger.lock.unlock() }
        let entries = mediumEntries(in: imageDirectory)
        if entries[original] != nil { return true }
        let total = entries.values.reduce(0) { $0 + $1.bytes }
        if total + mediumEstimate <= cap { return true }
        guard let oldest = entries.map({ (name: $0.key, date: $0.value.date) })
            .min(by: { isOlder($0, than: $1) }) else { return true }
        return isOlder(oldest, than: (original, originalDate(original, in: imageDirectory)))
    }

    private static func recordMedium(_ original: String, bytes: Int64, in imageDirectory: URL,
                                     cap: Int64 = mediumByteCap) {
        ledger.lock.lock(); defer { ledger.lock.unlock() }
        var entries = mediumEntries(in: imageDirectory)
        entries[original] = (bytes, originalDate(original, in: imageDirectory))
        evict(&entries, cap: cap, in: imageDirectory)
        ledger.byDirectory[imageDirectory.standardizedFileURL.path] = entries
    }

    /// Oldest original first, until under the cap. Call with the lock held.
    private static func evict(_ entries: inout [String: (bytes: Int64, date: Date)], cap: Int64, in imageDirectory: URL) {
        var total = entries.values.reduce(0) { $0 + $1.bytes }
        guard total > cap else { return }
        let oldestFirst = entries.map { (name: $0.key, date: $0.value.date) }.sorted { isOlder($0, than: $1) }
        for entry in oldestFirst where total > cap {
            try? FileManager.default.removeItem(at: url(for: entry.name, tier: medium, in: imageDirectory))
            total -= entries[entry.name]?.bytes ?? 0
            entries[entry.name] = nil
        }
    }

    private static func forgetMedium(_ originals: [String], in imageDirectory: URL) {
        ledger.lock.lock(); defer { ledger.lock.unlock() }
        let key = imageDirectory.standardizedFileURL.path
        guard ledger.byDirectory[key] != nil else { return }
        for name in originals { ledger.byDirectory[key]?[name] = nil }
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
        forgetMedium(removedOriginals, in: imageDirectory)
        return removedOriginals
    }

    /// Removes every derivative of one original. For `deleteImage`, which has
    /// already removed the original.
    static func removeDerivatives(of original: String, in imageDirectory: URL) {
        for tier in tiers {
            try? FileManager.default.removeItem(at: url(for: original, tier: tier, in: imageDirectory))
        }
        forgetMedium([original], in: imageDirectory)
    }

    /// Keeps tier M under its byte cap, evicting the OLDEST PHOTOGRAPHS first
    /// (by the original's date). Re-reads the folder, so it also corrects a
    /// ledger that drifted. Tier S is never evicted: it is the map's and the
    /// tower's only source.
    static func trimMedium(in imageDirectory: URL, cap: Int64 = mediumByteCap) {
        ledger.lock.lock(); defer { ledger.lock.unlock() }
        ledger.byDirectory[imageDirectory.standardizedFileURL.path] = nil
        var entries = mediumEntries(in: imageDirectory)
        evict(&entries, cap: cap, in: imageDirectory)
        ledger.byDirectory[imageDirectory.standardizedFileURL.path] = entries
    }
}
