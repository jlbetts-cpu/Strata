import Testing
import Foundation
import ImageIO
import SwiftData
import UIKit
@testable import Strata

/// **The photographs back up too** (2026-10-08). The owner's rule, from
/// September: "A design where a restored phone shows the tower with blocks that
/// have lost their pictures is not acceptable."
///
/// These pin the four halves of it with no iCloud at all: a photograph gets a
/// smaller copy on its win, the copy goes when the win does, a copy that
/// arrives is written out as the file the block reads without ever touching a
/// file already there, and the photographs from before sync get copies. Plus
/// the guard on the one function that deletes photographs.
///
/// Every file lives in a temporary folder handed in as the image directory,
/// never the app's real one.
@MainActor
@Suite("WinPhotoSync", .serialized)
struct WinPhotoSyncTests {

    // MARK: - Fixtures

    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none))
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("winphoto-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A photograph-like JPEG: stripes, so it does not compress to nothing.
    private func jpeg(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for x in stride(from: 0, to: width, by: 7) {
                UIColor(hue: CGFloat(x % 360) / 360, saturation: 0.7, brightness: 0.9, alpha: 1).setFill()
                ctx.fill(CGRect(x: x, y: 0, width: 7, height: height))
            }
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    private func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: w, height: h)
    }

    @discardableResult
    private func win(_ context: ModelContext, day: String, photo: String?) -> HabitLog {
        let habit = Habit(title: "Win \(day)", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: day, completed: true)
        context.insert(log)
        log.imageFileName = photo
        return log
    }

    private func count(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<WinPhoto>())
    }

    // MARK: - Attaching

    @Test("attaching makes a copy no larger than 1600px on a side, and smaller than the photograph")
    func attachMakesASmallerCopy() async throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = jpeg(width: 3000, height: 2000)
        try original.write(to: dir.appendingPathComponent("A_1.jpg"))

        let context = ModelContext(try container())
        let log = win(context, day: "2026-10-01", photo: "A_1.jpg")
        try context.save()

        let photo = await WinPhotoStore.attach(fileName: "A_1.jpg", to: log, context: context, imageDirectory: dir)
        #expect(photo != nil, "no copy was made")
        #expect(log.photo?.fileName == "A_1.jpg")
        let data = try #require(photo?.data)
        let size = try #require(pixelSize(of: data))
        #expect(max(size.width, size.height) == WinPhotoPayload.maxDimension)
        // The aspect survives the shrink.
        #expect(abs(size.width / size.height - 1.5) < 0.01)
        #expect(data.count < original.count)
        #expect(try count(context) == 1)
    }

    @Test("a photograph smaller than the cap is not blown up")
    func payloadNeverUpscales() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("small.jpg")
        try jpeg(width: 800, height: 600).write(to: url)
        let data = try #require(WinPhotoPayload.make(fromFileAt: url))
        #expect(pixelSize(of: data) == CGSize(width: 800, height: 600))
    }

    @Test("replacing a photograph replaces its copy, and the old copy is gone")
    func replacingSwapsTheCopy() async throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try jpeg(width: 400, height: 400).write(to: dir.appendingPathComponent("A_1.jpg"))
        try jpeg(width: 400, height: 300).write(to: dir.appendingPathComponent("A_2.jpg"))

        let context = ModelContext(try container())
        let log = win(context, day: "2026-10-01", photo: "A_1.jpg")
        try context.save()
        await WinPhotoStore.attach(fileName: "A_1.jpg", to: log, context: context, imageDirectory: dir)

        log.imageFileName = "A_2.jpg"
        try context.save()
        await WinPhotoStore.attach(fileName: "A_2.jpg", to: log, context: context, imageDirectory: dir)

        #expect(log.photo?.fileName == "A_2.jpg")
        #expect(try count(context) == 1, "the first photograph's copy outlived it")
    }

    @Test("a copy made for a photograph the win no longer names is not attached")
    func attachIgnoresAWinThatMovedOn() async throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try jpeg(width: 400, height: 400).write(to: dir.appendingPathComponent("A_1.jpg"))
        let context = ModelContext(try container())
        let log = win(context, day: "2026-10-01", photo: nil)
        try context.save()
        let photo = await WinPhotoStore.attach(fileName: "A_1.jpg", to: log, context: context, imageDirectory: dir)
        #expect(photo == nil)
        #expect(try count(context) == 0)
    }

    // MARK: - Deleting

    @Test("deleting a win deletes its copy")
    func deletingAWinDeletesItsCopy() throws {
        let context = ModelContext(try container())
        let log = win(context, day: "2026-10-01", photo: "A_1.jpg")
        let photo = WinPhoto(fileName: "A_1.jpg", data: Data([1, 2, 3]))
        context.insert(photo)
        log.photo = photo
        try context.save()
        #expect(try count(context) == 1)

        // The way the app deletes a win: the habit, whose logs cascade.
        let habit = try #require(log.habit)
        context.delete(habit)
        try context.save()
        #expect(try count(context) == 0, "the copy outlived its win, and would stay in iCloud")
    }

    @Test("taking a photograph off a win removes its copy and leaves the win")
    func detachRemovesOnlyTheCopy() throws {
        let context = ModelContext(try container())
        let log = win(context, day: "2026-10-01", photo: "A_1.jpg")
        let photo = WinPhoto(fileName: "A_1.jpg", data: Data([1, 2, 3]))
        context.insert(photo)
        log.photo = photo
        try context.save()

        log.imageFileName = nil
        WinPhotoStore.detach(from: log, context: context)
        try context.save()
        #expect(try count(context) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HabitLog>()) == 1)
    }

    // MARK: - The materialiser

    @Test("a copy whose photograph is missing is written out, and an existing file is never overwritten")
    func materialiserOnlyCreates() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let made = try container()
        let context = ModelContext(made)
        let picture = jpeg(width: 64, height: 64)

        // Missing on disk: must be written.
        context.insert(WinPhoto(fileName: "missing.heic", data: picture))
        // Present on disk with different bytes: must be left exactly as it is.
        let kept = Data("the 2560px original".utf8)
        try kept.write(to: dir.appendingPathComponent("present.heic"))
        context.insert(WinPhoto(fileName: "present.heic", data: picture))
        // A name that tries to leave the folder: refused.
        context.insert(WinPhoto(fileName: "../escape.heic", data: picture))
        // Bytes that are not a picture: never written.
        context.insert(WinPhoto(fileName: "broken.heic", data: Data("not a picture".utf8)))
        try context.save()

        let first = WinPhotoStore.materialise(container: made, imageDirectory: dir)
        #expect(first.written == ["missing.heic"])
        #expect(try Data(contentsOf: dir.appendingPathComponent("missing.heic")) == picture)
        #expect(try Data(contentsOf: dir.appendingPathComponent("present.heic")) == kept,
                "an existing photograph was overwritten")
        #expect(!FileManager.default.fileExists(atPath: dir.deletingLastPathComponent()
            .appendingPathComponent("escape.heic").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("broken.heic").path))
        // No temporary file is left behind.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix(WinPhotoStore.partPrefix) }
        #expect(leftovers.isEmpty)

        // A second pass finds nothing to do.
        let second = WinPhotoStore.materialise(container: made, imageDirectory: dir)
        #expect(second.written.isEmpty)
        #expect(try Data(contentsOf: dir.appendingPathComponent("present.heic")) == kept)
    }

    @Test("writing a copy refuses a name that is already taken")
    func writeNewNeverReplaces() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let kept = Data("original".utf8)
        try kept.write(to: dir.appendingPathComponent("A_1.heic"))
        let outcome = WinPhotoStore.writeNew(jpeg(width: 32, height: 32), named: "A_1.heic", in: dir)
        #expect(outcome == .alreadyThere)
        #expect(try Data(contentsOf: dir.appendingPathComponent("A_1.heic")) == kept)
    }

    // MARK: - The backfill

    @Test("the backfill makes copies only for wins without one, and skips a photograph that is not on disk")
    func backfillFillsOnlyTheGaps() async throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try jpeg(width: 300, height: 200).write(to: dir.appendingPathComponent("needs.jpg"))
        try jpeg(width: 300, height: 200).write(to: dir.appendingPathComponent("has.jpg"))

        let context = ModelContext(try container())
        let needs = win(context, day: "2026-10-03", photo: "needs.jpg")
        let has = win(context, day: "2026-10-02", photo: "has.jpg")
        let existing = WinPhoto(fileName: "has.jpg", data: Data([9]))
        context.insert(existing)
        has.photo = existing
        let gone = win(context, day: "2026-10-01", photo: "gone.jpg")
        win(context, day: "2026-09-30", photo: nil)
        try context.save()

        let report = await WinPhotoStore.backfill(context: context, imageDirectory: dir)
        #expect(report.created == 1)
        #expect(report.alreadyHad == 1)
        #expect(report.missingFile == 1)
        #expect(!report.stoppedEarly)
        #expect(needs.photo?.fileName == "needs.jpg")
        #expect(has.photo?.data == Data([9]), "a copy that existed was replaced")
        #expect(gone.photo == nil)
        #expect(try count(context) == 2)

        // Run again: nothing new.
        let again = await WinPhotoStore.backfill(context: context, imageDirectory: dir)
        #expect(again.created == 0)
        #expect(try count(context) == 2)
    }

    @Test("the backfill goes newest first, and stops when told")
    func backfillIsNewestFirstAndStoppable() async throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["old.jpg", "new.jpg"] {
            try jpeg(width: 100, height: 100).write(to: dir.appendingPathComponent(name))
        }
        let context = ModelContext(try container())
        let old = win(context, day: "2026-09-01", photo: "old.jpg")
        let new = win(context, day: "2026-10-01", photo: "new.jpg")
        try context.save()

        var asked = 0
        let report = await WinPhotoStore.backfill(context: context, imageDirectory: dir, batchSize: 1) {
            asked += 1
            return asked == 1
        }
        #expect(report.stoppedEarly)
        #expect(new.photo != nil, "the newest photograph was not first")
        #expect(old.photo == nil)
    }

    // MARK: - The orphan sweep

    @Test("the sweep never deletes a photograph an iCloud copy names, even with no win naming it")
    func pruneKeepsCopiesNames() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["arrived-before-its-win.heic", "named-by-a-win.heic", "orphan.heic"] {
            try Data(name.utf8).write(to: dir.appendingPathComponent(name))
        }
        let context = ModelContext(try container())
        win(context, day: "2026-10-01", photo: "named-by-a-win.heic")
        // A copy that arrived from iCloud before the row that names it.
        context.insert(WinPhoto(fileName: "arrived-before-its-win.heic", data: Data([1])))
        try context.save()

        let referenced = try WinPhotoStore.referencedNames(context: context)
        let result = ImageManager.pruneOrphans(referenced: referenced, in: dir)
        #expect(result.removed == ["orphan.heic"])
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("arrived-before-its-win.heic").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("named-by-a-win.heic").path))
    }

    @Test("the sweep waits for a first import on a synced store, and never runs while copies are written")
    func pruneGate() {
        // A synced store that has not heard from iCloud: rows may still come.
        #expect(!PhotoSync.pruneAllowed(mirrored: true, account: .signedIn,
                                        hasEverImported: false, materialising: false))
        #expect(!PhotoSync.pruneAllowed(mirrored: true, account: .unknown,
                                        hasEverImported: false, materialising: false))
        // Once it has, or when there is no account to hear from.
        #expect(PhotoSync.pruneAllowed(mirrored: true, account: .signedIn,
                                       hasEverImported: true, materialising: false))
        #expect(PhotoSync.pruneAllowed(mirrored: true, account: .signedOut,
                                       hasEverImported: false, materialising: false))
        #expect(PhotoSync.pruneAllowed(mirrored: false, account: .unknown,
                                       hasEverImported: false, materialising: false))
        // Never mid-write, whatever else is true.
        #expect(!PhotoSync.pruneAllowed(mirrored: false, account: .signedOut,
                                        hasEverImported: true, materialising: true))
    }

    // MARK: - A full iCloud

    @Test("a full iCloud pauses the backfill until an export gets through")
    func quotaPausesAndResumes() throws {
        let suite = "WinPhotoSyncTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sync = PhotoSync(defaults: defaults)
        #expect(!sync.isPausedForQuota)
        sync.exportFinished(succeeded: false, quotaExceeded: false)
        #expect(!sync.isPausedForQuota, "an ordinary failure is not a full iCloud")
        sync.exportFinished(succeeded: false, quotaExceeded: true)
        #expect(sync.isPausedForQuota)
        // Remembered across launches.
        #expect(PhotoSync(defaults: defaults).isPausedForQuota)
        sync.exportFinished(succeeded: true, quotaExceeded: false)
        #expect(!sync.isPausedForQuota)
    }
}
