import Foundation
import Testing
import UIKit

@testable import Strata

/// The derivative tiers, the migration's work list, and the sweep that must
/// never take `derived/` with it.
@MainActor
struct ImageDerivativesTests {

    // MARK: - Fixtures

    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("derivatives-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func photo(_ size: CGSize = CGSize(width: 1200, height: 900)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 10, y: 10, width: size.width / 3, height: size.height / 3))
        }
    }

    @discardableResult
    private func writeOriginal(_ name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try photo().jpegData(compressionQuality: 0.9)!.write(to: url)
        return url
    }

    private func pixelSize(_ url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: w, height: h)
    }

    // MARK: - Tier selection

    @Test("a read is served by the smallest tier that covers it, and above tier M by the original")
    func tierSelection() {
        #expect(ImageDerivatives.tier(forPixels: 1) == 320)
        #expect(ImageDerivatives.tier(forPixels: 271) == 320)     // the map's decodeWidth at 3x
        #expect(ImageDerivatives.tier(forPixels: 320) == 320)
        #expect(ImageDerivatives.tier(forPixels: 320.2) == 640)   // rounded up, never softer
        #expect(ImageDerivatives.tier(forPixels: 432) == 640)     // the gallery's bucket
        #expect(ImageDerivatives.tier(forPixels: 640) == 640)
        #expect(ImageDerivatives.tier(forPixels: 641) == nil)
        #expect(ImageDerivatives.tier(forPixels: 2560) == nil)
    }

    @Test("every bucket the store can ask for maps to a tier at least as large")
    func bucketsNeverUpscale() {
        for bucket in ThumbnailStore.widthBuckets {
            if let tier = ImageDerivatives.tier(forPixels: CGFloat(bucket)) {
                #expect(tier >= bucket, "bucket \(bucket) read from a \(tier)px derivative")
            } else {
                #expect(bucket > ImageDerivatives.medium)
            }
        }
    }

    @Test("a derivative's name round-trips to its whole original name, extension included")
    func namesRoundTrip() {
        for original in ["A_123.heic", "A_123.jpg", "B.jpg", "weird@name_1.heic"] {
            for tier in ImageDerivatives.tiers {
                let name = ImageDerivatives.derivedName(for: original, tier: tier)
                let back = ImageDerivatives.original(ofDerived: name)
                #expect(back?.original == original)
                #expect(back?.tier == tier)
            }
        }
        #expect(ImageDerivatives.derivedName(for: "A.heic", tier: 320)
                != ImageDerivatives.derivedName(for: "A.jpg", tier: 320))
        #expect(ImageDerivatives.original(ofDerived: "A.heic") == nil)
        #expect(ImageDerivatives.original(ofDerived: "A.heic@999.jpg") == nil)
        #expect(ImageDerivatives.original(ofDerived: "@320.jpg") == nil)
    }

    @Test("the cache ceiling is 192MB on a 6GB phone and a thirty-second of a small one")
    func cacheCeiling() {
        #expect(ImageManager.cacheCostLimit(physicalMemory: 6 << 30) == 192 << 20)
        #expect(ImageManager.cacheCostLimit(physicalMemory: 12 << 30) == 192 << 20)
        #expect(ImageManager.cacheCostLimit(physicalMemory: 3 << 30) == 96 << 20)
    }

    // MARK: - Baking

    @Test("a bake writes a small 8-bit JPEG under derived/ and leaves the original byte for byte")
    func bakeLeavesOriginalAlone() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = try writeOriginal("P_1.jpg", in: dir)
        let before = try Data(contentsOf: original)
        let beforeDate = try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        let url = try #require(ImageDerivatives.bake("P_1.jpg", tier: 320, in: dir))
        #expect(url.deletingLastPathComponent().lastPathComponent == ImageDerivatives.folderName)
        let size = try #require(pixelSize(url))
        #expect(max(size.width, size.height) == 320)
        #expect(abs(size.width / size.height - 1200.0 / 900.0) < 0.01)

        #expect(try Data(contentsOf: original) == before, "the original was rewritten")
        #expect(try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == beforeDate)
        #expect(ImageDerivatives.existing(for: "P_1.jpg", pixels: 300, in: dir) == url)
    }

    @Test("a missing original bakes nothing")
    func bakeMissing() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(ImageDerivatives.bake("nope.heic", tier: 320, in: dir) == nil)
        #expect(ImageDerivatives.unbaked(in: dir).isEmpty)
    }

    @Test("a derivative older than its original is not used")
    func staleDerivativeIgnored() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = try writeOriginal("P_2.jpg", in: dir)
        let derived = try #require(ImageDerivatives.bake("P_2.jpg", tier: 320, in: dir))
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-60)],
                                              ofItemAtPath: derived.path)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: original.path)
        #expect(ImageDerivatives.existing(for: "P_2.jpg", pixels: 300, in: dir) == nil)
    }

    // MARK: - Migration

    @Test("the migration's work list is idempotent and resumes from the directory, with no cursor")
    func migrationIdempotentAndResumable() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        for i in 0..<5 { try writeOriginal("M_\(i).jpg", in: dir) }
        // Something that is not a photograph must never be on the list.
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("someFolder"),
                                                withIntermediateDirectories: true)
        try Data().write(to: dir.appendingPathComponent(".hidden"))

        #expect(ImageDerivatives.unbaked(in: dir) == (0..<5).map { "M_\($0).jpg" })

        // "Killed" after two: the next run starts at the third.
        for name in ImageDerivatives.unbaked(in: dir).prefix(2) {
            ImageDerivatives.bake(name, tier: 320, in: dir)
        }
        #expect(ImageDerivatives.unbaked(in: dir) == ["M_2.jpg", "M_3.jpg", "M_4.jpg"])

        for name in ImageDerivatives.unbaked(in: dir) { ImageDerivatives.bake(name, tier: 320, in: dir) }
        #expect(ImageDerivatives.unbaked(in: dir).isEmpty)

        // A second full run does nothing and changes nothing.
        let files = try FileManager.default.contentsOfDirectory(atPath: ImageDerivatives.folder(in: dir).path).sorted()
        #expect(ImageDerivatives.unbaked(in: dir).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: ImageDerivatives.folder(in: dir).path).sorted() == files)
        #expect(files.count == 5)
    }

    // MARK: - Housekeeping

    @Test("the derivative sweep removes only derivatives whose original is gone, and leftovers")
    func derivativeSweep() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeOriginal("K.jpg", in: dir)
        try writeOriginal("G.jpg", in: dir)
        ImageDerivatives.bake("K.jpg", tier: 320, in: dir)
        ImageDerivatives.bake("K.jpg", tier: 640, in: dir)
        ImageDerivatives.bake("G.jpg", tier: 320, in: dir)
        try Data([1]).write(to: ImageDerivatives.folder(in: dir).appendingPathComponent("half-written.tmp"))
        try FileManager.default.removeItem(at: dir.appendingPathComponent("G.jpg"))

        let gone = ImageDerivatives.pruneOrphans(originals: ["K.jpg"], in: dir)
        #expect(gone == ["G.jpg"])
        let left = try FileManager.default.contentsOfDirectory(atPath: ImageDerivatives.folder(in: dir).path).sorted()
        #expect(left == ["K.jpg@320.jpg", "K.jpg@640.jpg"])
        // Originals are never its business.
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("K.jpg").path))
    }

    private func setDate(_ url: URL, _ date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    /// Fix round 1: tier M was trimmed by the DERIVATIVE's date, which threw
    /// away the copies just baked for the newest photographs.
    @Test("tier M keeps the newest photographs, whatever order the copies were made in; tier S is never trimmed")
    func trimMediumKeepsNewest() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var sizes: [String: Int64] = [:]
        // Baked newest photograph FIRST, so its copy is the oldest file.
        for (i, age) in [(2, 0.0), (1, 86_400.0), (0, 2 * 86_400.0)] {
            let name = "T_\(i).jpg"
            let original = try writeOriginal(name, in: dir)
            try setDate(original, Date().addingTimeInterval(-age))
            ImageDerivatives.bake(name, tier: 320, in: dir)
            let m = try #require(ImageDerivatives.bake(name, tier: 640, in: dir))
            sizes[name] = Int64(try m.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        // Room for exactly the two newest.
        ImageDerivatives.trimMedium(in: dir, cap: sizes["T_2.jpg"]! + sizes["T_1.jpg"]!)
        let left = Set(try FileManager.default.contentsOfDirectory(atPath: ImageDerivatives.folder(in: dir).path))
        #expect(left.contains("T_2.jpg@640.jpg"), "the newest photograph lost its copy")
        #expect(left.contains("T_1.jpg@640.jpg"))
        #expect(!left.contains("T_0.jpg@640.jpg"), "the oldest photograph kept its copy")
        #expect(left.isSuperset(of: ["T_0.jpg@320.jpg", "T_1.jpg@320.jpg", "T_2.jpg@320.jpg"]))
    }

    @Test("with the cap full, an older photograph is not admitted to tier M and a newer one is")
    func admission() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mid = try writeOriginal("mid.jpg", in: dir)
        try setDate(mid, Date().addingTimeInterval(-86_400))
        let m = try #require(ImageDerivatives.bake("mid.jpg", tier: 640, in: dir))
        let size = Int64(try m.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        let old = try writeOriginal("old.jpg", in: dir)
        try setDate(old, Date().addingTimeInterval(-10 * 86_400))
        try writeOriginal("new.jpg", in: dir)
        #expect(!ImageDerivatives.admitsMedium("old.jpg", in: dir, cap: size))
        #expect(ImageDerivatives.admitsMedium("new.jpg", in: dir, cap: size))
        #expect(ImageDerivatives.admitsMedium("mid.jpg", in: dir, cap: size), "a photograph already kept")
    }

    @Test("derived/ is excluded from the device backup")
    func excludedFromBackup() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeOriginal("B.jpg", in: dir)
        ImageDerivatives.bake("B.jpg", tier: 320, in: dir)
        let values = try ImageDerivatives.folder(in: dir).resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("out of space is recognised however the error arrives")
    func outOfSpace() {
        #expect(ImageDerivatives.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
        #expect(ImageDerivatives.isOutOfSpace(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                              userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))])
        #expect(ImageDerivatives.isOutOfSpace(wrapped))
        #expect(!ImageDerivatives.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)))
    }

    @Test("a directory entry the file system cannot describe is not treated as a photograph")
    func isOriginalFailsClosed() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(!ImageDerivatives.isOriginal(dir.appendingPathComponent("vanished.heic")))
        #expect(!ImageDerivatives.isOriginal(dir))
        #expect(ImageDerivatives.isOriginal(try writeOriginal("real.jpg", in: dir)))
        #expect(ImageDerivatives.placeholderOriginal(".A_1.heic.icloud") == "A_1.heic")
        #expect(ImageDerivatives.placeholderOriginal("A_1.heic") == nil)
        #expect(ImageDerivatives.placeholderOriginal(".icloud") == nil)
    }

    /// Measured on a photograph added through the picker: stored 5760x7680.
    @Test("a saved photograph is resized in pixels and drawn at scale 1")
    func resizeInPixels() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let big = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
        }
        let out = ImageManager.resizeIfNeeded(big, maxDimension: 2560)
        #expect(out.scale == 1)
        #expect(out.cgImage.map { max($0.width, $0.height) } == 2560)
        let small = photo(CGSize(width: 900, height: 1200))
        #expect(ImageManager.resizeIfNeeded(small, maxDimension: 2560) === small)
    }

    // MARK: - The real directory

    /// **The data-loss bug the spec warned about.** `pruneOrphans` listed the
    /// image directory and removed everything no log named — and `derived/`
    /// is a folder no log names, and `removeItem` on a folder is recursive.
    @Test("pruneOrphans never removes derived/, and takes an orphan's derivatives with it")
    func pruneKeepsDerivedFolder() throws {
        // A temp directory, never the test host's real photographs.
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeOriginal("keep.jpg", in: dir)
        try writeOriginal("drop.jpg", in: dir)
        try writeOriginal("evicted.heic", in: dir)
        let keepS = try #require(ImageDerivatives.bake("keep.jpg", tier: 320, in: dir))
        let dropS = try #require(ImageDerivatives.bake("drop.jpg", tier: 320, in: dir))
        let evictedS = try #require(ImageDerivatives.bake("evicted.heic", tier: 320, in: dir))
        // iCloud evicts it: the file becomes a hidden placeholder.
        try FileManager.default.moveItem(at: dir.appendingPathComponent("evicted.heic"),
                                         to: dir.appendingPathComponent(".evicted.heic.icloud"))

        let result = ImageManager.pruneOrphans(referenced: ["keep.jpg", "evicted.heic"], in: dir)

        #expect(result.removed == ["drop.jpg"])
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: ImageDerivatives.folder(in: dir).path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(FileManager.default.fileExists(atPath: keepS.path), "a live photograph's derivative was swept")
        #expect(FileManager.default.fileExists(atPath: evictedS.path), "an evicted photograph's derivative was swept")
        #expect(!FileManager.default.fileExists(atPath: dropS.path), "an orphan's derivative survived")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".evicted.heic.icloud").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("keep.jpg").path))
    }

    @Test("a full decode asked for by a task already cancelled never runs")
    func cancelledFullDecode() async throws {
        let manager = ImageManager.shared
        let name = "cancelled-full-\(UUID().uuidString).jpg"
        try writeOriginal(name, in: manager.imageDirectoryForTesting)
        defer { manager.deleteImage(fileName: name) }
        let task = Task { () -> UIImage? in
            withUnsafeCurrentTask { $0?.cancel() }
            return await manager.loadFullImage(fileName: name)
        }
        #expect(await task.value == nil)
        #expect(await manager.loadFullImage(fileName: name) != nil)
    }

    @Test("deleting one photograph removes its derivatives and forgets only its own pictures")
    func deleteIsLocal() async throws {
        let manager = ImageManager.shared
        let dir = manager.imageDirectoryForTesting
        let a = "delete-local-a-\(UUID().uuidString).jpg"
        let b = "delete-local-b-\(UUID().uuidString).jpg"
        try writeOriginal(a, in: dir)
        try writeOriginal(b, in: dir)
        defer {
            manager.deleteImage(fileName: a)
            manager.deleteImage(fileName: b)
        }
        ImageDerivatives.bake(a, tier: 320, in: dir)
        _ = await manager.loadThumbnail(fileName: a, maxWidth: 256)
        _ = await manager.loadThumbnail(fileName: b, maxWidth: 256)
        #expect(manager.isCachedForTesting(b, maxWidth: 256))

        manager.deleteImage(fileName: a)
        #expect(!FileManager.default.fileExists(atPath: ImageDerivatives.url(for: a, tier: 320, in: dir).path))
        #expect(!manager.isCachedForTesting(a, maxWidth: 256))
        #expect(manager.isCachedForTesting(b, maxWidth: 256), "one delete flushed another photograph's picture")
    }

    @Test("storage counts photographs, not derivatives, and includes the derivatives' bytes")
    func storageIncludesDerived() throws {
        let manager = ImageManager.shared
        let dir = manager.imageDirectoryForTesting
        let name = "storage-\(UUID().uuidString).jpg"
        try writeOriginal(name, in: dir)
        defer { manager.deleteImage(fileName: name) }
        let before = manager.storageUsed()
        let derived = try #require(ImageDerivatives.bake(name, tier: 320, in: dir))
        let after = manager.storageUsed()
        let size = Int64(try derived.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        #expect(after.count == before.count)
        #expect(after.bytes == before.bytes + size)
    }

    @Test("a read with no derivative yet bakes one, and the next read uses it")
    func readBakesOnDemand() async throws {
        let manager = ImageManager.shared
        let dir = manager.imageDirectoryForTesting
        let name = "read-bakes-\(UUID().uuidString).jpg"
        try writeOriginal(name, in: dir)
        defer { manager.deleteImage(fileName: name) }
        let image = try #require(await manager.loadThumbnail(fileName: name, maxWidth: 264))
        #expect(max(image.size.width, image.size.height) * image.scale <= 264.5)
        // Written on the bake lane; give it a moment.
        let url = ImageDerivatives.url(for: name, tier: 320, in: dir)
        for _ in 0..<50 where !FileManager.default.fileExists(atPath: url.path) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
