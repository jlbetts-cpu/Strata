import Foundation
import SwiftData
import Testing
import UIKit
@testable import Strata

/// A plan a crew can see, the pictures in a chat, and a day brought back
/// (`GroupPlan`, `ChatPlus`; the design is `docs/crew-plus-design.md`).
@MainActor
@Suite("Crew: group plans and the plus row", .serialized)
struct GroupPlanTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "group-plan-tests-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        await b.refresh()
        return (a, b, crew)
    }

    private func defaults() -> UserDefaults {
        let name = "group-plan-\(UUID())"
        return UserDefaults(suiteName: name)!
    }

    private func message(_ text: String, day: String = "2026-10-12", sketch: URL? = nil) -> CrewMessage {
        CrewMessage(messageID: UUID(), crewID: CrewID(rawValue: "crew-1"), senderProfileID: sam, crewDay: day,
                    text: text, sketch: sketch, createdAt: Date())
    }

    @Test("a plan is a line anyone can read, and it comes back out as the plan")
    func theLine() throws {
        let today = "2026-10-12"
        let cases: [(GroupPlan.When, String)] = [
            (.day("2026-10-12"), "Plan: Workout (today)"),
            (.day("2026-10-13"), "Plan: Workout (tomorrow)"),
            (.day("2026-10-20"), "Plan: Workout (2026-10-20)"),
            (.weekdays([2, 4, 6]), "Plan: Workout (Mon Wed Fri)"),
        ]
        for (when, readable) in cases {
            let line = try #require(GroupPlan.line(title: "  Workout ", when: when, sentOn: today))
            // What a build from before this shows: the words, after two
            // characters that draw nothing.
            #expect(line == CrewMessage.planMarker + readable)
            let plan = try #require(message(line, day: today).groupPlan)
            #expect(plan.title == "Workout")
            #expect(plan.when == when)
        }
        // A title with brackets of its own is still read by the last pair.
        let odd = try #require(GroupPlan.line(title: "Run (easy)", when: .day(today), sentOn: today))
        #expect(message(odd, day: today).groupPlan?.title == "Run (easy)")
        // Nothing to plan, and no days, make no line.
        #expect(GroupPlan.line(title: "   ", when: .day(today), sentOn: today) == nil)
        #expect(GroupPlan.line(title: "Run", when: .weekdays([]), sentOn: today) == nil)
        // The line passes the chat's own word check and its length.
        let long = try #require(GroupPlan.line(title: String(repeating: "a", count: 200), when: .weekdays(Array(1...7)), sentOn: today))
        #expect(long.count <= CrewMessage.textLimit)
        #expect(CrewWords.isAcceptable(long))
    }

    @Test("words somebody typed are never taken for a plan, and neither is a doodle")
    func notAPlan() {
        #expect(message("Plan: Workout (today)").groupPlan == nil)
        #expect(message("morning all").groupPlan == nil)
        #expect(message(CrewMessage.planMarker + "Plan: Workout (someday)").groupPlan == nil)
        #expect(message(CrewMessage.planMarker + "Plan:  (today)").groupPlan == nil)
        #expect(message(CrewMessage.stripMarker, sketch: URL(fileURLWithPath: "/tmp/s.png")).groupPlan == nil)
        // The markers are each their own, and none is the one older builds hide.
        let marks = [CrewMessage.planMarker, CrewMessage.pictureMarker, CrewMessage.stripMarker, CrewMessage.tossMarker]
        #expect(Set(marks).count == 4)
    }

    @Test("a crafted line never traps: no title is no plan")
    func craftedLines() {
        let m = CrewMessage.planMarker
        for text in [m + "Plan: (today)", m + "Plan: ()", m + "Plan:  (today)", m + "Plan: (", m + "Plan: )", m + "Plan: x ()",
                     m + "Plan:(today)", m, m + "Plan: ", m + " (today)", m + "Plan: a (today) (", m + "Plan: (today) (today)"] {
            // Reading it is the test: it used to trap on the first.
            let plan = message(text).groupPlan
            if let plan { #expect(!plan.title.isEmpty, "\(text.unicodeScalars.count)") }
        }
        #expect(message(m + "Plan: (today)").groupPlan == nil)
        #expect(message(m + "Plan: (today) (today)").groupPlan?.title == "(today)")
    }

    @Test("a plan with a time is proved by the win it becomes, and an emoji title is its own")
    func proof() {
        let crew = CrewID(rawValue: "c")
        let timed = GroupPlan(id: UUID(), crewID: crew, sender: sam, title: "Gym @ 6", when: .day("2026-10-12"))
        #expect(timed.proofKey == GroupPlan.key("Gym"))
        #expect(GroupPlan(id: UUID(), crewID: crew, sender: sam, title: "Lunch at 12", when: .day("2026-10-12")).proofKey == GroupPlan.key("lunch"))
        #expect(GroupPlan.key("🏃") != GroupPlan.key("🍜"))
        #expect(!GroupPlan.key("🏃").isEmpty)
    }

    @Test("someone who may not send photographs sends no sticker, strip or photo, and is offered none")
    func noPhotographs() async throws {
        let (a, _, crew) = try await pair()
        a.photosAllowed = { false }
        let png = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }.pngData()!
        #expect(await a.sendSticker(png, in: crew.id) == .notAllowed)
        #expect(await a.sendPicture(png, caption: "A year ago today.", in: crew.id) == .notAllowed)
        #expect(await a.sendStrip(png, in: crew.id) == .notAllowed)
        #expect(a.messages(in: crew.id).isEmpty)
        let container = try ModelContainer(for: PlanItem.self, HabitLog.self, Habit.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        #expect(CrewLookBack.all(for: crew.id, context: ModelContext(container), store: a).isEmpty)
        #expect(CrewLookBack.find(for: crew.id, context: ModelContext(container), store: a) == nil)
        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        #expect(chat.contains("store.photosAllowed() ? ChatPlusRow.Choice.allCases : [.win, .plan, .sticker]"))
        // A plan and a doodle are words and ink, and still theirs to send.
        #expect(await a.sendPlan(title: "Walk", when: .day(CrewDay.string(for: a.now(), in: crew.timeZone)), in: crew.id).outcome == .sent)
    }

    @Test("the book follows your plan, a closed card stays closed today, and the same words are not written twice")
    func theBook() throws {
        let container = try ModelContainer(for: PlanItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let book = defaults()
        let crew = CrewID(rawValue: "crew-1")
        let plan = GroupPlan(id: UUID(), crewID: crew, sender: sam, title: "Workout", when: .weekdays([2, 4]))
        let line = try #require(plan.join(context: context, today: "2026-10-12", defaults: book))
        // Deleted from the plan sheet: the book lets go, and I'm In is back.
        context.delete(line)
        try context.save()
        GroupPlanBook.reconcile(context: context, defaults: book)
        #expect(!GroupPlanBook.isIn(plan, defaults: book))
        #expect(GroupPlanBook.plans(in: crew, on: "2026-10-12", me: jayden, defaults: book).isEmpty)
        // Words already on your plan for that day are the plan.
        let mine = PlanItem(text: "workout", order: 0, category: .health, day: "2026-10-13")
        context.insert(mine)
        try context.save()
        let once = GroupPlan(id: UUID(), crewID: crew, sender: sam, title: "Workout", when: .day("2026-10-13"))
        #expect(once.join(context: context, today: "2026-10-12", defaults: book)?.id == mine.id)
        #expect(try context.fetch(FetchDescriptor<PlanItem>()).count == 1)
        // Closed is for today, and is kept.
        GroupPlanBook.close(once.bookKey, today: "2026-10-12", defaults: book)
        #expect(GroupPlanBook.closed(today: "2026-10-12", defaults: book) == [once.bookKey])
        #expect(GroupPlanBook.closed(today: "2026-10-13", defaults: book).isEmpty)
    }

    @Test("spicy noodles is a win, and the refused words are still refused")
    func words() {
        #expect(CrewWords.isAcceptable("Spicy noodles"))
        #expect(CrewWords.isAcceptable("spice rack, spiced up"))
        for term in CrewWords.refused { #expect(!CrewWords.isAcceptable("you \(term)"), "\(term)") }
        #expect(!CrewWords.isAcceptable("spics"))
    }

    @Test("when it is for, and how the card says it")
    func when() {
        let weekly = GroupPlan(id: UUID(), crewID: CrewID(rawValue: "c"), sender: sam, title: "Run", when: .weekdays([2, 4]))
        #expect(weekly.isFor("2026-10-12"))          // a Monday
        #expect(!weekly.isFor("2026-10-13"))
        #expect(weekly.whenWords(today: "2026-10-12") == "Mon, Wed")
        let once = GroupPlan(id: UUID(), crewID: CrewID(rawValue: "c"), sender: sam, title: "Run", when: .day("2026-10-13"))
        #expect(once.whenWords(today: "2026-10-12") == "tomorrow")
        #expect(once.whenWords(today: "2026-10-13") == "today")
        #expect(once.isFor("2026-10-13") && !once.isFor("2026-10-12"))
        // A win of the same name is the proof, however it was typed.
        #expect(GroupPlan.key(" Evening  Walk! ") == GroupPlan.key("evening walk"))
        #expect(GroupPlan.key("Run") != GroupPlan.key("Runs"))
    }

    @Test("the card names only the people who did it")
    func theCard() {
        #expect(GroupPlanCard.line(when: "tomorrow", done: []) == "Tomorrow")
        #expect(GroupPlanCard.line(when: "today", done: ["Sam"]) == "Today. Sam did it.")
        #expect(GroupPlanCard.line(when: "today", done: ["You", "Sam"]) == "Today. You and Sam did it.")
        #expect(GroupPlanCard.line(when: "today", done: ["You", "Sam", "Ana", "Leo"]) == "Today. You, Sam and 2 more did it.")
        let source = SourceSweep.code((try? SourceSweep.read("Strata/Views/Crews/ChatPlus.swift")) ?? "")
        // No count of who is in, and nobody who has not.
        for banned in [" of \\(", "waiting", "hasn't", "not in", "missed"] {
            #expect(!source.contains(banned), "\(banned)")
        }
    }

    @Test("I'm In puts it in your own plan once, and the book knows whose crew it is")
    func joining() throws {
        let container = try ModelContainer(for: PlanItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let book = defaults()
        let crew = CrewID(rawValue: "crew-1")
        let once = GroupPlan(id: UUID(), crewID: crew, sender: sam, title: "Workout", when: .day("2026-10-13"))
        #expect(!GroupPlanBook.isIn(once, defaults: book))
        let line = try #require(once.join(context: context, today: "2026-10-12", defaults: book))
        #expect(line.text == "Workout")
        #expect(line.day == "2026-10-13")
        #expect(GroupPlanBook.isIn(once, defaults: book))
        #expect(GroupPlanBook.crew(forPlanItem: line.id, defaults: book) == crew)
        // Again: the same line, not a second one.
        #expect(once.join(context: context, today: "2026-10-12", defaults: book)?.id == line.id)
        #expect(try context.fetch(FetchDescriptor<PlanItem>()).count == 1)
        // On its day the chat draws it from your own plan; not the day before.
        #expect(GroupPlanBook.plans(in: crew, on: "2026-10-13", me: jayden, defaults: book).map(\.title) == ["Workout"])
        #expect(GroupPlanBook.plans(in: crew, on: "2026-10-12", me: jayden, defaults: book).isEmpty)
        #expect(GroupPlanBook.plans(in: CrewID(rawValue: "other"), on: "2026-10-13", me: jayden, defaults: book).isEmpty)
        // A repeating one is a repeating line.
        let weekly = GroupPlan(id: UUID(), crewID: crew, sender: sam, title: "Run", when: .weekdays([2, 4, 6]))
        let repeating = try #require(weekly.join(context: context, today: "2026-10-12", defaults: book))
        #expect(repeating.repeatDaysRaw == "2,4,6")
        // Leaving takes it out of the book.
        GroupPlanBook.leave(once.bookKey, defaults: book)
        #expect(!GroupPlanBook.isIn(once, defaults: book))
        #expect(GroupPlanBook.crew(forPlanItem: line.id, defaults: book) == nil)
    }

    @Test("a plan sent on one phone is a plan on the other, and reads as words to anything older")
    func acrossPhones() async throws {
        let (a, b, crew) = try await pair()
        let day = CrewDay.string(for: a.now(), in: crew.timeZone)
        let sent = await a.sendPlan(title: "Evening walk", when: .day(day), in: crew.id)
        #expect(sent.outcome == .sent)
        #expect(sent.plan?.title == "Evening walk")
        await b.refresh()
        let line = try #require(b.messages(in: crew.id).last)
        let plan = try #require(line.groupPlan)
        #expect(plan.title == "Evening walk" && plan.when == .day(day) && plan.sender == jayden)
        // What a build that knows nothing of plans shows.
        #expect(CrewMessage.words(after: CrewMessage.planMarker, in: line.text) == "Plan: Evening walk (today)")
        // Refused words are refused in a plan as in a line.
        #expect(await a.sendPlan(title: "kys", when: .day(day), in: crew.id).outcome == .refusedWords)
        // The proof is the win: b does it, and a sees a win of that name.
        let now = b.now()
        await b.post(OwnWin(winID: UUID(), title: "evening walk", colour: .health, icon: .health, blockSize: .small,
                            photoJPEG: nil, cropX: nil, cropY: nil, createdAt: now, updatedAt: now), to: [crew.id])
        await a.refresh()
        let did = a.today(in: crew.id).filter { GroupPlan.key($0.title) == GroupPlan.key(plan.title) }.map(\.senderProfileID)
        #expect(did == [sam])
    }

    @Test("a sticker and a photo brought back arrive as pictures, with the line under the photo")
    func pictures() async throws {
        let (a, b, crew) = try await pair()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let png = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).image { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }.pngData()!
        #expect(await a.sendSticker(png, in: crew.id) == .sent)
        a.now = { Date().addingTimeInterval(5) }
        #expect(await a.sendPicture(png, caption: "A year ago today.", in: crew.id) == .sent)
        await b.refresh()
        let lines = b.messages(in: crew.id).filter { $0.senderProfileID == jayden }
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.isPicture && !$0.isStrip && !$0.isToss && $0.groupPlan == nil })
        #expect(lines.map(\.caption) == [SocialStore.stickerWord, "A year ago today."])
    }

    @Test("a notification says what a marked line is")
    func pushWords() {
        let cache = CrewNoteCache(me: "", crews: [:])
        func body(_ text: String, picture: Bool = false) -> String {
            cache.chatWords(crew: "x", sender: "y", text: text, hasPicture: picture).body
        }
        #expect(body(CrewMessage.planMarker + "Plan: Workout (tomorrow)") == "A friend planned Workout (tomorrow)")
        #expect(body(CrewMessage.pictureMarker + SocialStore.stickerWord, picture: true) == "A friend sent a sticker")
        #expect(body(CrewMessage.pictureMarker + "A year ago today.", picture: true) == "A friend: A year ago today.")
        #expect(body(CrewMessage.stripMarker, picture: true) == "A friend shared a photo strip")
        // The extension's copies of the markers are the app's.
        #expect(CrewNoteCache.planMarker == CrewMessage.planMarker)
        #expect(CrewNoteCache.pictureMarker == CrewMessage.pictureMarker)
        #expect(CrewNoteCache.stickerWord == SocialStore.stickerWord)
    }

    @Test("a day this crew saw: the furthest back, only what went to this crew, once a day")
    func lookBack() {
        let calendar = DateUtils.keyCalendar()
        let today = DateUtils.date(from: "2026-10-12")!
        let year = UUID(), month = UUID(), other = UUID()
        let candidates = [CrewLookBack.Candidate(id: month, day: "2026-09-12", fileName: "m.jpg"),
                          CrewLookBack.Candidate(id: year, day: "2025-10-12", fileName: "y.jpg"),
                          CrewLookBack.Candidate(id: other, day: "2026-04-12", fileName: "o.jpg")]
        // The six-month one never went to this crew.
        let found = CrewLookBack.pick(candidates, sent: [year, month], today: today, calendar: calendar)
        #expect(found?.logID == year)
        #expect(found?.title == "A year ago today")
        #expect(CrewLookBack.pick(candidates, sent: [month], today: today, calendar: calendar)?.title == "This day last month")
        #expect(CrewLookBack.pick(candidates, sent: [], today: today, calendar: calendar) == nil)
        #expect(CrewLookBack.pick(candidates, sent: [year], today: DateUtils.date(from: "2026-10-13")!, calendar: calendar) == nil)
        let book = defaults()
        let crew = CrewID(rawValue: "crew-1")
        #expect(!CrewLookBack.isAnswered(crew, today: "2026-10-12", defaults: book))
        CrewLookBack.answer(crew, today: "2026-10-12", defaults: book)
        #expect(CrewLookBack.isAnswered(crew, today: "2026-10-12", defaults: book))
        #expect(!CrewLookBack.isAnswered(crew, today: "2026-10-13", defaults: book))
    }

    @Test("the row is five, in his order, and nothing in the chat posts by itself")
    func theRow() throws {
        #expect(ChatPlusRow.Choice.allCases.map(\.word) == ["Win", "Plan", "Strip", "Memory", "Sticker"])
        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        // A look back is sent by a press: `bringBack` is only ever an action.
        #expect(chat.contains("action: { bringBack(found) }"))
        #expect(chat.contains("CrewMemorySheet(crewID: crewID) { found in bringBack(found) }"))
        #expect(!chat.contains(".task { bringBack"))
        // A group plan's crew is ticked for that win and is not made your usual.
        let add = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        #expect(add.contains("GroupPlanBook.crew(forPlanItem: line)"))
        #expect(add.contains("groupPlanCrew.map { crewChoice.subtracting([$0]) } ?? crewChoice"))
    }
}
