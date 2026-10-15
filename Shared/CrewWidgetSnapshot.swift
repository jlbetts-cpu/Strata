import Foundation

/// **A crew, on the home screen** (the owner, 2026-10-14, choosing the crew
/// widget from a brainstorm): everyone's head standing on the wins they have
/// logged today, and a head that has not logged yet standing on the ground.
///
/// The same arrangement as `WidgetSnapshot`, for the same reasons: the app
/// writes already-decided facts into the App Group and the widget only
/// draws. The widget never sees `SocialStore`, CloudKit, or a head pack; it
/// gets each person's face as a flat picture the app rendered.
///
/// **Only what a crew's own tower already shows.** Today's wins as colours
/// and sizes, first names, and faces, filtered as the tower filters them
/// (`SocialStore.today(in:)`: nobody you blocked, nothing you hid). No titles
/// and no photographs: a home screen is seen by whoever is holding the phone.
struct CrewWidgetSnapshot: Codable, Equatable {

    /// One win: its size and its colour.
    struct Win: Codable, Equatable {
        /// `BlockSize.massTier`: 1 Quick, 2 Regular, 3 Deep.
        let tier: Int
        /// The category's colour as `RRGGBB`.
        let hex: String
    }

    struct Member: Codable, Equatable, Identifiable {
        /// The profile id.
        let id: String
        let name: String
        /// Their face, a PNG in `headDirectory`. Named for what it shows, so
        /// a new head is a new name and the snapshot changes with it.
        let face: String?
        /// Today's, oldest first.
        let wins: [Win]
    }

    struct Crew: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// The crew's day this was written on, `yyyy-MM-dd` in its zone.
        let day: String
        /// The creator's zone: the crew day closes at their midnight.
        let zone: String
        let members: [Member]

        /// **The crew as it stands on `date`.** A file written yesterday is
        /// a new day with nobody's wins in it yet, so the widget never shows
        /// last night's blocks as today's when the app has not run since
        /// midnight. The same rule as `WidgetSnapshot.asOf`.
        func asOf(_ date: Date) -> Crew {
            let today = CrewWidgetSnapshot.dayString(for: date, zone: TimeZone(identifier: zone) ?? .current)
            guard today != day else { return self }
            return Crew(id: id, name: name, day: today, zone: zone,
                        members: members.map { Member(id: $0.id, name: $0.name, face: $0.face, wins: []) })
        }

        var loggedCount: Int { members.filter { !$0.wins.isEmpty }.count }
    }

    let crews: [Crew]
    let updated: Date

    static let empty = CrewWidgetSnapshot(crews: [], updated: .distantPast)

    /// The crew a widget was set to, or the first, so a widget placed before
    /// it is configured still shows somebody.
    func crew(_ id: String?) -> Crew? {
        if let id, let chosen = crews.first(where: { $0.id == id }) { return chosen }
        return crews.first
    }

    /// `CrewDay.string`, repeated here because that type is in the app target.
    static func dayString(for date: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Where it lives

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appendingPathComponent("crew-widget.json")
    }

    /// The faces, beside the file.
    static var headDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appendingPathComponent("crew-widget-faces", isDirectory: true)
    }

    static func read() -> CrewWidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(CrewWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    /// Everything but `updated`, so an unchanged crew is not rewritten and
    /// does not spend a WidgetKit reload.
    func sameContent(as other: CrewWidgetSnapshot) -> Bool { crews == other.crews }

    @discardableResult
    func write() -> Bool {
        guard let url = Self.fileURL,
              let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// What the gallery and the placeholder show.
    static let preview = CrewWidgetSnapshot(crews: [
        Crew(id: "preview", name: "Roommates", day: dayString(for: Date(), zone: .current),
             zone: TimeZone.current.identifier, members: [
                Member(id: "a", name: "Sam", face: nil, wins: [.init(tier: 2, hex: "0EAD74"), .init(tier: 1, hex: "40A9FF")]),
                Member(id: "b", name: "Ana", face: nil, wins: [.init(tier: 3, hex: "AF9CFA")]),
                Member(id: "c", name: "Leo", face: nil, wins: []),
                Member(id: "d", name: "Mia", face: nil, wins: [.init(tier: 1, hex: "FF8A5B")])
             ])
    ], updated: Date())
}
