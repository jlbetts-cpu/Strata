import Foundation
import SwiftUI
import Testing
@testable import Strata

/// **Asked on 2026-10-11**: albums that can be taken off the shelf, photos
/// that can be moved in their frames, a size that stays chosen, hints that
/// wait their turn, and one prompt for the place a plan is written.
@MainActor
@Suite("Albums, crops and hints, 2026-10-11")
struct AlbumsAndCropTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    // MARK: Albums

    @Test("removing an album is this one, or every one of its kind")
    func albumKeys() {
        #expect(RemovedAlbums.key(for: .curated("gym session@2026-10"), today: "2026-10-11") == "curated:gym session@2026-10")
        #expect(RemovedAlbums.familyKey(for: .curated("gym session@2026-10")) == "curated:gym session")
        #expect(RemovedAlbums.key(for: .crew("crew-1@2026-10"), today: "2026-10-11") == "crew:crew-1@2026-10")
        #expect(RemovedAlbums.familyKey(for: .crew("crew-1@2026-10")) == "crew:crew-1")
        // A moment's id is relative ("a year ago today"), so one removed
        // today is today's only.
        #expect(RemovedAlbums.key(for: .moment("onThisDay:1"), today: "2026-10-11") == "moment:onThisDay:1@2026-10-11")
        #expect(RemovedAlbums.familyKey(for: .moment("onThisDay:1")) == "moment:onThisDay")
        // A day had no key while no day's card was ever on the shelf. The
        // flashback (`Flashback`, 2026-10-12) is one, so it has both: today's
        // alone, and the same family as every other look back.
        #expect(RemovedAlbums.key(for: .day("2026-09-11"), today: "2026-10-11") == "day:2026-09-11@2026-10-11")
        #expect(RemovedAlbums.familyKey(for: .day("2026-09-11")) == "moment:onThisDay")
    }

    @Test("a removed album is off the shelf, its kind too when asked, and both come back")
    func albumRemoval() {
        let suite = "albums-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let october = AlbumKind.curated("gym session@2026-10")
        let november = AlbumKind.curated("gym session@2026-11")
        func removed(_ kind: AlbumKind, on day: String = "2026-10-11") -> Bool {
            RemovedAlbums.isRemoved(kind, today: day, in: Set(RemovedAlbums.all(defaults: defaults).keys))
        }
        let one = RemovedAlbums.remove(october, title: "Gym Session", never: false, today: "2026-10-11", defaults: defaults)
        #expect(removed(october) && !removed(november), "this month's only")
        RemovedAlbums.showAgain(try! #require(one), defaults: defaults)
        #expect(!removed(october))
        #expect(defaults.data(forKey: RemovedAlbums.key) == nil, "nothing kept when nothing is removed")
        let all = RemovedAlbums.remove(october, title: "Gym Session", never: true, today: "2026-10-11", defaults: defaults)
        #expect(removed(october) && removed(november), "every month's")
        #expect(RemovedAlbums.all(defaults: defaults)[try! #require(all)]?.never == true)
        // A past day removed today is back tomorrow, unless it was "never".
        let moment = AlbumKind.moment("onThisDay:1")
        RemovedAlbums.remove(moment, title: "A year ago", never: false, today: "2026-10-11", defaults: defaults)
        #expect(removed(moment) && !removed(moment, on: "2026-10-12"))
    }

    @Test("the shelf drops a removed album before its cap, and the card is larger than a photo")
    func shelf() throws {
        let shelf = try code("Strata/Models/MonthShelf.swift")
        #expect(shelf.contains("return Array(shelf.filter { !hidden($0.kind) }.prefix(monthShelfMax))"),
                "removed after the cap leaves a gap instead of the next album")
        #expect(MemoriesShelf.albumWidth == 152)
        let view = try code("Strata/Views/MemoriesShelf.swift")
        #expect(view.contains("Button(\"Remove Album\", systemImage: \"minus.circle\") { onRemove(album, false) }"))
        #expect(try code("Strata/Views/MemoriesView.swift").contains("UndoLine.shared.show(\"Album removed\""))
        #expect(try code("Strata/Views/SettingsView.swift").contains("RemovedAlbumsView()"))
    }

    // MARK: Moving a photo

    @Test("a moved photo never shows past its own edge")
    func cropIsClamped() {
        let photo = CGSize(width: 4000, height: 3000)   // 4:3, wider than a square frame
        let square = CGSize(width: 100, height: 100)
        let range = CropEditor.range(photo: photo, frame: square)
        #expect(abs(range.width - 0.125) < 0.0001 && range.height == 0, "room either side, none above or below")
        #expect(CropEditor.clamped(CGPoint(x: 0.9, y: 0.4), photo: photo, frame: square) == CGPoint(x: range.width, y: 0))
        #expect(CropEditor.clamped(CGPoint(x: -0.9, y: 0), photo: photo, frame: square).x == -range.width)
        #expect(CropEditor.clamped(.zero, photo: photo, frame: square) == .zero)
    }

    @Test("a strip remembers where each photo was moved to")
    func stripCrops() {
        let day = "test-\(UUID().uuidString)"
        let a = UUID(), b = UUID()
        defer { StripKeeping.setCrops([:], .me, day: day) }
        #expect(StripKeeping.crops(.me, day: day).isEmpty)
        StripKeeping.setCrops([a: CGPoint(x: 0.1, y: -0.05), b: .zero], .me, day: day)
        let kept = StripKeeping.crops(.me, day: day)
        #expect(kept[a] == CGPoint(x: 0.1, y: -0.05))
        #expect(kept[b] == nil, "the middle is not kept")
    }

    @Test("Move Photo is on the block's menu and the strip's, and both draw what was chosen")
    func cropIsWired() throws {
        let add = try code("Strata/Views/EditWinSheet.swift")
        #expect(add.contains("Button(\"Move Photo\""))
        // Each call hands over the zoom as well since 2026-10-13, when a
        // photo could be pinched in its frame (`PhotoWindowTests`): the same
        // three wirings, with one more number each.
        #expect(add.contains("CropEditor(image: photo, aspect: cropAspect, crop: crop, zoom: zoom)"))
        #expect(add.contains("CachedImageView.shift(crop: CropEditor.clamped(crop, photo: photo.size, frame: well, zoom: zoom)"),
                "the sheet's block drew the middle whatever the crop was")
        #expect(try code("Strata/Views/Strip/StripEditor.swift").contains("CropEditor(image: frame.picture, aspect: aspect(of: frame.id), crop: frame.crop, zoom: frame.zoom)"))
        #expect(try code("Strata/Views/Strip/StripView.swift").contains("CropEditor.clamped(frame.crop"))
    }

    // MARK: The size, the glass, the hints, the prompt

    @Test("a plain press of the shutter does not undo the size chosen on the sheet")
    func sizeStays() throws {
        #expect(try code("Strata/Views/EditWinSheet.swift").contains("if drawn != .small { size = drawn }"))
    }

    @Test("every hint waits for a clear tower and the ring, and says what the app does")
    func hints() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        // Five since 2026-10-13: tonight's note (`DayNote`) and where a
        // win's note shows (`WinNote`) are said under the header too, and
        // wait as the other three do.
        // Six since 2026-10-17: the day in photos (`QuickAddCue`) waits too.
        // Seven the same night: the first cheer (`FirstCheer`) waits too.
        #expect(main.components(separatedBy: "await Self.waitForRing()").count - 1 == 7)
        #expect(FirstCheer.title.count <= TipCopy.longestMessage)
        #expect(WinNote.hintLine.count <= TipCopy.longestMessage)
        #expect(!main.contains("guard !Task.isCancelled, winDraft == nil, TipStage.shared.holder == nil"))
        #expect(try code("Strata/Views/Crews/FirstWinInviteCard.swift").contains("await MainAppView.waitForRing()"))
        // "Pull", the verb onboarding uses twice for the same gesture: one
        // word for one thing (`docs/ten.md`, rule 4).
        #expect(DayOneHint.drawOut == "Pull the slot sideways or up.")
        #expect(PlannedHint.line == "Tap one to finish it.")
        #expect(PlannedHint.line.count <= TipCopy.longestMessage && DayOneHint.drawOut.count <= TipCopy.longestMessage)
        let onboarding = try code("Strata/Views/OnboardingView.swift")
        #expect(onboarding.contains("if size != .small || reduceMotion { hasDrawn = true }"),
                "with Reduce Motion the first page could not be left")
        #expect(!onboarding.contains("prints the day's strip"), "a day of plain blocks prints none")
    }

    @Test("a planned win is finished the three ways a block is filled, in the add sheet's words")
    func plannedWinFromTheLibrary() throws {
        let outline = try code("Strata/Views/PlannedBlocks.swift")
        let take = try #require(outline.range(of: "Button(\"Take Photo\", systemImage: \"camera\") { onCamera(item) }"))
        let library = try #require(outline.range(of: "Button(\"Choose from Library\", systemImage: \"photo.on.rectangle\") { onLibrary(item) }"))
        let plain = try #require(outline.range(of: "Button(\"Log Without a Photo\", systemImage: \"checkmark\") { onLog(item) }"))
        #expect(take.lowerBound < library.lowerBound && library.lowerBound < plain.lowerBound)
        #expect(outline.contains(".photosPicker(isPresented:"))
        // Through `planned` since 2026-10-13, which a crew's tower shares:
        // the same guard, one place.
        let main = try code("Strata/Views/MainAppView.swift")
        #expect(main.contains("onLibrary: { planned(nil, $0, .library) }"))
        #expect(main.contains("case .library: if stillThere(item), !alreadyWon(item) { pickingPlan = item }"))
    }

    /// It pinned `.id(scheme)`, which remade a glass effect that kept the
    /// tint it was made with. Since 2026-10-13 the pane is not glass (the
    /// owner: no shadow on the + block, and glass draws one that cannot be
    /// switched off): it is the system material, which follows the
    /// appearance by itself. What is pinned is the behaviour: no glass.
    @Test("the slot's pane follows the appearance, and casts no shadow")
    func paneFollowsAppearance() throws {
        let pane = try code("Strata/Views/SlotGlass.swift")
        #expect(pane.contains(".background(.ultraThinMaterial, in: shape)"),
                "the panes stayed dark on a light page until the app was reopened")
        let body = try #require(pane.range(of: "private struct SlotGlassPane"))
        #expect(!pane[body.lowerBound...].contains(".glassEffect("), "the + block is glass again, and glass draws a shadow")
    }

    /// The owner, 2026-10-12: "the tips kinda push the page down for a
    /// second, looks like a glitch. Make sure there isn't anything like
    /// that throughout the app."
    @Test("a tip floats over the page and never moves what is under it")
    func tipsTakeNoRoom() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        // Since 2026-10-13 the header is a bar and the tip is in the bar's
        // own slot under it (`pinnedBar(_:below:)`): an overlay that
        // overflowed the bar was drawn and took no touch. Still no room in
        // the layout, which is what this test is about.
        #expect(main.contains(".pinnedBar({ towerHeader }, below: {"),
                "the tower's tip is stacked in the header's inset again, and the page jumps when it arrives")
        #expect(!main.contains("towerHeader\n                    winsTip"))
        #expect(!main.contains("towerHeader\n                    .overlay(alignment: .bottom)"), "inside a bar that takes no touch")
        let edge = try code("Strata/Views/ScrollEdge.swift")
        #expect(edge.contains(".overlay(alignment: .top) {\n                below().padding(.top, barFoot)"))
        let memories = try code("Strata/Views/MemoriesView.swift")
        #expect(memories.contains("@State private var showsMonthTip = MonthDrawingTip().shouldDisplay"),
                "the month's tip is decided after the page is up, and the month moves down for it")
        #expect(!memories.contains("showsMonthTip = status == .available"), "it can arrive mid-visit again")
    }

    @Test("the place a plan is written says the same thing in both sheets")
    func onePrompt() throws {
        #expect(PlanScope.day(0).prompt() == "Plan for today")
        #expect(PlanScope.day(1).prompt() == "Plan for tomorrow")
        #expect(PlanScope.repeating.prompt() == "Plan something that repeats")
        #expect(try code("Strata/Views/DaySheet.swift").contains("private var planPlaceholder: String { planScope.prompt() }"))
        #expect(try code("Strata/Views/EditWinSheet.swift").contains("planFor?.prompt() ?? \"What did you do?\""))
    }

    @Test("your three are not listed twice, not offered while planning, and reachable from the plan")
    func yourThreeConnected() throws {
        let lines = try code("Strata/Views/PlanLines.swift")
        #expect(lines.contains("three.filter { !planned.contains("))
        #expect(lines.contains("Button(\"Change Your Three\", systemImage: \"pencil\") { choosingThree = true }"))
        #expect(try code("Strata/Views/EditWinSheet.swift").contains("if !isEditing, !isPlanning, !ideas.isEmpty { ideaRow }"))
    }
}

