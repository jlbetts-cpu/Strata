import Foundation
import ImageIO
import UniformTypeIdentifiers
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "WinPhoto")

/// The bytes a `WinPhoto` carries: the photograph again, smaller.
///
/// **1600px, not the 2560 the phone keeps, so a year of photographs fits a
/// free iCloud plan** (the owner's pick, 2026-10-08: "sync at a smaller size").
/// `docs/research/icloud-backup.md` section 7 puts a real 2560px photograph at
/// about 600KB and shows a free 5GB account, already shared with the device
/// backup, filling inside the first year at two photographs a day. Pixels go
/// with the square of the side, so 1600 is 39% of the pixels of 2560 and lands
/// at roughly a third of the bytes, which is the difference between a year
/// fitting and not. It is still wider than a 6.3" phone's screen is across, so
/// a restored photograph fills the viewer at full width; what it gives up is
/// the deepest pinch-zoom, on the restored phone only. The phone that took the
/// picture keeps reading its own 2560px file and never sees this copy.
///
/// The one number, in one place. Change it and every photograph attached after
/// the change syncs at the new size; photographs already in iCloud stay as
/// they are, because nothing re-encodes a `WinPhoto` that has bytes.
nonisolated enum WinPhotoPayload {
    /// The longest side of the synced copy, in pixels. See the type's note.
    static let maxDimension: CGFloat = 1600
    /// Lossy quality for the synced copy. A step under the 0.85 the original
    /// is saved at, because this is the copy that costs the person storage.
    static let quality: CGFloat = 0.8

    /// Whether this device can write HEIC. Every iPhone this app supports can;
    /// JPEG is the fallback for a simulator or a future device that cannot,
    /// and it is the same choice `ImageManager.save` makes.
    static let encodesHEIC: Bool =
        (CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []).contains(UTType.heic.identifier)

    /// The synced copy of the photograph at `url`, or nil when it is missing or
    /// will not decode.
    ///
    /// Through ImageIO's thumbnailer, which decodes straight to the target size
    /// and never holds the full picture. Never upscales: a photograph already
    /// smaller than the cap is re-encoded at its own size.
    static func make(fromFileAt url: URL, maxDimension: CGFloat = maxDimension,
                     quality: CGFloat = quality) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        return make(from: source, maxDimension: maxDimension, quality: quality)
    }

    static func make(from source: CGImageSource, maxDimension: CGFloat = maxDimension,
                     quality: CGFloat = quality) -> Data? {
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let type = encodesHEIC ? UTType.heic.identifier : UTType.jpeg.identifier
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out as CFMutableData, type as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}

/// Putting a photograph's iCloud copy on its win, taking it off, and the two
/// passes that move pictures between the store and the image directory.
///
/// **Every write of `imageFileName` for a new or replaced photograph comes
/// through `attach`** (2026-10-08), so a photograph is in the sync from the
/// moment it is on its block: `AddWinSheet`, the one-tap win in `MainAppView`,
/// `TaggedWinKeeper`, and the undo in `WinDeletion`. A restore from a backup
/// file does not attach one by one; it asks `PhotoSync` for a backfill pass,
/// which finds every photographed win with no copy, and the backfill is also
/// what catches the debug seeds, `ImageMigrationRunner`'s old blobs, and any
/// attach that was killed half way. Taking a photograph off a win goes through
/// `detach`.
enum WinPhotoStore {

    // MARK: - Attaching

    /// Gives a win the iCloud copy of the photograph it now names.
    ///
    /// Call it AFTER `imageFileName` has been written and saved: the encode
    /// happens off the main actor and takes a moment, and the win is not made
    /// to wait for its own backup. If the win has moved on by the time the
    /// bytes are ready (deleted, or given a different photograph), nothing is
    /// attached, and whoever moved it on attaches their own.
    ///
    /// - Returns: the copy now on the win, or nil when none could be made,
    ///   which the backfill retries on a later launch.
    @discardableResult
    static func attach(fileName: String, to log: HabitLog, context: ModelContext,
                       imageDirectory: URL? = nil) async -> WinPhoto? {
        let url = (imageDirectory ?? ImageManager.shared.imageDirectory).appendingPathComponent(fileName)
        let data = await Task.detached(priority: .utility) { WinPhotoPayload.make(fromFileAt: url) }.value
        guard !log.isDeleted, log.modelContext != nil, log.imageFileName == fileName else { return nil }
        return link(fileName: fileName, data: data, to: log, context: context)
    }

    /// `attach`, for a caller that is not async. The sheet closes and the
    /// tower draws while the copy is made.
    static func attachSoon(fileName: String, to log: HabitLog, context: ModelContext) {
        Task { @MainActor in _ = await attach(fileName: fileName, to: log, context: context) }
    }

