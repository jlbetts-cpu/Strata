import Foundation

/// The backup file's format, in one place, for both directions.
///
/// **Why one file owns both.** The export shipped for months with no importer,
/// which means the app had a backup nobody could restore — the owner reinstalled
/// believing his wins were in iCloud, and they were not. The way that stays
/// fixed is that the writer and the reader are the same types: a field added to
/// the export is a field the restore reads, because there is only one
/// declaration of it.
///
/// **The file on disk.** A zip of one folder, named `Strata Backup <date>`,
/// containing `wins.json` and a `photos/` folder of the originals. The zip is
/// made by `NSFileCoordinator`'s `.forUploading`, so it always has that one
/// wrapping folder; the reader finds it by looking for `wins.json` rather than
/// by reconstructing the name, because the name carries the date the backup was
/// made and a restore must not depend on guessing it.
///
/// **Two versions, and the older one is lossy.** Version 1 is every backup made
/// before 2026-09-23. It carries no identifiers and — this is the part that
/// matters — no `imageFileName`, so its `photos/` folder cannot be attached back
/// to the wins it belongs to: the file name holds the log's UUID and the JSON
/// never wrote that UUID down. Version 2 carries ids and the file name, and is
/// a strict superset of version 1, so a version-2 file still decodes against
/// every version-1 field. `RestorePlan` says out loud when it is reading a
/// version-1 file and what will be missing.
nonisolated enum BackupArchive {

    /// Bumped only when a reader written today could not understand the file.
    /// Adding an optional field does not need a bump, which is why every field
    /// added in version 2 is optional.
    static let currentFormatVersion = 2

    static let winsFileName = "wins.json"
    static let photosFolderName = "photos"

    // MARK: - The JSON

    /// **Every field added after version 1 is Optional**, so a version-1 file
    /// decodes without a second set of types: the synthesised decoder uses
    /// `decodeIfPresent` for an Optional and a missing key becomes nil. A
    /// non-optional with a default would still require the key.
    struct Document: Codable, Sendable {
        /// Absent in version 1, which is how a version-1 file is recognised.
        var formatVersion: Int?
        let exportDate: Date
        let appVersion: String
        let habits: [ExportHabit]
        let logs: [ExportLog]

        var version: Int { formatVersion ?? 1 }
    }

    /// A win's template: what it is called, what colour it draws in, how big
    /// its block is.
    struct ExportHabit: Codable, Sendable {
        // Version 1.
        let title: String
        let category: String
        let blockSize: String
        let frequency: [String]
        let scheduledTime: String?
        let createdAt: Date

        // Version 2. **These are not cosmetic.** Without `isTodo`,
        // `isQuickWin` and `scheduledDate` a restored win is not the shape
        // `QuickWinService` makes, and without `spontaneousCategoryRaw` every
        // uncategorised win comes back green, because `displayCategory` falls
        // back to `.health` when there is no colour to read.
        var id: UUID?
        var isTodo: Bool?
        var scheduledDate: String?
        var isQuickWin: Bool?
        var spontaneousCategoryRaw: String?
        var timeOfDay: String?
        var customDurationMinutes: Int?
        var graceDays: Int?
        var sortOrder: Int?
        var reminderEnabled: Bool?
        var updatedAt: Date?
    }

    /// One block on the tower.
    struct ExportLog: Codable, Sendable {
        // Version 1. `habitTitle` is how version 1 pointed at its habit, and
        // it stays in version 2 as well: it costs nothing, it keeps the file
        // readable by a person, and it is the fallback when `habitID` names a
        // habit the file does not contain.
        let habitTitle: String
        let dateString: String
        let completed: Bool
        let completedAt: Date?
        let skipped: Bool
        let note: String?
        let caption: String

        // Version 2.
        var id: UUID?
        var habitID: UUID?
        /// **The field whose absence made version 1 unrestorable.** The
        /// photographs were in the zip and nothing said which win each belonged
        /// to.
        var imageFileName: String?
        var cropPositionX: Double?
        var cropPositionY: Double?
        var towerOrder: Int?
        var latitude: Double?
        var longitude: Double?
        var locationAccuracy: Double?
        var createdAt: Date?
        var updatedAt: Date?
        var timeZoneIdentifier: String?
        var isBonusBlock: Bool?
        var subtasks: [ExportSubTask]?
    }

    /// A win's checklist. User-written text, so it travels.
    struct ExportSubTask: Codable, Sendable {
        let id: UUID
        let title: String
        let completed: Bool
    }

    // MARK: - Encoding

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Unchanged from the first export: a backup somebody opens in a text
        // editor should be readable, and sorted keys make two backups
        // diffable.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Everything that can go wrong while WRITING a backup, each with the step
    /// it failed at. `exportData` used to `return` in silence at five different
    /// points, so the button did nothing and nobody could say what happened.
    enum WriteFailure: Error {
        case couldNotEncodeJSON(String)
        case couldNotMakeFolder(String)
        case couldNotWriteJSON(String)
        case couldNotZip(String)

        var message: String {
            switch self {
            case .couldNotEncodeJSON(let detail): "Strata could not write out your wins (\(detail))."
            case .couldNotMakeFolder(let detail): "Strata could not make room for the backup (\(detail))."
            case .couldNotWriteJSON(let detail): "Strata could not write the backup's index (\(detail))."
            case .couldNotZip(let detail): "Strata could not pack the backup into one file (\(detail))."
            }
        }
    }

    /// Writes the backup and returns the zip.
    ///
    /// - Parameter photographs: the original image files to copy in. **Copied,
    ///   never moved**: these are the person's only copy.
    static func writeZip(document: Document, photographs: [URL],
                         named name: String,
                         in temporaryDirectory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let data: Data
        do { data = try encoder().encode(document) }
        catch { throw WriteFailure.couldNotEncodeJSON(error.localizedDescription) }

        let fm = FileManager.default
        let folder = temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try? fm.removeItem(at: folder)
        do { try fm.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { throw WriteFailure.couldNotMakeFolder(error.localizedDescription) }

        do { try data.write(to: folder.appendingPathComponent(winsFileName)) }
        catch { throw WriteFailure.couldNotWriteJSON(error.localizedDescription) }

        let photos = folder.appendingPathComponent(photosFolderName, isDirectory: true)
        try? fm.createDirectory(at: photos, withIntermediateDirectories: true)
        for file in photographs {
            // One photograph that will not copy does not fail the backup: the
            // wins and the rest of the pictures are still worth having, and the
            // restore names what is missing when it gets there.
            try? fm.copyItem(at: file, to: photos.appendingPathComponent(file.lastPathComponent))
        }

        // **Zipped by the system, with no dependency.** `NSFileCoordinator`'s
        // `.forUploading` option hands back a zip of a directory — it is what
        // AirDrop uses for a folder — so a backup is one file somebody can mail
        // themselves without the app shipping an archiver. `ZipArchiveReader`
        // reads exactly what this produces.
        var coordinationError: NSError?
        var zipped: URL?
        var copyError: String?
        NSFileCoordinator().coordinate(readingItemAt: folder,
                                       options: [.forUploading],
                                       error: &coordinationError) { url in
            let destination = temporaryDirectory.appendingPathComponent("\(name).zip")
            try? fm.removeItem(at: destination)
            // Only if the copy went. `zipped` was once assigned whatever the
            // destination URL would have been, so a failed copy handed the
            // share sheet a file that is not there.
            do { try fm.copyItem(at: url, to: destination); zipped = destination }
            catch { copyError = error.localizedDescription }
        }
        try? fm.removeItem(at: folder)

        guard let zipped else {
            throw WriteFailure.couldNotZip(copyError
                ?? coordinationError?.localizedDescription
                ?? "the system archiver gave no reason")
        }
        return zipped
    }

    // MARK: - Reading

    /// Everything that can go wrong while READING a backup. Each one is a
    /// sentence a person can act on, because the alternative — the thing this
    /// feature exists to undo — is a screen that does nothing and says nothing.
    enum ReadFailure: Error {
        /// Not a zip, or a zip that stops early.
        case notABackup(String)
        /// A zip, but with no `wins.json` in it.
        case noWinsFile
        /// Made by a newer Strata than this one.
        case fromTheFuture(fileVersion: Int)
        /// The JSON is there and a field is not the shape this version expects.
        case malformedJSON(String)
        /// The archive itself refused: damaged, encrypted, an unreadable method.
        case archive(ZipArchiveReader.Failure)

        var message: String {
            switch self {
            case .notABackup(let detail):
                "This file isn't a Strata backup, or it didn't finish downloading. \(detail)"
            case .noWinsFile:
                "This zip has no wins.json inside it, so it isn't a Strata backup. Pick the file Back Up Everything made."
            case .fromTheFuture(let version):
                "This backup was made by a newer version of Strata (format \(version); this one reads \(BackupArchive.currentFormatVersion)). Update Strata and try again. Nothing has been changed."
            case .malformedJSON(let detail):
                "Strata could not read this backup's index: \(detail). Nothing has been changed."
            case .archive(let failure):
                switch failure {
                case .notAZip:
                    "This file isn't a zip, so it isn't a Strata backup."
                case .truncated(let detail):
                    "This backup is incomplete — it may not have finished downloading or copying. \(detail)"
                case .unsupported(let detail):
                    "Strata cannot read this zip: \(detail)."
                case .encrypted(let detail):
                    "This backup is password-protected and Strata cannot open it. \(detail)"
                case .corrupt(let detail):
                    "This backup is damaged. \(detail)"
                }
            }
        }
    }

    /// An opened backup: its index, decoded, plus the photographs still sitting
    /// in the archive waiting to be asked for.
    ///
    /// The photographs are NOT decompressed here. A year's library is hundreds
    /// of megabytes, and the preview screen only needs to count them; they are
    /// pulled out one at a time when somebody has confirmed the restore.
    struct Contents: Sendable {
        let document: Document
        let photoEntries: [String: ZipArchiveReader.Entry]
        private let reader: ZipArchiveReader

        init(document: Document, photoEntries: [String: ZipArchiveReader.Entry], reader: ZipArchiveReader) {
            self.document = document
            self.photoEntries = photoEntries
            self.reader = reader
        }

        var version: Int { document.version }

        /// One photograph's bytes, CRC-checked by the reader.
        func photograph(named name: String) throws -> Data {
            guard let entry = photoEntries[name] else {
                throw ZipArchiveReader.Failure.corrupt("\(name) is not in this backup")
            }
            return try reader.data(for: entry)
        }
    }

    /// Opens a backup: reads the index, decodes `wins.json`, and lists the
    /// photographs. **Nothing is written and nothing in the store is touched.**
    static func read(zipAt url: URL) throws -> Contents {
        let reader: ZipArchiveReader
        do { reader = try ZipArchiveReader(url: url) }
        catch let failure as ZipArchiveReader.Failure { throw ReadFailure.archive(failure) }
        catch { throw ReadFailure.notABackup(error.localizedDescription) }

        // Found by suffix, so the restore does not have to reconstruct the name
        // of the folder the backup was zipped from — that name carries the date
        // it was made.
        guard let winsEntry = reader.firstEntry(endingWith: winsFileName) else {
            throw ReadFailure.noWinsFile
        }
        let root = String(winsEntry.path.dropLast(winsFileName.count))

        let data: Data
        do { data = try reader.data(for: winsEntry) }
        catch let failure as ZipArchiveReader.Failure { throw ReadFailure.archive(failure) }

        let document: Document
        do { document = try decoder().decode(Document.self, from: data) }
        catch let error as DecodingError { throw ReadFailure.malformedJSON(Self.describe(error)) }
        catch { throw ReadFailure.malformedJSON(error.localizedDescription) }

        // **Refused, not half-read.** A newer Strata may mean something
        // different by a field this version thinks it understands, and a
        // half-understood restore writes wrong data into the one place the
        // person cannot get it back from.
        guard document.version <= currentFormatVersion else {
            throw ReadFailure.fromTheFuture(fileVersion: document.version)
        }

        var photos: [String: ZipArchiveReader.Entry] = [:]
        for entry in reader.entries(directlyInside: root + photosFolderName + "/") {
            let name = (entry.path as NSString).lastPathComponent
            // A name that is empty, or that tries to climb out of the folder,
            // is dropped rather than followed. Restoring writes by basename
            // through `ImageManager` so it could not escape anyway, but a
            // reader that filters is one fewer thing to reason about.
            guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else { continue }
            photos[name] = entry
        }
        return Contents(document: document, photoEntries: photos, reader: reader)
    }

    /// A decoding error as a sentence naming the field, because "the data
    /// couldn't be read because it isn't in the correct format" is not
    /// something anybody can act on.
    static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }
            return keys.isEmpty ? "the file" : keys.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "\(path(context)) is missing \"\(key.stringValue)\""
        case .typeMismatch(let type, let context):
            return "\(path(context)) is not the expected \(type)"
        case .valueNotFound(let type, let context):
            return "\(path(context)) has no value where a \(type) is needed"
        case .dataCorrupted(let context):
            return "\(path(context)) is not valid JSON (\(context.debugDescription))"
        @unknown default:
            return error.localizedDescription
        }
    }
}
