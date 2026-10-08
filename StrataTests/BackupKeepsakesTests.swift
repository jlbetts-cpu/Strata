import Testing
import Foundation
import UIKit
@testable import Strata

/// Stickers and strips go round a backup, and a restore only adds.
///
/// Self-test, each of which re-injects a real bug:
/// - Drop `stickers:` from `BackupArchive.writeZip`'s call in `makeZip` and
///   `aRoundTripBringsThemBack` fails with no stickers: every day marked with
///   one shows a dot after a restore.
/// - Let `BackupKeepsakes.restore` write a strip file that is already there
///   and `aRestoreNeverReplaces` fails.
@Suite("BackupKeepsakes")
@MainActor
struct BackupKeepsakesTests {
    private func folder(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "keepsakes-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func defaults() -> UserDefaults {
        let name = "keepsakes-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func png(_ colour: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            colour.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    @Test("stickers, strip decor and developed strips come back from a backup")
    func aRoundTripBringsThemBack() throws {
        let stickersHere = StickerStore(directory: try folder("stickers"))
        let sticker = try #require(stickersHere.add(png(.red)))
        let ink = InkFiles(directory: try folder("ink"))
        try ink.write(Data("decor".utf8), named: "strip-me-2026-10-07.png")
        let keys = defaults()
        let left = UUID()
        keys.set(true, forKey: "strip.developed.me.2026-10-07")
        keys.set([left.uuidString], forKey: "strip.out.me.2026-10-07")
        keys.set("white", forKey: "strip.paper.chosen")

        let zip = try BackupExport.makeZip(habits: [], logs: [], appVersion: "1.0 (1)", photographs: [],
                                           ink: ink, stickers: stickersHere, keepsakeDefaults: keys,
                                           temporaryDirectory: try folder("zip"))
        let contents = try BackupArchive.read(zipAt: zip)

        let stickersThere = StickerStore(directory: try folder("stickers2"))
        let inkThere = InkFiles(directory: try folder("ink2"))
        let keysThere = defaults()
        let done = BackupKeepsakes.restore(contents, stickers: stickersThere, ink: inkThere, defaults: keysThere)

        #expect(done.stickers == 1)
        #expect(stickersThere.names == [sticker])
        #expect(stickersThere.image(sticker) != nil)
        #expect(inkThere.exists("strip-me-2026-10-07.png"))
        #expect(keysThere.bool(forKey: "strip.developed.me.2026-10-07"))
        #expect(keysThere.stringArray(forKey: "strip.out.me.2026-10-07") == [left.uuidString])
        #expect(keysThere.string(forKey: "strip.paper.chosen") == "white")
    }

    @Test("a restore never replaces what this phone already has")
    func aRestoreNeverReplaces() throws {
        let stickersHere = StickerStore(directory: try folder("stickers"))
        _ = stickersHere.add(png(.blue))
        let ink = InkFiles(directory: try folder("ink"))
        try ink.write(Data("from the backup".utf8), named: "strip-me-2026-10-06.png")
        let keys = defaults()
        keys.set("black", forKey: "strip.paper.chosen")
        let zip = try BackupExport.makeZip(habits: [], logs: [], appVersion: "1.0 (1)", photographs: [],
                                           ink: ink, stickers: stickersHere, keepsakeDefaults: keys,
                                           temporaryDirectory: try folder("zip"))
        let contents = try BackupArchive.read(zipAt: zip)

        let inkThere = InkFiles(directory: try folder("ink2"))
        try inkThere.write(Data("drawn here".utf8), named: "strip-me-2026-10-06.png")
        let keysThere = defaults()
        keysThere.set("work", forKey: "strip.paper.chosen")
        BackupKeepsakes.restore(contents, stickers: StickerStore(directory: try folder("s2")), ink: inkThere,
                                defaults: keysThere)
        #expect(try Data(contentsOf: inkThere.url("strip-me-2026-10-06.png")) == Data("drawn here".utf8))
        #expect(keysThere.string(forKey: "strip.paper.chosen") == "work")
    }
}