    /// Puts these bytes on the win under this name, replacing a copy of any
    /// other photograph, and saves.
    ///
    /// **A copy of a different photograph is deleted even when there are no
    /// new bytes to put in its place.** It is the old picture; leaving it on
    /// the win would put the wrong photograph back on a restored phone.
    @discardableResult
    static func link(fileName: String, data: Data?, to log: HabitLog, context: ModelContext) -> WinPhoto? {
        if let existing = log.photo {
            if existing.fileName == fileName { return existing }
            log.photo = nil
            context.delete(existing)
        }
        guard let data else {
            save(context, what: "taking an old photograph's copy off a win")
            return nil
        }
        let photo = WinPhoto(fileName: fileName, data: data)
        context.insert(photo)
        log.photo = photo
        save(context, what: "a photograph's iCloud copy")
        return photo
    }

    /// Takes the iCloud copy off a win whose photograph is being removed. The
    /// caller saves, in the same save that clears `imageFileName`, so the two
    /// can never disagree on disk.
    ///
    /// Deleting the row is what deletes the copy from iCloud. It never touches
    /// a file: the photograph on disk is the caller's to remove, after its own
    /// save, as it always was.
    static func detach(from log: HabitLog, context: ModelContext) {
        guard let photo = log.photo else { return }
        log.photo = nil
        context.delete(photo)
    }

    /// Saves a change that is only about the iCloud copy.
    ///
    /// **Quietly: not stamped, and not sent to a crew.** Linking a copy changes
    /// the `HabitLog` it hangs on (the inverse), so an ordinary save would move
    /// that win's `updatedAt` and `CrewSync` would send every crew holding it
    /// an "edit" with its photograph. A backfill over a year of wins would
    /// re-send a year of photographs to friends. Nothing a person can see
    /// changed, so nothing says it did.
    ///
    /// Never `try?`: logged when it fails, and the backfill finds the win again
    /// on a later launch.
    static func save(_ context: ModelContext, what: String) {
        do {
            try StoreStamp.withoutStamping { try context.save() }
        } catch {
            logger.error("\(what, privacy: .public) did not save: \(String(describing: error), privacy: .private)")
        }
    }

    // MARK: - Which names are in use

