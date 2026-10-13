import SwiftData
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

    /// **What the streak needs today, and never WHO** (the owner,
    /// 2026-10-05, the ADHD positioning).
    ///
    /// It said "Waiting on Leo today." A name under a streak is a roll call:
    /// it tells the whole crew who is holding them up, and it tells Leo,
    /// who opened the app to see his friends' wins, that he is the problem.
    /// That is the opposite of what a crew is for here, so nobody who has
    /// not posted is ever named, anywhere: not here, not in a notification,
    /// not on the tower. One line when the day is complete, and the rule
    /// itself otherwise. The waiting list is still counted (`waiting`); only
    /// its emptiness is ever said out loud.
    ///
    /// **Milestones are celebrated, a break is a fresh start** (the
    /// unification pass, 2026-10-09: "look what your crew is building, 14
    /// days", never a threat of loss). On a milestone day the line says what
    /// the crew built; after a run has ended it says the best still stands.
    static let milestones = CrewPingRecord.milestones

    static func streakLine(people: Int, waiting: Int, current: Int = 0, best: Int = 0) -> String {
        if milestones.contains(current) { return "Look what your crew is building. \(current) days." }
        // The rule says rest days are free, so a quiet day reads as allowed
        // rather than as a streak quietly at risk (`Streaks.Rest`).
        // **Two people and eight both read right** (the owner's Launch
        // Pack, 2026-10-12: "a crew of two is complete"). "Everyone" said to
        // a pair means the other one.
        if people > 1 && waiting == 0 { return people == 2 ? "You're both in today." : "Everyone's in today." }
        // Said plainly: it had "Nice work, crew." after it, which is praise
        // the day had not asked for (`docs/voice.md`).
        if people > 1 && people - waiting >= CrewHistory.needed(of: people) { return "Today counts." }
        if current == 0 && best >= 7 { return "Starting fresh. Your best is still \(best)." }
        let who = switch people {
        case ...1: "you send"
        case 2: "either of you sends"
        default: "half the crew sends"
        }
        return "A day counts when \(who) a win. Two days off a week are fine."
    }

    /// The crew's current streak alone, for its row in the list (the flame).
    ///
    /// **Worked out when its inputs change, not on every redraw** (found
    /// 2026-10-10 by review): the list asks per row per render, and each ask
    /// rebuilt the crew's history and walked its days.
    @MainActor
    static func current(for crew: Crew, store: SocialStore = .shared) -> Int {
        let today = CrewDay.string(for: Date(), in: crew.timeZone)
        let wins = store.wins(in: crew.id).filter { !store.blocked.contains($0.senderProfileID) }
        let stored = store.history[crew.id] ?? CrewHistory()
        var hasher = Hasher()
        hasher.combine(today)
        hasher.combine(stored.days)
        hasher.combine(wins.map(\.winID))
        hasher.combine(crew.members.map(\.profileID))
        let key = hasher.finalize()
        if let hit = streakMemo[crew.id], hit.key == key { return hit.value }
        var history = stored
        if let cutoff = CrewDay.oldestKept(today: today, in: crew.timeZone) {
            history.record(wins, from: cutoff, rewritingFrom: CrewHistory.rewriteFrom(today, in: crew.timeZone), through: today)
        }
        let value = CrewHistory.streak(history.keptDays(members: crew.members, zone: crew.timeZone), today: today, zone: crew.timeZone)
        streakMemo[crew.id] = (key, value)
        return value
    }

    @MainActor private static var streakMemo: [CrewID: (key: Int, value: Int)] = [:]

    /// The milestone the crew reached TODAY, or nil: today is a kept day
    /// (half the crew has posted) and the streak it makes is one of
    /// `milestones`. What the crew is told about, once (`SocialStore
    /// .pingMilestone`).
    @MainActor
    static func milestoneToday(for crew: Crew, store: SocialStore = .shared) -> Int? {
        let today = CrewDay.string(for: store.now(), in: crew.timeZone)
        var history = store.history[crew.id] ?? CrewHistory()
        if let cutoff = CrewDay.oldestKept(today: today, in: crew.timeZone) {
            let wins = store.wins(in: crew.id).filter { !store.blocked.contains($0.senderProfileID) }
            history.record(wins, from: cutoff, rewritingFrom: CrewHistory.rewriteFrom(today, in: crew.timeZone), through: today)
        }
        let kept = history.keptDays(members: crew.members, zone: crew.timeZone)
        guard kept.contains(today) else { return nil }
        let streak = CrewHistory.streak(kept, today: today, zone: crew.timeZone)
        guard milestones.contains(streak) else { return nil }
        // **Only a phone that has seen the whole streak says its number**
        // (found by review, 2026-10-10). The count is each phone's own: one
        // that joined last week, or was set up again, holds two weeks at
        // most, and would have told a crew on day forty that it had reached
        // seven. So this phone's record must reach back to the crew's first
        // day, or past the day the streak began. Otherwise it says nothing
        // and a phone that knows does.
        let first = crew.members.map(\.joinedAt).min().map { CrewDay.string(for: $0, in: crew.timeZone) } ?? today
        guard knowsWholeStreak(streak, earliest: history.days.keys.min(), crewBegan: first, today: today,
                               zone: crew.timeZone) else { return nil }
        return streak
    }

    /// Whether a phone whose record of a crew begins on `earliest` can vouch
    /// for a streak of `streak` days ending `today`: the record reaches the
    /// crew's first day, or a few days past where the streak began.
    nonisolated static func knowsWholeStreak(_ streak: Int, earliest: String?, crewBegan: String, today: String,
                                             zone: TimeZone) -> Bool {
        guard let earliest else { return false }
        let before = CrewDay.day(today, offsetBy: -(streak + 3), in: zone) ?? ""
        return earliest <= crewBegan || earliest <= before
    }

    static func make(_ inputs: Inputs) -> CrewStats {
        var history = inputs.history
        // Today's wins arrive before the next refresh counts them: counted
        // here as well, so a win you just sent moves the numbers at once.
        if let cutoff = CrewDay.oldestKept(today: inputs.today, in: inputs.zone) {
            history.record(inputs.wins, from: cutoff,
                           rewritingFrom: CrewHistory.rewriteFrom(inputs.today, in: inputs.zone), through: inputs.today)
        }
        let full = history.keptDays(members: inputs.members, zone: inputs.zone)
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
    @State private var keptPhotos = 0
    @Environment(\.modelContext) private var modelContext
    @AppStorage("crewChartUnit") private var unitRaw = WinTrend.Unit.week.rawValue

    private var store: SocialStore { SocialStore.shared }

    private var inputs: CrewStats.Inputs {
        CrewStats.Inputs(history: store.history[crew.id] ?? CrewHistory(),
                         wins: store.wins(in: crew.id).filter { !store.blocked.contains($0.senderProfileID) && !store.hiddenWins.contains($0.winID) },
                         members: crew.members,
                         zone: crew.timeZone,
                         today: CrewDay.string(for: Date(), in: crew.timeZone))
    }

    /// How many of your photographs this crew holds, counted once when the
    /// sheet opens: the crew's inputs change every few seconds during a
    /// sync, and this is a fetch of every photographed win.
    private func countKept() async {
        #if DEBUG
        await store.debugMarkSentIfAsked(context: modelContext)
        #endif
        let sent = store.winsSent(to: crew.id)
        keptPhotos = sent.isEmpty ? 0 : ((try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.imageFileName != nil }))) ?? []).filter { sent.contains($0.id) }.count
    }

    var body: some View {
        // **The work hangs on ONE section.** A modifier on a `Group` is
        // applied to each of its children, so this ran three times a change.
        streak
            .task(id: crew.id) { await countKept() }
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

    private var streakLine: String {
        CrewStats.streakLine(people: stats.people, waiting: stats.waiting.count, current: stats.current, best: stats.best)
    }

    // MARK: - Days

    /// **Recent Days**: the two weeks a crew holds. A row opens the day
    /// itself, its tower and its photographs (`CrewDayView`); the video is in
    /// that page's corner. It used to play straight away, when a crew held
    /// only a couple of days and the video was the only way to keep one.
    private var days: some View {
        Section {
            // **The crew's week, put together** (the owner's Launch Pack,
            // 2026-10-12: "consider a crew weekly or monthly recap"). The
            // replay the app already makes of your own week, of the wins
            // this crew holds: this week so far, and last week, which is
            // always whole inside the two weeks a crew keeps. Asked for,
            // never announced: nothing new is sent to anyone.
            ForEach(weeks) { week in
                Button {
                    playWeek(week.period)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(week.title)
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text("\(week.count) \(week.count == 1 ? "win" : "wins")")
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "play")
                            .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .regular)
                            .foregroundStyle(AppColors.inkSecondary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(week.title), \(week.count) \(week.count == 1 ? "win" : "wins")")
                .accessibilityHint("Plays the week")
            }
            ForEach(stats.days) { day in
                NavigationLink {
                    CrewDayView(crew: crew, day: day.key, title: dayName(day.key),
                                header: DayTitle.twoTone(forKey: day.key, calendar: Self.calendar(crew.timeZone))) {
                        playDay(day.key)
                    }
                } label: {
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
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(dayName(day.key)), \(day.count) \(day.count == 1 ? "win" : "wins")")
            }
            // **The other side of "two weeks"** (unification, 2026-10-09):
            // the crew forgets, Memories keeps. Your own photographs sent
            // here, all of them, as Memories' crew album.
            if keptPhotos > 0 {
                NavigationLink {
                    PhotoCollectionView(source: .crew(crew.id.rawValue))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kept in Memories")
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("\(keptPhotos) of your \(keptPhotos == 1 ? "photo" : "photos")")
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
        } header: {
            FormSectionLabel("Recent Days")
        } footer: {
            Text("Wins stay for two weeks. Play a day or a week to save it as a video.")
                .formFooter()
        }
        .listRowSeparator(.hidden)
    }

    /// The day's name, in the crew's zone: `DayTitle`, so "Sunday 4 October"
    /// here is the same words as on your own past day. It was "Sunday, Oct 4"
    /// until the cohesion pass (2026-10-05). It is also the crew day page's
    /// title, which is handed this.
    private func dayName(_ key: String) -> String {
        DayTitle.title(forKey: key, calendar: Self.calendar(crew.timeZone))
    }

    /// A week of the crew's, as the Days section offers it.
    struct Week: Identifiable, Equatable {
        let title: String
        let period: ReplayPeriod
        let count: Int
        var id: String { period.id }
    }

    /// This week and last week, each only when the crew has a win in it.
    static func weeks(days: [CrewStats.HeldDay], today: Date, calendar: Calendar, name: String) -> [Week] {
        var this = ReplayPeriod.week(containing: today, calendar: calendar)
        var last = ReplayPeriod.week(containing: calendar.date(byAdding: .day, value: -1, to: this.firstDay) ?? today,
                                     calendar: calendar)
        // **This week ends today** (found by review, 2026-10-13): days
        // still to come played as empty days, a few seconds of nothing at
        // the end of the replay and of the saved video.
        let todayKey = ReplayPeriod.key(today, calendar: calendar)
        this = ReplayPeriod(kind: .week, days: this.days.filter { $0 <= todayKey }, firstDay: this.firstDay,
                            calendar: calendar, name: name)
        last.name = name
        let counts = Dictionary(days.map { ($0.key, $0.count) }, uniquingKeysWith: +)
        return [("This Week", this), ("Last Week", last)].compactMap { title, period in
            let count = period.days.reduce(0) { $0 + (counts[$1] ?? 0) }
            return count > 0 ? Week(title: title, period: period, count: count) : nil
        }
    }

    private var weeks: [Week] {
        Self.weeks(days: stats.days, today: store.now(), calendar: Self.calendar(crew.timeZone),
                   name: crew.displayName(excluding: store.me))
    }

    private func playWeek(_ period: ReplayPeriod) {
        let wins = period.days.flatMap { store.wins(in: crew.id, on: $0) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { win in
                ReplayWin(id: win.winID, dateString: win.crewDay, completedAt: win.createdAt,
                          title: win.title, category: win.colour, size: win.blockSize,
                          photo: win.photo.map { .file($0.path) },
                          crop: CGPoint(x: win.cropX ?? 0, y: win.cropY ?? 0))
            }
        guard !wins.isEmpty else { return }
        HapticsEngine.tick()
        play(Replay(period: period, wins: wins))
    }

    private func playDay(_ key: String) {
        guard let period = ReplayPeriod.day(key, name: crew.displayName(excluding: store.me),
                                            calendar: Self.calendar(crew.timeZone)) else { return }
        let wins = store.wins(in: crew.id, on: key)
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
