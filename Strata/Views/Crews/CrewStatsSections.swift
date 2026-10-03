import SwiftUI

/// A crew's numbers, worked out once each time what they are made of
/// changes, never per frame: a crew's whole history is walked once here, and
/// the sheet's redraws read the result.
struct CrewStats: Equatable {
    var current = 0
    var best = 0
    /// Who has not posted a win today, so the streak can be kept.
    var waiting: [CrewMember] = []
    var people = 0
    var bars: [WinTrend.Unit: [WinTrend.Bar]] = [:]
    var summaries: [WinTrend.Unit: WinTrend.Summary] = [:]
    /// The days the crew still holds, newest first: the ones that can be
    /// saved as a video.
    var days: [HeldDay] = []

    struct HeldDay: Identifiable, Equatable {
        let key: String
        let count: Int
        var id: String { key }
    }

    /// What the numbers are made of, compared before anything is counted.
    struct Inputs: Equatable {
        var history: CrewHistory
        var wins: [SharedWin]
        var members: [CrewMember]
        var zone: TimeZone
        var today: String
    }

    static func make(_ inputs: Inputs) -> CrewStats {
        var history = inputs.history
        // Today's wins arrive before the next refresh counts them: counted
        // here as well, so a win you just sent moves the numbers at once.
        if let cutoff = CrewDay.day(inputs.today, offsetBy: -3, in: inputs.zone) {
            history.record(inputs.wins, from: cutoff, through: inputs.today)
        }
        let full = history.fullDays(members: inputs.members, zone: inputs.zone)
        var stats = CrewStats()
        stats.current = CrewHistory.streak(full, today: inputs.today, zone: inputs.zone)
        stats.best = max(CrewHistory.best(full, zone: inputs.zone), stats.current)
        stats.waiting = history.waiting(today: inputs.today, members: inputs.members)
        stats.people = inputs.members.count
        let totals = history.totals
        for unit in WinTrend.Unit.allCases {
            stats.bars[unit] = WinTrend.bars(dayCounts: totals, unit: unit)
            stats.summaries[unit] = WinTrend.summary(dayCounts: totals, unit: unit)
        }
        let byDay = Dictionary(grouping: inputs.wins, by: \.crewDay)
        stats.days = byDay.keys.sorted(by: >).map { HeldDay(key: $0, count: byDay[$0]?.count ?? 0) }
        return stats
    }
}

/// The middle of a crew's page: the streak you keep together, the crew's
/// wins over time, and its days, each one a video to keep.
///
/// The same streak and the same chart as Profile (`StreakFigure`,
/// `WinTrendSection`), so a crew's numbers read the way yours do.
struct CrewStatsSections: View {
    let crew: Crew
    /// A day to play. Presented by the page, never from in here: these are
    /// a List's sections, and a cover hung on them was copied onto every
    /// section by `Group` and torn down with a cell, so a day's video opened
    /// and closed at once (the owner, 2026-10-02: "it closes immediately").
    let play: (Replay) -> Void

    @State private var stats = CrewStats()
    @AppStorage("crewChartUnit") private var unitRaw = WinTrend.Unit.week.rawValue

    private var store: SocialStore { SocialStore.shared }

    private var inputs: CrewStats.Inputs {
        CrewStats.Inputs(history: store.history[crew.id] ?? CrewHistory(),
                         wins: store.wins(in: crew.id).filter { !store.blocked.contains($0.senderProfileID) },
                         members: crew.members,
                         zone: crew.timeZone,
                         today: CrewDay.string(for: Date(), in: crew.timeZone))
    }

    var body: some View {
        // **The work hangs on ONE section.** A modifier on a `Group` is
        // applied to each of its children, so this ran three times a change.
        streak
            .task(id: inputs) {
                stats = CrewStats.make(inputs)
                #if DEBUG
                // `-strataCrewDayReplay 1`: the newest day plays, so it can be filmed.
                if DebugHarness.argument("-strataCrewDayReplay") == "1", !debugPlayed, let day = stats.days.first {
                    debugPlayed = true
                    playDay(day.key)
                }
                #endif
            }
        WinTrendSection(bars: stats.bars, summaries: stats.summaries, unitRaw: $unitRaw, owner: .crew)
        if !stats.days.isEmpty { days }
    }

