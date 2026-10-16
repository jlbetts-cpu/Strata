import Foundation
import SwiftData
import Testing
@testable import Strata

/// What the owner and two readers found on 2026-10-13, going through the
/// app's flows: a menu opening over the keyboard, a repeating line renamed
/// for one day, and a handful of places a person was left with no way on.
@MainActor
@Suite("Flows: the dead ends found on 2026-10-13", .serialized)
struct FlowFixTests {
    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanItem.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    @Test("in Add a Win, every menu waits for the keyboard to go")
    func menusAfterTheKeyboard() throws {
        let add = try code("Strata/Views/AddWinSheet.swift")
        // The block's menu from a press, from the photo's Replace, and from
        // the hold's two Replaces; and the names of who was there.
        #expect(add.components(separatedBy: "afterKeyboard { choosingSource = true }").count - 1 == 4)
        #expect(add.contains("afterKeyboard { tagging = true }"))
        // None of them opens straight over the keys any more.
        #expect(!add.contains("\n            choosingSource = true\n"))
        #expect(!add.contains("\n            tagging = true\n"))
        // Either field: the name, or (since the same day) a win's note.
        #expect(add.contains("guard titleFocused || noteFocused else { open(); return }"))
    }

    @Test("Add waits for a photo chosen from the library")
    func addWaitsForTheLibrary() throws {
        let add = try code("Strata/Views/AddWinSheet.swift")
        #expect(add.contains("photoLoading = loading"))
        #expect(add.contains("if photoLoading == loading { photoLoading = nil }"))
    }

    @Test("a repeating line renamed is asked about only when there is something to ask")
    func renameAsks() {
        #expect(PlanRename.asks(repeated: true, repeats: true, before: "Gym", now: "Gym with Sam", onToday: true))
        // Not a repeat, or made one in this sitting: there is no "every time" yet.
        #expect(!PlanRename.asks(repeated: false, repeats: true, before: "Gym", now: "Run", onToday: true))
        #expect(!PlanRename.asks(repeated: true, repeats: false, before: "Gym", now: "Run", onToday: true))
        // The same words, or only spaces changed.
        #expect(!PlanRename.asks(repeated: true, repeats: true, before: "Gym", now: " Gym ", onToday: true))
        #expect(!PlanRename.asks(repeated: true, repeats: true, before: "Gym", now: "  ", onToday: true))
        // Not on today's plan: today has nothing to be different from.
        #expect(!PlanRename.asks(repeated: true, repeats: true, before: "Gym", now: "Run", onToday: false))
        // A crew's plan: today's copy would be a line the crew's book does
        // not know, off the crew's tower and no longer the crew's win.
        #expect(!PlanRename.asks(repeated: true, repeats: true, before: "Gym", now: "Run", onToday: true, isCrewPlan: true))
    }

    @Test("just today: the repeating line keeps its name and steps aside, and today has the new one")
    func renameJustToday() throws {
        let ctx = try context()
        let defaults = try #require(UserDefaults(suiteName: "plan-rename-\(UUID().uuidString)"))
        let today = Date()
        let calendar = Calendar.current
        let gym = PlanItem(text: "Gym", order: 3, category: .health)
        gym.repeatDays = [calendar.component(.weekday, from: today)]
        gym.sizeRaw = BlockSize.medium.rawValue
        ctx.insert(gym)
        // As the sheet leaves it: the new words typed straight onto the line.
        gym.text = "Gym with Sam"
        let line = PlanRename.justToday(gym, before: "Gym", context: ctx, today: today, defaults: defaults)
        #expect(gym.text == "Gym" && gym.repeats)
        #expect(PlanSkips.isSkipped(gym.id, on: today, defaults: defaults))
        #expect(line.text == "Gym with Sam" && !line.repeats)
        #expect(line.day == DateUtils.dateString(from: today))
        #expect(line.order == 3 && line.category == .health && line.size == .medium)
        #expect(line.isOpen(on: today, calendar: calendar, today: today))
        // Tomorrow the repeat is itself again, and the one-off is not there.
        let next = calendar.date(byAdding: .day, value: 7, to: today)!
        #expect(!PlanSkips.isSkipped(gym.id, on: next, defaults: defaults))
        #expect(!line.belongs(on: next, calendar: calendar, today: next))
        let all = try ctx.fetch(FetchDescriptor<PlanItem>())
        #expect(all.count == 2)
        let sheet = try code("Strata/Views/PlanItemDetailSheet.swift")
        #expect(sheet.contains("Button(\"Just Today\")") && sheet.contains("Button(\"Every Time\")"))
        // The words are written straight onto the line, so while there is a
        // question the sheet cannot be swiped away past it.
        #expect(sheet.contains(".interactiveDismissDisabled(asksScope)"))
        // What it opened on is read as the sheet is made.
        #expect(sheet.contains("_nameBefore = State(initialValue: item.text)"))
        #expect(sheet.contains("isCrewPlan: GroupPlanBook.crew(forPlanItem: item.id) != nil"))
    }

