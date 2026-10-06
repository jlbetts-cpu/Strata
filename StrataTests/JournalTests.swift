import Testing
import Foundation
import SwiftData
@testable import Strata

/// **The day's journal** (`docs/superpowers/specs/2026-10-05-shared-wins-journal-doodles-design.md`,
/// section 2): one `MoodLog` a day, an emoji over a dead column, one question
/// that never writes, and a lock that asks once.
@MainActor
@Suite("Journal")
struct JournalTests {

    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    // MARK: - Storage

    @Test("the emoji and the sketch live in the two dead columns, and empty is none")
    func accessorsReadTheDeadColumns() {
        let entry = MoodLog(dateString: "2026-10-05", mood: 3, motivation: 3)
        #expect(entry.symbol == nil)
        #expect(!entry.hasContent)
        entry.symbol = "🌊"
        #expect(entry.videoURL == "🌊")
        #expect(entry.hasContent)
        entry.symbol = ""
        #expect(entry.videoURL == nil, "an empty symbol must not leave a blank badge")
        entry.sketchFileName = "sketch-1.png"
        #expect(entry.imageURL == "sketch-1.png")
        #expect(entry.sketchFileName == "sketch-1.png")
        entry.sketchFileName = nil
        entry.note = "   \n"
        #expect(!entry.hasContent, "whitespace is not a note")
    }

    @Test("one entry a day: saving twice updates the same row")
    func oneEntryPerDay() throws {
        let ctx = try context()
        #expect(DayNotes.entry(for: "2026-10-05", context: ctx) == nil)
        DayNotes.save(note: "Long walk", symbol: nil, for: "2026-10-05", context: ctx)
        DayNotes.save(note: "Long walk by the river", symbol: "🌊", for: "2026-10-05", context: ctx)
        let all = try ctx.fetch(FetchDescriptor<MoodLog>())
        #expect(all.count == 1)
        #expect(all.first?.note == "Long walk by the river")
        #expect(all.first?.symbol == "🌊")
        #expect(DayNotes.hasNote(on: "2026-10-05", context: ctx))
        #expect(!DayNotes.hasNote(on: "2026-10-04", context: ctx))
    }

