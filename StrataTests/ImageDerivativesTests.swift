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

    @Test("tier M is trimmed oldest-read first under its cap; tier S never")
    func trimMedium() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        for i in 0..<3 {
            try writeOriginal("T_\(i).jpg", in: dir)
            ImageDerivatives.bake("T_\(i).jpg", tier: 320, in: dir)
            let m = try #require(ImageDerivatives.bake("T_\(i).jpg", tier: 640, in: dir))
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(Double(i - 10))],
                                                  ofItemAtPath: m.path)
        }
        ImageDerivatives.trimMedium(in: dir, cap: 1)
        let left = Set(try FileManager.default.contentsOfDirectory(atPath: ImageDerivatives.folder(in: dir).path))
        #expect(left.isSuperset(of: ["T_0.jpg@320.jpg", "T_1.jpg@320.jpg", "T_2.jpg@320.jpg"]))
        #expect(left.filter { $0.hasSuffix("@640.jpg") }.count <= 1)
    }

    // MARK: - The real directory

    /// **The data-loss bug the spec warned about.** `pruneOrphans` listed the
    /// image directory and removed everything no log named — and `derived/`
    /// is a folder no log names, and `removeItem` on a folder is recursive.
    @Test("pruneOrphans never removes derived/, and takes an orphan's derivatives with it")
    func pruneKeepsDerivedFolder() throws {
        let manager = ImageManager.shared
        let dir = manager.imageDirectoryForTesting
        let keep = "prune-derived-keep-\(UUID().uuidString).jpg"
        let drop = "prune-derived-drop-\(UUID().uuidString).jpg"
        try writeOriginal(keep, in: dir)
        try writeOriginal(drop, in: dir)
        defer {
            for name in [keep, drop] {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
                ImageDerivatives.removeDerivatives(of: name, in: dir)
            }
        }
        let keepS = try #require(ImageDerivatives.bake(keep, tier: 320, in: dir))
        let dropS = try #require(ImageDerivatives.bake(drop, tier: 320, in: dir))

        var referenced = Set(manager.allStoredFileNamesForBenchmark())
        #expect(!referenced.contains(ImageDerivatives.folderName), "the benchmark listing counts the folder as a photo")
        referenced.remove(drop)
        let removed = manager.pruneOrphans(referenced: referenced)

        #expect(removed == 1)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: ImageDerivatives.folder(in: dir).path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(FileManager.default.fileExists(atPath: keepS.path), "a live photograph's derivative was swept")
        #expect(!FileManager.default.fileExists(atPath: dropS.path), "an orphan's derivative survived")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(keep).path))
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
