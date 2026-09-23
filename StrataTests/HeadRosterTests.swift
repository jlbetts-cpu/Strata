import Testing
import Foundation
import UIKit
@testable import Strata

/// Several heads, each with a name, one of them in use.
///
/// The owner, 2026-09-23: "I want it so you are able to save multiple heads,
/// like you are able to add your friend's head for instance to your tower
/// instead of yours."
///
/// **His made heads cannot be replaced**, so the tests that matter most here
/// are the ones about the head that already exists: that it is adopted where
/// it lies, that not one of its files is touched, and that a build from before
/// the collection would still load it afterwards.
///
/// Nothing here touches `HeadStore.shared`, which would read and write the
/// real Application Support directory. Every test works on a temporary folder
/// or on `Roster` alone, which is why the list rules are `mutating` functions
/// on a value type rather than list surgery inside the store.
///
/// Self-test, each of which re-injects a real bug:
/// - Drop the adoption block in `HeadStore.loadedRoster` and
///   `anExistingHeadIsAdoptedAndBecomesActive` fails with an empty list: that
///   is his head disappearing from the app on first launch.
/// - Copy or rewrite anything inside `Head/` during adoption and
///   `adoptingWritesNothingIntoTheOldFolder` fails.
/// - Make `Roster.remove` leave `activeID` alone and
///   `deletingTheActiveHeadPromotesAnother` fails with nothing in use, which
///   shows every caller a person with no head while their heads sit on disk.
/// - Drop the `hasPrefix(inside)` guard in `HeadStore.resolve` and
///   `aFolderOutsideTheAppDirectoryIsRefused` deletes a file outside the app.
/// - Make `Roster.add` leave `activeID` alone and
///   `addingAHeadPutsItInUse` fails.
@Suite("HeadRoster")
struct HeadRosterTests {

    // MARK: - Helpers

    private func support() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "head-roster-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A head on disk the way it was before the collection existed: one
    /// `Head` folder, written by the version 2 path.
    @MainActor
    private func writeExistingHead(in support: URL) -> URL {
        let url = support.appending(path: HeadStore.legacyFolder, directoryHint: .isDirectory)
        HeadStore.writeVersion2Fixture(to: url)
        return url
    }