    /// Every photograph file name the store points at: the wins' names and the
    /// iCloud copies' names, together.
    ///
    /// **The copies' names are the half that matters under sync.** A copy can
    /// arrive, and be written out as a file, before the win that names it has
    /// arrived; the old reading, the wins' names alone, called that file an
    /// orphan. Throws rather than returning an empty set: an empty set handed
    /// to `pruneOrphans` erases every photograph on the phone.
    static func referencedNames(context: ModelContext) throws -> Set<String> {
        var names = Set(try context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.imageFileName != nil })).compactMap(\.imageFileName))
        var descriptor = FetchDescriptor<WinPhoto>()
        descriptor.propertiesToFetch = [\.fileName]
        for photo in try context.fetch(descriptor) where !photo.fileName.isEmpty {
            names.insert(photo.fileName)
        }
        return names
    }

    // MARK: - The backfill

    /// What one backfill pass did, for the log and the tests.
    struct BackfillReport: Equatable {
        /// Copies made.
        var created = 0
        /// Wins whose photograph is not on this phone. On a new phone that is
        /// every win whose copy has not arrived yet, which is why it is not a
        /// failure; the copy is coming the other way.
        var missingFile = 0
        /// Wins whose photograph would not decode.
        var unreadable = 0
        /// Wins that already had a copy.
        var alreadyHad = 0
        /// The pass was told to stop before the end.
        var stoppedEarly = false
    }

    /// Makes the iCloud copy for every photographed win that has none.
    ///
    /// **Newest first**, so a pass that stops half way (a full iCloud, a kill,
    /// the app going away) has sent the half the person looked at most
    /// recently. **Paged** (`pageSize` wins read at a time, `batchSize` encoded
    /// at a time off the main actor), so a library of thousands is never in
    /// memory at once and the main actor only ever holds a page of rows.
    ///
    /// Only CREATES rows. It reads photograph files and never writes, moves or
    /// deletes one; a win whose file is missing is skipped, not changed.
    ///
    /// - Parameter proceed: asked before every batch; false stops the pass.
    ///   `PhotoSync` sleeps in it, waits out a busy moment, and says no when
    ///   iCloud is full.
    static func backfill(context: ModelContext, imageDirectory: URL,
                         pageSize: Int = 24, batchSize: Int = 6,
                         proceed: () async -> Bool = { true }) async -> BackfillReport {
        var report = BackfillReport()
        var offset = 0
        while true {
            // The set this pages over is "every win with a photograph", which
            // the backfill itself never changes, so the offset stays true.
            var descriptor = FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.imageFileName != nil },
                sortBy: [SortDescriptor(\.dateString, order: .reverse),
                         SortDescriptor(\.createdAt, order: .reverse)])
            descriptor.fetchLimit = pageSize
            descriptor.fetchOffset = offset
            let page: [HabitLog]
            do {
                page = try context.fetch(descriptor)
            } catch {
                logger.error("the backfill could not read the wins: \(String(describing: error), privacy: .private)")
                report.stoppedEarly = true
                return report
            }
            guard !page.isEmpty else { return report }
            offset += page.count

            var wanting: [(log: HabitLog, name: String)] = []
            for log in page {
                guard let name = log.imageFileName else { continue }
                if log.photo != nil { report.alreadyHad += 1 } else { wanting.append((log, name)) }
            }

            var start = 0
            while start < wanting.count {
                guard !Task.isCancelled, await proceed() else {
                    report.stoppedEarly = true
                    return report
                }
                let batch = Array(wanting[start..<min(start + batchSize, wanting.count)])
                start += batch.count
                let jobs = batch.map { (name: $0.name, url: imageDirectory.appendingPathComponent($0.name)) }
                let made = await Task.detached(priority: .utility) { () -> [String: Encoded] in
                    var out: [String: Encoded] = [:]
                    for job in jobs {
                        guard FileManager.default.fileExists(atPath: job.url.path) else {
                            out[job.name] = .missing
                            continue
                        }
                        out[job.name] = WinPhotoPayload.make(fromFileAt: job.url).map(Encoded.bytes) ?? .unreadable
                    }
                    return out
                }.value

                var changed = false
                for item in batch {
                    switch made[item.name] ?? .missing {
                    case .missing:
                        report.missingFile += 1
                    case .unreadable:
                        report.unreadable += 1
                    case .bytes(let data):
                        // The win may have moved on while its copy was made.
                        guard !item.log.isDeleted, item.log.modelContext != nil,
                              item.log.photo == nil, item.log.imageFileName == item.name else { continue }
                        let photo = WinPhoto(fileName: item.name, data: data)
                        context.insert(photo)
                        item.log.photo = photo
                        report.created += 1
                        changed = true
                    }
                }
                if changed { save(context, what: "a backfill batch") }
            }
            if page.count < pageSize { return report }
        }
    }

    nonisolated enum Encoded: Sendable {
        case bytes(Data)
        case missing
        case unreadable
    }

    // MARK: - The materialiser

    /// What one materialise pass did.
    nonisolated struct Materialised: Equatable, Sendable {
        /// Files written, by name.
        var written: [String] = []
        /// Copies whose file was already on disk, and left alone.
        var present = 0
        /// Copies that could not be written, by name.
        var failed: [String] = []
        /// The store could not be read, so nothing was decided.
        var unreadable = false
    }

    /// Writes out every iCloud copy whose photograph is not on this phone.
    ///
    /// **It only ever CREATES files. It never overwrites and never deletes a
    /// photograph.** CLAUDE.md: "Never delete or rewrite image files on a code
    /// path that only meant to read them", and a path that only means to fill
    /// a gap has no business touching a file that is already there. The file
    /// on a phone that took the picture is the 2560px original; this copy is
    /// 1600px, and writing it over the original would quietly throw away the
    /// better photograph. So a name that is present is skipped, the write goes
    /// to a temporary file first, and the move into place refuses an existing
    /// name (`moveItem` does not replace), which closes the gap between the
    /// check and the write.
    ///
    /// **Off the main actor, on a context of its own, a few rows at a time.**
    /// The names are read first, in pages, without the bytes; only the copies
    /// actually missing on disk are read with their bytes, eight at a time, on
    /// a fresh context each time so nothing builds up. A thousand photographs
    /// are never in memory at once.
    ///
    /// - Returns: what was written. The caller tells the image views
    ///   (`ThumbnailStore.fileArrived`), so a block drawing its colour while
    ///   its picture was missing asks again and the picture fades in.
    nonisolated static func materialise(container: ModelContainer, imageDirectory: URL,
                                        isCancelled: () -> Bool = { false }) -> Materialised {
        var out = Materialised()
        let fm = FileManager.default
        try? fm.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        sweepStaleParts(in: imageDirectory)

        // 1. Which names are missing. Names and dates only, never the bytes.
        var missing: [String] = []
        var seen = Set<String>()
        var offset = 0
        let pageSize = 200
        while true {
            if isCancelled() { return out }
            let page: [String]? = autoreleasepool {
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<WinPhoto>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                descriptor.fetchLimit = pageSize
                descriptor.fetchOffset = offset
                descriptor.propertiesToFetch = [\.fileName, \.createdAt]
                guard let rows = try? context.fetch(descriptor) else { return nil }
                return rows.map(\.fileName)
            }
            guard let page else {
                out.unreadable = true
                return out
            }
            if page.isEmpty { break }
            offset += page.count
            for name in page {
                guard let safe = safeName(name), seen.insert(safe).inserted else { continue }
                if isPresent(safe, in: imageDirectory) { out.present += 1 } else { missing.append(safe) }
            }
            if page.count < pageSize { break }
        }

        // 2. Their bytes, a few at a time, each written once.
        var start = 0
        while start < missing.count {
            if isCancelled() { break }
            let chunk = Array(missing[start..<min(start + 8, missing.count)])
            start += chunk.count
            autoreleasepool {
                let context = ModelContext(container)
                let names = chunk
                let descriptor = FetchDescriptor<WinPhoto>(predicate: #Predicate { names.contains($0.fileName) })
                guard let rows = try? context.fetch(descriptor) else {
                    out.failed += chunk
                    return
                }
                for name in chunk {
                    // A copy with no bytes yet is an asset still on its way
                    // down. The next pass picks it up; it is not a failure.
                    guard let data = rows.first(where: { $0.fileName == name && $0.data != nil })?.data else {
                        continue
                    }
                    switch writeNew(data, named: name, in: imageDirectory) {
                    case .written: out.written.append(name)
                    case .alreadyThere: out.present += 1
                    case .refused, .notAPicture, .failed: out.failed.append(name)
                    }
                }
            }
        }
        return out
    }

    nonisolated enum WriteOutcome: Equatable, Sendable {
        case written, alreadyThere, refused, notAPicture, failed
    }

    /// Writes bytes under a name that is not taken, or does nothing.
    ///
    /// Decoded first, as `ImageManager.adopt` does with a backup, so a damaged
    /// copy is never written out as a block with a grey hole in it.
    nonisolated static func writeNew(_ data: Data, named name: String, in directory: URL) -> WriteOutcome {
        guard let safe = safeName(name) else { return .refused }
        let target = directory.appendingPathComponent(safe)
        let fm = FileManager.default
        if isPresent(safe, in: directory) { return .alreadyThere }
        guard ImageManager.decodes(data) else { return .notAPicture }
        let part = directory.appendingPathComponent("\(partPrefix)\(UUID().uuidString)\(partSuffix)")
        do {
            try data.write(to: part, options: .atomic)
        } catch {
            return .failed
        }
        do {
            // Refuses an existing destination, which is the guarantee.
            try fm.moveItem(at: part, to: target)
        } catch {
            try? fm.removeItem(at: part)
            return fm.fileExists(atPath: target.path) ? .alreadyThere : .failed
        }
        return .written
    }

    /// A name from the store, reduced to a plain file name in the image
    /// directory, or nil when it is not one. The same rule `adopt` applies to a
    /// name out of a zip: nothing that arrives from iCloud can aim a write
    /// outside the folder, or at a hidden file.
    nonisolated static func safeName(_ name: String) -> String? {
        let safe = (name as NSString).lastPathComponent
        guard !safe.isEmpty, safe == name, safe != ".", safe != "..", !safe.hasPrefix(".") else { return nil }
        return safe
    }

    /// The photograph is on this phone, or is an evicted placeholder of it,
    /// which counts as present for the same reason it does in `pruneOrphans`.
    nonisolated static func isPresent(_ name: String, in directory: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: directory.appendingPathComponent(name).path)
            || fm.fileExists(atPath: directory.appendingPathComponent(".\(name).icloud").path)
    }

    /// The temporary file a write goes through. Hidden, so `pruneOrphans` and
    /// the derivative migration both pass it by.
    nonisolated static let partPrefix = ".winphoto-"
    nonisolated static let partSuffix = ".part"

    /// Removes this file's own leftovers from a write that was killed between
    /// the two steps. Only names this code makes: the prefix and the suffix
    /// together, plain files, never anything else in the folder.
    nonisolated static func sweepStaleParts(in directory: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: []) else { return }
        for url in items {
            let name = url.lastPathComponent
            guard name.hasPrefix(partPrefix), name.hasSuffix(partSuffix) else { continue }
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? true
            guard !isFolder else { continue }
            try? fm.removeItem(at: url)
        }
    }
}
