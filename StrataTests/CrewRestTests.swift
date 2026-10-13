import Foundation
import Testing
import UIKit
@testable import Strata

/// The rest of the Launch Pack's crew list (2026-10-13): the invite as a
/// code to show, an Invite on a crew of one, a sticker on a win, and a
/// crew's week as a replay.
@MainActor
@Suite("Crew: code, sticker on a win, week", .serialized)
struct CrewRestTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "crew-rest-tests-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        store.myFirstName = { me == jayden ? "Jayden" : "Sam" }
        store.derive = { $0 }
        return store
    }

    private func sticker() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { c in
            UIColor.orange.setFill()
            c.cgContext.fillEllipse(in: CGRect(x: 4, y: 4, width: 56, height: 56))
        }.pngData()!
    }

    @Test("the code is the invite link, whole, and reads back as it")
    func theCode() throws {
        // As long as a real invite: the page, a crew id and a 43-character key.
        let link = "https://jlbetts-cpu.github.io/Strata/join.html#crew-0A1B2C3D-4E5F-4000-8000-0123456789AB."
            + String(repeating: "Ab3_", count: 10) + "xyz"
        let image = try #require(CrewCodeSheet.image(for: link))
        #expect(image.size.width == image.size.height)
        #expect(CrewCodeSheet.read(image) == link)
        // Dark dots on its own light paper in both appearances: a reversed
        // code is the one a camera reads least well.
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewCode.swift"))
        #expect(sheet.contains(".foregroundStyle(Self.dots)") && sheet.contains(".background(Self.paper"))
        #expect(!sheet.contains(".foregroundStyle(AppColors.inkPrimary)\n                            .accessibilityLabel(\"Invite code\")"))
        // Nothing is kept anywhere but the link: no code is looked up.
        let source = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewCode.swift"))
        #expect(source.contains("SocialStore.shared.inviteURL(for: crewID)"))
        #expect(!source.contains("UserDefaults") && !source.contains("CKRecord"))
    }

    @Test("the code is a glyph in the corner of the crew's page, and nothing stands on a crew of one's screen")
    func inviting() throws {
        // The owner, on seeing both (2026-10-13): "I dont like how invite is
        // just there and the qr code can be in the top left".
        let tower = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewTowerView.swift"))
        #expect(!tower.contains("QuietWord(\"Invite\")"))
        let info = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewInfoSheet.swift"))
        #expect(!info.contains("Text(\"Show a Code\")"), "not a row of its own")
        #expect(info.contains("BareToolbarItem(placement: .topBarLeading) {"))
        #expect(info.contains("Image(systemName: \"qrcode\").sheetAction(.confirm, as: .glyph)"))
        #expect(info.contains(".sheet(isPresented: $showsCode) { CrewCodeSheet(crewID: crewID) }"))
        // Invite itself is still a row there.
        #expect(info.contains("Text(\"Invite\")"))
    }

    @Test("a sticker on a win is a star to an older build and the picture to this one")
    func stickerOnAWin() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        let now = Date()
        let win = OwnWin(winID: UUID(), title: "Gym", colour: .health, icon: .health, blockSize: .small,
                         photoJPEG: nil, cropX: nil, cropY: nil, createdAt: now, updatedAt: now)
        await a.post(win, to: [crew.id])
        await b.refresh()
        #expect(await b.react(sticker: sticker(), to: win.winID, in: crew.id) == .sent)
        await a.refresh()
        let seen = try #require(a.reactions(to: win.winID, in: crew.id).first)
        // What a build from before this prints: a star, not "sticker:...".
        #expect(seen.emoji == Reaction.stickerStandIn)
        #expect(!seen.emoji.hasPrefix(Reaction.stickerPrefix))
        #expect(seen.isStickerOnAWin && seen.sketch != nil)
        // An emoji after it replaces it, and the picture goes with the sticker.
        b.now = { Date().addingTimeInterval(5) }
        await b.react("🔥", to: win.winID, in: crew.id)
        let after = try #require(b.reactions(to: win.winID, in: crew.id).first)
        #expect(after.emoji == "🔥" && after.sketch == nil && !after.isStickerOnAWin)
        // Someone who may not send photographs sends no sticker.
        b.photosAllowed = { false }
        b.now = { Date().addingTimeInterval(10) }
        #expect(await b.react(sticker: sticker(), to: win.winID, in: crew.id) == .notAllowed)
        // **The next crew day it is still a sticker** (found by review,
        // 2026-10-13): the clearing of old replies took its picture, and a
        // star nobody chose was left on the win.
        b.photosAllowed = { true }
        b.now = { Date().addingTimeInterval(20) }
        #expect(await b.react(sticker: sticker(), to: win.winID, in: crew.id) == .sent)
        b.now = { Date().addingTimeInterval(86_400 + 120) }
        await b.refresh()
        let nextDay = try #require(b.reactions(to: win.winID, in: crew.id).first)
        #expect(nextDay.isStickerOnAWin, "\(nextDay.emoji), sketch \(nextDay.sketch != nil)")
        // Taken back by its star: the picture goes with it.
        let file = try #require(nextDay.sketch)
        b.now = { Date().addingTimeInterval(86_400 + 200) }
        await b.react(Reaction.stickerStandIn, to: win.winID, in: crew.id)
        #expect(b.reactions(to: win.winID, in: crew.id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        // A friend's is checked as a photograph is, and its file is not one
        // of the win's own, which a new version of the win sweeps away.
        let store = SourceSweep.code(try SourceSweep.read("Strata/Social/SocialStore.swift"))
        #expect(store.contains("reaction.profileID != me && (reaction.isSticker || reaction.isStickerOnAWin)"))
        let winName = win.winID.uuidString, reactionName = Reaction.name(winID: win.winID, profileID: sam)
        #expect(!PublicCrewCloud.stem(.reaction, name: reactionName, tag: "t").hasPrefix(PublicCrewCloud.family(.sharedWin, name: winName)))
        #expect(PublicCrewCloud.stem(.sharedWin, name: winName, tag: "t") == "\(winName)-t")
        #expect(PublicCrewCloud.stem(.crew, name: "crew", tag: "t") == "crew-picture-t")
        // A star somebody picked from the keyboard is a star.
        #expect(!Reaction(winID: UUID(), crewID: crew.id, profileID: sam, emoji: Reaction.stickerStandIn, createdAt: now).isStickerOnAWin)
    }

    @Test("your own win takes your reaction, and nobody is told")
    func reactingToYourOwn() async throws {
        let a = store(jayden), b = store(sam)
        a.sendsPings = true
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        let now = Date()
        let win = OwnWin(winID: UUID(), title: "Gym", colour: .health, icon: .health, blockSize: .small,
                         photoJPEG: nil, cropX: nil, cropY: nil, createdAt: now, updatedAt: now)
        await a.post(win, to: [crew.id])
        let before = world.pings.values.filter { $0[CrewPingRecord.kind] == CrewPingRecord.Kind.reaction.rawValue }.count
        await a.react("🔥", to: win.winID, in: crew.id)
        #expect(a.myReaction(to: win.winID, in: crew.id) == "🔥")
        // The crew sees it as yours.
        await b.refresh()
        #expect(b.reactions(to: win.winID, in: crew.id).map(\.profileID) == [jayden])
        // No push: a reaction's ping goes to the win's owner, never from them.
        #expect(world.pings.values.filter { $0[CrewPingRecord.kind] == CrewPingRecord.Kind.reaction.rawValue }.count == before)
        // And a sticker, the same.
        a.now = { Date().addingTimeInterval(5) }
        #expect(await a.react(sticker: sticker(), to: win.winID, in: crew.id) == .sent)
        // The same emoji again takes it back, as on a friend's.
        a.now = { Date().addingTimeInterval(10) }
        await a.react("🔥", to: win.winID, in: crew.id)
        a.now = { Date().addingTimeInterval(15) }
        await a.react("🔥", to: win.winID, in: crew.id)
        #expect(a.myReaction(to: win.winID, in: crew.id) == nil)
    }

    @Test("the crew's screen shows each plan once: today's proposals, then yours for today, less the closed")
    func plansOnTheCrewScreen() {
        let crew = CrewID(rawValue: "crew-1")
        func plan(_ title: String, _ day: String) -> GroupPlan {
            GroupPlan(id: UUID(), crewID: crew, sender: sam, title: title, when: .day(day))
        }
        let walk = plan("Walk", "2026-10-13"), gym = plan("Gym", "2026-10-14"), walkMine = plan("walk", "2026-10-13")
        let read = plan("Read", "2026-10-13")
        let shown = CrewPlanCards.plans(proposed: [walk, gym], mine: [walkMine, read], closed: [])
        #expect(shown.map(\.title) == ["Walk", "Gym", "Read"])
        #expect(CrewPlanCards.plans(proposed: [walk, gym], mine: [read], closed: [gym.bookKey]).map(\.title) == ["Walk", "Read"])
        #expect(CrewPlanCards.plans(proposed: [], mine: [], closed: []).isEmpty)
        #expect(CrewPlanCards.most == 2)
        let tower = SourceSweep.code((try? SourceSweep.read("Strata/Views/Crews/CrewTowerView.swift")) ?? "")
        // Floating under the header, so nothing on the page moves.
        // Under the header's bar, never in it: in it, I'm In took no touch.
        #expect(tower.contains(".pinnedBar({ header }, below: {"))
        #expect(tower.contains("CrewPlanCards(crewID: crewID, refresh: plansRefresh)"))
        #expect(!tower.contains("header.overlay(alignment: .bottom)"))
    }

    @Test("a crew's week: this week and last, only with wins in them, titled with the crew")
    func weeks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // Tuesday 13 October 2026.
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 12)))
        let days = [CrewStats.HeldDay(key: "2026-10-13", count: 2), CrewStats.HeldDay(key: "2026-10-12", count: 3),
                    CrewStats.HeldDay(key: "2026-10-08", count: 4), CrewStats.HeldDay(key: "2026-10-05", count: 1)]
        let weeks = CrewStatsSections.weeks(days: days, today: today, calendar: calendar, name: "Roommates")
        #expect(weeks.map(\.title) == ["This Week", "Last Week"])
        #expect(weeks.map(\.count) == [5, 5])
        // This week ends today: days still to come are not empty days in a replay.
        #expect(weeks[0].period.days == ["2026-10-12", "2026-10-13"])
        #expect(weeks[0].period.range(relativeTo: today, locale: Locale(identifier: "en_US")).hasPrefix("Roommates, "))
        #expect(weeks[1].period.days.first == "2026-10-05" && weeks[1].period.days.last == "2026-10-11")
        // Titled with the crew, as its day is; yours is still "Your week".
        #expect(weeks[0].period.title == "Roommates")
        #expect(ReplayPeriod.week(containing: today, calendar: calendar).title == "Your week")
        // A week with nothing in it is not offered.
        #expect(CrewStatsSections.weeks(days: [days[0]], today: today, calendar: calendar, name: "R").map(\.title) == ["This Week"])
        #expect(CrewStatsSections.weeks(days: [], today: today, calendar: calendar, name: "R").isEmpty)
        // Last week is always whole inside the fourteen days a crew keeps.
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let last = CrewStatsSections.weeks(days: (0..<14).map { back in
                CrewStats.HeldDay(key: CrewDay.string(for: calendar.date(byAdding: .day, value: -back, to: day)!, in: calendar.timeZone), count: 1)
            }, today: day, calendar: calendar, name: "R").last
            #expect(last?.count == 7, "offset \(offset)")
        }
    }
}
