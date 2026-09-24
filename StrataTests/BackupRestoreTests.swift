import Testing
import Foundation
import SwiftData
import UIKit
@testable import Strata

/// **The test that proves a backup is a backup.**
///
/// The app shipped an export and no importer, which means it shipped a backup
/// nobody could restore, and the owner found that out by reinstalling and losing
/// everything he had. A round trip is the only test that can say the feature
/// works: export a store, walk away from it, restore into an empty one, and
/// check the same wins, the same days and the same photograph names came back.
///
/// The rest are the cases where it must fail safely instead: a file that is not
/// ours, a truncated one, a backup from a version this app does not understand,
/// and a restore into a store that already holds some of the same records.
@MainActor
@Suite("BackupRestore")
struct BackupRestoreTests {

    // MARK: - Fixtures

    private func container() throws -> ModelContainer {
        try ModelContainer(for: Habit.self, HabitLog.self, Tower.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A temporary directory of this test's own, so nothing lands beside the
    /// host's real files.
    private func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A real PNG on disk, under a name the restore will write into the image
    /// directory. Named distinctively so the cleanup can never take one of the
    /// host's own photographs.
    private func photograph(in folder: URL) throws -> (name: String, url: URL) {
        let name = "backup-test-\(UUID().uuidString).png"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let url = folder.appendingPathComponent(name)
        try image.pngData()!.write(to: url)
        return (name, url)
    }

    private func removeFromImageDirectory(_ names: [String]) {
        for name in names {
            ImageManager.shared.deleteImage(fileName: name)
        }
    }

    /// Three wins across two days, one of them carrying a photograph, a caption
    /// and a note, so the round trip has something to lose.
    private func seed(_ context: ModelContext, photographName: String?) throws -> [HabitLog] {
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        let day2 = day1.addingTimeInterval(60 * 60 * 26)
        _ = try QuickWinService.logWin(title: "Ran 5k", category: .health, size: .medium,
                                       on: day1, context: context, tower: nil)
        _ = try QuickWinService.logWin(title: QuickWinService.untitled, category: .unlabeled,
                                       size: .hard, spontaneous: .creativity,
                                       on: day1.addingTimeInterval(120), context: context, tower: nil)
        _ = try QuickWinService.logWin(title: "Shipped it", category: .work, size: .small,
                                       on: day2, context: context, tower: nil)
        let logs = try context.fetch(FetchDescriptor<HabitLog>(
            sortBy: [SortDescriptor(\.completedAt)]))
        logs[0].caption = "A caption"
        logs[0].note = "A note"
        logs[0].imageFileName = photographName
        logs[0].latitude = 38.5449
        logs[0].longitude = -121.7405
        logs[2].towerOrder = 7
        try context.save()
        return logs
    }

    private func makeZip(from context: ModelContext, into folder: URL) throws -> URL {
        let habits = try context.fetch(FetchDescriptor<Habit>())
        let logs = try context.fetch(FetchDescriptor<HabitLog>())
        let photographs = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "png" } ?? []
        return try BackupExport.makeZip(habits: habits, logs: logs, appVersion: "1.0 (1)",
                                        photographs: photographs,
                                        temporaryDirectory: folder)
    }

    // MARK: - The round trip

    @Test("export, wipe, restore: the same wins, days and photographs come back")
    func roundTrip() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        defer { removeFromImageDirectory([photo.name]) }

        let before = ModelContext(try container())
        let seeded = try seed(before, photographName: photo.name)
        let zip = try makeZip(from: before, into: folder)

        // The phone after a reinstall: the same app, an empty store.
        let after = ModelContext(try container())
        let contents = try BackupArchive.read(zipAt: zip)
        #expect(contents.version == BackupArchive.currentFormatVersion)

        let plan = try BackupRestore.plan(contents, context: after)
        #expect(plan.summary.wins == 3)
        #expect(plan.summary.days == 2)
        #expect(plan.summary.photographs == 1)
        #expect(plan.summary.attachablePhotographs == 1)
        #expect(plan.winsToAdd == 3)
        #expect(plan.winsAlreadyHere == 0)
        #expect(plan.winsWithoutATemplate == 0)
        #expect(plan.warnings.isEmpty, "a current backup should raise nothing: \(plan.warnings)")

        let report = BackupRestore.apply(plan, contents: contents, context: after)
        #expect(report.failure == nil, "\(report.failure ?? "")")
        #expect(report.problems.isEmpty, "\(report.problems)")
        #expect(report.winsAdded == 3)
        #expect(report.daysAdded == 2)
        #expect(report.photographsRestored + report.photographsAlreadyHere == 1)

        let restored = try after.fetch(FetchDescriptor<HabitLog>(
            sortBy: [SortDescriptor(\.completedAt)]))
        #expect(restored.count == 3)
        #expect(restored.map(\.dateString) == seeded.map(\.dateString))
        #expect(restored.compactMap(\.imageFileName) == [photo.name])
        #expect(restored[0].caption == "A caption")
        #expect(restored[0].note == "A note")
        #expect(restored[0].latitude == 38.5449)
        #expect(restored[2].towerOrder == 7)
        // The block itself: size and colour are what the tower draws.
        #expect(restored.compactMap { $0.habit?.blockSize } == seeded.compactMap { $0.habit?.blockSize })
        #expect(restored.compactMap { $0.habit?.displayCategory } == seeded.compactMap { $0.habit?.displayCategory })
        #expect(restored.compactMap { $0.habit?.title } == seeded.compactMap { $0.habit?.title })
        // Every restored win has a habit, or it would never draw on the tower.
        #expect(restored.allSatisfy { $0.habit != nil })
        // And the photograph is really on disk under the name the win points at.
        #expect(ImageManager.shared.fileExists(fileName: photo.name))
        // The ids travelled, which is what makes a second restore a no-op.
        #expect(Set(restored.map(\.id)) == Set(seeded.map(\.id)))
    }

