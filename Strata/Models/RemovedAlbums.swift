import Foundation

/// **Albums you took off the shelf** (the owner, 2026-10-11: "for the
/// albums make it so you are able to delete albums and all the utility for
/// those that don't want that album").
///
/// An album here is not a thing that is stored: it is a view of wins you
/// already have, made again each time the page is drawn (`Album.monthShelf`).
/// So there is nothing to delete, and "Remove" is the honest word (the app's
/// own rule, `docs/ten.md`: Remove comes off something that stays). The wins
/// and photos are where they always were, in the calendar and the grid.
///
/// Two strengths, as Photos and Google Photos both have (`docs/albums.md`):
/// - **this one**: this title this month, this crew this month, this past
///   day today;
/// - **never**: every month's album of that title, every album of that
///   crew, every "a year ago" kind of album.
///
/// Kept beside the model, on this phone, as Skip Today is (`PlanSkips`):
/// the model has no row for an album, and a new field would need the iCloud
/// schema deployed by hand. Every one can be brought back from Settings.
nonisolated enum RemovedAlbums {
    static let key = "memories.removedAlbums"

    struct Entry: Codable, Equatable, Sendable {
        var title: String
        var at: Double
        /// Every album of its kind, not this one alone.
        var never: Bool
    }

    /// This one album. A moment's id is relative ("a year ago today"), so
    /// it is stamped with the day: tomorrow's is a different album.
    static func key(for kind: AlbumKind, today: String) -> String? {
        switch kind {
        case .curated(let key): "curated:\(key)"
        case .crew(let key): "crew:\(key)"
        case .moment(let id): "moment:\(id)@\(today)"
        case .day: nil
        }
    }

    /// Every album of its kind: the title in any month, the crew in any
    /// month, the rule behind a moment.
    static func familyKey(for kind: AlbumKind) -> String? {
        switch kind {
        case .curated(let key): "curated:\(Album.splitMonth(key).key)"
        case .crew(let key): "crew:\(Album.splitMonth(key).key)"
        case .moment(let id): "moment:\(id.split(separator: ":").first.map(String.init) ?? id)"
        case .day: nil
        }
    }

    static func isRemoved(_ kind: AlbumKind, today: String, in keys: Set<String>) -> Bool {
        if let one = key(for: kind, today: today), keys.contains(one) { return true }
        if let family = familyKey(for: kind), keys.contains(family) { return true }
        return false
    }

    static func all(defaults: UserDefaults = .standard) -> [String: Entry] {
        guard let data = defaults.data(forKey: key),
              let table = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return table
    }

    private static func write(_ table: [String: Entry], defaults: UserDefaults) {
        if table.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(table) {
            defaults.set(data, forKey: key)
        }
    }

    /// Takes the album, or its whole kind, off the shelf. Returns the key
    /// it is kept under, for Undo and for Settings.
    @discardableResult
    static func remove(_ kind: AlbumKind, title: String, never: Bool, today: String, now: Date = Date(),
                       defaults: UserDefaults = .standard) -> String? {
        guard let key = never ? familyKey(for: kind) : key(for: kind, today: today) else { return nil }
        var table = all(defaults: defaults)
        table[key] = Entry(title: title, at: now.timeIntervalSince1970, never: never)
        write(table, defaults: defaults)
        return key
    }

    static func showAgain(_ key: String, defaults: UserDefaults = .standard) {
        var table = all(defaults: defaults)
        table[key] = nil
        write(table, defaults: defaults)
    }
}