    @Test("a crew plan pressed on a crew's tower makes a win for that crew alone")
    func crewPlanGoesToItsCrew() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        // Both ways a planned win becomes a draft carry the tower it came from.
        #expect(main.components(separatedBy: "crews: planCrew.map { [$0] }").count == 3)
        #expect(main.contains("private func planned(_ crew: CrewID?, _ item: PlanItem, _ action: PlannedAction) {\n        planCrew = crew"))
        // This page's own boxes say so, so a crew is never left over from before.
        #expect(main.components(separatedBy: "planned(nil, $0, .").count == 6)
        #expect(try code("Strata/Views/Crews/CrewsListView.swift").contains("onPlanned: { planned(id, $0, $1) }"))
    }

    @Test("a strip sent as a picture carries no rim of light")
    func stripHasNoRimInTheChat() throws {
        let story = try code("Strata/Views/Strip/StripStory.swift")
        let flat = try #require(story.range(of: "func flatPNG() -> Data? {"))
        let posed = try #require(story.range(of: "func png() -> Data? {"))
        #expect(flat.lowerBound < posed.lowerBound)
        #expect(story[flat.lowerBound..<posed.lowerBound].contains("rimmed: false"))
        let view = try code("Strata/Views/Strip/StripView.swift")
        #expect(view.contains("if rimmed {\n                        RoundedRectangle(cornerRadius: outerCorner, style: .continuous)\n                            .strokeBorder(BlockRim.gradient(in: colorScheme)"))
    }

    @Test("a somewins.xyz invitation opens the app: the app claims the domain and the site names the app")
    func appLinks() throws {
        let entitlements = try SourceSweep.read("Strata/Strata.entitlements")
        #expect(entitlements.contains("<key>com.apple.developer.associated-domains</key>"))
        #expect(entitlements.contains("<string>\(CrewInviteLink.appLinkDomain)</string>"))
        let host = try #require(URL(string: CrewInviteLink.page)?.host)
        #expect(CrewInviteLink.appLinkDomain == "applinks:\(host)")
        // The site's half: this app, and the invite's own paths only.
        let site = try SourceSweep.read("docs/.well-known/apple-app-site-association")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(site.utf8)) as? [String: Any])
        let details = try #require((json["applinks"] as? [String: Any])?["details"] as? [[String: Any]])
        #expect(details.first?["appIDs"] as? [String] == ["W34J6358L7.JaydenBetts.Strata"])
        let paths = (details.first?["components"] as? [[String: Any]] ?? []).compactMap { $0["/"] as? String }
        #expect(paths == ["/join", "/join.html"])
        #expect(paths.contains(try #require(URL(string: CrewInviteLink.page)?.path)))
        // GitHub publishes the folder only because the site's config says to.
        #expect(try SourceSweep.read("docs/_config.yml").contains("include: [\".well-known\"]"))
        // A strip's link is still the app's page and never an invitation.
        #expect(StripMessageActivity.page == "https://somewins.xyz/")
        #expect(CrewInviteLink.read(try #require(URL(string: StripMessageActivity.page))) == nil)
    }

    @Test("words typed into a field that grows stay inside its glass")
    func writingFieldHoldsItsWords() throws {
        // The first word of a field grown to five lines: 16 in, 8 down
        // (`gapLabel`, `gapTight`), in a box 300 wide and 126 tall.
        let size = CGSize(width: 300, height: 126)
        let word = CGPoint(x: GridConstants.gapLabel, y: GridConstants.gapTight + 2)
        // As a capsule its end is 63 round, and the word is outside it.
        #expect(!GlassField.holds(word, in: size, radius: size.height / 2), "the fault, as reported")
        // Held at one line's half height, the word is inside, at every height.
        for lines in 1...5 {
            let grown = CGSize(width: 300, height: CGFloat(lines) * 22 + 22)
            #expect(GlassField.holds(word, in: grown, radius: GlassField.radius), "\(lines) lines")
            #expect(GlassField.holds(CGPoint(x: word.x, y: grown.height - word.y), in: grown, radius: GlassField.radius))
        }
        #expect(GlassField.radius == GlassIconButton.defaultSide / 2)
        // Every field that grows uses it: the journal's and the plan's bar, and the chat's.
        let bar = try code("Strata/Views/DayComposer.swift")
        #expect(bar.contains(".glassField()") && !bar.contains(".glassCapsule("))
        let chat = try code("Strata/Views/Crews/CrewChatSheet.swift")
        // The field's prompt is the app's ink since 2026-10-15 (the
        // consistency pass), and the field is its own view since the same
        // day (`ChatTextInput`, so a keystroke redraws only the field): the
        // glass goes on at the call site.
        let field = try #require(chat.range(of: "ChatTextInput(field: field, crewID: crewID, writing: $writing)"))
        let after = chat[field.upperBound...].prefix(600)
        #expect(after.contains(".glassField()") && !after.contains(".glassCapsule("))
        // And nothing else that grows sits in a capsule.
        for path in ["Strata/Views/AddWinSheet.swift", "Strata/Views/DayWinNotes.swift", "Strata/Views/PlanItemDetailSheet.swift"] {
            let source = try code(path)
            for piece in source.components(separatedBy: "axis: .vertical").dropFirst() {
                #expect(!piece.prefix(500).contains(".glassCapsule("), "\(path)")
            }
        }
    }

    @Test("an album's cover has no rim of light")
    func albumCoverHasNoRim() throws {
        let cover = try code("Strata/Views/AlbumCoverView.swift")
        #expect(!cover.contains("strokeBorder"))
        #expect(!cover.contains("blockRimWidth"))
    }

    @Test("Not Today says what it did and can be taken back")
    func notTodayUndo() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        #expect(main.contains("UndoLine.shared.show(repeats ? PlanWords.skipped : PlanWords.moved"))
        #expect(main.contains("PlanSkips.unskip(item.id, on: now)"))
        #expect(main.contains("item.day = dayBefore"))
        for line in [PlanWords.moved, PlanWords.skipped] {
            #expect(!line.contains("!") && !line.lowercased().contains("miss"))
        }
    }

    @Test("an invitation is kept until it is answered, for a week from when it was first held, and only a real link")
    func invitationKept() throws {
        let defaults = try #require(UserDefaults(suiteName: "invite-kept-\(UUID().uuidString)"))
        #expect(CrewRouter.kept(defaults: defaults) == nil)
        let key = String(repeating: "A", count: 43)
        let link = try #require(URL(string: "\(CrewInviteLink.page)#crew-0123abcd.\(key)"))
        let router = CrewRouter()
        // Held: written down by the router itself.
        router.hold(CrewInvite(url: link), defaults: defaults)
        #expect(router.pendingInvite?.url == link)
        #expect(CrewRouter.kept(defaults: defaults)?.url == link)
        // The week runs from the first time, however often it is held again.
        let first = Date().addingTimeInterval(-6 * 86_400)
        defaults.set(["url": link.absoluteString, "at": first.timeIntervalSince1970] as [String: Any], forKey: CrewRouter.pendingKey)
        CrewRouter.remember(CrewInvite(url: link), defaults: defaults)
        #expect((defaults.dictionary(forKey: CrewRouter.pendingKey)?["at"] as? Double) == first.timeIntervalSince1970)
        #expect(CrewRouter.kept(now: first.addingTimeInterval(6.5 * 86_400), defaults: defaults) != nil)
        #expect(CrewRouter.kept(now: first.addingTimeInterval(8 * 86_400), defaults: defaults) == nil)
        // A different invitation starts its own week.
        let other = try #require(URL(string: "\(CrewInviteLink.page)#crew-9999ffff.\(key)"))
        CrewRouter.remember(CrewInvite(url: other), defaults: defaults)
        #expect((defaults.dictionary(forKey: CrewRouter.pendingKey)?["at"] as? Double ?? 0) > first.timeIntervalSince1970)
        // Refused or answered: gone.
        router.hold(nil, defaults: defaults)
        #expect(router.pendingInvite == nil && CrewRouter.kept(defaults: defaults) == nil)
        // Something that is not an invitation is never written or taken up.
        let stray = try #require(URL(string: "https://example.com/join#x"))
        router.hold(CrewInvite(url: stray), defaults: defaults)
        #expect(defaults.object(forKey: CrewRouter.pendingKey) == nil)
        defaults.set(["url": stray.absoluteString, "at": Date().timeIntervalSince1970] as [String: Any], forKey: CrewRouter.pendingKey)
        #expect(CrewRouter.kept(defaults: defaults) == nil)
        let source = try code("Strata/Social/StrataAppDelegate.swift")
        // Let go only once it is answered: on a join that worked, or an
        // answer that will not change.
        #expect(source.contains("let crew = try await SocialStore.shared.accept(invite)\n            Self.forget()"))
        #expect(source.contains("if let known = error as? CrewError, known != .notSignedIn { Self.forget() }"))
        // And a join already agreed to does not move the page under you.
        #expect(!source.contains("opensList = true\n            Task { await accept(invite) }"))
        #expect(try code("Strata/StrataApp.swift").contains(".task { CrewRouter.shared.resumePending() }"))
    }

    @Test("Never Show Past Days stops the evening's line too")
    func pastDaysSwitch() throws {
        #expect(PastWinReminder.pastDaysKey == "moment:onThisDay")
        #expect(RemovedAlbums.familyKey(for: .day("2025-10-13")) == PastWinReminder.pastDaysKey)
        let never = RemovedAlbums.Entry(title: "Past Days", at: 0, never: true)
        let once = RemovedAlbums.Entry(title: "Past Days", at: 0, never: false)
        #expect(PastWinReminder.pastDaysOff(in: [PastWinReminder.pastDaysKey: never]))
        // Removed for a day is not switched off.
        #expect(!PastWinReminder.pastDaysOff(in: [PastWinReminder.pastDaysKey: once]))
        #expect(!PastWinReminder.pastDaysOff(in: ["curated:gym": never]))
        #expect(!PastWinReminder.pastDaysOff(in: [:]))
        #expect(try code("Strata/Services/PastWin.swift").contains("note == nil && !Self.pastDaysOff(in: RemovedAlbums.all())"))
    }

    @Test("a crew notification tapped another day still opens its win; the chat's undo line clears the field")
    func crewSmallThings() throws {
        let tower = try code("Strata/Views/Crews/CrewTowerView.swift")
        #expect(tower.contains("let win = store.wins(in: crewID).first(where: { $0.winID == id }) else { return }\n        CrewRouter.shared.openWin = nil"))
        let chat = try code("Strata/Views/Crews/CrewChatSheet.swift")
        let undo = try #require(chat.range(of: ".undoLine()"))
        // The field is under the thread in one column since 2026-10-15, not
        // an inset over it; the undo line still hangs on the thread above it.
        let field = try #require(chat.range(of: "\n            composer\n        }"))
        #expect(undo.lowerBound < field.lowerBound)
        #expect(chat.components(separatedBy: ".undoLine()").count == 2)
    }
}