/// **A time, typed into a plan line** (the owner, 2026-10-11: "gym @ 2 ...
/// super simple and optional").
@MainActor
@Suite("A time in a plan line")
struct PlanTimeTests {
    @Test("the end of the line is read as a time, the way a person planning a day means it")
    func parses() {
        #expect(PlanTime.parse("Gym @ 2") == .init(title: "Gym", minutes: 14 * 60))
        #expect(PlanTime.parse("gym @2:30") == .init(title: "gym", minutes: 14 * 60 + 30))
        #expect(PlanTime.parse("Class @ 9") == .init(title: "Class", minutes: 9 * 60), "nine is the morning")
        #expect(PlanTime.parse("Run @ 7pm") == .init(title: "Run", minutes: 19 * 60))
        #expect(PlanTime.parse("Call Mum at 6") == .init(title: "Call Mum", minutes: 18 * 60))
        #expect(PlanTime.parse("Flight @ 14:05") == .init(title: "Flight", minutes: 14 * 60 + 5))
        #expect(PlanTime.parse("Sleep @ 12am") == .init(title: "Sleep", minutes: 0))
        #expect(PlanTime.parse("Lunch @ 12") == .init(title: "Lunch", minutes: 12 * 60))
    }

    @Test("a line with no time is exactly what was typed")
    func leavesTheRestAlone() {
        for line in ["Gym", "Email sam@school.edu", "Lunch at Sam's", "Read chapter 2", "@ 2", "Meet @ 25", "Run @ 2:75", "Top 10"] {
            #expect(PlanTime.parse(line) == nil, "\(line) is not a line with a time")
            #expect(PlanTime.title(line) == line)
        }
    }

