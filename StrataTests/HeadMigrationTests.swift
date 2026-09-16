import Testing
import Foundation
import UIKit
@testable import Strata

/// Migrating a version 2 head: never over a head made or deleted while it
/// ran, never touching the images a version 2 head wrote, and a second run
/// does nothing.
///
/// Self-test: drop the `now == startedAt` guard in
/// `HeadStore.finishMigration` and `aSaveDuringMigrationWins` fails with the
/// new head's folder full of the old head's derived faces; drop the
/// `onDisk.version < 3` re-read and `aDeleteDuringMigrationStaysDeleted`
/// fails with the head brought back.
@MainActor
@Suite("HeadMigration", .serialized)
struct HeadMigrationTests {

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "head-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "Head", directoryHint: .isDirectory)
        HeadStore.writeVersion2Fixture(to: url)
        #expect(FileManager.default.fileExists(atPath: url.appending(path: "head.json").path))
        return url
    }

    private func files(_ url: URL) -> [String: Data] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return Dictionary(uniqueKeysWithValues: names.compactMap { name in
            (try? Data(contentsOf: url.appending(path: name))).map { (name, $0) }
        })
    }

    @Test("a clean migration adds faces, keeps every version 2 image byte for byte, and runs once")
    func cleanAndIdempotent() throws {
        let url = try folder()
        let before = files(url)
        let prepared = try #require(HeadStore.prepareMigration(url))
        let rig = try #require(HeadStore.finishMigration(prepared, in: url, startedAt: 0, now: 0))
        #expect(rig.shut != nil)
        let after = files(url)
        for (name, data) in before where name != "head.json" {
            #expect(after[name] == data, "\(name) changed")
        }
        #expect(after.keys.contains("neutral-shut.png"))
        let (_, manifest) = try #require(HeadStore.read(from: url))
        #expect(manifest.version == 3)
        // Again: nothing to do, nothing written.
        #expect(HeadStore.prepareMigration(url) == nil)
        #expect(HeadStore.finishMigration(prepared, in: url, startedAt: 0, now: 0) == nil)
        #expect(files(url) == after)
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appending(path: "Head-migrating").path))
    }

    @Test("a head saved while the migration ran is left alone")
    func aSaveDuringMigrationWins() throws {
        let url = try folder()
        let prepared = try #require(HeadStore.prepareMigration(url))
        // A new head is made: the folder is cleared and written fresh.
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let neutral = try #require(UIImage(named: "HeadSmile")?.pngData())
        try HeadStore.write(HeadStore.Payload(faces: [.neutral: .init(png: neutral, eyes: [])], shut: nil), to: url)
        let saved = files(url)
        #expect(HeadStore.finishMigration(prepared, in: url, startedAt: 0, now: 1) == nil)
        #expect(files(url) == saved)
    }

    @Test("a head deleted while the migration ran stays deleted")
    func aDeleteDuringMigrationStaysDeleted() throws {
        let url = try folder()
        let prepared = try #require(HeadStore.prepareMigration(url))
        try FileManager.default.removeItem(at: url)
        #expect(HeadStore.finishMigration(prepared, in: url, startedAt: 0, now: 1) == nil)
        // Even if the epoch were somehow the same, a missing head is not written back.
        #expect(HeadStore.finishMigration(prepared, in: url, startedAt: 0, now: 0) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("a banded brows file that has gone falls back to the raw capture")
    func bandedBrowsFallBack() throws {
        let url = try folder()
        let prepared = try #require(HeadStore.prepareMigration(url))
        _ = try #require(HeadStore.finishMigration(prepared, in: url, startedAt: 0, now: 0))
        let (_, manifest) = try #require(HeadStore.read(from: url))
        guard manifest.bandedBrows == true else { return }
        try FileManager.default.removeItem(at: url.appending(path: "browsUp-banded.png"))
        let (payload, _) = try #require(HeadStore.read(from: url))
        let raw = try Data(contentsOf: url.appending(path: "browsUp.png"))
        #expect(payload.faces[.browsUp]?.png == raw)
        #expect(payload.rawBrows == nil)
    }
}
