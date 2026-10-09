import Testing
import Foundation
import SwiftData
@testable import Strata

/// **The cohesion pass, 2026-10-05**: one name for a day, notifications that
/// land on their subject and say what happened, replies that are their own
/// news, a crew streak that names nobody, and reminders that stay right when
/// a win is logged from outside the app.
@MainActor
@Suite("Cohesion pass")
struct CohesionPassTests {

    // MARK: - One day title

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private let english = Locale(identifier: "en_US")

    /// Sunday 4 October 2026, mid-afternoon.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 15))!
    }

    @Test("a day is Today, Yesterday, its weekday and date, and the year only when it is another year's")
    func dayTitles() {
        func title(_ key: String) -> String {
            DayTitle.title(forKey: key, now: now, calendar: calendar, locale: english)
        }
        #expect(title("2026-10-04") == "Today")
        #expect(title("2026-10-03") == "Yesterday")
        #expect(title("2026-10-01") == "Thursday 1 October")
        #expect(title("2026-01-05") == "Monday 5 January")
        #expect(title("2025-10-05") == "Sunday 5 October 2025")
        #expect(title("not a day") == "not a day")
    }

    /// Proven able to fail: with the year rule inverted, the caption and the
    /// title both flip and these go red together.
    @Test("the past win's caption and the day's title agree on when a year is said")
    func captionAgreesOnTheYear() {
        let thisYear = PastWin.dateWords("2026-03-04", today: now, calendar: calendar)
        let lastYear = PastWin.dateWords("2025-03-04", today: now, calendar: calendar)
        #expect(!thisYear.contains("2026"))
        #expect(lastYear.contains("2025"))
        #expect(!DayTitle.title(forKey: "2026-03-04", now: now, calendar: calendar, locale: english).contains("2026"))
        #expect(DayTitle.title(forKey: "2025-03-04", now: now, calendar: calendar, locale: english).contains("2025"))
    }

    @Test("a crew day is named in the crew's zone, so its Today is the crew's")
    func crewZoneTitles() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 3pm Sunday in California is 7am Monday in Tokyo.
        #expect(DayTitle.title(forKey: "2026-10-05", now: now, calendar: tokyo, locale: english) == "Today")
        #expect(DayTitle.title(forKey: "2026-10-04", now: now, calendar: tokyo, locale: english) == "Yesterday")
    }

    @Test("every page that names a day asks DayTitle, and none of them formats its own")
    func oneSpelling() throws {
        // `DaySheet` is the journal's sheet, merged with the plan (2026-10-05).
        for file in ["Views/DaySheet.swift", "Views/DayAlbumDetailView.swift", "Views/Crews/CrewStatsSections.swift"] {
            let text = try MorningSource.read(file)
            #expect(text.contains("DayTitle.title(forKey:"), "\(file) names a day its own way")
            #expect(!text.contains("dateFormat = \"EEEE d MMMM\""), "\(file) still formats a day by hand")
        }
    }

    // MARK: - The crew streak names nobody

    @Test("the streak line is the rule, or everyone in, and never a name")
    func streakLineHasNoNames() {
        #expect(CrewStats.streakLine(people: 3, waiting: 0) == "Everyone's in today.")
        // The rule became half the crew on 2026-10-09 (unification pass §5):
        // a kept day short of everyone says so, warmly, still naming nobody.
        #expect(CrewStats.streakLine(people: 3, waiting: 1) == "Today counts. Nice work, crew.")
        #expect(CrewStats.streakLine(people: 3, waiting: 3) == "A day counts when half the crew posts a win. Two days off a week are fine.")
        #expect(CrewStats.streakLine(people: 2, waiting: 1) == "A day counts when everyone posts a win. Two days off a week are fine.")
        #expect(CrewStats.streakLine(people: 1, waiting: 0) == "A day counts when everyone posts a win. Two days off a week are fine.")
    }

    @Test("no crew screen says who is still to post")
    func nobodyIsWaitedOn() throws {
        // Code only: the doc comment quotes the old line on purpose.
        let stats = SourceSweep.code(try MorningSource.read("Views/Crews/CrewStatsSections.swift"))
        #expect(!stats.contains("Waiting on"), "a crew screen names who has not posted")
        #expect(!stats.contains("stats.waiting.map"), "the waiting list is being turned into words")
    }

    // MARK: - Notifications land on their subject

    @Test("a tap goes where the notification was about")
    func routes() {
        let win = UUID()
        #expect(NotificationRoute.of(identifier: win.uuidString, userInfo: ["crew": "crew-1", "win": win.uuidString])
                == .crew("crew-1", win: win))
        #expect(NotificationRoute.of(identifier: "strata.pastwin.2026-10-04",
                                     userInfo: [NotificationRoute.dayKey: "2025-10-04"]) == .memoriesDay("2025-10-04"))
        // A past win scheduled before the day was in its userInfo.
        #expect(NotificationRoute.of(identifier: "strata.pastwin.2026-10-04", userInfo: [:]) == .memories)
        #expect(NotificationRoute.of(identifier: "strata.replay.week-2026-09-28", userInfo: [:])
                == .replay(kind: "week", firstDay: "2026-09-28"))
        #expect(NotificationRoute.of(identifier: "strata.replay.month-2026-09-01", userInfo: [:])
                == .replay(kind: "month", firstDay: "2026-09-01"))
        #expect(NotificationRoute.of(identifier: "strata.replay.nonsense", userInfo: [:]) == .memories)
        #expect(NotificationRoute.of(identifier: "strata.reminder.2026-10-04", userInfo: [:]) == .wins)
        #expect(NotificationRoute.of(identifier: "strata.daily.reminder", userInfo: [:]) == .wins)
        #expect(NotificationRoute.of(identifier: "something.else", userInfo: [:]) == nil)
    }

    @Test("the schedulers and the router spell the identifiers the same way")
    func prefixesAgree() {
        #expect(DailyReminder.prefix == NotificationRoute.Prefix.daily)
        #expect(DailyReminder.legacy == NotificationRoute.Prefix.dailyLegacy)
        #expect(PastWinReminder.prefix == NotificationRoute.Prefix.pastWin)
        #expect(ReplayReminder.prefix == NotificationRoute.Prefix.replay)
        // The replay's identifier is its prefix and the period's id, which
        // is the spelling the router parses back.
        let week = ReplayPeriod.week(containing: now, calendar: calendar)
        let route = NotificationRoute.of(identifier: ReplayReminder.prefix + week.id, userInfo: [:])
        #expect(route == .replay(kind: "week", firstDay: week.days[0]))
    }

    @Test("the landing router keeps a Memories subject for Memories, and the tab for the tab bar")
    func landing() {
        let router = LandingRouter()
        router.land(.memoriesDay("2025-10-04"))
        #expect(router.pending == .memoriesDay("2025-10-04"))
        #expect(router.memories == .memoriesDay("2025-10-04"))
        router.memories = nil
        router.land(.wins)
        #expect(router.pending == .wins)
        #expect(router.memories == nil, "the daily reminder has nothing for Memories to open")
    }

    @Test("the delegate is installed with Crews off, and the replay says no more than its title")
    func delegateAlwaysOnAndNoWhereToLook() throws {
        let delegate = try MorningSource.read("Social/StrataAppDelegate.swift")
        let launch = delegate.components(separatedBy: "didFinishLaunchingWithOptions").last ?? ""
        let setsDelegate = try #require(launch.range(of: "UNUserNotificationCenter.current().delegate = self"))
        // `isUsable` (2026-10-08): the flag AND iOS 26, which crews now need.
        let gate = try #require(launch.range(of: "guard CrewsFlag.isUsable else { return true }"))
        #expect(setsDelegate.lowerBound < gate.lowerBound, "the delegate is behind the Crews flag again")
        for item in ReplayReminder.upcoming(now: now, calendar: calendar, hasWins: { _ in true }) {
            #expect(!item.body.contains("Find it in Memories"))
        }
    }

    @Test("the daily reminder is a cue that names nothing missing")
    func dailyReminderIsACue() {
        #expect(DailyReminder.title == "Anything you finished counts.")
        for word in ["Nothing", "yet", "missed", "haven't", "forgot"] {
            #expect(!(DailyReminder.title + DailyReminder.body).contains(word))
        }
    }

    @Test("the past win arrives passively, in its own thread")
    func pastWinIsPassive() throws {
        let text = try MorningSource.read("Services/PastWin.swift")
        #expect(text.contains("content.interruptionLevel = .passive"))
        #expect(text.contains("content.threadIdentifier = NotificationRoute.Thread.pastWin"))
        #expect(Set([NotificationRoute.Thread.daily, NotificationRoute.Thread.pastWin,
                     NotificationRoute.Thread.replay]).count == 3)
    }

    // MARK: - A win from outside the app keeps the reminders right

    @Test("logging from the Lock Screen, a control or Siri runs the reminders' after-win step once")
    func intentKeepsRemindersRight() throws {
        let container = try ModelContainer(for: Habit.self, HabitLog.self, Tower.self, MoodLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true,
                                                                              cloudKitDatabase: .none))
        var ran = 0
        _ = try LogWinIntent.log(name: "Ran", size: .small, in: container) { _ in ran += 1 }
        #expect(ran == 1)
        // And the default is the real step, which is the app's own two calls.
        let source = try MorningSource.read("Intents/LogWinIntent.swift")
        let body = source.components(separatedBy: "static func keepRemindersRight").last ?? ""
        #expect(body.contains("DailyReminder.skipToday()"))
        #expect(body.contains("PastWinReminder.schedule(context: context)"))
        #expect(source.contains("afterWin: @MainActor (ModelContext) -> Void = LogWinIntent.keepRemindersRight"))
    }

    // MARK: - Suggest knows who a kept win was with

    @Test("a kept tagged win says who it was with in the question's prompt")
    func keptWithFeedsSuggest() throws {
        let ctx = ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let defaults = UserDefaults(suiteName: "kept-\(UUID().uuidString)")!
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let made = try QuickWinService.logWin(title: "Morning run", category: .health, on: day, context: ctx, tower: nil)
        _ = try QuickWinService.logWin(title: "Gym", category: .health, on: day, context: ctx, tower: nil)
        KeptWith.record(["Sam", " "], for: made.logID, defaults: defaults)
        let key = DateUtils.dateString(from: day)
        let company = JournalQuestionContext.company(on: key, context: ctx, defaults: defaults)
        #expect(company == ["Morning run": ["Sam"]])
        let context = JournalQuestionContext(wins: ["Morning run", "Gym"], alreadyAsked: [], isToday: true,
                                             company: company)
        #expect(context.prompt.contains("Morning run (with Sam), Gym"))
        // A question about the friend still names the win, so it is kept.
        #expect(JournalQuestionRules.clean("What was the run with Sam like?", wins: context.wins) != nil)
    }

    @Test("both helpers are told the owner's voice rules")
    func voiceRules() {
        for rules in [JournalQuestionRules.instructions, PlanSuggestionRules.instructions] {
            #expect(rules.contains("never coach"))
            #expect(rules.contains("target"))
            #expect(rules.contains("not do") || rules.contains("not done"))
            #expect(rules.contains("Calm and specific"))
        }
    }

    // MARK: - The Why page

    @Test("Why It Works This Way makes no promise and no medical claim, and says so")
    func whyPage() {
        let all = (WhyItWorksView.sections.flatMap { [$0.title, $0.body] } + [WhyItWorksView.notMedical]
                   + WhyItWorksView.sources).joined(separator: "\n")
        #expect(WhyItWorksView.notMedical == "Some Wins is not a medical app and does not diagnose or treat ADHD.")
        #expect(!all.contains("\u{2014}") && !all.contains("\u{2013}"), "a long dash")
        let prose = WhyItWorksView.sections.map(\.body).joined(separator: " ").lowercased()
        for promise in ["cure", "treat", "improve", "proven", "guarantee", "helps you", "will help", "habit"] {
            #expect(!prose.contains(promise), "the page promises or claims: \(promise)")
        }
        #expect(WhyItWorksView.sections.map(\.title) == [
            "A list of what you did", "Right where it happens", "It shows straight away",
            "Quiet days are fine", "Photos help you remember", "Friends, without a feed",
        ])
        #expect(WhyItWorksView.sources.count == 3)
    }
}

