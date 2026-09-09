import XCTest

/// Gestures, actually driven.
///
/// The rest of this project verifies through `simctl` launch arguments because
/// nothing on the build machine can tap a simulator — `osascript` has no
/// accessibility permission. That limit does not apply here: XCUITest drives
/// the simulator through the test runner, so a press, a drag and a swipe are
/// all reachable. Anything behind a finger gets tested in this file.
final class TowerGestureTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(wins: Int, tab: String = "tower") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", tab, "-strataSeedWins", "\(wins)"]
        app.launch()
        if tab == "tower" { ensureWinsTab(app) }
        return app
    }

    /// `-strataStartTab` races the TabView's own default selection, and the
    /// app now opens on the camera — so a test that wants the tower has to be
    /// willing to press the tab itself rather than assume it landed there.
    private func ensureWinsTab(_ app: XCUIApplication) {
        if app.staticTexts["Walk"].firstMatch.waitForExistence(timeout: 25) { return }
        let wins = app.buttons["Wins"]
        if wins.waitForExistence(timeout: 5) { wins.tap() }
        _ = app.staticTexts["Walk"].firstMatch.waitForExistence(timeout: 25)
    }

    /// Proves the runner can reach the app at all before anything else is
    /// claimed on the strength of it.
    @MainActor
    func testSmokeTowerRenders() throws {
        let app = launch(wins: 6)
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 30),
                      "no seeded block on screen")
    }

    /// The tower reads bottom-up, so blocks sorted by DESCENDING y are in
    /// tower order: the first one placed is the lowest on screen.
    private func towerOrder(_ app: XCUIApplication, of titles: [String]) -> [String] {
        titles
            .map { (title: $0, y: app.staticTexts[$0].firstMatch.frame.midY) }
            .filter { $0.y > 0 }
            .sorted { $0.y > $1.y }
            .map(\.title)
    }

    /// The regression that made this whole gesture a bad trade: a tower you
    /// could no longer scroll. Nothing about the reorder is worth having if
    /// this fails.
    /// Every y position a given title occupies, low to high.
    ///
    /// Not `firstMatch`: a seeded tower repeats its titles, so "the first Walk"
    /// is a different element before and after a scroll and its position can
    /// come back unchanged by coincidence. The whole set has to shift when the
    /// content moves.
    private func rowYs(_ app: XCUIApplication, _ title: String) -> [CGFloat] {
        app.staticTexts.matching(NSPredicate(format: "label == %@", title))
            .allElementsBoundByIndex
            .map(\.frame.midY)
            .sorted()
    }

    /// Every block label on screen with its position — the tower's fingerprint.
    ///
    /// One repeated title is a weak instrument: a seeded tower reuses names, so
    /// "the first Walk" can be a different element before and after a scroll
    /// and come back at a coincidentally similar y. If the content moves at
    /// all, this changes.
    private func towerFingerprint(_ app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex
            .map { "\($0.label)@\(Int($0.frame.midY))" }
            .sorted()
    }

    @MainActor
    func testTowerStillScrollsWithReorderInstalled() throws {
        let app = launch(wins: 44)
        XCTAssertTrue(app.staticTexts["Walk"].firstMatch.waitForExistence(timeout: 30))
        // A seeded tower runs a drop cascade per block. CLAUDE.md's rule is
        // ~16s before believing the screen, and swiping into the tail of that
        // animation is what made this report a scroll bug that was not there.
        Thread.sleep(forTimeInterval: 16)

        let scroller = app.scrollViews.firstMatch
        XCTAssertTrue(scroller.exists, "no scroll view on the tower at all")

        let before = towerFingerprint(app)
        XCTAssertFalse(before.isEmpty, "no blocks found on the tower")

        scroller.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 2)
        let afterUp = towerFingerprint(app)

        scroller.swipeDown(velocity: .slow)
        Thread.sleep(forTimeInterval: 2)
        let afterDown = towerFingerprint(app)

        XCTAssertTrue(before != afterUp || before != afterDown,
                      "the tower did not scroll in either direction.\nbefore \(before)\nup \(afterUp)")
    }

    /// A tap still opens a block — the lift must not have eaten it.
    @MainActor
    func testTapStillOpensABlock() throws {
        let app = launch(wins: 6)
        let block = app.staticTexts["Walk"].firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 30))
        block.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10)
                      || app.textFields.firstMatch.waitForExistence(timeout: 10),
                      "tapping a block opened nothing")
    }

    /// A hold is not a tap: holding a block must not open its edit sheet.
    ///
    /// It used to. `FlippableBlockView` recognises its tap with
    /// `simultaneousGesture`, which means alongside — so any long press also
    /// counted as a tap and the sheet opened over whatever the press was for.
    @MainActor
    func testHoldDoesNotOpenTheEditSheet() throws {
        let app = launch(wins: 6)
        let block = app.staticTexts["Walk"].firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 6)

        block.press(forDuration: 1.2)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.textFields.firstMatch.exists,
                       "holding a block opened its edit sheet")
    }

    // MARK: - The next slot

    /// Drawing a bigger block and letting go must not shrink the slot first.
    ///
    /// The slot's size comes from the parent's `drawingSize`, and
    /// `NextSlotButton.fire` used to reset that to `.small` the instant the
    /// finger lifted — while the slot was still on screen for the 300ms scroll
    /// settle before the cascade hides it. This drags the slot out to a bigger
    /// size, releases, and films it; the frames are checked separately.
    @MainActor
    func testDrawingABiggerBlockThenReleasing() throws {
        let app = launch(wins: 4)
        let slot = app.buttons["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 30), "no next slot on the tower")
        Thread.sleep(forTimeInterval: 8)

        // The tally, not the block count. A win logged from the slot is
        // untitled, and an untitled block deliberately draws NO text at all —
        // so counting labels cannot see it arrive. The header numeral can.
        XCTAssertTrue(app.staticTexts["4"].exists, "tally did not start at 4")

        // Out to the side is "medium" — 46pt is GridConstants.slotStep.
        let start = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let out = start.withOffset(CGVector(dx: 70, dy: 0))
        start.press(forDuration: 0.15, thenDragTo: out,
                    withVelocity: .slow, thenHoldForDuration: 0.5)

        XCTAssertTrue(app.staticTexts["5"].waitForExistence(timeout: 15),
                      "dragging the slot out and releasing logged nothing")
    }

    // MARK: - History

    private func launchHistory(days: Int = 26) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "insights", "-strataSeedHistory", "\(days)"]
        app.launch()
        return app
    }

    /// The whole point of the tab: a photo taken last week has to be reachable.
    @MainActor
    func testAnAlbumOpensItsDayAndComesBack() throws {
        let app = launchHistory()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 40),
                      "no albums on the History tab")
        Thread.sleep(forTimeInterval: 6)

        // An album's accessibility label carries the day and the win count.
        let album = app.buttons.matching(NSPredicate(format: "label CONTAINS 'wins'")).firstMatch
        XCTAssertTrue(album.exists, "no album card found")
        album.tap()

        XCTAssertTrue(app.staticTexts["PHOTOS"].waitForExistence(timeout: 15)
                      || app.buttons["Wins"].waitForExistence(timeout: 5),
                      "tapping an album opened nothing")

        // Back by the edge swipe rather than the chevron: the day screen
        // hides its navigation title, so `app.navigationBars` finds nothing to
        // reach into.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15),
                      "could not get back to the albums")
    }

    /// Search filters the record without touching the store.
    @MainActor
    func testSearchNarrowsTheAlbums() throws {
        let app = launchHistory()
        let field = app.textFields["Search your wins"]
        XCTAssertTrue(field.waitForExistence(timeout: 40), "no search field")
        Thread.sleep(forTimeInterval: 6)

        let before = app.buttons.matching(NSPredicate(format: "label CONTAINS 'wins'")).count
        XCTAssertGreaterThan(before, 1, "not enough albums to filter")

        field.tap()
        field.typeText("zzzznotathing")
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.staticTexts["Nothing matches that."].waitForExistence(timeout: 10),
                      "a nonsense search still showed albums")
    }

    /// A photo opens by tapping its BLOCK, and the glass close button shuts it.
    ///
    /// The day screen used to carry a photo grid under the tower — a second
    /// copy of the same pictures. The photo is on the block; you tap the block.
    /// This is also the only way to prove the Liquid Glass close button is
    /// hittable, since `.glassEffect` sits between the glyph and the touch.
    @MainActor
    func testAPhotoOpensFromABlockAndCloses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "insights",
                               "-strataSeedHistory", "14", "-strataOpenDay", "2"]
        app.launch()
        // Wait for a BLOCK, not just any text. The header renders before the
        // day's tower is built, so `staticTexts.firstMatch` succeeds while
        // there is still nothing to tap — which is why this passed alone and
        // failed when run after other tests had warmed the store.
        let anyBlock = app.staticTexts.matching(
            NSPredicate(format: "label IN {'Sketch','Deep work','Walk','Inbox zero','Called Mum','Ten minutes','Stretched','Read a chapter','Tidied desk','Ran 5k','Wrote it down','Cooked dinner'}")
        ).firstMatch
        XCTAssertTrue(anyBlock.waitForExistence(timeout: 45),
                      "the day screen never drew its tower")
        Thread.sleep(forTimeInterval: 4)

        // Not every block carries a photo, so try a few. A block with none
        // correctly does nothing, which is why this is a loop and not one tap.
        let close = app.buttons["Close photo"]
        var opened = false
        for label in app.staticTexts.allElementsBoundByIndex.prefix(8) {
            guard label.exists, label.isHittable else { continue }
            label.tap()
            if close.waitForExistence(timeout: 3) { opened = true; break }
        }
        XCTAssertTrue(opened, "tapping the blocks never opened a photo")

        close.tap()
        XCTAssertFalse(close.waitForExistence(timeout: 3),
                       "the glass close button did not dismiss the photo")
    }

    // MARK: - Camera

    /// The grid toggle has to work in BOTH directions. Off is easy; the
    /// reported bug is that it never comes back.
    @MainActor
    func testGridToggleTurnsOffAndBackOn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "camera"]
        app.launch()

        let grid = app.buttons["gridToggle"]
        let timer = app.buttons["timerToggle"]
        XCTAssertTrue(grid.waitForExistence(timeout: 30), "no grid toggle on the camera")
        Thread.sleep(forTimeInterval: 4)

        // Both directions, from whichever state it starts in — the preference
        // persists across launches, so the test must not assume.
        let start = grid.value as? String ?? "?"
        grid.tap(); Thread.sleep(forTimeInterval: 2)
        let flipped = grid.value as? String ?? "?"
        XCTAssertNotEqual(start, flipped, "the grid toggle did nothing")
        grid.tap(); Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(grid.value as? String ?? "?", start,
                       "the grid could not be toggled back — this is the bug where a "
                       + "dimmed control stops taking taps")

        // The timer cycles Off / 3 / 10, as iOS Camera does.
        let t0 = timer.value as? String ?? "?"
        timer.tap(); Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(timer.value as? String ?? "?", t0, "the timer did not change")
    }
}
