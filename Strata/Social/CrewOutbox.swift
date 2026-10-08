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

    /// Removes `entry` only if it is still the one waiting: a newer write to
    /// the same record that arrived while this one was being sent must stay.
    mutating func removeIfUnchanged(_ entry: Entry) {
        entries.removeAll { $0.crew == entry.crew && $0.type == entry.type && $0.name == entry.name
            && $0.fields == entry.fields }
    }

    /// Writes that failed this many times are for something that is gone.
    mutating func dropHopeless(after attempts: Int = 20) -> [Entry] {
        let gone = entries.filter { $0.attempts >= attempts }
        entries.removeAll { $0.attempts >= attempts }
        return gone
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

    /// A file that is there but cannot be read is set aside, never read as
    /// "nothing waiting": the next write would put an empty outbox over it,
    /// and every win still on its way to a crew would be lost without a word.
    static func load(from url: URL) -> CrewOutbox {
        guard let data = try? Data(contentsOf: url) else { return CrewOutbox() }
        if let outbox = try? JSONDecoder().decode(CrewOutbox.self, from: data) { return outbox }
        let aside = url.deletingLastPathComponent()
            .appending(path: "outbox.unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.copyItem(at: url, to: aside)
        return CrewOutbox()
    }

    func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

// One entry another build wrote, that this one cannot read, costs that entry
// and not the whole queue; a missing `attempts` is a first attempt.
extension CrewOutbox {
    private struct Lossy: Decodable {
        let entry: Entry?
        init(from decoder: Decoder) throws { entry = try? Entry(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = (try c.decodeIfPresent([Lossy].self, forKey: .entries) ?? []).compactMap(\.entry)
    }
}

extension CrewOutbox.Entry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        crew = try c.decode(CrewID.self, forKey: .crew)
        type = try c.decode(CrewRecordType.self, forKey: .type)
        name = try c.decode(String.self, forKey: .name)
        fields = try c.decodeIfPresent(RecordFields.self, forKey: .fields)
        attempts = try c.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
    }
}