/// **Replies and tags, as the crew hears them.**
@MainActor
@Suite("Cohesion pass: replies and tags", .serialized)
struct CohesionCrewTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "cohesion-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        store.sendsPings = true
        return store
    }

    func win(_ title: String) -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    func pair() async throws -> (SocialStore, SocialStore, Crew) {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        return (a, b, crew)
    }

    @Test("a reply has its own key, apart from the reaction's")
    func replyKeys() {
        let id = UUID()
        #expect(SocialStore.pingKey(winID: id, carriesLine: false) == "reaction-\(id.uuidString)")
        #expect(SocialStore.pingKey(winID: id, carriesLine: true) == "reply-\(id.uuidString)")
        var reaction = Reaction(winID: id, crewID: CrewID(rawValue: "c"), profileID: sam, emoji: "🔥", createdAt: .now)
        #expect(CrewNotifications.announceKeys(reaction).reply == nil)
        reaction.line = "  "
        #expect(CrewNotifications.announceKeys(reaction).reply == nil, "blank is not a reply")
        reaction.line = "so proud"
        #expect(CrewNotifications.announceKeys(reaction).reaction == reaction.id)
        #expect(CrewNotifications.announceKeys(reaction).reply == "reply-" + reaction.id)
    }

    /// **A reply is no longer a reaction's ping** (2026-10-05). It was its
    /// own news on the reaction kind, keyed apart from the emoji, so the
    /// words woke the owner. Replies are lines in the crew's chat now, which
    /// the app announces itself ("Sam: so proud" to the win's owner,
    /// `CrewNotifications.announceMessages`, tested in `CrewChatTests`), and
    /// a ping would need a kind and a subscription of its own; pings are
    /// off. So the second ping this test counted is now held to NOT
    /// happening, and the reply is held to reaching the chat instead. The
    /// emoji half is unchanged.
    @Test("a reaction pings once; a reply goes to the chat, and a changed emoji does not ping again")
    func aReplyIsItsOwnPing() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.canReply = { true }
        func reactionPings() -> Int { world.pings.values.filter { $0[CrewPingRecord.kind] == "reaction" }.count }
        await b.react("🔥", to: run.winID, in: crew.id)
        #expect(reactionPings() == 1)
        #expect(await b.reply("so proud", to: run.winID, in: crew.id) == .sent)
        #expect(reactionPings() == 1, "a reply is a chat line, not a reaction")
        await a.refresh()
        #expect(a.messages(in: crew.id).map(\.text) == ["so proud"], "the words are news of their own, in the chat")
        await b.react("👑", to: run.winID, in: crew.id)
        #expect(reactionPings() == 1, "a changed emoji is not news")
    }

    /// The words survive any tap on an emoji. They used to share one record
    /// with the reaction, so taking the emoji back took them too; a reply
    /// is its own chat line now and no reaction gesture can reach it.
    @Test("the same emoji again never unsends a reply; with no reply it takes the reaction back")
    func theSameEmojiNeverUnsendsAReply() async throws {
        let (a, b, crew) = try await pair()
        let run = win("Run")
        await a.post(run, to: [crew.id])
        await b.refresh()
        b.canReply = { true }
        #expect(await b.reply("so proud", to: run.winID, in: crew.id) == .sent)
        await b.react("❤️", to: run.winID, in: crew.id)
        await a.refresh()
        #expect(a.messages(in: crew.id).map(\.text) == ["so proud"], "a double tap erased the words")
        #expect(a.reactions(to: run.winID, in: crew.id).map(\.emoji) == ["❤️"])
        // A new emoji still replaces the old one and keeps the words.
        await b.react("🔥", to: run.winID, in: crew.id)
        await a.refresh()
        #expect(a.reactions(to: run.winID, in: crew.id).map(\.emoji) == ["🔥"])
        #expect(a.messages(in: crew.id).map(\.text) == ["so proud"])
        // A plain reaction still toggles off.
        let gym = win("Gym")
        await a.post(gym, to: [crew.id])
        await b.refresh()
        await b.react("👑", to: gym.winID, in: crew.id)
        await b.react("👑", to: gym.winID, in: crew.id)
        await a.refresh()
        #expect(a.reactions(to: gym.winID, in: crew.id).isEmpty)
    }

    private func crew() -> Crew {
        Crew(id: CrewID(rawValue: "crew-t"), name: "Roommates", ownerProfileID: jayden, timeZoneIdentifier: "UTC",
             createdAt: .now, photo: nil,
             members: [CrewMember(profileID: jayden, firstName: "Jayden", head: nil, joinedAt: .distantPast),
                       CrewMember(profileID: sam, firstName: "Sam", head: nil, joinedAt: .now)])
    }

    @Test("a reply reads like Messages, and the person tagged is told they were added")
    func words() {
        let crew = crew()
        var tagged = SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: sam, crewDay: "2026-10-05",
                               title: "Morning run", colour: .health, icon: .health, blockSize: .small, photo: nil,
                               cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
        tagged.withPeople = [jayden]
        #expect(CrewNotifications.Text.of(tagged, in: crew, me: jayden).body == "Sam added you to Morning run")
        // Somebody else in the crew, not tagged, hears the ordinary line.
        #expect(CrewNotifications.Text.of(tagged, in: crew, me: UUID()).body == "Sam: Morning run")
        var reply = Reaction(winID: tagged.winID, crewID: crew.id, profileID: sam, emoji: "🔥", createdAt: .now)
        reply.line = "so proud of you"
        #expect(CrewNotifications.Text.replied(reply, in: crew) == "Sam: so proud of you")
    }

    @Test("the notification extension says the same sentences")
    func extensionWords() {
        let cache = CrewNoteCache(me: "me-id", crews: [
            "crew-1": .init(title: "Roommates", zoneName: "crew-x", zoneOwner: "o", joined: true,
                            members: ["sam": .init(profileID: "p", name: "Sam")], myWins: ["w1": "Gym"]),
        ])
        #expect(cache.words(kind: .reaction, crew: "crew-1", sender: "sam", winID: "w1", title: nil, emoji: "🔥",
                            line: "so proud") == ("Roommates", "Sam: so proud"))
        #expect(cache.words(kind: .reaction, crew: "crew-1", sender: "sam", winID: "w1", title: nil, emoji: "🔥",
                            line: "  ") == ("Roommates", "Sam reacted 🔥 to \u{201C}Gym\u{201D}"))
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w2", title: "Morning run", emoji: nil,
                            tagsMe: true) == ("Roommates", "Sam added you to Morning run"))
        #expect(cache.words(kind: .win, crew: "crew-1", sender: "sam", winID: "w2", title: "Morning run", emoji: nil)
                == ("Roommates", "Sam: Morning run"))
    }
}
