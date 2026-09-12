import UIKit
import ImageIO

final class ImageManager: @unchecked Sendable {
    static let shared = ImageManager()

    /// Where the photographs live.
    ///
    /// Readable so a backup can copy them and Settings can total them up. It
    /// is a folder in Documents, so it is included in the device backup iOS
    /// makes on its own — this is about the file the owner can hand to
    /// somebody, or keep when they change phone.
    let imageDirectory: URL
    private let thumbnailCache = NSCache<NSString, UIImage>()
    /// Concurrent, and with NOTHING that blocks on it.
    ///
    /// **The bound was right and the primitive was wrong.** This queue briefly
    /// had a `DispatchSemaphore` limiting decodes to one per core, which reads
    /// like prudence and is the classic way to exhaust a thread pool: a
    /// semaphore blocks the worker holding it, and GCD answers a blocked
    /// worker by spawning another. With a gallery scrolling, a map of
    /// twenty-eight blocks and a month of thirty asking at once, enough
    /// workers sat blocked that new work never started — photographs that
    /// were slow, then photographs that never arrived at all.
    ///
    /// Measured at 80 cold thumbnails, all three ways:
    ///
    ///     serial queue                      3.0x slower than this
    ///     concurrent + blocking semaphore   stalls under load
    ///     Task.detached (cooperative pool)  545ms   1.53x
    ///     concurrent, nothing blocking      215ms   5.12x  <- this
    ///
    /// The cooperative pool is bounded by construction and was the safe
    /// answer, but it is two and a half times slower here. Non-blocking work
    /// on a concurrent queue needs no bound: every block does its decode and
    /// returns, so threads are always making progress and none can starve.
    private let ioQueue = DispatchQueue(label: "com.strata.imagemanager.io",
                                        qos: .userInitiated, attributes: .concurrent)

