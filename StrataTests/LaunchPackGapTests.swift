import Foundation
import Testing
@testable import Strata

/// What the owner's Launch Pack asked for and the first pass left out,
/// found when he asked for it to be checked against the doc (2026-10-13):
/// the day's own line, the empty tower's lines, the crew's evening, the
/// recap's gift line, and a crew plan said as done.
@Suite("Launch Pack: what the first pass left out")
struct LaunchPackGapTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private func day(_ key: String) -> Date { DateUtils.date(from: key)!.addingTimeInterval(12 * 3600) }
    private func pick(_ counts: [String: Int], first: String = "2026-08-01", today: String = "2026-10-11") -> DayNote.Note? {
        DayNote.pick(counts: counts, firstDay: first, today: day(today), calendar: calendar, weekday: { _ in "Sunday" })
    }

    @Test("the best of its weekday in three weeks is said, with the number held for the app")
    func bestWeekday() {
        // Eight today; three and five the two Sundays before; nine the one before those.
        let note = pick(["2026-10-11": 8, "2026-10-04": 3, "2026-09-27": 5, "2026-09-20": 9])
        #expect(note?.outside == "Your best Sunday in three weeks.")
        #expect(note?.headline == "Eight wins today.")
        #expect(note?.detail == "Your best Sunday in three weeks."
                || note?.detail == "Your best Sunday in three weeks. Good one to look back on.")
        #expect(note?.day == "2026-10-11")
        // The count runs back while each Sunday had wins and fewer of them.
        #expect(pick(["2026-10-11": 4, "2026-10-04": 1, "2026-09-27": 2, "2026-09-20": 3, "2026-09-13": 1])?.outside
                == "Your best Sunday in five weeks.")
        // **A Sunday with nothing on it ends the count; it is not one today
        // beat.** Counted, a return after a lapse read "in eleven weeks",
        // which is a count of the gap.
        #expect(pick(["2026-10-11": 4, "2026-09-20": 2]) == nil)
        #expect(pick(["2026-10-11": 4, "2026-10-04": 2, "2026-09-20": 1]) == nil)
    }

    @Test("it is never said of a week before there was anything to beat, or of a small day")
    func onlyWhenTrue() {
        // Installed last Sunday: one week is not "in three weeks".
        #expect(pick(["2026-10-11": 8, "2026-10-04": 3], first: "2026-10-04") == nil)
        // Two wins is not anybody's best.
        #expect(pick(["2026-10-11": 2]) == nil)
        // Matched, not beaten.
        #expect(pick(["2026-10-11": 5, "2026-10-04": 5]) == nil)
        // No win today, no note.
        #expect(pick(["2026-10-10": 9]) == nil)
    }

    @Test("days running are said on the days worth saying, in his words")
    func daysRunning() {
        let three = pick(["2026-10-11": 1, "2026-10-10": 2, "2026-10-09": 1])
        #expect(three?.outside == "Day three. Don't look now.")
        #expect(three?.headline == "Three days running.")
        #expect(three?.detail == "Four wins across them.")
        // Four days is not one of them.
        #expect(pick(["2026-10-11": 1, "2026-10-10": 1, "2026-10-09": 1, "2026-10-08": 1]) == nil)
        #expect(DayNote.days == [3, 7, 14, 30, 50, 100])
        #expect(DayNote.word(12) == "twelve" && DayNote.word(13) == "13")
    }

    @Test("no note raises its voice, asks, counts a gap or says streak")
    func noteVoice() {
        let notes = [pick(["2026-10-11": 8, "2026-10-04": 3, "2026-09-27": 5]),
                     pick(["2026-10-11": 1, "2026-10-10": 2, "2026-10-09": 1])].compactMap { $0 }
        #expect(notes.count == 2)
        for line in notes.flatMap({ [$0.outside, $0.headline, $0.detail] }) + [DayNote.warm, EmptyTower.start, EmptyTower.quiet,
                                                                              CrewEvening.hadADay, ReplayReminder.gift] {
            #expect(!line.contains("!") && !line.contains("?"), "\(line)")
            #expect(!line.contains("\u{2014}") && !line.contains("\u{2013}"), "\(line)")
            #expect(!line.lowercased().contains("streak") && !line.lowercased().contains("missed"), "\(line)")
        }
    }

    @Test("tonight's note is kept for the app, said once, after eight, and only today's")
    func keptAndDue() throws {
        let defaults = try #require(UserDefaults(suiteName: "day-note-\(UUID().uuidString)"))
        let note = try #require(pick(["2026-10-11": 8, "2026-10-04": 3, "2026-09-27": 5]))
        DayNote.keep(note, defaults: defaults)
        #expect(DayNote.kept(today: "2026-10-11", defaults: defaults) == note)
        #expect(DayNote.kept(today: "2026-10-12", defaults: defaults) == nil)
        // In the calendar the day's key is written in, so this holds on a
        // machine in any time zone.
        let local = DateUtils.keyCalendar()
        let evening = local.date(bySettingHour: 20, minute: 30, second: 0, of: day("2026-10-11"))!
        let afternoon = local.date(bySettingHour: 15, minute: 0, second: 0, of: day("2026-10-11"))!
        #expect(DayNote.due(now: afternoon, calendar: local, defaults: defaults) == nil)
        #expect(DayNote.due(now: evening, calendar: local, defaults: defaults) == note)
        DayNote.markShown(note, defaults: defaults)
        #expect(DayNote.due(now: evening, calendar: local, defaults: defaults) == nil)
        DayNote.keep(nil, defaults: defaults)
        #expect(DayNote.kept(today: "2026-10-11", defaults: defaults) == nil)
    }

    @Test("the note takes the evening's one quiet slot and lands on Wins")
    func noteSlot() throws {
        let id = NotificationRoute.Prefix.pastWin + "2026-10-11"
        #expect(NotificationRoute.of(identifier: id, userInfo: [NotificationRoute.noteKey: "2026-10-11"]) == .wins)
        #expect(NotificationRoute.of(identifier: id, userInfo: [NotificationRoute.dayKey: "2025-10-11"]) == .memoriesDay("2025-10-11"))
        let past = SourceSweep.code(try SourceSweep.read("Strata/Services/PastWin.swift"))
        // One evening line: the past win is picked only when there is no note.
        #expect(past.contains("let pick = note == nil && !Self.pastDaysOff(in: RemovedAlbums.all())"))
        #expect(past.contains("content.title = note.outside"))
        #expect(past.components(separatedBy: "content.interruptionLevel = .passive").count == 3)
    }

    @Test("the empty tower teaches someone new, then says his line, and meets a return without counting it")
    func emptyTower() {
        #expect(EmptyTower.line(total: 0, lastWinDay: nil, today: "2026-10-13") == EmptyTower.teach)
        #expect(EmptyTower.line(total: 4, lastWinDay: "2026-10-01", today: "2026-10-13") == EmptyTower.teach)
        #expect(EmptyTower.line(total: 5, lastWinDay: "2026-10-12", today: "2026-10-13") == "Nothing logged yet. Just the start of the day.")
        #expect(EmptyTower.line(total: 40, lastWinDay: "2026-10-11", today: "2026-10-13") == EmptyTower.start)
        #expect(EmptyTower.line(total: 40, lastWinDay: "2026-10-10", today: "2026-10-13") == "You've been quiet a few days. No rush.")
        // The return's line holds no number.
        #expect(EmptyTower.quiet.rangeOfCharacter(from: .decimalDigits) == nil)
        let main = SourceSweep.code((try? SourceSweep.read("Strata/Views/MainAppView.swift")) ?? "")
        #expect(main.contains("Text(emptyTowerLine)"))
        // In the app only: no notification says it.
        for path in ["Strata/Services/DailyReminder.swift", "Strata/Services/PastWin.swift", "Strata/Services/ReplayReminder.swift"] {
            #expect(!SourceSweep.code((try? SourceSweep.read(path)) ?? "").contains("EmptyTower"))
        }
    }

    @Test("the crew's evening says the crew had a day only once it has")
    func crewEvening() {
        #expect(CrewEvening.line(othersToday: 0) == "Your crew's tower is open too.")
        #expect(CrewEvening.line(othersToday: 2) == CrewEvening.line)
        #expect(CrewEvening.line(othersToday: 3) == "Your crew had a day.")
    }

    @Test("the month's recap is a gift and says so; the week's says nothing more")
    func recapGift() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
        let up = ReplayReminder.upcoming(now: now, calendar: calendar) { _ in true }
        #expect(up.first { $0.title == "September, put together." }?.body == "We made this for you.")
        #expect(up.first { $0.title == "Your week, put together." }?.body == "")
    }

    @Test("a crew's plan, done, is said as done, in the app and in the extension")
    func planDone() {
        let cache = CrewNoteCache(me: "me-id", crews: [
            "crew-1": .init(title: "Roommates", zoneName: "crew-x", zoneOwner: "o", joined: true,
                            members: ["sam": .init(profileID: "p", name: "Sam")], myWins: [:], plans: ["workout"]),
        ])
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w", title: "Workout", emoji: nil)
                == ("Roommates", "Sam just did Workout"))
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w", title: "Morning run", emoji: nil)
                == ("Roommates", "Sam added Morning run"))
        // Tagged still says tagged: that one is a question waiting.
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w", title: "Workout", emoji: nil, tagsMe: true).body
                == "Sam added you to Workout")
        // A cache from before plans reads as it did.
        let old = #"{"me":"m","crews":{"c":{"title":"T","zoneName":"z","zoneOwner":"o","joined":true,"members":{},"myWins":{}}}}"#
        let decoded = try? JSONDecoder().decode(CrewNoteCache.self, from: Data(old.utf8))
        #expect(decoded?.crews["c"]?.plans == nil)
        // The key is the one the app tells a plan and its win apart by.
        for title in ["Workout", "  Morning   Run ", "Café run", "Gym!", "🏃"] {
            #expect(CrewNoteCache.planKey(title) == GroupPlan.key(title), "\(title)")
        }
        let sam = UUID(), me = UUID()
        let crew = Crew(id: CrewID(rawValue: "crew-1"), name: "Roommates", ownerProfileID: me, timeZoneIdentifier: "UTC",
                        createdAt: .now, photo: nil,
                        members: [CrewMember(profileID: me, firstName: "Jayden", head: nil, joinedAt: .distantPast),
                                  CrewMember(profileID: sam, firstName: "Sam", head: nil, joinedAt: .now)])
        let win = SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: sam, crewDay: "2026-10-13", title: "Workout",
                            colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                            createdAt: .now, updatedAt: .now)
        #expect(CrewNotifications.Text.of(win, in: crew, me: me, plans: ["workout"]).body == "Sam just did Workout")
        #expect(CrewNotifications.Text.of(win, in: crew, me: me).body == "Sam added Workout")
    }
}
