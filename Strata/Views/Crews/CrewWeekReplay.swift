import Foundation

/// **A crew's week, put together** (the owner, 2026-10-14, choosing the crew
/// replay from a brainstorm). The replay engine that films your own tower,
/// run on everyone's wins in a crew.
///
/// The Days section of a crew's info sheet has offered This Week and Last
/// Week since 2026-10-13, where nobody looks on a Sunday. The crew tower now
/// offers the week as your own replay is offered: from Sunday at five until
/// Tuesday starts (`ReplayPeriod.windowOpens`), once, as a card under the
/// header.
@MainActor
enum CrewWeekReplay {
    /// A crew's wins over `days`, oldest first, as the replay takes them.
    static func wins(on days: [String], in crewID: CrewID, store: SocialStore = .shared) -> [ReplayWin] {
        days.flatMap { store.wins(in: crewID, on: $0) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { win in
                ReplayWin(id: win.winID, dateString: win.crewDay, completedAt: win.createdAt,
                          title: win.title, category: win.colour, size: win.blockSize,
                          photo: win.photo.map { .file($0.path) },
                          crop: CGPoint(x: win.cropX ?? 0, y: win.cropY ?? 0))
            }
    }

    /// The week whose window is open now in the crew's zone, if anyone in
    /// the crew logged in it.
    static func live(in crewID: CrewID, store: SocialStore = .shared) -> Replay? {
        guard let crew = store.crew(crewID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = crew.timeZone
        #if DEBUG
        var current = ReplayPeriod.current(.week, at: store.now(), calendar: calendar)
        // `-strataCrewWeek`: this week, whatever the day, for screenshots.
        if DebugHarness.argument("-strataCrewWeek") != nil {
            current = ReplayPeriod.week(containing: store.now(), calendar: calendar)
        }
        #else
        let current = ReplayPeriod.current(.week, at: store.now(), calendar: calendar)
        #endif
        guard var period = current else { return nil }
        period.name = crew.displayName(excluding: store.me)
        let wins = wins(on: period.days, in: crewID, store: store)
        return wins.isEmpty ? nil : Replay(period: period, wins: wins)
    }

    /// Whether the card for this crew's week was already shown and put away.
    static func wasShown(_ replay: Replay, in crewID: CrewID) -> Bool {
        (UserDefaults.standard.stringArray(forKey: shownKey) ?? []).contains(key(replay, crewID))
    }

    static func markShown(_ replay: Replay, in crewID: CrewID) {
        let shown = UserDefaults.standard.stringArray(forKey: shownKey) ?? []
        guard !shown.contains(key(replay, crewID)) else { return }
        // The last few dozen, so the list never grows for good.
        UserDefaults.standard.set(Array((shown + [key(replay, crewID)]).suffix(40)), forKey: shownKey)
    }

    private static let shownKey = "crews.weekReplayShown"
    private static func key(_ replay: Replay, _ crewID: CrewID) -> String { "\(crewID.rawValue)/\(replay.period.id)" }
}