    private func files(_ url: URL) -> [String: Data] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return Dictionary(uniqueKeysWithValues: names.compactMap { name in
            (try? Data(contentsOf: url.appending(path: name))).map { (name, $0) }
        })
    }

    private func entry(_ name: String, folder: String = "Heads/\(UUID().uuidString)") -> HeadStore.Entry {
        HeadStore.Entry(id: UUID(), name: name, created: Date(), folder: folder)
    }

    /// Everything about a roster except the dates. A `created` date goes
    /// through the roster file as a JSON number, and this suite is not the
    /// place to find out how many digits of a `Double` that keeps.
    private func shape(_ roster: HeadStore.Roster) -> (Int, [UUID], [String], [String], UUID?) {
        (roster.version, roster.heads.map(\.id), roster.heads.map(\.name),
         roster.heads.map(\.folder), roster.activeID)
    }

    // MARK: - The head that already exists

    @Test("the one head already on the phone is adopted and becomes the active head")
    @MainActor
    func anExistingHeadIsAdoptedAndBecomesActive() throws {
        let support = try support()
        _ = writeExistingHead(in: support)
        #expect(HeadStore.readRoster(in: support) == nil, "there is no roster file before the first launch")

        let roster = HeadStore.loadedRoster(in: support, legacyName: "Me")
        #expect(roster.heads.count == 1)
        let adopted = try #require(roster.heads.first)
        #expect(adopted.folder == HeadStore.legacyFolder, "the head keeps the folder it has always had")
        #expect(adopted.name == "Me")
        #expect(roster.activeID == adopted.id, "the only head is the head in use")

        // And it really loads: what every caller asking for "the head" gets.
        let directory = try #require(HeadStore.directory(of: adopted, in: support))
        let loaded = try #require(HeadStore.load(at: directory))
        #expect(loaded.rig != nil)

        // Written down, so the second launch does not adopt it twice.
        let stored = try #require(HeadStore.readRoster(in: support))
        #expect(shape(stored) == shape(roster))
        let again = HeadStore.loadedRoster(in: support, legacyName: "Me")
        #expect(shape(again) == shape(roster), "adopting is idempotent")
    }

    @Test("adopting writes nothing into the old head's folder, and an old build still loads it")
    @MainActor
    func adoptingWritesNothingIntoTheOldFolder() throws {
        let support = try support()
        let head = writeExistingHead(in: support)
        let before = files(head)
        #expect(!before.isEmpty)

        _ = HeadStore.loadedRoster(in: support, legacyName: "Me")

        let after = files(head)
        #expect(after == before, "a file inside Head/ changed during adoption")
        // A build from before the collection reads exactly this and nothing
        // else. It is still readable, and still version 2, so its own
        // migration still has something to do.
        let (payload, manifest) = try #require(HeadStore.read(from: head))
        #expect(manifest.version == 2)
        #expect(payload.faces[.neutral] != nil)
        // The roster is beside the folder, never inside it: an older build
        // walking Head/ must not meet a file it does not expect.
        #expect(after[HeadStore.rosterFile] == nil)
        #expect(FileManager.default.fileExists(atPath: support.appending(path: HeadStore.rosterFile).path))
    }

    @Test("a head written again by an older build is picked back up")
    @MainActor
    func anOldBuildsRemakeIsAdoptedAgain() throws {
        let support = try support()
        // A roster with one head of its own, and no legacy entry: what a
        // rollback and a re-make on the old build would leave behind.
        var roster = HeadStore.Roster()
        let made = entry("Head 2")
        let madeFolder = try #require(HeadStore.resolve(folder: made.folder, in: support))
        try FileManager.default.createDirectory(at: madeFolder, withIntermediateDirectories: true)
        HeadStore.writeVersion2Fixture(to: madeFolder)
        roster.add(made)
        HeadStore.writeRoster(roster, in: support)

        _ = writeExistingHead(in: support)
        let loaded = HeadStore.loadedRoster(in: support, legacyName: "Me")
        #expect(loaded.heads.count == 2)
        #expect(loaded.heads.first?.folder == HeadStore.legacyFolder, "the oldest head is first in the row")
        #expect(loaded.activeID == made.id, "adopting does not change which head is in use")
    }

    @Test("an entry whose folder has gone is forgotten, and nothing on disk is removed for it")
    @MainActor
    func aMissingFolderIsForgotten() throws {
        let support = try support()
        let head = writeExistingHead(in: support)
        var roster = HeadStore.loadedRoster(in: support, legacyName: "Me")
        let ghost = entry("Gone")
        roster.add(ghost)
        HeadStore.writeRoster(roster, in: support)

        let loaded = HeadStore.loadedRoster(in: support, legacyName: "Me")
        #expect(!loaded.heads.contains { $0.id == ghost.id })
        #expect(loaded.heads.count == 1)
        #expect(loaded.activeID == loaded.heads.first?.id, "the head in use was the ghost, so the real one takes over")
        #expect(!files(head).isEmpty, "forgetting an entry must not remove anybody's files")
    }

    // MARK: - Exactly one active head

    @Test("adding a head puts it in use, and there is always exactly one")
    func addingAHeadPutsItInUse() {
        var roster = HeadStore.Roster()
        #expect(roster.activeID == nil, "no heads, nothing in use")

        let me = entry("Me")
        roster.add(me)
        #expect(roster.activeID == me.id)

        let friend = entry("Sam")
        roster.add(friend)
        #expect(roster.heads.count == 2)
        #expect(roster.activeID == friend.id, "a head you just made is the head you meant to use")
        #expect(roster.heads.filter { $0.id == roster.activeID }.count == 1)
    }

    @Test("deleting the active head promotes another rather than leaving none")
    func deletingTheActiveHeadPromotesAnother() {
        var roster = HeadStore.Roster()
        let a = entry("A"), b = entry("B"), c = entry("C")
        for one in [a, b, c] { roster.add(one) }
        roster.use(a.id)

        // The middle of the row: the one after it takes over.
        let removed = roster.remove(a.id)
        #expect(removed?.id == a.id)
        #expect(roster.heads.map(\.id) == [b.id, c.id])
        #expect(roster.activeID == b.id)

        // The end of the row: the last one left takes over.
        roster.use(c.id)
        roster.remove(c.id)
        #expect(roster.activeID == b.id)
        #expect(roster.heads.count == 1)
    }

    @Test("deleting a head that is not in use leaves the one in use alone")
    func deletingAnotherHeadKeepsTheActiveOne() {
        var roster = HeadStore.Roster()
        let a = entry("A"), b = entry("B")
        roster.add(a)
        roster.add(b)
        #expect(roster.activeID == b.id)
        roster.remove(a.id)
        #expect(roster.activeID == b.id)
        #expect(roster.heads.map(\.id) == [b.id])
    }

    @Test("deleting the last head leaves none in use, and a stale active id settles")
    func theLastHeadAndAStaleActiveID() {
        var roster = HeadStore.Roster()
        let only = entry("Me")
        roster.add(only)
        roster.remove(only.id)
        #expect(roster.heads.isEmpty)
        #expect(roster.activeID == nil, "there is nothing left to be in use")

        // A roster pointing at a head that is not in the list (a hand-edited
        // file, or one written by a build that crashed mid-edit).
        let a = entry("A")
        var stale = HeadStore.Roster(heads: [a], activeID: UUID())
        stale.settle()
        #expect(stale.activeID == a.id)
        // And settling an empty list leaves nothing pointed at.
        var empty = HeadStore.Roster(heads: [], activeID: UUID())
        empty.settle()
        #expect(empty.activeID == nil)
    }

    @Test("removing a head that is not there changes nothing")
    func removingAStranger() {
        var roster = HeadStore.Roster()
        let a = entry("A")
        roster.add(a)
        let before = roster
        #expect(roster.remove(UUID()) == nil)
        #expect(roster == before)
    }

    // MARK: - Names

    @Test("a head is never nameless")
    func names() {
        #expect(HeadStore.defaultName(index: 0, person: "") == "Me")
        #expect(HeadStore.defaultName(index: 0, person: "   ") == "Me")
        #expect(HeadStore.defaultName(index: 0, person: "Jayden") == "Jayden")
        #expect(HeadStore.defaultName(index: 1, person: "Jayden") == "Head 2")
        #expect(HeadStore.defaultName(index: 4, person: "") == "Head 5")

        var roster = HeadStore.Roster()
        let a = entry("Me")
        roster.add(a)
        roster.rename(a.id, to: "  Sam  ")
        #expect(roster.heads[0].name == "Sam", "a typed name is trimmed")
        roster.rename(a.id, to: "   ")
        #expect(roster.heads[0].name == "Sam", "clearing the field keeps the name it has")
        roster.rename(a.id, to: String(repeating: "x", count: 200))
        #expect(roster.heads[0].name.count == HeadStore.Roster.nameLimit)
        roster.rename(UUID(), to: "Nobody")
        #expect(roster.heads[0].name.count == HeadStore.Roster.nameLimit)
    }

    // MARK: - Nothing writes outside the app's own directory

    @Test("a folder outside the app's own directory is refused, and nothing out there is removed")
    func aFolderOutsideTheAppDirectoryIsRefused() throws {
        let support = try support()
        let outside = support.deletingLastPathComponent()
            .appending(path: "precious-\(UUID().uuidString).txt")
        try Data("a head is minutes of work".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }

        for folder in ["", "..", "../..", "../\(outside.lastPathComponent)", "../../", "."] {
            #expect(HeadStore.resolve(folder: folder, in: support) == nil, "\"\(folder)\" resolved")
        }
        // The two shapes the app really writes.
        #expect(HeadStore.resolve(folder: HeadStore.legacyFolder, in: support) != nil)
        let id = UUID()
        let made = try #require(HeadStore.resolve(folder: HeadStore.folder(for: id), in: support))
        #expect(made.path.hasPrefix(support.standardizedFileURL.path + "/"))
        #expect(made.lastPathComponent == id.uuidString)
        // A folder that climbs back inside is still inside, and allowed.
        #expect(HeadStore.resolve(folder: "Heads/../Head", in: support) != nil)

        // The delete path refuses it too, which is the one that destroys data.
        let escaping = entry("Escaping", folder: "../\(outside.lastPathComponent)")
        #expect(HeadStore.removeFolder(escaping, in: support) == false)
        #expect(FileManager.default.fileExists(atPath: outside.path), "a file outside the app was deleted")

        // And it never reaches the list in the first place.
        var roster = HeadStore.Roster()
        roster.add(escaping)
        HeadStore.writeRoster(roster, in: support)
        let loaded = HeadStore.loadedRoster(in: support, legacyName: "Me")
        #expect(loaded.heads.isEmpty)
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test("deleting a head removes its own folder and no other")
    @MainActor
    func deletingRemovesOnlyItsOwnFolder() throws {
        let support = try support()
        let kept = writeExistingHead(in: support)
        let doomed = entry("Sam")
        let doomedFolder = try #require(HeadStore.resolve(folder: doomed.folder, in: support))
        try FileManager.default.createDirectory(at: doomedFolder, withIntermediateDirectories: true)
        HeadStore.writeVersion2Fixture(to: doomedFolder)

        #expect(HeadStore.removeFolder(doomed, in: support) == true)
        #expect(!FileManager.default.fileExists(atPath: doomedFolder.path))
        #expect(!files(kept).isEmpty, "the other head's files went with it")
    }

    // MARK: - The roster file

    @Test("the roster survives a round trip through the file")
    func theRosterRoundTrips() throws {
        let support = try support()
        var roster = HeadStore.Roster()
        roster.add(entry("Me", folder: HeadStore.legacyFolder))
        roster.add(entry("Sam"))
        HeadStore.writeRoster(roster, in: support)
        let read = try #require(HeadStore.readRoster(in: support))
        #expect(shape(read) == shape(roster))
        #expect(read.version == 1)
    }
}
