import Foundation
import Testing
import UIKit
import UserNotifications
@testable import Strata

/// **Leaning on push** (the owner, 2026-10-10: "I think we should lean on
/// push notifications"): a line in the chat, someone joining, a streak
/// milestone and a friend's strip each tell the crew, and an open crew reads
/// on the push rather than asking every three seconds.
@MainActor
@Suite("Crew pushes", .serialized)
struct CrewPushTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "crew-push-tests-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        store.sendsPings = true
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

    func pings(_ kind: CrewPingRecord.Kind) -> [[String: String]] {
        world.pings.values.filter { $0[CrewPingRecord.kind] == kind.rawValue }
    }

    // MARK: What leaves the phone

    @Test func joiningTellsTheCrewOnce() async throws {
        let (_, b, crew) = try await pair()
        let joined = pings(.joined)
        #expect(joined.count == 1, "the one who joined says so; starting a crew is not joining it")
        let ping = try #require(joined.first)
        #expect(ping[CrewPingRecord.crew] == CrewPingRecord.tag(crew.id.rawValue))
        #expect(ping[CrewPingRecord.sender] == CrewPingRecord.tag(sam.uuidString))
        // The joiner's own id, so a phone that has not met them can read
        // their name off their member record. No name, no crew id.
        #expect(ping[CrewPingRecord.win] == sam.uuidString)
        #expect(!ping.values.contains(crew.id.rawValue))
        #expect(!ping.values.contains("Sam"))
        await b.refresh()
        #expect(pings(.joined).count == 1)
    }

    @Test func aLineInTheChatPingsAndTheNextFewDoNot() async throws {
        let (a, _, crew) = try await pair()
        #expect(await a.send("morning all", in: crew.id) == .sent)
        #expect(pings(.message).count == 1)
        let ping = try #require(pings(.message).first)
        #expect(Set(ping.keys) == [CrewPingRecord.crew, CrewPingRecord.sender, CrewPingRecord.kind, CrewPingRecord.win])
        #expect(!ping.values.contains("morning all"), "the words stay sealed in the crew")
        // Four short lines are one tap on a friend's shoulder.
        a.now = { Date().addingTimeInterval(20) }
        #expect(await a.send("who is up", in: crew.id) == .sent)
        #expect(pings(.message).count == 1)
        a.now = { Date().addingTimeInterval(SocialStore.messagePingGap + 21) }
        #expect(await a.send("coffee?", in: crew.id) == .sent)
        #expect(pings(.message).count == 2)
    }

    @Test func aStripAlwaysPings() async throws {
        let (a, _, crew) = try await pair()
        #expect(await a.send("one", in: crew.id) == .sent)
        let strip = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 36)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 36))
        }.pngData()!
        a.now = { Date().addingTimeInterval(5) }
        #expect(await a.sendStrip(strip, in: crew.id) == .sent)
        #expect(pings(.message).count == 2, "a strip is the goal reached, once a day: never held back")
    }

    func win(at date: Date) -> OwnWin {
        OwnWin(winID: UUID(), title: "Gym", colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: date, updatedAt: date)
    }

    /// **A win sent to several crews tells every crew, and each person
    /// once** (2026-10-12). It left one ping, under whichever crew saved
    /// first: a friend who was only in the others was never told.
    @Test func aWinToSeveralCrewsTellsEveryoneOnce() async throws {
        let ana = UUID()
        let a = store(jayden), b = store(sam), c = store(ana)
        let (withSam, samLink) = try await a.createCrew(name: "With Sam")
        _ = try await b.accept(CrewInvite(url: samLink))
        let (withAna, anaLink) = try await a.createCrew(name: "With Ana")
        _ = try await c.accept(CrewInvite(url: anaLink))
        let (samAgain, againLink) = try await a.createCrew(name: "Sam Again")
        _ = try await b.accept(CrewInvite(url: againLink))
        for store in [a, b, c] { await store.refresh() }
        let before = pings(.win).count
        await a.post(win(at: Date()), to: [withSam.id, withAna.id, samAgain.id])
        let sent = pings(.win).dropFirst(before)
        let crews = Set(pings(.win).compactMap { $0[CrewPingRecord.crew] })
        // Ana's crew is told, whichever of Sam's two saved first.
        #expect(crews.contains(CrewPingRecord.tag(withAna.id.rawValue)))
        // Sam is in two of them and is told once: two pings in all, not three, and not one.
        #expect(pings(.win).count - before == 2, "\(sent.count)")
        let samCrews = crews.intersection([CrewPingRecord.tag(withSam.id.rawValue), CrewPingRecord.tag(samAgain.id.rawValue)])
        #expect(samCrews.count == 1)
        // Refreshing, or an edit, tells nobody again.
        await a.refresh()
        #expect(pings(.win).count - before == 2)
    }

    /// Seven days running in a crew of two: the win that makes the seventh
    /// day tells the crew, once, whoever else posts after it. Either of a
    /// pair keeps a day since 2026-10-12 (`CrewHistory.needed`), so it is
    /// the first win of the seventh day.
    @Test func theWinThatMakesAMilestoneTellsTheCrewOnce() async throws {
        let (a, b, crew) = try await pair()
        let start = Date()
        for day in 0..<7 {
            let at = start.addingTimeInterval(Double(day) * 86_400)
            a.now = { at }
            b.now = { at }
            await a.refresh()
            await b.refresh()
            await a.post(win(at: at), to: [crew.id])
            #expect(pings(.milestone).count == (day == 6 ? 1 : 0), "day \(day + 1): one of two keeps the day")
            await b.refresh()
            await b.post(win(at: at), to: [crew.id])
            #expect(pings(.milestone).count == (day == 6 ? 1 : 0), "day \(day + 1): told once")
        }
        let ping = try #require(pings(.milestone).first)
        #expect(ping[CrewPingRecord.win] == "7")
        #expect(ping[CrewPingRecord.crew] == CrewPingRecord.tag(crew.id.rawValue))
        // A second win the same day, from either phone: still the one.
        let last = start.addingTimeInterval(6 * 86_400 + 60)
        a.now = { last }
        await a.refresh()
        await a.post(win(at: last), to: [crew.id])
        #expect(pings(.milestone).count == 1)
    }

    /// A phone that joined a week ago holds two weeks at most. Its seven,
    /// or its fourteen, is not the crew's number, so it says nothing.
    @Test func aPhoneThatHasNotSeenTheWholeStreakSaysNoNumber() throws {
        let zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let today = "2026-10-10"
        func day(_ back: Int) -> String { CrewDay.day(today, offsetBy: -back, in: zone)! }
        func knows(_ streak: Int, earliest: Int?, began: Int) -> Bool {
            CrewStats.knowsWholeStreak(streak, earliest: earliest.map(day), crewBegan: day(began), today: today, zone: zone)
        }
        // The crew began forty days ago; this phone's record is two weeks.
        #expect(!knows(14, earliest: 13, began: 40))
        #expect(!knows(7, earliest: 6, began: 40))
        // A phone that was there from the crew's first day: its count is the crew's.
        #expect(knows(7, earliest: 6, began: 6))
        #expect(knows(30, earliest: 40, began: 40))
        // A phone that knows of days well before the streak began.
        #expect(knows(7, earliest: 12, began: 40))
        #expect(!knows(7, earliest: 8, began: 40))
        // Nothing recorded: nothing to vouch for.
        #expect(!knows(7, earliest: nil, began: 6))
    }

    // MARK: What the push says

    let cache = CrewNoteCache(me: "me", crews: [
        "crew-1": .init(title: "Roommates", zoneName: "crew-x", zoneOwner: "o", joined: true,
                        members: ["sam": .init(profileID: "p", name: "Sam")], myWins: [:]),
    ])

    @Test func theChatPushIsTheLineItself() {
        #expect(cache.chatWords(crew: "crew-1", sender: "sam", text: "morning all", hasPicture: false)
                == ("Roommates", "Sam: morning all"))
        #expect(cache.chatWords(crew: "crew-1", sender: "sam", text: "", hasPicture: true)
                == ("Roommates", "Sam sent a doodle"))
        #expect(cache.chatWords(crew: "crew-1", sender: "sam", text: CrewMessage.stripMarker, hasPicture: true)
                == ("Roommates", "Sam shared a photo strip"))
        // A line that could not be read still says something true.
        #expect(cache.chatWords(crew: "crew-1", sender: "sam", text: nil, hasPicture: false)
                == ("Roommates", "Sam wrote in the chat"))
        #expect(cache.chatWords(crew: "crew-9", sender: "x", text: nil, hasPicture: false)
                == ("Some Wins", "A friend wrote in the chat"))
        // Never a number: a phone pings once a minute however much is
        // written, so a count of pushes was a wrong count of lines.
        let body = cache.chatWords(crew: "crew-1", sender: "sam", text: "again", hasPicture: false).body
        #expect(!body.contains("new in"))
    }

    @Test func theMarkersAreTheSameOnBothSides() {
        #expect(CrewPingRecord.stripMarker == CrewMessage.stripMarker)
        #expect(CrewPingRecord.tossMarker == CrewMessage.tossMarker)
    }

    @Test func joiningAndMilestonesAreSaidWarmly() throws {
        #expect(cache.joinedWords(crew: "crew-1", sender: "new", name: "Priya") == ("Roommates", "Priya joined"))
        #expect(cache.joinedWords(crew: "crew-1", sender: "sam", name: nil) == ("Roommates", "Sam joined"))
        #expect(cache.joinedWords(crew: "crew-1", sender: "new", name: " ") == ("Roommates", "Someone new joined"))
        let seven = try #require(cache.milestoneWords(crew: "crew-1", days: "7"))
        #expect(seven == ("Roommates", "Look what your crew is building. 7 days."))
        #expect(cache.milestoneWords(crew: "crew-1", days: "x") == nil)
        #expect(cache.milestoneWords(crew: "crew-1", days: "1") == nil)
        // A ping is a plain record anyone can write: only a number a crew
        // is ever told, and only for a crew this phone is in.
        #expect(cache.milestoneWords(crew: "crew-1", days: "99999") == nil)
        #expect(cache.milestoneWords(crew: "crew-1", days: "8") == nil)
        #expect(cache.milestoneWords(crew: "crew-9", days: "7") == nil)
        #expect(CrewStats.milestones == CrewPingRecord.milestones)
        for words in [seven.1, cache.joinedWords(crew: "crew-1", sender: "new", name: nil).1] {
            for guilt in ["miss", "lose", "lost", "streak", "don't", "\u{2014}"] {
                #expect(!words.lowercased().contains(guilt))
            }
        }
    }

    @Test func aChatLineIsSaidAloudAndGoodNewsWaits() {
        func level(_ kind: CrewPingRecord.Kind) -> UNNotificationInterruptionLevel {
            let content = UNMutableNotificationContent()
            CrewAlertLevel.apply(to: content, kind: kind, tagsMe: false)
            return content.interruptionLevel
        }
        #expect(level(.message) == .active)
        #expect(level(.joined) == .passive)
        #expect(level(.milestone) == .passive)
    }

    // MARK: A busy chat rings once

    @Test func aConversationRingsOnceUntilItIsOpened() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-rang-\(UUID().uuidString)"))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CrewChatPending.rings(crew: "c", now: start, defaults: defaults))
        #expect(!CrewChatPending.rings(crew: "c", now: start.addingTimeInterval(30), defaults: defaults))
        #expect(!CrewChatPending.rings(crew: "c", now: start.addingTimeInterval(CrewChatPending.gap - 1), defaults: defaults))
        // Another crew is another conversation.
        #expect(CrewChatPending.rings(crew: "d", now: start.addingTimeInterval(31), defaults: defaults))
        // Quiet long enough, it rings again.
        #expect(CrewChatPending.rings(crew: "c", now: start.addingTimeInterval(CrewChatPending.gap + 1), defaults: defaults))
        // And so does the first line after the chat was opened.
        #expect(!CrewChatPending.rings(crew: "c", now: start.addingTimeInterval(CrewChatPending.gap + 20), defaults: defaults))
        CrewChatPending.opened(crew: "c", defaults: defaults)
        #expect(CrewChatPending.rings(crew: "c", now: start.addingTimeInterval(CrewChatPending.gap + 40), defaults: defaults))
    }

    @Test func theAppsOwnChatAlertStandsDownOnlyWhenChatPingsArrive() async throws {
        let suite = "crew-push-plan-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let a = SocialStore(cloud: FakeCrewCloud(world: world, me: jayden), defaults: defaults,
                            directory: FileManager.default.temporaryDirectory.appending(path: suite))
        a.isEnabled = { true }
        a.myFirstName = { "Jayden" }
        a.derive = { $0 }
        a.sendsPings = true
        #expect(!a.chatPingsLive)
        // A plan kept by a build from before the chat pinged is not enough:
        // win and reaction pings arrive, the chat's do not yet.
        let old = Data(#"{"winCrews":["a"],"reactionCrews":["a"],"me":"me","excluding":["me"]}"#.utf8)
        defaults.set(old, forKey: "crews.pings.plan")
        #expect(a.pingsLive && !a.chatPingsLive)
        // Told this build's plan, they do.
        _ = try await a.createCrew(name: "Roommates")
        await a.refresh()
        #expect(a.chatPingsLive)
    }

    @Test func aRefusedSubscriptionIsNotBelieved() async throws {
        let (a, b, _) = try await pair()
        #expect(a.pingsLive)
        let cloud = try #require(a.cloud as? FakeCrewCloud)
        // The plan changes (a block) and iCloud says no.
        cloud.listenError = CocoaError(.fileWriteUnknown)
        a.block(b.me)
        await a.refresh()
        #expect(!a.pingsLive, "not subscribed: the app's own notifications carry on")
        // And it is not asked again on every refresh.
        let asked = cloud.listenAttempts
        await a.refresh()
        await a.refresh()
        #expect(cloud.listenAttempts == asked)
        // Ten minutes on, with iCloud well again, it is.
        cloud.listenError = nil
        a.now = { Date().addingTimeInterval(700) }
        await a.refresh()
        #expect(a.pingsLive)
    }

    // MARK: What the phone asks to hear

    @Test func thePlanHearsTheCrewsOwnNews() throws {
        let plan = CrewPingPlan(winCrews: ["b", "a"], reactionCrews: ["a"], me: "me", excluding: ["blocked"])
        let text = plan.crewPredicate.predicateFormat
        for kind in CrewPingRecord.crewKinds { #expect(text.contains(kind.rawValue)) }
        #expect(text.contains("blocked") && text.contains("\"me\""), "never from you, never from someone you blocked")
        #expect(!CrewPingRecord.crewKinds.contains(.win) && !CrewPingRecord.crewKinds.contains(.reaction))
        // A plan kept by a build from before this is not this plan, so the
        // phone asks again and gets the crew's subscription.
        let old = Data(#"{"winCrews":["a","b"],"reactionCrews":["a"],"me":"me","excluding":["blocked","me"]}"#.utf8)
        #expect((try? JSONDecoder().decode(CrewPingPlan.self, from: old)) != plan)
        let kept = try JSONDecoder().decode(CrewPingPlan.self, from: JSONEncoder().encode(plan))
        #expect(kept == plan)
    }

    // MARK: An open crew reads on the push

    @Test func pushesSlowTheAskingAndTheirAbsenceBringsItBack() {
        var pace = CrewLivePace()
        #expect(pace.interval == CrewLivePace.quick)
        // A push said to look, and there was something: pushes are arriving.
        pace.asked(changed: true, byPush: true)
        #expect(pace.interval == CrewLivePace.pushedQuick)
        for _ in 0..<CrewLivePace.quietBeforeIdle { pace.asked(changed: false) }
        #expect(pace.interval == CrewLivePace.pushedIdle)
        // Asking found something no push announced: once is a push still on
        // its way, twice is pushes not arriving.
        pace.asked(changed: true)
        #expect(pace.interval == CrewLivePace.pushedQuick)
        pace.asked(changed: true)
        #expect(pace.interval == CrewLivePace.quick)
        // And one arriving is believed again.
        pace.asked(changed: true, byPush: true)
        #expect(pace.interval == CrewLivePace.pushedQuick)
    }

    /// iCloud's push can beat its own query by a second or two, so the ask
    /// a push asked for can come back empty. It is asked again soon, not in
    /// eight seconds or forty.
    @Test func aPushThatFoundNothingIsFollowedUp() {
        var pace = CrewLivePace()
        pace.asked(changed: true, byPush: true)
        for _ in 0..<CrewLivePace.quietBeforeIdle { pace.asked(changed: false) }
        #expect(pace.interval == CrewLivePace.pushedIdle)
        pace.asked(changed: false, byPush: true)
        #expect(pace.interval == CrewLivePace.quick)
        // The follow-up that finds it is the push's news, not a miss.
        pace.asked(changed: true)
        #expect(pace.interval == CrewLivePace.pushedQuick)
        // And one that never finds anything gives up after two.
        pace.asked(changed: false, byPush: true)
        pace.asked(changed: false)
        #expect(pace.interval == CrewLivePace.quick)
        pace.asked(changed: false)
        #expect(pace.interval != CrewLivePace.quick)
    }

    @Test func aPushWithACrewOpenBumpsItAndReadsEverythingRarely() async throws {
        let (a, b, crew) = try await pair()
        let cloud = try #require(a.cloud as? FakeCrewCloud)
        // Nothing open: a push reads everything, as it always did.
        var before = cloud.calls
        await a.pushed()
        #expect(cloud.calls > before)
        #expect(a.livePush == 0)
        // A crew open: the first push reads everything and bumps the crew;
        // the ones that follow within half a minute only bump it.
        a.liveCrew = crew.id
        a.now = { Date().addingTimeInterval(120) }
        await a.pushed()
        #expect(a.livePush == 1)
        before = cloud.calls
        a.now = { Date().addingTimeInterval(130) }
        await a.pushed()
        await a.pushed()
        #expect(a.livePush == 3)
        #expect(cloud.calls == before, "a busy chat pushes for every line; the whole account is not read for each")
        _ = b
    }
}
