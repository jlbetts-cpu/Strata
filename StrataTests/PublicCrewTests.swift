import Foundation
import Testing
@testable import Strata

/// Crews in the public database, sealed end to end (2026-10-09,
/// `tasks/unification-log.md` §1). The sealing is pure, so it is proven
/// here without CloudKit.
@Suite("Public crews: keys, links and sealed boxes")
struct PublicCrewTests {
    let crew = CrewID(rawValue: "crew-3F2504E0-4F89-11D3-9A0C-0305E82C3301")

    @Test("a box opens with its key and record, and with nothing else")
    func sealing() throws {
        let key = CrewKey.new()
        let sealed = try key.seal(Data("Gym".utf8), context: "crew-1~SharedWin~a")
        #expect(try key.open(sealed, context: "crew-1~SharedWin~a") == Data("Gym".utf8))
        // Another crew's key cannot read it.
        #expect(throws: (any Error).self) { try CrewKey.new().open(sealed, context: "crew-1~SharedWin~a") }
        // Lifted into another record, it does not open either.
        #expect(throws: (any Error).self) { try key.open(sealed, context: "crew-1~SharedWin~b") }
        // And the sealed bytes do not carry the words.
        #expect(String(data: sealed, encoding: .utf8)?.contains("Gym") != true)
    }

    @Test("an invite link carries the crew and its key, after the #")
    func links() throws {
        let key = CrewKey.new()
        let url = CrewInviteLink.url(crew: crew, key: key)
        #expect(url.absoluteString.hasPrefix(CrewInviteLink.page + "#"))
        #expect(url.query == nil, "the key must never be in a part a server sees")
        let read = try #require(CrewInviteLink.read(url))
        #expect(read.crew == crew && read.key == key)
        let app = try #require(CrewInviteLink.read(CrewInviteLink.appURL(crew: crew, key: key)))
        #expect(app.crew == crew && app.key == key)
    }

    @Test("anything else is no invitation")
    func notLinks() {
        let key = CrewKey.new().linkText
        for text in ["https://example.com/join.html#\(crew.rawValue).\(key)",
                     "\(CrewInviteLink.page)#\(crew.rawValue)",
                     "\(CrewInviteLink.page)#\(crew.rawValue).short",
                     "\(CrewInviteLink.page)#notacrew.\(key)",
                     "\(CrewInviteLink.page)#crew-../../x.\(key)",
                     "somewins://other#\(crew.rawValue).\(key)"] {
            #expect(CrewInviteLink.read(URL(string: text)!) == nil, "\(text)")
        }
    }

    @Test("fields and photos survive sealing, and the extension reads the words")
    func boxRoundTrip() throws {
        let key = CrewKey.new()
        let folder = FileManager.default.temporaryDirectory.appending(path: "box-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let photo = folder.appending(path: "photo.jpg")
        try Data(repeating: 7, count: 4096).write(to: photo)
        let win = UUID()
        let fields: RecordFields = ["title": .string("Ran 5k"), "winID": .uuid(win),
                                    "blockSize": .int(2), "createdAt": .date(Date(timeIntervalSince1970: 1_800_000_000)),
                                    "photo": .asset(photo)]
        let name = CrewItemRecord.name(crew: crew.rawValue, kind: "SharedWin", name: win.uuidString)
        let sealed = try CrewItemBox.seal(fields, key: key, recordName: name, folder: folder.appending(path: "out"))
        #expect(sealed.assets.count == 1)
        let uploaded = try #require(sealed.assets["a"])
        #expect(try Data(contentsOf: uploaded) != Data(repeating: 7, count: 4096), "the photo goes up sealed")

        let opened = try CrewItemBox.open(sealed.box, assets: sealed.assets, key: key, recordName: name,
                                          into: folder.appending(path: "in"), stem: "w-1")
        #expect(opened["title"] == .string("Ran 5k"))
        #expect(opened["winID"]?.uuid == win)
        #expect(opened["blockSize"] == .int(2))
        let back = try #require(opened["photo"]?.asset)
        #expect(try Data(contentsOf: back) == Data(repeating: 7, count: 4096))

        let words = CrewItemRecord.strings(in: sealed.box, key: key, recordName: name)
        #expect(words["title"] == "Ran 5k")
        #expect(words["winID"]?.lowercased() == win.uuidString.lowercased())
        #expect(CrewItemRecord.strings(in: sealed.box, key: CrewKey.new(), recordName: name).isEmpty)
    }

    @Test("keys are kept per crew and only for crews you are in")
    func keyStore() {
        let store = CrewKeyStore(suite: "public-crew-tests-\(UUID().uuidString)")
        let key = CrewKey.new()
        store.set(key, for: crew)
        #expect(store.key(for: crew) == key)
        #expect(store.all.count == 1)
        store.set(nil, for: crew)
        #expect(store.key(for: crew) == nil)
    }

    @Test("the old private zones are gone from the app's code")
    func noZones() throws {
        let cloud = try SourceSweep.code(SourceSweep.read("Strata/Social/PublicCrewCloud.swift"))
        #expect(!cloud.contains("CKShare("), "crews are not iCloud shares any more")
        #expect(!cloud.contains("recordZoneChanges"), "crews do not live in zones any more")
        #expect(cloud.contains("publicCloudDatabase"))
    }
}
