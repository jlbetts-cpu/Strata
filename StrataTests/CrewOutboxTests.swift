import Testing
import Foundation
@testable import Strata

/// The outbox holds wins still on their way to a crew. Losing it loses them
/// without a word, so what matters is how it READS a file it did not write.
///
/// Self-test, each of which re-injects a real bug:
/// - Return `CrewOutbox()` from `load` on a failed decode without setting the
///   file aside and `anUnreadableFileIsKept` fails: the next write would have
///   put an empty outbox over it.
/// - Drop the lossy decode and `oneUnreadableEntryCostsOnlyItself` fails with
///   nothing loaded.
@Suite("CrewOutbox")
struct CrewOutboxTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "crew-outbox-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func entry(_ name: String) -> CrewOutbox.Entry {
        CrewOutbox.Entry(crew: CrewID(rawValue: "crew-test"), type: .sharedWin, name: name, fields: nil)
    }

    @Test("an outbox round-trips through its file")
    func roundTrips() throws {
        let url = try folder().appending(path: "outbox.json")
        var box = CrewOutbox()
        box.put(entry("a"))
        box.put(entry("b"))
        try box.write(to: url)
        #expect(CrewOutbox.load(from: url) == box)
    }

    @Test("a file that cannot be read is set aside, not read as nothing waiting")
    func anUnreadableFileIsKept() throws {
        let dir = try folder()
        let url = dir.appending(path: "outbox.json")
        let garbage = Data("{\"entries\": [".utf8)
        try garbage.write(to: url)
        #expect(CrewOutbox.load(from: url).isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let aside = try #require(names.first { $0.hasPrefix("outbox.unreadable-") })
        #expect(try Data(contentsOf: dir.appending(path: aside)) == garbage)
    }

    @Test("one entry this build cannot read costs only itself, and a missing count is a first try")
    func oneUnreadableEntryCostsOnlyItself() throws {
        let url = try folder().appending(path: "outbox.json")
        let json = """
        {"entries": [
          {"crew": {"rawValue": "crew-test"}, "type": "SharedWin", "name": "kept"},
          {"crew": {"rawValue": "crew-test"}, "type": "SomethingNewer", "name": "skipped"}
        ]}
        """
        try Data(json.utf8).write(to: url)
        let box = CrewOutbox.load(from: url)
        #expect(box.pendingCrews(for: UUID()).isEmpty)
        #expect(!box.isEmpty)
        var expected = CrewOutbox()
        expected.put(entry("kept"))
        #expect(box == expected)
    }
}
