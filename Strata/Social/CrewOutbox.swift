import Foundation

/// Writes that have not reached the cloud yet, kept on disk.
///
/// **Not SwiftData.** These are about other people's copies of your wins, and
/// the private store is only ever about your own record. A plain JSON file in
/// `Application Support/Crews`, rewritten whole on every change: it holds a
/// handful of entries at most.
///
/// A newer write to the same record replaces an older one, so an edit made
/// offline and then a withdrawal made offline send one delete, not a save
/// and a delete.
nonisolated struct CrewOutbox: Codable, Equatable, Sendable {
    nonisolated struct Entry: Codable, Equatable, Sendable {
        let crew: CrewID
        let type: CrewRecordType
        let name: String
        /// Nil deletes the record.
        let fields: RecordFields?
        var attempts = 0
    }

    private(set) var entries: [Entry] = []

    var isEmpty: Bool { entries.isEmpty }

    mutating func put(_ entry: Entry) {
        entries.removeAll { $0.crew == entry.crew && $0.type == entry.type && $0.name == entry.name }
        entries.append(entry)
    }

    mutating func remove(_ entry: Entry) {
        entries.removeAll { $0.crew == entry.crew && $0.type == entry.type && $0.name == entry.name }
    }

    mutating func noteFailure(_ entry: Entry) {
        guard let i = entries.firstIndex(where: { $0.crew == entry.crew && $0.type == entry.type && $0.name == entry.name })
        else { return }
        entries[i].attempts += 1
    }

    mutating func drop(crew: CrewID) {
        entries.removeAll { $0.crew == crew }
    }

    /// The crews a win is still waiting to reach.
    func pendingCrews(for winID: UUID) -> Set<CrewID> {
        Set(entries.filter { $0.type == .sharedWin && $0.name == winID.uuidString && $0.fields != nil }.map(\.crew))
    }

    static func load(from url: URL) -> CrewOutbox {
        guard let data = try? Data(contentsOf: url),
              let outbox = try? JSONDecoder().decode(CrewOutbox.self, from: data) else { return CrewOutbox() }
        return outbox
    }

    func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