    @Test("restoring the same backup twice adds nothing the second time")
    func restoreIsIdempotent() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        defer { removeFromImageDirectory([photo.name]) }

        let before = ModelContext(try container())
        _ = try seed(before, photographName: photo.name)
        let zip = try makeZip(from: before, into: folder)

        let after = ModelContext(try container())
        let contents = try BackupArchive.read(zipAt: zip)
        _ = BackupRestore.apply(try BackupRestore.plan(contents, context: after),
                                contents: contents, context: after)

        let second = try BackupRestore.plan(contents, context: after)
        #expect(second.winsAlreadyHere == 3)
        #expect(second.winsToAdd == 0)
        #expect(second.isEmptyOfWork)
        let report = BackupRestore.apply(second, contents: contents, context: after)
        #expect(report.winsAdded == 0)
        #expect(try after.fetchCount(FetchDescriptor<HabitLog>()) == 3)
    }

    @Test("a restore into a store that already holds some of the same wins adds only the rest")
    func partialOverlapAddsOnlyWhatIsMissing() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        defer { removeFromImageDirectory([photo.name]) }

        let before = ModelContext(try container())
        _ = try seed(before, photographName: photo.name)
        let zip = try makeZip(from: before, into: folder)
        let contents = try BackupArchive.read(zipAt: zip)

        // A phone that has been used since the loss: one win from the backup is
        // back on it, plus one the backup has never seen.
        let after = ModelContext(try container())
        var half = try BackupRestore.plan(contents, context: after)
        half.logsToAdd = Array(half.logsToAdd.prefix(1))
        half.habitsToAdd = Array(half.habitsToAdd.prefix(1))
        half.photographsToRestore = []
        _ = BackupRestore.apply(half, contents: contents, context: after)
        _ = try QuickWinService.logWin(title: "Logged after the loss", category: .focus,
                                       on: Date(timeIntervalSince1970: 1_900_000_000),
                                       context: after, tower: nil)
        let survivor = try after.fetch(FetchDescriptor<HabitLog>())
            .first { $0.habit?.title == "Logged after the loss" }
        #expect(survivor != nil)

        let plan = try BackupRestore.plan(contents, context: after)
        #expect(plan.winsAlreadyHere == 1)
        #expect(plan.winsToAdd == 2)
        let report = BackupRestore.apply(plan, contents: contents, context: after)
        #expect(report.failure == nil, "\(report.failure ?? "")")
        #expect(report.winsAdded == 2)

        let all = try after.fetch(FetchDescriptor<HabitLog>())
        #expect(all.count == 4, "3 from the backup and the one logged since")
        // **The win that was not in the backup is still here.** This is the
        // assertion the whole merge-not-replace decision exists for.
        #expect(all.contains { $0.habit?.title == "Logged after the loss" })
        // And no win was duplicated.
        #expect(Set(all.map(\.id)).count == 4)
    }

    @Test("a win already here without its photograph gets it back")
    func photographIsReattachedToAWinAlreadyHere() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        defer { removeFromImageDirectory([photo.name]) }

        let before = ModelContext(try container())
        _ = try seed(before, photographName: photo.name)
        let zip = try makeZip(from: before, into: folder)
        let contents = try BackupArchive.read(zipAt: zip)

        let after = ModelContext(try container())
        // Everything restored except the photographs, which is what a restore
        // from a zip whose pictures failed to write would leave behind.
        var withoutPhotographs = try BackupRestore.plan(contents, context: after)
        withoutPhotographs.photographsToRestore = []
        _ = BackupRestore.apply(withoutPhotographs, contents: contents, context: after)
        #expect(try after.fetch(FetchDescriptor<HabitLog>()).allSatisfy { $0.imageFileName == nil })

        let plan = try BackupRestore.plan(contents, context: after)
        #expect(plan.photographsForExistingWins.count == 1)
        let report = BackupRestore.apply(plan, contents: contents, context: after)
        #expect(report.photographsReattached == 1)
        let named = try after.fetch(FetchDescriptor<HabitLog>()).compactMap(\.imageFileName)
        #expect(named == [photo.name])
    }

    // MARK: - Failing safely

    @Test("a file that is not a zip is refused with a message, and nothing is touched")
    func notAZip() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("not-a-backup.zip")
        try Data("this is not a zip, it is a sentence".utf8).write(to: url)

        #expect(throws: Error.self) { _ = try BackupArchive.read(zipAt: url) }
        do {
            _ = try BackupArchive.read(zipAt: url)
        } catch let failure as BackupArchive.ReadFailure {
            #expect(failure.message.contains("zip") || failure.message.contains("backup"),
                    "the message must say something a person can act on: \(failure.message)")
        }
    }

    @Test("a truncated backup is refused rather than half read")
    func truncated() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        let before = ModelContext(try container())
        _ = try seed(before, photographName: photo.name)
        let zip = try makeZip(from: before, into: folder)

        let whole = try Data(contentsOf: zip)
        let cut = folder.appendingPathComponent("cut.zip")
        try whole.prefix(whole.count / 2).write(to: cut)
        #expect(throws: Error.self) { _ = try BackupArchive.read(zipAt: cut) }
    }

    @Test("a damaged entry is caught by its checksum, not handed on as an image")
    func damagedEntryIsCaught() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        let before = ModelContext(try container())
        _ = try seed(before, photographName: photo.name)
        let zip = try makeZip(from: before, into: folder)

        // Flip a byte inside the photograph's own compressed bytes, which is
        // what a file damaged in transit looks like.
        var bytes = try Data(contentsOf: zip)
        let reader = try ZipArchiveReader(data: bytes)
        guard let entry = reader.entries.first(where: { $0.path.hasSuffix(photo.name) }) else {
            Issue.record("the photograph is not in the zip")
            return
        }
        // The payload starts after the LOCAL header, whose name and extra
        // lengths are its own: the system archiver writes an extra field, so
        // measuring from the central directory's name length alone lands in the
        // extra field and flips a byte that changes nothing. Read the local
        // header the way the reader does.
        let header = entry.localHeaderOffset
        let nameLength = Int(bytes[header + 26]) | Int(bytes[header + 27]) << 8
        let extraLength = Int(bytes[header + 28]) | Int(bytes[header + 29]) << 8
        let payload = header + 30 + nameLength + extraLength
        #expect(entry.compressedSize > 2, "the fixture photograph is too small to damage")
        let target = payload + entry.compressedSize / 2
        bytes[target] = bytes[target] ^ 0xFF
        let damaged = folder.appendingPathComponent("damaged.zip")
        try bytes.write(to: damaged)

        let contents = try BackupArchive.read(zipAt: damaged)
        // The index still reads: it is one entry that is damaged, and the person
        // is told which.
        #expect(throws: ZipArchiveReader.Failure.self) {
            _ = try contents.photograph(named: photo.name)
        }
    }

    @Test("a backup from a newer Strata is refused, by name, and nothing is changed")
    func fromTheFuture() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let document = BackupArchive.Document(
            formatVersion: BackupArchive.currentFormatVersion + 7,
            exportDate: Date(), appVersion: "99.0 (1)", habits: [], logs: [])
        let zip = try BackupArchive.writeZip(document: document, photographs: [],
                                             named: "Strata Backup 2099-01-01", in: folder)
        do {
            _ = try BackupArchive.read(zipAt: zip)
            Issue.record("a backup from the future was read as if it were understood")
        } catch let failure as BackupArchive.ReadFailure {
            guard case .fromTheFuture(let version) = failure else {
                Issue.record("wrong failure: \(failure)")
                return
            }
            #expect(version == BackupArchive.currentFormatVersion + 7)
            #expect(failure.message.contains("Update Strata"))
        }
    }

    @Test("a field that has changed shape is reported by name")
    func malformedJSONNamesTheField() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        // `completed` as a string rather than a bool: a field that changed shape
        // between versions looks exactly like this.
        let json = """
        {"appVersion":"1.0","exportDate":"2026-09-01T00:00:00Z","habits":[],
         "logs":[{"habitTitle":"Win","dateString":"2026-09-01","completed":"yes",
                  "skipped":false,"caption":""}]}
        """
        let inner = folder.appendingPathComponent("Strata Backup 2026-09-01", isDirectory: true)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: inner.appendingPathComponent(BackupArchive.winsFileName))
        var error: NSError?
        var zip: URL?
        NSFileCoordinator().coordinate(readingItemAt: inner, options: [.forUploading],
                                       error: &error) { url in
            let destination = folder.appendingPathComponent("hand-made.zip")
            try? FileManager.default.copyItem(at: url, to: destination)
            zip = destination
        }
        guard let zip else {
            Issue.record("could not build the fixture zip: \(String(describing: error))")
            return
        }
        do {
            _ = try BackupArchive.read(zipAt: zip)
            Issue.record("a log with the wrong shape was read as if it were fine")
        } catch let failure as BackupArchive.ReadFailure {
            guard case .malformedJSON(let detail) = failure else {
                Issue.record("wrong failure: \(failure)")
                return
            }
            #expect(detail.contains("completed"), "the message must name the field: \(detail)")
        }
    }

    @Test("a zip with no wins.json is not mistaken for a backup")
    func zipWithoutAnIndex() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let inner = folder.appendingPathComponent("Something Else", isDirectory: true)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: inner.appendingPathComponent("readme.txt"))
        var zip: URL?
        NSFileCoordinator().coordinate(readingItemAt: inner, options: [.forUploading],
                                       error: nil) { url in
            let destination = folder.appendingPathComponent("other.zip")
            try? FileManager.default.copyItem(at: url, to: destination)
            zip = destination
        }
        guard let zip else { Issue.record("no fixture"); return }
        do {
            _ = try BackupArchive.read(zipAt: zip)
            Issue.record("a zip of something else was accepted as a backup")
        } catch let failure as BackupArchive.ReadFailure {
            guard case .noWinsFile = failure else {
                Issue.record("wrong failure: \(failure)")
                return
            }
            #expect(failure.message.contains("wins.json"))
        }
    }

    // MARK: - The old format

    @Test("a version-1 backup restores its wins and says its photographs cannot come back")
    func versionOneIsRestoredAndItsLossIsStated() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photo = try photograph(in: folder)
        defer { removeFromImageDirectory([photo.name]) }

        let before = ModelContext(try container())
        _ = try seed(before, photographName: photo.name)
        let habits = try before.fetch(FetchDescriptor<Habit>())
        let logs = try before.fetch(FetchDescriptor<HabitLog>())

        // Exactly what the export wrote before today: no `formatVersion`, no
        // ids, no `imageFileName`. Built by stripping the current document, so
        // this fixture cannot drift from the shape being claimed.
        let current = BackupExport.document(habits: habits, logs: logs, appVersion: "1.0 (1)")
        let document = BackupArchive.Document(
            formatVersion: nil, exportDate: current.exportDate, appVersion: current.appVersion,
            habits: current.habits.map { habit in
                BackupArchive.ExportHabit(title: habit.title, category: habit.category,
                                          blockSize: habit.blockSize, frequency: habit.frequency,
                                          scheduledTime: habit.scheduledTime, createdAt: habit.createdAt)
            },
            logs: current.logs.map { log in
                BackupArchive.ExportLog(habitTitle: log.habitTitle, dateString: log.dateString,
                                        completed: log.completed, completedAt: log.completedAt,
                                        skipped: log.skipped, note: log.note, caption: log.caption)
            })
        let zip = try BackupArchive.writeZip(document: document, photographs: [photo.url],
                                             named: "Strata Backup 2026-09-01", in: folder)

        let after = ModelContext(try container())
        let contents = try BackupArchive.read(zipAt: zip)
        #expect(contents.version == 1)

        let plan = try BackupRestore.plan(contents, context: after)
        #expect(plan.summary.wins == 3)
        #expect(plan.summary.days == 2)
        #expect(plan.summary.photographs == 1)
        #expect(plan.summary.attachablePhotographs == 0,
                "version 1 never wrote the file name down, so nothing in it is attachable")
        #expect(plan.warnings.contains { $0.contains("older version") },
                "the loss has to be stated before the tap: \(plan.warnings)")

        let report = BackupRestore.apply(plan, contents: contents, context: after)
        #expect(report.failure == nil, "\(report.failure ?? "")")
        #expect(report.winsAdded == 3)
        #expect(report.photographsRestored == 0)

        let restored = try after.fetch(FetchDescriptor<HabitLog>(
            sortBy: [SortDescriptor(\.completedAt)]))
        #expect(restored.count == 3)
        #expect(restored.compactMap { $0.habit?.title } == logs.sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }.compactMap { $0.habit?.title })
        // **Each win keeps its own size.** Version 1 pointed at its habit by
        // title alone, and a tower of one-tap wins is a hundred habits with the
        // same title: paired carelessly they would all draw at one size.
        #expect(restored.compactMap { $0.habit?.blockSize } == logs.sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }.compactMap { $0.habit?.blockSize })
        // Not every block green: version 1 dropped the colour of an
        // uncategorised win, and `displayCategory` falls back to `.health`.
        #expect(restored.allSatisfy { $0.habit?.spontaneousCategoryRaw != nil
                                      || $0.habit?.category != .unlabeled })
        // Nothing was written into the image directory for a photograph nobody
        // can attach: an unreferenced original is deleted by the launch sweep
        // anyway, so writing it would be a promise the app cannot keep.
        #expect(!ImageManager.shared.fileExists(fileName: photo.name))
    }

    @Test("a win whose kind is missing from the file is reported, not dropped in silence")
    func aWinWithNoTemplateIsCounted() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let document = BackupArchive.Document(
            formatVersion: BackupArchive.currentFormatVersion,
            exportDate: Date(), appVersion: "1.0 (1)", habits: [],
            logs: [BackupArchive.ExportLog(habitTitle: "Unknown", dateString: "2026-09-01",
                                           completed: true, completedAt: Date(), skipped: false,
                                           note: nil, caption: "", id: UUID())])
        let zip = try BackupArchive.writeZip(document: document, photographs: [],
                                             named: "Strata Backup 2026-09-01", in: folder)
        let after = ModelContext(try container())
        let contents = try BackupArchive.read(zipAt: zip)
        let plan = try BackupRestore.plan(contents, context: after)
        #expect(plan.winsWithoutATemplate == 1)
        #expect(plan.winsToAdd == 0)
        #expect(plan.warnings.contains { $0.contains("kind of win") })
    }

    // MARK: - The zip reader itself

    @Test("the reader reads what the system archiver writes, byte for byte")
    func readerMatchesTheSystemArchiver() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let inner = folder.appendingPathComponent("Strata Backup 2026-09-23", isDirectory: true)
        let photos = inner.appendingPathComponent(BackupArchive.photosFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)

        // A compressible file, an incompressible one, an empty one and a tiny
        // one: the four shapes a zip entry comes in.
        let json = String(repeating: "{\"key\":\"value\"},", count: 500)
        try Data(json.utf8).write(to: inner.appendingPathComponent(BackupArchive.winsFileName))
        var noise = Data()
        for i in 0..<120_000 { noise.append(UInt8((i &* 7919) % 251)) }
        try noise.write(to: photos.appendingPathComponent("noise.bin"))
        try Data().write(to: photos.appendingPathComponent("empty.bin"))
        try Data("x".utf8).write(to: photos.appendingPathComponent("tiny.bin"))

        var zip: URL?
        NSFileCoordinator().coordinate(readingItemAt: inner, options: [.forUploading],
                                       error: nil) { url in
            let destination = folder.appendingPathComponent("reader.zip")
            try? FileManager.default.copyItem(at: url, to: destination)
            zip = destination
        }
        guard let zip else { Issue.record("no fixture"); return }

        let reader = try ZipArchiveReader(url: zip)
        guard let index = reader.firstEntry(endingWith: BackupArchive.winsFileName) else {
            Issue.record("wins.json was not found in a zip that contains it")
            return
        }
        let index0 = try reader.data(for: index)
        #expect(index0 == Data(json.utf8))
        let root = String(index.path.dropLast(BackupArchive.winsFileName.count))
        let entries = reader.entries(directlyInside: root + BackupArchive.photosFolderName + "/")
        #expect(entries.count == 3, "found \(entries.map(\.path))")
        for entry in entries {
            let name = (entry.path as NSString).lastPathComponent
            let expected = try Data(contentsOf: photos.appendingPathComponent(name))
            let got = try reader.data(for: entry)
            #expect(got == expected, "\(name) did not come back intact")
        }
    }
}
