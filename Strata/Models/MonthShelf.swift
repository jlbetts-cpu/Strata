import Foundation

/// **The month's albums** (the unification pass, 2026-10-09: "the Memories
/// tab is the hub, with curated auto-generated albums").
///
/// One row of cards under the month's photo count, above its photographs:
/// albums the app made out of what you already logged, for the month the
/// picker names, because the month governs the whole page (the owner,
/// 2026-10-03). Nothing on the first screen moves; the row is part of the
/// photographs, which is what every album is made of.
///
/// - **Moments** ("A year ago today"), on the current month only: they are
///   about now, and stepping back to March does not make them March's.
/// - **With your crew**: your own photographed wins you sent to a crew that
///   month. Your own only: a friend's photograph leaves the crew after two
///   weeks (`CrewDay.keptDays`) and is not kept here either.
/// - **What you kept doing**: a title you photographed on more than one day.
///
/// At most five, and none at all rather than a row of one weak card: a shelf
/// earns its band by having something worth opening in it.
nonisolated extension Album {
    static let monthShelfMax = 5
    /// A crew album needs three photographs to be more than one afternoon.
    static let monthCrewMinPhotos = 3
    /// An interest inside a month: three photographs over two days at least.
    static let monthInterestMinPhotos = 3
    static let monthInterestMinDays = 2

    /// One crew, as the shelf needs it: its name and the wins of yours it
    /// holds (`SocialStore.winsSent(to:)`).
    struct ShelfCrew: Sendable {
        let id: String
        let name: String
        let wins: Set<UUID>
    }

    /// `month` is `"yyyy-MM"`, as `HabitLog.dateString` begins.
    static func monthShelf(records: [WinRecord], month: String, crews: [ShelfCrew],
                           moments: [Album]) -> [Album] {
        let inMonth = records.filter { $0.hasPhoto && $0.dateString.hasPrefix(month + "-") }
        var shelf = moments

        let crewAlbums: [Album] = crews.compactMap { crew in
            let group = inMonth.filter { $0.id.map(crew.wins.contains) ?? false }
            guard group.count >= monthCrewMinPhotos else { return nil }
            return Album(id: "crew:\(crew.id)@\(month)",
                         kind: .crew("\(crew.id)@\(month)"),
                         title: "With \(crew.name)",
                         subtitle: "\(group.count) PHOTOS",
                         sortDate: group.map(\.completedAt).max() ?? .distantPast,
                         photoFileNames: coverOrder(for: group),
                         winCount: group.count,
                         haystack: crew.name.lowercased())
        }
        .sorted { $0.winCount != $1.winCount ? $0.winCount > $1.winCount : $0.sortDate > $1.sortDate }
        shelf += crewAlbums

        var byKey: [String: [WinRecord]] = [:]
        for record in inMonth {
            let key = titleKey(record.title)
            guard isCuratable(key) else { continue }
            byKey[key, default: []].append(record)
        }
        let interests: [Album] = byKey.compactMap { key, group in
            guard group.count >= monthInterestMinPhotos,
                  Set(group.map(\.dateString)).count >= monthInterestMinDays else { return nil }
            let display = displayTitle(for: group)
            return Album(id: "curated:\(key)@\(month)",
                         kind: .curated("\(key)@\(month)"),
                         title: display,
                         subtitle: "\(group.count) PHOTOS",
                         sortDate: group.map(\.completedAt).max() ?? .distantPast,
                         photoFileNames: coverOrder(for: group),
                         winCount: group.count,
                         haystack: "\(key) \(display)".lowercased())
        }
        .sorted { $0.winCount != $1.winCount ? $0.winCount > $1.winCount : $0.id < $1.id }
        shelf += interests

        return Array(shelf.prefix(monthShelfMax))
    }

    /// A shelf key's two halves: `"gym@2026-10"` gives ("gym", "2026-10").
    /// A key without a month (the all-time interest albums) gives nil for it.
    static func splitMonth(_ key: String) -> (key: String, month: String?) {
        guard let at = key.lastIndex(of: "@") else { return (key, nil) }
        let month = String(key[key.index(after: at)...])
        guard month.count == 7, month.dropFirst(4).first == "-",
              month.allSatisfy({ $0.isNumber || $0 == "-" }) else { return (key, nil) }
        return (String(key[..<at]), month)
    }
}
