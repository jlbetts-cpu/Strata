import UIKit
import ImageIO
import QuartzCore

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
    /// **Every thumbnail something is still holding, whether or not the cache
    /// still is.** Weak values: an entry lives exactly as long as a view (or
    /// anything else) keeps the picture alive.
    ///
    /// The cache evicts on count and cost, and it used to evict pictures that
    /// were ON SCREEN. The view asking again then got nothing, dropped the
    /// picture, showed its placeholder, re-read the file and faded the same
    /// picture back in. That is the photo viewer's filmstrip dimming and
    /// re-fading for seconds after a switch to dark mode (the replay posters
    /// for the new scheme decode dozens of photographs and pushed the strip's
    /// out of a 100-entry cache), and with a year of photographs it never
    /// stopped at all: the strip and the map traded evictions for ever and
    /// their pictures never settled. A picture still alive is handed back and
    /// put back in the cache instead, so nothing on screen can be evicted out
    /// from under itself, and nothing is decoded twice while it is showing.
    private let liveThumbnails = NSMapTable<NSString, UIImage>(keyOptions: .copyIn,
                                                               valueOptions: .weakMemory)
    private let liveLock = NSLock()
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

    /// **Three lanes, one shape** (2026-09-16). Each is the same concurrent,
    /// non-blocking queue measured above, at a different QoS, so the system
    /// runs what a person is looking at first:
    ///
    ///     visible    .userInitiated   a view drawing now asked for it (`ioQueue`)
    ///     prefetch   .utility         ahead of a scroll, a slideshow's next
    ///                                 frame, a replay warming up, the widget
    ///     bake       .background      the derivative migration
    ///
    /// No semaphore on any of them — see `ioQueue`. How many run at once is
    /// bounded one level up: `ThumbnailStore` caps the visible and prefetch
    /// lanes, and the migration bakes one file at a time and waits whenever
    /// the store has visible work.
    enum Lane: Sendable { case visible, prefetch, bake }

    private let prefetchQueue = DispatchQueue(label: "com.strata.imagemanager.prefetch",
                                              qos: .utility, attributes: .concurrent)
    private let bakeQueue = DispatchQueue(label: "com.strata.imagemanager.bake",
                                          qos: .background, attributes: .concurrent)

    /// **Decodes of an ORIGINAL, bounded without blocking anything**
    /// (2026-09-16).
    ///
    /// Measured on the iOS 26.3 simulator against a library of 2560px HEIC
    /// originals (`-strataSeedRealPhotos`), the queue above FROZE THE APP.
    /// `-strataBenchImages 200` put 64 GCD workers inside VideoToolbox's HEVC
    /// decoder, every one parked on a semaphore waiting for work that needed
    /// a thread, for 20+ minutes. Opening the map did the same with the 48
    /// reads `ThumbnailStore` allows — and then the main thread blocked too,
    /// in Core Animation's commit, on an ImageIO mutex one of those decodes
    /// held. Every earlier measurement of this pipeline was taken against the
    /// JPEG fixture, which never enters VideoToolbox, so none of them could
    /// see it. (Simulator only, as far as this machine can tell; the device
    /// decodes HEVC in hardware, and that is unverified.)
    ///
    /// An `OperationQueue` with a concurrency limit is the non-blocking bound
    /// the semaphore was not: it does not START more than this many, so no
    /// thread ever waits. With derivatives in place almost nothing comes
    /// here — only a photograph not yet migrated, the viewer's full decode,
    /// and the migration itself.
    private let originalDecodes: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.strata.imagemanager.originals"
        queue.maxConcurrentOperationCount = ImageManager.maxOriginalDecodes
        return queue
    }()
    static let maxOriginalDecodes = 3

    /// Runs `work` on the originals queue at the lane's priority.
    private func decodeOriginal<T>(_ lane: Lane, _ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            let op = BlockOperation { continuation.resume(returning: work()) }
            switch lane {
            case .visible: op.qualityOfService = .userInitiated; op.queuePriority = .high
            case .prefetch: op.qualityOfService = .utility; op.queuePriority = .low
            case .bake: op.qualityOfService = .background; op.queuePriority = .veryLow
            }
            originalDecodes.addOperation(op)
        }
    }

    private func queue(_ lane: Lane) -> DispatchQueue {
        switch lane {
        case .visible: ioQueue
        case .prefetch: prefetchQueue
        case .bake: bakeQueue
        }
    }

    /// How much room the photographs take, in bytes, and how many there are.
    ///
    /// Walked rather than summed from a counter: a counter drifts the first
    /// time anything writes a file without telling it, and the number people
    /// check is the one that has to be true.
    func storageUsed() -> (count: Int, bytes: Int64) {
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: keys) else { return (0, 0) }
        var bytes: Int64 = 0
        var count = 0
        for url in items where ImageDerivatives.isOriginal(url) {
            count += 1
            bytes += Int64((try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0)
        }
        // **The derivatives count too.** They are this app's bytes on this
        // phone, and a figure that left out `derived/` would stop being true
        // the day it shipped. The count stays photographs, not files.
        let derived = ImageDerivatives.folder(in: imageDirectory)
        for url in (try? FileManager.default.contentsOfDirectory(
            at: derived, includingPropertiesForKeys: keys)) ?? [] {
            bytes += Int64((try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0)
        }
        return (count, bytes)
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
    ///
    /// **It never touches a directory** (2026-09-16). `removeItem` on a folder
    /// is recursive, and `derived/` — every derivative in the app — is a
    /// folder whose name no log refers to, so the first sweep after the
    /// derivatives shipped would have deleted all of them. Only plain files
    /// are candidates; derivatives get their own pass, which removes one only
    /// when its original is no longer on disk.
    @discardableResult
    func pruneOrphans(referenced: Set<String>) -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else { return 0 }
        var removed = 0
        var removedNames: [String] = []
        var survivors = Set<String>()
        for url in items where ImageDerivatives.isOriginal(url) {
            let name = url.lastPathComponent
            guard !referenced.contains(name) else { survivors.insert(name); continue }
            do {
                try FileManager.default.removeItem(at: url)
                removed += 1
                removedNames.append(name)
            } catch {
                survivors.insert(name)
            }
        }
        let derivedGone = ImageDerivatives.pruneOrphans(originals: survivors, in: imageDirectory)
        forgetThumbnails(of: removedNames + derivedGone)
        return removed
    }

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = docs.appendingPathComponent("strata-images", isDirectory: true)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: imageDirectory.path) {
            try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }

        // **Cost governs, not count.** It was 100 thumbnails and 50MB, and a
        // hundred is four screens of the gallery, or the map's eighty blocks
        // and not much else — every visit back re-decoded. Three hundred is
        // no longer the binding limit; 150MB is (about 300 map-sized
        // pictures), and NSCache still empties itself under memory pressure.
        //
        // **A fraction of the phone, not a constant** (2026-09-16): 192MB on
        // a 6GB phone, 96MB on a 3GB one, so a small phone is not carrying a
        // large phone's ceiling. Raised only once the entries got cheap: a
        // map picture from a 320px derivative costs about half what one from
        // the original did, so 600 fit where 300 used to.
        thumbnailCache.countLimit = 600
        thumbnailCache.totalCostLimit = Self.cacheCostLimit(physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    /// `min(192MB, physicalMemory / 32)`.
    static func cacheCostLimit(physicalMemory: UInt64) -> Int {
        Int(min(UInt64(192 << 20), physicalMemory / 32))
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
                    // Both tiers from the picture already in hand: two small
                    // encodes and no decode. After the original is safely on
                    // disk, and a failure here costs nothing but a lazy bake
                    // on first read. See `ImageDerivatives`.
                    for tier in ImageDerivatives.tiers {
                        ImageDerivatives.bake(from: resized, original: fileName,
                                              tier: tier, in: self.imageDirectory)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        announceArrival(fileName)
        return fileName
    }

    /// A file now exists under this name, so anything that asked for it and
    /// was told there was nothing can ask again. See `ThumbnailStore`.
    private func announceArrival(_ fileName: String) {
        Task { @MainActor in ThumbnailStore.shared.fileArrived(fileName) }
    }

    // MARK: - HEIC Encoding

    private static func isHEICSupported() -> Bool {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return types.contains("public.heic")
    }

    #if DEBUG
    /// The save path's own encoder, for `-strataSeedRealPhotos`, so a seeded
    /// photograph is the same kind of file a saved one is.
    static func encodeHEICForSeeding(image: UIImage, quality: CGFloat) -> Data? {
        encodeHEIC(image: image, quality: quality)
    }
    #endif

    nonisolated private static func encodeHEIC(image: UIImage, quality: CGFloat) -> Data? {
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
        let key = "\(fileName)_\(Int(maxWidth))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        return recoverLive(key)
    }

    /// A picture the cache let go of that is still alive somewhere, put back.
    /// See `liveThumbnails`.
    private func recoverLive(_ key: NSString) -> UIImage? {
        liveLock.lock()
        let alive = liveThumbnails.object(forKey: key)
        liveLock.unlock()
        guard let alive else { return nil }
        thumbnailCache.setObject(alive, forKey: key, cost: Self.cost(of: alive))
        return alive
    }

    nonisolated private static func cost(of image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    }

    private func forgetAllThumbnails() {
        thumbnailCache.removeAllObjects()
        liveLock.lock()
        liveThumbnails.removeAllObjects()
        keysByName.removeAll()
        liveLock.unlock()
    }

    /// Every cache key a file has been decoded under, so ONE photograph can be
    /// forgotten. Keys only — never an image — so this keeps nothing alive.
    /// Guarded by `liveLock`.
    ///
    /// Deleting one photograph in the viewer used to empty the whole cache,
    /// "because NSCache can't enumerate by prefix", and the gallery underneath
    /// re-decoded every picture it had.
    private var keysByName: [String: Set<NSString>] = [:]

    private func remember(_ key: NSString, for fileName: String) {
        liveLock.lock()
        keysByName[fileName, default: []].insert(key)
        liveLock.unlock()
    }

    /// Forgets these photographs' pictures and nobody else's.
    private func forgetThumbnails(of fileNames: [String]) {
        guard !fileNames.isEmpty else { return }
        liveLock.lock()
        var keys: [NSString] = []
        for name in fileNames { keys += keysByName.removeValue(forKey: name) ?? [] }
        for key in keys { liveThumbnails.removeObject(forKey: key) }
        liveLock.unlock()
        for key in keys { thumbnailCache.removeObject(forKey: key) }
    }

    #if DEBUG
    /// Whether a picture is in memory for this file at this width, for the
    /// eviction tests.
    func isCachedForTesting(_ fileName: String, maxWidth: CGFloat) -> Bool {
        thumbnailCache.object(forKey: "\(fileName)_\(Int(maxWidth))" as NSString) != nil
    }
    #endif

    /// Returns a downsampled thumbnail from cache or disk. Thread-safe.
    ///
    /// **Read from the smallest derivative that covers the width**, and from
    /// the original only above tier M. A photograph with no derivative yet is
    /// decoded from its original ONCE at the tier's size, which both answers
    /// this read and becomes the derivative (written on the bake lane, so the
    /// encode never sits in front of a visible picture).
    func loadThumbnail(fileName: String, maxWidth: CGFloat, lane: Lane = .visible,
                       cancelled: CancelFlag? = nil) async -> UIImage? {
        let cacheKey = "\(fileName)_\(Int(maxWidth))" as NSString

        // Cache hit, or a picture still alive after the cache let it go
        if let cached = thumbnailCache.object(forKey: cacheKey) ?? recoverLive(cacheKey) {
            return cached
        }

        // Cache miss — downsample from disk
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let directory = imageDirectory

        // Decoded on a concurrent GCD queue with nothing blocking on it — see
        // `ioQueue` for the measurement (5.12x against serial; the cooperative
        // pool was 1.53x). How many are asked for at once is bounded one level
        // up, in `ThumbnailStore`.
        // Which file answers this is decided here, before any queue: a
        // derivative goes to its lane's concurrent queue, an original to the
        // bounded `originalDecodes`. Two `stat`s, microseconds.
        let derived = ImageDerivatives.existing(for: fileName, pixels: maxWidth, in: directory)
        let thumbnail: UIImage?
        if let derived {
            thumbnail = await withCheckedContinuation { continuation in
                queue(lane).async {
                    // **Cancelled before it started, not during.** A decode
                    // cannot be interrupted, so the only useful moment to drop
                    // one whose cell has scrolled away is before it begins.
                    if cancelled?.isSet == true { continuation.resume(returning: nil); return }
                    #if DEBUG
                    Self.countSource("derived")
                    #endif
                    continuation.resume(returning: Self.downsample(url: derived, maxPixelWidth: maxWidth))
                }
            }
        } else {
            let bakeQueue = self.bakeQueue
            thumbnail = await decodeOriginal(lane) {
                if cancelled?.isSet == true { return nil }
                return Self.readThumbnail(fileName: fileName, url: fileURL, maxWidth: maxWidth,
                                          directory: directory, bakeQueue: bakeQueue)
            }
        }
        guard let thumbnail else { return nil }
        thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: Self.cost(of: thumbnail))
        liveLock.lock()
        liveThumbnails.setObject(thumbnail, forKey: cacheKey)
        liveLock.unlock()
        remember(cacheKey, for: fileName)
        return thumbnail
    }

    /// A flag a caller sets to drop a read that has not started. Checked once,
    /// at the top of the queue block.
    final class CancelFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set() { lock.withLock { value = true } }
    }

    /// A read with no derivative, off the main thread. See `loadThumbnail`.
    nonisolated private static func readThumbnail(fileName: String, url: URL, maxWidth: CGFloat,
                                      directory: URL, bakeQueue: DispatchQueue) -> UIImage? {
        guard let tier = ImageDerivatives.tier(forPixels: maxWidth) else {
            #if DEBUG
            countSource("original")
            #endif
            return downsample(url: url, maxPixelWidth: maxWidth)
        }
        // No derivative yet: one decode of the original at the tier's size.
        #if DEBUG
        countSource("bakedOnRead")
        #endif
        guard let tierImage = ImageDerivatives.decode(url, maxPixels: tier) else { return nil }
        bakeQueue.async {
            // `bake(from:)` writes only under `derived/`; the original is
            // not touched. It is re-checked there, so a file deleted in the
            // meantime is simply not baked.
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            ImageDerivatives.bake(from: UIImage(cgImage: tierImage), original: fileName,
                                  tier: tier, in: directory)
        }
        let longest = max(tierImage.width, tierImage.height)
        guard CGFloat(longest) > maxWidth.rounded(.up) else { return UIImage(cgImage: tierImage) }
        let scale = maxWidth / CGFloat(longest)
        guard let smaller = ImageDerivatives.eightBit(
            tierImage, width: max(1, Int((CGFloat(tierImage.width) * scale).rounded())),
            height: max(1, Int((CGFloat(tierImage.height) * scale).rounded()))) else {
            return UIImage(cgImage: tierImage)
        }
        return UIImage(cgImage: smaller)
    }

    #if DEBUG
    /// Where each cold read came from, for `-strataPerfProbe`: after the
    /// migration nearly every read should say `derived`.
    nonisolated private static func countSource(_ source: String) {
        guard PerfProbe.isOn else { return }
        Task { @MainActor in PerfProbe.count("ThumbFrom-\(source)") }
    }
    #endif

    // MARK: - Migration

    /// Bakes tier S for every photograph that does not have one yet, at
    /// background priority, one file at a time, and never while a person is
    /// waiting on a picture. Trims tier M under its cap first.
    ///
    /// **Idempotent and resumable by construction**: the work list is
    /// `ImageDerivatives.unbaked`, recomputed from the directory, so there is
    /// no cursor to persist or corrupt, a second run finds nothing to do, and
    /// a run killed half way loses at most the one file it was writing.
    ///
    /// **It only creates files under `derived/`.** See `ImageDerivatives`:
    /// no original is written, moved or deleted by anything reachable from
    /// here.
    ///
    /// - Returns: how many were baked.
    @discardableResult
    func migrateDerivatives() async -> Int {
        let directory = imageDirectory
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            bakeQueue.async {
                ImageDerivatives.trimMedium(in: directory)
                done.resume()
            }
        }
        // Tier S for every photograph first — the map and the tower have no
        // other source — then tier M for the newest, up to its cap.
        let work = await withCheckedContinuation { (found: CheckedContinuation<[(String, Int)], Never>) in
            bakeQueue.async {
                let small = ImageDerivatives.unbaked(in: directory).map { ($0, ImageDerivatives.small) }
                let medium = ImageDerivatives.unbakedMedium(in: directory).map { ($0, ImageDerivatives.medium) }
                found.resume(returning: small + medium)
            }
        }
        guard !work.isEmpty else { return 0 }
        #if DEBUG
        let started = CACurrentMediaTime()
        PerfProbe.emit("[PERF-MIGRATE] start unbaked=\(work.count)")
        #endif
        var baked = 0
        for (name, tier) in work {
            if Task.isCancelled { break }
            // Visible work outranks this absolutely: wait until nothing on
            // screen is being read or waiting to be.
            while await MainActor.run(body: { ThumbnailStore.shared.hasVisibleWork }) {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { break }
            }
            let ok = await decodeOriginal(.bake) {
                ImageDerivatives.bake(name, tier: tier, in: directory) != nil
            }
            if ok { baked += 1 }
            await Task.yield()
        }
        #if DEBUG
        PerfProbe.emit(String(format: "[PERF-MIGRATE] done baked=%d of %d in %.1fs",
                              baked, work.count, CACurrentMediaTime() - started))
        #endif
        return baked
    }

    // MARK: - Load Full Image

    /// Loads the full-resolution image from disk with forced background decode.
    /// Not cached — use only for detail/carousel views.
    func loadFullImage(fileName: String) async -> UIImage? {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        // Through the bounded originals queue: a full HEIC decode is exactly
        // the work that froze the app when too many ran at once.
        return await decodeOriginal(.visible) {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL,
                                                          sourceOptions as CFDictionary)
            else { return nil }
            let decodeOptions: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0,
                                                                decodeOptions as CFDictionary)
            else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }

    // MARK: - Delete

    /// Removes the image file from disk and evicts related cache entries.
    func deleteImage(fileName: String) {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        ImageDerivatives.removeDerivatives(of: fileName, in: imageDirectory)
        // This photograph's pictures, and no one else's — see `keysByName`.
        // The live table entries go too, or a deleted photograph could be
        // handed back to a view still asking for it.
        forgetThumbnails(of: [fileName])
    }

    /// The directory, for the prune tests. They need real files on disk —
    /// there is no way to test a function about the file system otherwise.
    var imageDirectoryForTesting: URL { imageDirectory }

    /// Drops every cached thumbnail. Only a benchmark needs this — it exists
    /// so a measurement can start cold rather than reporting cache hits.
    func emptyThumbnailCacheForBenchmark() {
        forgetAllThumbnails()
    }

    /// Evicts the cache only, leaving pictures still held alive recoverable.
    /// What memory pressure does; for `ThumbnailStoreTests`.
    func evictThumbnailCacheForTesting() {
        thumbnailCache.removeAllObjects()
    }

    /// Every photograph on disk, for the same reason.
    func allStoredFileNamesForBenchmark() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
            .filter(ImageDerivatives.isOriginal)
            .map(\.lastPathComponent)
            .sorted()
    }

    // MARK: - Exists

    func fileExists(fileName: String) -> Bool {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Resize

    nonisolated private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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

    nonisolated private static func downsample(url: URL, maxPixelWidth: CGFloat) -> UIImage? {
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
        announceArrival(fileName)
        return fileName
    }
}

// MARK: - Error

enum ImageManagerError: Error {
    case compressionFailed
}