    #if DEBUG
    @State private var debugPlayed = false
    #endif

    // MARK: - Streak

    /// Days in a row that everyone posted a win. Best beside it, as on
    /// Profile, so a break never looks like the record was lost.
    private var streak: some View {
        Section {
            HStack(alignment: .top, spacing: GridConstants.gapWide) {
                StreakFigure(value: stats.current, label: "Current")
                StreakFigure(value: stats.best, label: "Best")
            }
            .padding(.vertical, GridConstants.gapTight)
        } header: {
            FormSectionLabel("Crew Streak")
        } footer: {
            Text(streakLine).formFooter()
        }
        .listRowSeparator(.hidden)
    }

    /// What keeps the streak going today, in a few words. Never a scolding:
    /// a name is an invitation.
    private var streakLine: String {
        if stats.people > 1, stats.waiting.isEmpty { return "Everyone's in today." }
        // Nobody yet, as at the start of a day: one line for the crew, not a
        // roll call of every name.
        if stats.people > 1, stats.waiting.count == stats.people {
            return stats.current > 0 ? "A new day. Everyone's win keeps it going." : "A day counts when everyone posts a win."
        }
        let names = stats.waiting.map { $0.profileID == store.me ? "you" : ($0.firstName.isEmpty ? "a friend" : $0.firstName) }
        guard !names.isEmpty else { return "A day counts when everyone posts a win." }
        let list = names.formatted(.list(type: .and))
        return stats.current > 0 ? "Waiting on \(list) today." : "A day counts when everyone posts a win. Waiting on \(list)."
    }

    // MARK: - Days

    /// The days the crew still holds. A crew's photos leave it after a few
    /// days, so this is where a day is kept: played, and saved as a video.
    private var days: some View {
        Section {
            ForEach(stats.days) { day in
                Button { playDay(day.key) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayName(day.key))
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text("\(day.count) \(day.count == 1 ? "win" : "wins")")
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle")
                            .font(Typography.headerMedium)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressSurface)
                .accessibilityLabel("\(dayName(day.key)), \(day.count) \(day.count == 1 ? "win" : "wins")")
                .accessibilityHint("Plays the day. You can save it as a video.")
            }
        } header: {
            FormSectionLabel("Days")
        } footer: {
            Text("A crew's photos stay for a few days. Play a day to save it as a video.")
                .formFooter()
        }
        .listRowSeparator(.hidden)
    }

    private func dayName(_ key: String) -> String {
        let today = CrewDay.string(for: Date(), in: crew.timeZone)
        if key == today { return "Today" }
        if CrewDay.day(today, offsetBy: -1, in: crew.timeZone) == key { return "Yesterday" }
        guard let start = CrewDay.start(of: key, in: crew.timeZone) else { return key }
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.abbreviated).day()
        style.timeZone = crew.timeZone
        return start.formatted(style)
    }

    private func playDay(_ key: String) {
        guard let period = ReplayPeriod.day(key, name: crew.displayName(excluding: store.me),
                                            calendar: Self.calendar(crew.timeZone)) else { return }
        let wins = store.wins(in: crew.id)
            .filter { $0.crewDay == key && !store.blocked.contains($0.senderProfileID) }
            .map { win in
                ReplayWin(id: win.winID, dateString: win.crewDay, completedAt: win.createdAt,
                          title: win.title, category: win.colour, size: win.blockSize,
                          photo: win.photo.map { .file($0.path) },
                          crop: CGPoint(x: win.cropX ?? 0, y: win.cropY ?? 0))
            }
        HapticsEngine.tick()
        play(Replay(period: period, wins: wins))
    }

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }
}