    @Test("the win is called by the line without its time, and a win by that name ticks it")
    func titleAndTick() {
        #expect(PlanTime.title("Gym @ 2") == "Gym")
        let today = DateUtils.date(from: "2026-10-10")!
        let line = PlanItem(text: "Gym @ 2", order: 0, day: "2026-10-10")
        #expect(DayComposing.onPlan("gym", in: [line], on: today, calendar: .current) === line)
        #expect(DayComposing.onPlan("Gym @ 2", in: [line], on: today, calendar: .current) === line)
    }

    @Test("the time is shown under the line with its days, and on the hour reads short")
    func shown() {
        let locale = Locale(identifier: "en_US")
        #expect(PlanTime.label(14 * 60, locale: locale).replacingOccurrences(of: "\u{202F}", with: " ") == "2 PM")
        #expect(PlanTime.label(14 * 60 + 30, locale: locale).replacingOccurrences(of: "\u{202F}", with: " ") == "2:30 PM")
        let line = PlanItem(text: "Gym @ 2", order: 0)
        line.repeatDays = [2, 4, 6]
        let subtitle = PlanLines.subtitle(for: line, calendar: .current) ?? ""
        #expect(subtitle.hasSuffix(" · Mon Wed Fri") && subtitle.contains("2"))
        #expect(PlanLines.subtitle(for: PlanItem(text: "Gym", order: 0), calendar: .current) == nil)
    }
}