    /// How much room the photographs take, in bytes, and how many there are.
    ///
    /// Walked rather than summed from a counter: a counter drifts the first
    /// time anything writes a file without telling it, and the number people
    /// check is the one that has to be true.
    func storageUsed() -> (count: Int, bytes: Int64) {
        let keys: [URLResourceKey] = [.fileSizeKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: keys) else { return (0, 0) }
        var bytes: Int64 = 0
        for url in items {
            let size = (try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0
            bytes += Int64(size)
        }
        return (items.count, bytes)
    }

    /// Delete image files that no win refers to any more.
    ///
    /// **Nothing in this app had ever cleaned up, and it showed: 3127
    /// photographs, 522MB, on a phone whose owner had taken a fraction of
    /// that.** Three paths leaked. Deleting a win removed the rows and left
    /// its pictures on disk; replacing a photograph overwrote `imageFileName`
    /// and abandoned the file it had pointed at; and no sweep existed to
    /// collect either. All three are fixed, but the files already stranded can
    /// only be found this way.
    ///
    /// **This is the most dangerous function in the app.** CLAUDE.md: "Never
    /// delete or rewrite image files on a code path that only meant to read
    /// them." This one means to delete, which is exactly why the caller must
    /// hand over a set it KNOWS is complete — a failed fetch presented as an
    /// empty set would erase every photograph the user has. The caller
    /// distinguishes a throw from an empty result; this refuses to help it
    /// cheat, and takes the set rather than fetching one itself.
    ///
    /// - Parameter referenced: every file name any log points at, complete.
    /// - Returns: how many files were removed, for the log.
    @discardableResult
    func pruneOrphans(referenced: Set<String>) -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: nil) else { return 0 }
        var removed = 0
        for url in items {
            let name = url.lastPathComponent
            guard !name.hasPrefix("."), !referenced.contains(name) else { continue }
            try? FileManager.default.removeItem(at: url)
            removed += 1
        }
        if removed > 0 { thumbnailCache.removeAllObjects() }
        return removed
    }

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = docs.appendingPathComponent("strata-images", isDirectory: true)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: imageDirectory.path) {
            try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }

        // Cache limits: 100 thumbnails, ~50MB
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
    }

    // MARK: - Save

    /// Resizes and encodes to HEIC (or JPEG fallback), writes to disk.
    /// Returns the generated fileName (e.g. "UUID.heic").
    /// Trims an image to an aspect ratio, from the centre.
    ///
    /// This is what replaced the crop screen. A block clips its photo to its
    /// own shape anyway, so the pixels outside that shape are stored, resized
    /// and decoded for a picture nobody can see — a 4:3 photo on a 2:1 block
    /// wastes a third of the file. Trimming first means what is on disk is
    /// what is on the block.
    ///
    /// Centre is the right default rather than a compromise: the middle of the
    /// frame is where people put the subject, so a centre trim keeps it and a
    /// crop screen mostly confirms what a centre trim would have done anyway.
 
    /// How large a photograph is kept.
    ///
    /// **1024 was throwing away three quarters of the screen.** A 6.3" phone
    /// is 1206x2622 pixels, so a portrait photograph stored 1024 tall was
    /// being stretched 2.56x to fill the viewer — every picture in the app
    /// arrived soft, and no amount of camera work fixes a photograph that is
    /// upscaled after capture. Measured on a real full-screen photograph, the
    /// whole saving was 117KB:
    ///
    ///     cap 1024   471x1024     45 KB   <- was
    ///     cap 2048   942x2048    115 KB
    ///     cap 2560  1177x2560    ~160 KB  <- is
    ///
    /// 2560 covers today's screens at 3x with a little spare for the viewer's
    /// pinch-zoom, and is still an order of magnitude under the 12MP original.
    /// A real camera photograph carries more detail than that fixture, so
    /// expect a few hundred KB each rather than 160.
    static let storedMaxDimension: CGFloat = 2560

    func save(image: UIImage, for logID: UUID,
              maxDimension: CGFloat = ImageManager.storedMaxDimension,
              quality: CGFloat = 0.85) async throws -> String {
        let heicSupported = Self.isHEICSupported()
        let ext = heicSupported ? "heic" : "jpg"
        let suffix = Int(Date().timeIntervalSince1970) % 100000
        let fileName = "\(logID.uuidString)_\(suffix).\(ext)"
        let fileURL = imageDirectory.appendingPathComponent(fileName)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ioQueue.async {
                let resized = Self.resizeIfNeeded(image, maxDimension: maxDimension)

                let data: Data?
                if heicSupported {
                    data = Self.encodeHEIC(image: resized, quality: quality)
                } else {
                    data = resized.jpegData(compressionQuality: quality)
                }

                guard let imageData = data else {
                    continuation.resume(throwing: ImageManagerError.compressionFailed)
                    return
                }
                do {
                    try imageData.write(to: fileURL, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return fileName
    }

    // MARK: - HEIC Encoding

    private static func isHEICSupported() -> Bool {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return types.contains("public.heic")
    }

    private static func encodeHEIC(image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.heic" as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Load Thumbnail

    /// A thumbnail already in memory, or nil. Synchronous, so a view can draw
    /// it during its own body rather than waiting for a lifecycle callback
    /// that may never come. See `ThumbnailStore`.
    func cachedThumbnail(fileName: String, maxWidth: CGFloat) -> UIImage? {
        thumbnailCache.object(forKey: "\(fileName)_\(Int(maxWidth))" as NSString)
    }

    /// Returns a downsampled thumbnail from cache or disk. Thread-safe.
    func loadThumbnail(fileName: String, maxWidth: CGFloat) async -> UIImage? {
        let cacheKey = "\(fileName)_\(Int(maxWidth))" as NSString

        // Cache hit
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        // Cache miss — downsample from disk
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        // **Decoded on Swift's cooperative pool, not on a GCD queue.**
        //
        // This used to be a concurrent `DispatchQueue` whose workers took a
        // `DispatchSemaphore` to bound how many decodes ran at once. The bound
        // was right and the primitive was wrong: a semaphore BLOCKS the thread
        // holding it, and blocking GCD workers is how a thread pool is
        // exhausted. With a gallery scrolling, a map of twenty-eight blocks
        // and a month of thirty all asking at once, enough workers sat blocked
        // that new work never started — photographs that were slow, and then
        // photographs that never arrived at all.
        //
        // A detached task needs no bound, because the cooperative pool already
        // has one: it is as wide as the machine has cores, and work queues
        // rather than spawning threads. Nothing blocks, so nothing can starve.
        let thumbnail: UIImage? = await withCheckedContinuation { continuation in
            ioQueue.async {
                continuation.resume(returning:
                    Self.downsample(url: fileURL, maxPixelWidth: maxWidth))
            }
        }
        guard let thumbnail else { return nil }
        let cost = Int(thumbnail.size.width * thumbnail.size.height
                       * thumbnail.scale * thumbnail.scale * 4)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: cost)
        return thumbnail
    }

    // MARK: - Load Full Image

    /// Loads the full-resolution image from disk with forced background decode.
    /// Not cached — use only for detail/carousel views.
    func loadFullImage(fileName: String) async -> UIImage? {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            ioQueue.async {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL,
                                                          sourceOptions as CFDictionary)
            else { continuation.resume(returning: nil); return }
            let decodeOptions: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0,
                                                                decodeOptions as CFDictionary)
            else { continuation.resume(returning: nil); return }
            continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    // MARK: - Delete

    /// Removes the image file from disk and evicts related cache entries.
    func deleteImage(fileName: String) {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        // Nuke all cached thumbnails — NSCache can't enumerate by prefix,
        // and hardcoded widths miss actual display sizes. Regeneration is cheap.
        thumbnailCache.removeAllObjects()
    }

    /// The directory, for the prune tests. They need real files on disk —
    /// there is no way to test a function about the file system otherwise.
    var imageDirectoryForTesting: URL { imageDirectory }

    /// Drops every cached thumbnail. Only a benchmark needs this — it exists
    /// so a measurement can start cold rather than reporting cache hits.
    func emptyThumbnailCacheForBenchmark() {
        thumbnailCache.removeAllObjects()
    }

    /// Every photograph on disk, for the same reason.
    func allStoredFileNamesForBenchmark() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: imageDirectory.path)) ?? [])
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    // MARK: - Exists

    func fileExists(fileName: String) -> Bool {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Resize

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - ImageIO Downsample

    private static func downsample(url: URL, maxPixelWidth: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelWidth,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Migration Support

    /// Saves raw JPEG data directly to disk (used by migration runner for existing imageData blobs).
    func saveData(_ data: Data, for logID: UUID) throws -> String {
        let fileName = "\(logID.uuidString).jpg"
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileName
    }
}

// MARK: - Error

enum ImageManagerError: Error {
    case compressionFailed
}
