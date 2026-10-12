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

    @Test("removing an album is this one, or every one of its kind, and never a day")
    func albumKeys() {
        #expect(RemovedAlbums.key(for: .curated("gym session@2026-10"), today: "2026-10-11") == "curated:gym session@2026-10")
        #expect(RemovedAlbums.familyKey(for: .curated("gym session@2026-10")) == "curated:gym session")
        #expect(RemovedAlbums.key(for: .crew("crew-1@2026-10"), today: "2026-10-11") == "crew:crew-1@2026-10")
        #expect(RemovedAlbums.familyKey(for: .crew("crew-1@2026-10")) == "crew:crew-1")
        // A moment's id is relative ("a year ago today"), so one removed
        // today is today's only.
        #expect(RemovedAlbums.key(for: .moment("onThisDay:1"), today: "2026-10-11") == "moment:onThisDay:1@2026-10-11")
        #expect(RemovedAlbums.familyKey(for: .moment("onThisDay:1")) == "moment:onThisDay")
        #expect(RemovedAlbums.key(for: .day("2026-10-11"), today: "2026-10-11") == nil)
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
        let add = try code("Strata/Views/AddWinSheet.swift")
        #expect(add.contains("Button(\"Move Photo\""))
        #expect(add.contains("CropEditor(image: photo, aspect: cropAspect, crop: crop)"))
        #expect(add.contains("CachedImageView.shift(crop: CropEditor.clamped(crop, photo: photo.size, frame: well)"),
                "the sheet's block drew the middle whatever the crop was")
        #expect(try code("Strata/Views/Strip/StripEditor.swift").contains("CropEditor(image: frame.picture, aspect: aspect(of: frame.id), crop: frame.crop)"))
        #expect(try code("Strata/Views/Strip/StripView.swift").contains("CropEditor.clamped(frame.crop"))
    }

    // MARK: The size, the glass, the hints, the prompt

    @Test("a plain press of the shutter does not undo the size chosen on the sheet")
    func sizeStays() throws {
        #expect(try code("Strata/Views/AddWinSheet.swift").contains("if drawn != .small { size = drawn }"))
    }

    @Test("every hint waits for a clear tower and the ring, and says what the app does")
    func hints() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        #expect(main.components(separatedBy: "await Self.waitForRing()").count - 1 == 3)
        #expect(!main.contains("guard !Task.isCancelled, winDraft == nil, TipStage.shared.holder == nil"))
        #expect(try code("Strata/Views/Crews/FirstWinInviteCard.swift").contains("await MainAppView.waitForRing()"))
        #expect(DayOneHint.drawOut == "Drag the slot sideways or up.")
        #expect(PlannedHint.line == "Tap to take it. Hold for more.")
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
        #expect(try code("Strata/Views/MainAppView.swift").contains("onLibrary: { if stillThere($0), !alreadyWon($0) { pickingPlan = $0 } }"))
    }

    @Test("the slot's glass is made again when the appearance changes")
    func paneFollowsAppearance() throws {
        #expect(try code("Strata/Views/SlotGlass.swift").contains(".id(scheme)"),
                "the panes stayed dark on a light page until the app was reopened")
    }

    @Test("the place a plan is written says the same thing in both sheets")
    func onePrompt() throws {
        #expect(PlanScope.day(0).prompt() == "Plan for today")
        #expect(PlanScope.day(1).prompt() == "Plan for tomorrow")
        #expect(PlanScope.repeating.prompt() == "Plan something that repeats")
        #expect(try code("Strata/Views/DaySheet.swift").contains("private var planPlaceholder: String { planScope.prompt() }"))
        #expect(try code("Strata/Views/AddWinSheet.swift").contains("planFor?.prompt() ?? \"What did you do?\""))
    }

    @Test("your three are not listed twice, not offered while planning, and reachable from the plan")
    func yourThreeConnected() throws {
        let lines = try code("Strata/Views/PlanLines.swift")
        #expect(lines.contains("three.filter { !planned.contains("))
        #expect(lines.contains("Button(\"Change Your Three\", systemImage: \"pencil\") { choosingThree = true }"))
        #expect(try code("Strata/Views/AddWinSheet.swift").contains("if !isEditing, !isPlanning, !ideas.isEmpty { ideaRow }"))
    }
}