    @Test("opening a day and writing nothing makes no row")
    func nothingWrittenIsNothingStored() throws {
        let ctx = try context()
        DayNotes.save(note: "  ", symbol: nil, for: "2026-10-05", context: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<MoodLog>()) == 0)
    }

    @Test("get-or-create returns the existing row, and makes one only once")
    func getOrCreate() throws {
        let ctx = try context()
        let first = DayNotes.entryOrNew(for: "2026-10-05", context: ctx)
        let second = DayNotes.entryOrNew(for: "2026-10-05", context: ctx)
        #expect(first.id == second.id)
        #expect(try ctx.fetchCount(FetchDescriptor<MoodLog>()) == 1)
    }

    @Test("a month's emoji come back keyed by day, and only that month's")
    func monthSymbols() throws {
        let ctx = try context()
        DayNotes.save(note: nil, symbol: "🌊", for: "2026-10-05", context: ctx)
        DayNotes.save(note: "words only", symbol: nil, for: "2026-10-06", context: ctx)
        DayNotes.save(note: nil, symbol: "🎂", for: "2026-09-30", context: ctx)
        let map = DayNotes.symbols(from: "2026-10-01", to: "2026-11-01", context: ctx)
        #expect(map == ["2026-10-05": "🌊"])
    }

    @Test("the Memories month carries its emoji")
    func memoriesModelCarriesSymbols() throws {
        let ctx = try context()
        let today = DateUtils.dateString(from: Date())
        DayNotes.save(note: nil, symbol: "🔥", for: today, context: ctx)
        let vm = MemoriesViewModel()
        vm.select(month: Date(), context: ctx)
        #expect(vm.symbols[today] == "🔥")
        // Changed from the day's page: the month picks it up on refresh.
        DayNotes.save(note: nil, symbol: "🌙", for: today, context: ctx)
        vm.refreshSymbols(context: ctx)
        #expect(vm.symbols[today] == "🌙")
    }

    @Test("a calendar cell knows its own date")
    func calendarDayKey() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        #expect(MonthCalendarView.dateString(day: 5, in: october, calendar: calendar) == "2026-10-05")
        #expect(MonthCalendarView.dateString(day: 31, in: october, calendar: calendar) == "2026-10-31")
    }

    @Test("the journal's glyph is one constant, and hollow")
    func hollowGlyph() {
        // The owner, 2026-10-05: hollow, never filled, on Wins and on a past
        // day alike, and his pick is `text.alignleft`, to sit with the Plan's
        // `checklist`.
        #expect(!JournalIcon.name.hasSuffix(".fill"))
        #expect(JournalIcon.name == "text.alignleft")
    }

    // MARK: - The question

    @Test("the fixed list is the owner's four, in the 5 Minute Journal style")
    func fallbackList() {
        #expect(JournalQuestionRules.fallback == [
            "What made today good?", "What are you glad you did?",
            "What would you do again?", "Who made today better?",
        ])
        // A past day is not "today".
        #expect(JournalQuestionRules.fallback(isToday: false).allSatisfy { !$0.contains("today") })
        // And it moves on rather than asking the same thing twice.
        #expect(JournalQuestionRules.fallbackQuestion(after: ["What made today good?"], isToday: true)
                == "What are you glad you did?")
        #expect(JournalQuestionRules.fallbackQuestion(after: JournalQuestionRules.fallback, isToday: true)
                == "What made today good?", "after all four it starts again")
    }

    @Test("a question is cut at its first question mark: no answer text")
    func noAnswerText() {
        let wins = ["Morning run"]
        #expect(JournalQuestionRules.clean("What made the run happen? The cool air helped.", wins: wins)
                == "What made the run happen?")
        #expect(JournalQuestionRules.clean("What made the run happen?? Really?", wins: wins)
                == "What made the run happen?")
        #expect(JournalQuestionRules.clean("What made the run happen?\nBecause you went early.", wins: wins)
                == "What made the run happen?")
    }

    @Test("a question is a question, at most twelve words")
    func lengthAndShape() {
        let wins = ["Morning run"]
        #expect(JournalQuestionRules.clean("Tell me about the run.", wins: wins) == nil,
                "no question mark, no question")
        let fourteen = "What was it about the morning that made the run feel so very easy?"
        #expect(fourteen.split(separator: " ").count == 14)
        #expect(JournalQuestionRules.clean(fourteen, wins: wins) == nil, "too long is refused, never cut")
        let twelve = "What about this morning made the run feel easy for you today?"
        #expect(twelve.split(separator: " ").count == 12)
        #expect(JournalQuestionRules.clean(twelve, wins: wins) == twelve)
        #expect(JournalQuestionRules.clean("Run?", wins: wins) == nil, "too bare to answer")
    }

    @Test("a question is tidied: no quotes, numbers, bullets or emoji, a capital to start")
    func tidied() {
        let wins = ["Morning run"]
        #expect(JournalQuestionRules.clean("\"what made the run happen?\" 🏃", wins: wins)
                == "What made the run happen?")
        #expect(JournalQuestionRules.clean("1. What made the run happen?", wins: wins)
                == "What made the run happen?")
        #expect(JournalQuestionRules.clean("- What made the 🏃 run happen?", wins: wins)
                == "What made the run happen?")
    }

    @Test("a question asks about one of the day's actual wins")
    func namesAWin() {
        let wins = ["Morning run", "Called Grandma"]
        #expect(JournalQuestionRules.clean("What are you grateful for?", wins: wins) == nil)
        #expect(JournalQuestionRules.clean("What did Grandma say?", wins: wins) == "What did Grandma say?")
        #expect(JournalQuestionRules.clean("What got you running this morning?", wins: wins)
                == "What got you running this morning?")
    }

    @Test("no wins, no model, a failure or a bad answer: the fixed list")
    func fallsBack() async {
        struct Broken: JournalQuestioner {
            func ask(_ context: JournalQuestionContext) async throws -> String {
                throw CancellationError()
            }
        }
        let noWins = JournalQuestionContext(wins: [], alreadyAsked: [], isToday: true)
        #expect(JournalQuestionRules.fallback.contains(
            await JournalQuestions.next(noWins, using: FixedJournalQuestioner())))
        let withWins = JournalQuestionContext(wins: ["Morning run"], alreadyAsked: [], isToday: true)
        #expect(JournalQuestionRules.fallback.contains(await JournalQuestions.next(withWins, using: nil)))
        #expect(JournalQuestionRules.fallback.contains(await JournalQuestions.next(withWins, using: Broken())))
        let rambling = FixedJournalQuestioner(answers: ["Your run was great and you should feel proud."])
        #expect(JournalQuestionRules.fallback.contains(await JournalQuestions.next(withWins, using: rambling)))
        let good = FixedJournalQuestioner(answers: ["What made the run happen? Early light."])
        #expect(await JournalQuestions.next(withWins, using: good) == "What made the run happen?")
    }

    @Test("asking again brings another question")
    func anotherQuestion() async {
        let fixed = FixedJournalQuestioner(answers: ["What made the run happen?", "Where did the run take you?"])
        let first = JournalQuestionContext(wins: ["Morning run"], alreadyAsked: [], isToday: true)
        let one = await JournalQuestions.next(first, using: fixed)
        let again = JournalQuestionContext(wins: ["Morning run"], alreadyAsked: [one], isToday: true)
        let two = await JournalQuestions.next(again, using: fixed)
        #expect(one != two)
    }

    @Test("the question is asked from the day's own win titles")
    func winTitlesForADay() throws {
        let ctx = try context()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try QuickWinService.logWin(title: "Morning run", category: .health, on: day, context: ctx, tower: nil)
        _ = try QuickWinService.logWin(title: "Morning run", category: .health,
                                       on: day.addingTimeInterval(60), context: ctx, tower: nil)
        _ = try QuickWinService.logWin(on: day.addingTimeInterval(120), context: ctx, tower: nil)
        _ = try QuickWinService.logWin(title: "Called Grandma", category: .social,
                                       on: day.addingTimeInterval(180), context: ctx, tower: nil)
        _ = try QuickWinService.logWin(title: "Another day", category: .work,
                                       on: day.addingTimeInterval(60 * 60 * 30), context: ctx, tower: nil)
        let titles = JournalQuestionContext.winTitles(on: DateUtils.dateString(from: day), context: ctx)
        #expect(titles == ["Morning run", "Called Grandma"], "deduped, in order, untitled wins left out")
    }

    // MARK: - The lock

    /// What the stand-in for Face ID was asked, and what it answers.
    @MainActor final class Prompt {
        var asked = 0
        var answer = true
    }

    @Test("off by default, and then the journal opens without asking")
    func lockOffByDefault() async {
        let defaults = UserDefaults(suiteName: "journal-lock-\(UUID().uuidString)")!
        let prompt = Prompt()
        let lock = JournalLock(defaults: defaults) { prompt.asked += 1; return prompt.answer }
        #expect(!lock.isOn)
        #expect(await lock.unlock())
        #expect(prompt.asked == 0)
    }

    @Test("on, it asks once a session, refuses on a failure, and asks again after leaving")
    func lockAsksOnce() async {
        let defaults = UserDefaults(suiteName: "journal-lock-\(UUID().uuidString)")!
        defaults.set(true, forKey: JournalLock.defaultsKey)
        let prompt = Prompt()
        prompt.answer = false
        let lock = JournalLock(defaults: defaults) { prompt.asked += 1; return prompt.answer }
        #expect(!(await lock.unlock()), "a failed check opens nothing")
        prompt.answer = true
        #expect(await lock.unlock())
        #expect(await lock.unlock())
        #expect(prompt.asked == 2, "asked for the failure and the first success, never again this session")
        lock.relock()
        #expect(await lock.unlock())
        #expect(prompt.asked == 3)
    }
}
