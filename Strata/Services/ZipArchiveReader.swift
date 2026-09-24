import Foundation
import Compression

/// Reads the zip file `BackupArchive` writes, with no dependency.
///
/// **Why this exists at all.** The backup is zipped by `NSFileCoordinator`'s
/// `.forUploading` option, which is the system's own archiver and costs the app
/// nothing. There is no matching system UNzip: `NSFileCoordinator` only makes
/// them, `FileManager` has no reader, and `Compression` decompresses a byte
/// stream but does not parse a container. So restoring a backup needs either an
/// archiving dependency or a reader for the small part of the format the
/// system's own archiver produces. This is that reader.
///
/// **It reads; it never writes.** Nothing in this file creates, moves or
/// deletes a file. Entries are decompressed into memory one at a time, and the
/// caller decides where anything goes.
///
/// What it supports, which is what `.forUploading` emits: stored (method 0) and
/// deflate (method 8) entries, with or without the Zip64 records. Everything
/// else — encryption, any other compression method, a multi-part archive — is a
/// named error rather than a wrong answer. **Every entry's CRC is checked
/// against the one in the archive**, which is how a truncated download or a
/// photograph that went bad on a USB stick is caught here rather than three
/// layers up as an image that will not decode.
nonisolated struct ZipArchiveReader: Sendable {

    /// One file in the archive. `path` is as stored, so it carries the folder
    /// the backup was zipped from.
    struct Entry: Sendable {
        let path: String
        let compressedSize: Int
        let uncompressedSize: Int
        let storedCRC: UInt32
        let method: UInt16
        let localHeaderOffset: Int

        /// Zip stores a directory as a zero-length entry whose name ends in a
        /// slash. Nothing here needs them.
        var isDirectory: Bool { path.hasSuffix("/") }
    }

    /// Every failure carries the detail a person can act on. There is no
    /// `unknown` case and nothing returns nil: "the file you picked is not a
    /// Strata backup" and "the photograph inside it is damaged" are different
    /// problems with different answers, and a restore that cannot tell them
    /// apart is the silent-failure bug this whole feature exists to undo.
    enum Failure: Error, Equatable {
        /// No end-of-central-directory record: not a zip at all.
        case notAZip
        /// A zip, but it stops before the bytes its own index promises.
        case truncated(String)
        /// A zip this reader will not read, named so the message can say why.
        case unsupported(String)
        /// Password-protected.
        case encrypted(String)
        /// The bytes are there and they are not what the archive says they are.
        case corrupt(String)
    }

    private let bytes: Data
    let entries: [Entry]

    /// Reads the archive's index. The entries' contents stay on disk until
    /// `data(for:)` asks for one.
    ///
    /// Memory-mapped: a backup with a year of photographs in it is hundreds of
    /// megabytes, and reading the whole thing into memory to pull a 4 KB JSON
    /// file out of it is how a restore gets killed for memory on the phone it
    /// is most needed on.
    init(url: URL) throws {
        bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        entries = try Self.readCentralDirectory(bytes)
    }

    /// For the tests, which build archives in memory.
    init(data: Data) throws {
        bytes = data
        entries = try Self.readCentralDirectory(bytes)
    }

    /// The first entry whose path ends with this suffix, case-sensitively.
    /// Used to find `wins.json` without having to know the name of the folder
    /// the backup was zipped from.
    func firstEntry(endingWith suffix: String) -> Entry? {
        entries.first { !$0.isDirectory && $0.path.hasSuffix(suffix) }
    }

    /// Every entry directly inside `folder`, which must end in a slash.
    func entries(directlyInside folder: String) -> [Entry] {
        entries.filter { entry in
            guard !entry.isDirectory, entry.path.hasPrefix(folder) else { return false }
            let rest = entry.path.dropFirst(folder.count)
            // Directly inside: no further slash, and not an empty name.
            return !rest.isEmpty && !rest.contains("/")
        }
    }

    // MARK: - Reading one entry

    /// The entry's bytes, decompressed and CRC-checked.
    func data(for entry: Entry) throws -> Data {
        let payload = try compressedPayload(for: entry)
        let output: Data
        switch entry.method {
        case 0:
            guard payload.count == entry.uncompressedSize else {
                throw Failure.truncated("\(entry.path) is \(payload.count) bytes where the archive says \(entry.uncompressedSize)")
            }
            output = payload
        case 8:
            output = try inflate(payload, expecting: entry.uncompressedSize, path: entry.path)
        default:
            // Named, not "unsupported archive": the number is the thing a
            // person can search for, and it tells us which archiver made it.
            throw Failure.unsupported("\(entry.path) uses compression method \(entry.method), which Strata cannot read")
        }
        let actual = Self.crc32(output)
        guard actual == entry.storedCRC else {
            throw Failure.corrupt("\(entry.path) is damaged: its checksum is \(String(actual, radix: 16)) and the archive says \(String(entry.storedCRC, radix: 16))")
        }
        return output
    }

    /// The raw bytes of the entry, found through its LOCAL header.
    ///
    /// The local header is read for the name and extra-field lengths only,
    /// because those two can differ from the central directory's copies and the
    /// data begins after whichever the local header declares. The sizes are
    /// taken from the central directory, which is the copy that is correct even
    /// when the entry was written with a streaming data descriptor.
    private func compressedPayload(for entry: Entry) throws -> Data {
        let header = entry.localHeaderOffset
        guard header >= 0, header + 30 <= bytes.count else {
            throw Failure.truncated("\(entry.path) points past the end of the file")
        }
        guard read32(header) == 0x04034b50 else {
            throw Failure.corrupt("\(entry.path) has no local header where the archive's index says it is")
        }
        let nameLength = Int(read16(header + 26))
        let extraLength = Int(read16(header + 28))
        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard start <= bytes.count, end <= bytes.count else {
            throw Failure.truncated("\(entry.path) needs \(entry.compressedSize) bytes from \(start) and the file is \(bytes.count) long")
        }
        return bytes.subdata(in: (bytes.startIndex + start)..<(bytes.startIndex + end))
    }

    /// Raw DEFLATE, which is what a zip entry holds.
    ///
    /// `COMPRESSION_ZLIB` in Apple's `Compression` is raw DEFLATE with no zlib
    /// wrapper, which is exactly the zip entry's payload. The destination is
    /// sized from the central directory rather than grown, so a stream that
    /// expands to more than it promised cannot run away with the phone's
    /// memory.
    private func inflate(_ payload: Data, expecting size: Int, path: String) throws -> Data {
        guard size > 0 else { return Data() }
        var output = Data(count: size)
        let written: Int = output.withUnsafeMutableBytes { destination in
            payload.withUnsafeBytes { source in
                guard let d = destination.bindMemory(to: UInt8.self).baseAddress,
                      let s = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, size, s, payload.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else {
            throw Failure.corrupt("\(path) would not decompress: \(written) bytes came out where the archive says \(size)")
        }
        return output
    }

    // MARK: - The central directory

    private static func readCentralDirectory(_ bytes: Data) throws -> [Entry] {
        let reader = Cursor(bytes)
        guard let eocd = reader.findEndOfCentralDirectory() else { throw Failure.notAZip }

        var entryCount = Int(reader.read16(eocd + 10))
        var directoryOffset = Int(reader.read32(eocd + 16))
        var directorySize = Int(reader.read32(eocd + 12))

        // Zip64, which a backup only reaches with a very large library. The
        // sentinel values say "the real number is in the Zip64 record".
        if entryCount == 0xFFFF || directoryOffset == 0xFFFF_FFFF || directorySize == 0xFFFF_FFFF {
            guard eocd >= 20, reader.read32(eocd - 20) == 0x07064b50 else {
                throw Failure.unsupported("this archive needs a Zip64 index that is missing")
            }
            let zip64 = Int(reader.read64(eocd - 20 + 8))
            guard zip64 >= 0, zip64 + 56 <= bytes.count, reader.read32(zip64) == 0x06064b50 else {
                throw Failure.truncated("the archive's Zip64 index is not where it says it is")
            }
            entryCount = Int(reader.read64(zip64 + 32))
            directorySize = Int(reader.read64(zip64 + 40))
            directoryOffset = Int(reader.read64(zip64 + 48))
        }

        guard directoryOffset >= 0, directorySize >= 0,
              directoryOffset + directorySize <= bytes.count else {
            throw Failure.truncated("the archive's index runs past the end of the file, so the file is incomplete")
        }

        var entries: [Entry] = []
        var cursor = directoryOffset
        let limit = directoryOffset + directorySize
        for _ in 0..<max(0, entryCount) {
            guard cursor + 46 <= limit else {
                throw Failure.truncated("the archive lists \(entryCount) files and its index ends after \(entries.count)")
            }
            guard reader.read32(cursor) == 0x02014b50 else {
                throw Failure.corrupt("the archive's index is damaged at entry \(entries.count + 1)")
            }
            let flags = reader.read16(cursor + 8)
            let nameLength = Int(reader.read16(cursor + 28))
            let extraLength = Int(reader.read16(cursor + 30))
            let commentLength = Int(reader.read16(cursor + 32))
            guard cursor + 46 + nameLength + extraLength + commentLength <= limit else {
                throw Failure.truncated("the archive's index ends inside entry \(entries.count + 1)")
            }
            let nameBytes = bytes.subdata(
                in: (bytes.startIndex + cursor + 46)..<(bytes.startIndex + cursor + 46 + nameLength))
            // UTF-8 whether or not the flag claims it: the alternative in the
            // spec is IBM code page 437, and a name that is not valid UTF-8 is
            // read leniently rather than refusing the whole backup over a file
            // name. The photographs' names are all ASCII UUIDs.
            let path = String(decoding: nameBytes, as: UTF8.self)

            if flags & 0x0001 != 0 {
                throw Failure.encrypted("\(path) is password-protected, and Strata cannot open it")
            }

            var uncompressed = Int(reader.read32(cursor + 24))
            var compressed = Int(reader.read32(cursor + 20))
            var localOffset = Int(reader.read32(cursor + 42))
            // The Zip64 extra field replaces whichever of the three were
            // written as the 0xFFFFFFFF sentinel, in this order and only
            // those. Reading it unconditionally would misread a normal entry.
            if uncompressed == 0xFFFF_FFFF || compressed == 0xFFFF_FFFF || localOffset == 0xFFFF_FFFF {
                var extra = cursor + 46 + nameLength
                let extraEnd = extra + extraLength
                var found = false
                while extra + 4 <= extraEnd {
                    let id = reader.read16(extra)
                    let size = Int(reader.read16(extra + 2))
                    guard extra + 4 + size <= extraEnd else { break }
                    if id == 0x0001 {
                        var field = extra + 4
                        if uncompressed == 0xFFFF_FFFF, field + 8 <= extra + 4 + size {
                            uncompressed = Int(reader.read64(field)); field += 8
                        }
                        if compressed == 0xFFFF_FFFF, field + 8 <= extra + 4 + size {
                            compressed = Int(reader.read64(field)); field += 8
                        }
                        if localOffset == 0xFFFF_FFFF, field + 8 <= extra + 4 + size {
                            localOffset = Int(reader.read64(field))
                        }
                        found = true
                        break
                    }
                    extra += 4 + size
                }
                guard found else {
                    throw Failure.unsupported("\(path) is indexed in a way Strata cannot read")
                }
            }

            entries.append(Entry(path: path,
                                 compressedSize: compressed,
                                 uncompressedSize: uncompressed,
                                 storedCRC: reader.read32(cursor + 16),
                                 method: reader.read16(cursor + 10),
                                 localHeaderOffset: localOffset))
            cursor += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    // MARK: - Bytes

    private func read16(_ offset: Int) -> UInt16 { Cursor(bytes).read16(offset) }
    private func read32(_ offset: Int) -> UInt32 { Cursor(bytes).read32(offset) }

    /// Little-endian reads that cannot walk off the end: every one is bounded,
    /// and a read past the end is zero rather than a crash. A corrupt archive
    /// is a message, never a trap.
    private struct Cursor {
        let bytes: Data
        init(_ bytes: Data) { self.bytes = bytes }

        func byte(_ offset: Int) -> UInt8 {
            guard offset >= 0, offset < bytes.count else { return 0 }
            return bytes[bytes.startIndex + offset]
        }
        func read16(_ offset: Int) -> UInt16 {
            UInt16(byte(offset)) | (UInt16(byte(offset + 1)) << 8)
        }
        func read32(_ offset: Int) -> UInt32 {
            (0..<4).reduce(UInt32(0)) { $0 | (UInt32(byte(offset + $1)) << (8 * UInt32($1))) }
        }
        func read64(_ offset: Int) -> UInt64 {
            (0..<8).reduce(UInt64(0)) { $0 | (UInt64(byte(offset + $1)) << (8 * UInt64($1))) }
        }

        /// The end-of-central-directory record sits at the very end of the file
        /// unless there is an archive comment, which can be 64 KB long, so it
        /// is found by scanning backwards. Scanning forwards would stop at the
        /// first entry that happens to contain the signature in its bytes.
        func findEndOfCentralDirectory() -> Int? {
            let minimum = 22
            guard bytes.count >= minimum else { return nil }
            let earliest = max(0, bytes.count - minimum - 0xFFFF)
            var offset = bytes.count - minimum
            while offset >= earliest {
                if read32(offset) == 0x06054b50 {
                    // The record must account for the rest of the file exactly,
                    // or the signature was a coincidence inside somebody's data.
                    let commentLength = Int(read16(offset + 20))
                    if offset + minimum + commentLength == bytes.count { return offset }
                }
                offset -= 1
            }
            return nil
        }
    }

    // MARK: - CRC

    private static let crcTable: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var value = UInt32(index)
            for _ in 0..<8 {
                value = (value & 1 == 1) ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
            }
            return value
        }
    }()

    /// The checksum zip stores, so a damaged entry is caught here.
    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        let table = crcTable
        data.withUnsafeBytes { raw in
            for byte in raw.bindMemory(to: UInt8.self) {
                crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
