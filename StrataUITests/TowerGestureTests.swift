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
        // Two known labels, not every element on screen. Enumerating
        // `allElementsBoundByIndex` races the accessibility tree — it resolves
        // a count, then indexes, and the snapshot can change in between
        // ("No matches found for Element at index 46"). Two blocks moving is
        // all the evidence a scroll needs.
        ["Walk", "Sketch"].compactMap { title -> String? in
            let e = app.staticTexts[title].firstMatch
            guard e.exists else { return nil }
            return "\(title)@\(Int(e.frame.midY))"
        }
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
        XCTAssertTrue(app.staticTexts["4"].waitForExistence(timeout: 20),
                      "tally did not start at 4")

        // Out to the side is "medium" — 46pt is GridConstants.slotStep.
        let start = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let out = start.withOffset(CGVector(dx: 70, dy: 0))
        start.press(forDuration: 0.15, thenDragTo: out,
                    withVelocity: .slow, thenHoldForDuration: 0.5)

        XCTAssertTrue(app.staticTexts["5"].waitForExistence(timeout: 15),
                      "dragging the slot out and releasing logged nothing")
    }

    /// The FIRST slot of the day grows as you draw it out.
    ///
    /// The empty tower is its own code path — `emptyTowerSlot` rather than the
    /// slot inside the packed grid — and it used to draw a hard-coded 1x1
    /// whatever size you had dragged out. The drop was the right size, so
    /// nothing about the RESULT was wrong; only the preview was, and every
    /// day starts on this screen, so it was the first thing anyone saw the
    /// gesture do.
    ///
    /// **The gesture runs on a background queue and the frame is read from
    /// the test thread**, because `press(forDuration:thenDragTo:)` blocks
    /// until the finger lifts — by which point the block has dropped and the
    /// slot is back to one cell. There is no way to measure a live preview
    /// from inside the call that produces it.
    @MainActor
    func testTheFirstSlotOfTheDayGrowsAsItIsDrawn() throws {
        let app = XCUIApplication()
        // `-strataSeedWins` at all is what makes the harness wipe the store
        // first, so 0 is how an empty tower is asked for — not by omitting it.
        app.launchArguments = ["-strataStartTab", "tower",
                               "-strataSeedWins", "0",
                               "-strataSeedHabits", "0",
                               "-strataSeedUnlabeled", "0"]
        app.launch()
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        let slot = app.buttons["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 40), "no first slot on an empty tower")
        Thread.sleep(forTimeInterval: 10)
        // The whole point is the EMPTY tower's own code path, so a test that
        // ran against a tower with blocks in it would pass without ever
        // reaching the thing it is checking.
        // The empty state's own copy, not the tally: the header combines its
        // children for VoiceOver, so the numeral is not a `staticText` of its
        // own to match on.
        XCTAssertTrue(app.staticTexts["Nothing yet today"].waitForExistence(timeout: 10),
                      "the tower is not empty, so this is not the first slot of the day")

        let before = slot.frame.width
        XCTAssertGreaterThan(before, 0, "the slot has no width to grow from")

        // Sampled on a background queue while the gesture runs here. It is
        // this way round because event synthesis throws
        // "Must be called on the main thread" off it — measured, and the
        // reason this test is not the other way round.
        //
        // One sample could land either side of the spring, so it keeps the
        // widest the slot is ever seen at rather than a single reading.
        let widest = Sampler(element: slot, start: before)
        let sampling = expectation(description: "sampling finished")
        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(4.5)
            while Date() < deadline {
                widest.observe()
                Thread.sleep(forTimeInterval: 0.15)
            }
            sampling.fulfill()
        }

        let start = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15,
                    thenDragTo: start.withOffset(CGVector(dx: 70, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 4.0)
        wait(for: [sampling], timeout: 15)

        XCTAssertGreaterThan(widest.value, before * 1.5,
                             "the first slot of the day did not grow while being drawn out "
                             + "(\(before)pt at rest, \(widest.value)pt widest during the drag)")
    }

    /// The widest an element has been seen at, sampled off the test thread.
    private final class Sampler: @unchecked Sendable {
        private let element: XCUIElement
        private let lock = NSLock()
        private var widest: CGFloat

        init(element: XCUIElement, start: CGFloat) {
            self.element = element
            self.widest = start
        }

        func observe() {
            let w = element.frame.width
            lock.lock(); widest = max(widest, w); lock.unlock()
        }

        var value: CGFloat {
            lock.lock(); defer { lock.unlock() }; return widest
        }
    }

    /// Holds the slot open so a screenshot burst can catch its press state.
    ///
    /// Not an assertion — XCUITest cannot photograph the middle of its own
    /// gesture. It exists so `simctl io screenshot` running alongside can, and
    /// the pixels get judged outside. Skipped unless asked for by name.
    @MainActor
    func testHoldTheSlotForACapture() throws {
        guard ProcessInfo.processInfo.environment["STRATA_HOLD_SLOT"] != nil else {
            throw XCTSkip("diagnostic only")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataSeedWins", "3"]
        app.launch()
        let slot = app.buttons["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 40), "no next slot")
        Thread.sleep(forTimeInterval: 14)
        slot.press(forDuration: 6.0)
    }

    // MARK: - Plan

    /// Pressing a plan line's block opens the add sheet with the line already
    /// written, and the line survives backing out of that sheet.
    ///
    /// The second half is the part worth testing: the item is deleted when the
    /// win SAVES, not when the block is pressed, so cancelling must not lose
    /// what you typed.
    @MainActor
    func testAPlanLineOpensTheAddSheetPrefilled() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataSeedWins", "3",
                               "-strataSeedPlan", "5"]
        app.launch()

        let line = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Send the invoice'")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 40), "the plan did not open")
        line.tap()

        // The add sheet's title field. Its LABEL is the placeholder; the text
        // in it is its VALUE — asserting on the label finds nothing however
        // well the pre-fill works.
        let field = app.textFields["What did you do?"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "the add sheet did not open")
        XCTAssertEqual(field.value as? String, "Send the invoice",
                       "the title was not pre-filled from the plan line")

        // Back out. The line must still be there — checked, because pressing
        // the block is what finishes it, but not gone.
        app.swipeDown(velocity: .fast)
        Thread.sleep(forTimeInterval: 3)
        let plan = app.buttons["Plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 15),
                      "did not get back to the tower after the add sheet")
        plan.tap()
        let back = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Send the invoice'")).firstMatch
        if !back.waitForExistence(timeout: 15) {
            add(XCTAttachment(screenshot: XCUIScreen.main.screenshot()))
            XCTFail("cancelling the add sheet threw the plan line away")
            return
        }

        // And it is CHECKED. Pressing the block is what finishes a line — the
        // add sheet that follows is an offer to also put it on the tower, so
        // cancelling that must not un-finish it. The bullet's label carries
        // the state.
        XCTAssertTrue(back.label.contains("done"),
                      "the line came back unchecked: \(back.label)")
    }

    // MARK: - Memories

    private func launchMemories(days: Int = 60, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "memories",
                               "-strataSeedHistory", "\(days)"] + extra
        app.launch()
        dismissSystemAlerts()
        return app
    }

    /// Clears the permission prompts a fresh install re-arms.
    ///
    /// `simctl privacy grant camera` does not suppress them, and an
    /// interruption monitor only fires on the next interaction — which meant
    /// `app.tap()`, and that landed on an album card and pushed a detail
    /// screen. Three tests failed looking for elements that were one
    /// navigation level behind them. Tapping Springboard's own button is
    /// deterministic and touches nothing in the app.
    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let allow = springboard.buttons["Allow"]
            guard allow.waitForExistence(timeout: 4) else { return }
            allow.tap()
        }
    }

    /// The whole point of the tab: a photograph taken last week has to be
    /// reachable.
    ///
    /// It used to assert `staticTexts["Today"]`. That stopped being true when
    /// albums went photographs-only — the seed deliberately gives today no
    /// photo, so today produces no card at all. The shelf's own labels are
    /// what to wait on now.
    @MainActor
    func testAnAlbumOpensAndComesBack() throws {
        let app = launchMemories()

        // `waitForExistence` on the element itself, not `waitFor…` on a
        // sibling and then `.exists` on this one. The shelf is a `LazyHStack`,
        // so its cards enter and leave the accessibility tree as it settles,
        // and a bare `exists` after a sleep is exactly the race CLAUDE.md
        // already documents — it failed here first time out.
        let album = app.buttons.matching(NSPredicate(format: "label CONTAINS 'PHOTOS'")).firstMatch
        XCTAssertTrue(album.waitForExistence(timeout: 40), "no album card found")

        // Assert on the shelf going away rather than on `navigationBars`.
        // The destination does have a navigation bar — verified by opening one
        // directly with `-strataOpenCurated` — but the root hides its own with
        // `.toolbar(.hidden,)`, and querying for one is a probe pointed at the
        // wrong thing: it says nothing about whether the push happened.
        let shelfLabel = app.staticTexts["ALBUMS"]
        XCTAssertTrue(shelfLabel.waitForExistence(timeout: 10),
                      "the shelf was not on screen to begin with")
        album.tap()
        expectation(for: NSPredicate(format: "exists == false"),
                    evaluatedWith: shelfLabel, handler: nil)
        waitForExpectations(timeout: 15)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(app.staticTexts["Memories"].waitForExistence(timeout: 15),
                      "could not get back to the shelf")
    }

    /// A day in the month tower opens that day.
    ///
    /// This is the one that matters for the month picker: first-fit packing is
    /// not monotonic, so the blocks are not in reading order and every one of
    /// them has to be its own destination.
    @MainActor
    func testAMonthBlockOpensItsDay() throws {
        let app = launchMemories()
        let block = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Day '")).firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 40), "no day blocks in the month tower")
        Thread.sleep(forTimeInterval: 3)
        block.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15),
                      "tapping a month block opened nothing")
    }

    /// The picker steps back, and refuses to step past the current month.
    @MainActor
    func testTheMonthPickerStepsAndStopsAtToday() throws {
        let app = launchMemories()
        let forward = app.buttons["Next month"]
        XCTAssertTrue(forward.waitForExistence(timeout: 40), "no month picker")
        Thread.sleep(forTimeInterval: 3)

        // Nothing later than this month exists, so forward starts disabled.
        XCTAssertFalse(forward.isEnabled,
                       "the picker offered a month that has not happened yet")

        let back = app.buttons["Previous month"]
        XCTAssertTrue(back.isEnabled, "60 days of seed should reach a previous month")
        back.tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(forward.isEnabled, "stepping back did not re-enable forward")
    }

    /// The picker still works once the month has scrolled under it.
    ///
    /// This is the part of the layout that could not be asserted from reading
    /// it. A busy month is over a thousand points tall, so the chevrons are
    /// only reachable because the picker is a pinned section header — and a
    /// pinned header that is also a control is exactly where taps fall through
    /// to the content sliding beneath it.
    @MainActor
    func testTheMonthPickerStaysUsableWhileScrolled() throws {
        let app = launchMemories()
        let back = app.buttons["Previous month"]
        XCTAssertTrue(back.waitForExistence(timeout: 40), "no month picker")
        Thread.sleep(forTimeInterval: 3)

        // Scroll the month up under the header.
        for _ in 0..<3 { app.swipeUp() }
        Thread.sleep(forTimeInterval: 1)

        XCTAssertTrue(back.exists, "the picker did not stay pinned")
        XCTAssertTrue(back.isHittable, "the pinned picker is not hittable")
        back.tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.buttons["Next month"].isEnabled,
                      "the pinned chevron did not change the month — taps are falling through")
    }

    /// Search filters the record without touching the store.
    // Search went with the paged album grid (2026-09-09). The month tower
    // reaches every day and the gallery reaches every photograph, so the third
    // list of the same record — and the field over it — were clutter. If
    // search returns it needs its own test.

    /// A photo opens by tapping its BLOCK, and the glass close button shuts it.
    ///
    /// The day screen used to carry a photo grid under the tower — a second
    /// copy of the same pictures. The photo is on the block; you tap the block.
    /// This is also the only way to prove the Liquid Glass close button is
    /// hittable, since `.glassEffect` sits between the glyph and the touch.
    @MainActor
    func testAPhotoOpensFromABlockAndCloses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "memories",
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
        //
        // The query is re-evaluated on every pass rather than snapshotted with
        // `allElementsBoundByIndex` up front: the tower is still settling, the
        // accessibility tree changes under a held array, and this test failed
        // once and passed on a re-run with identical code. That is the trap
        // CLAUDE.md names.
        // Tap BLOCKS, by the seed's own title set — not "the first eight
        // static texts", which is mostly the header and which stopped finding
        // a photograph at all once the fixture was made sparse enough to
        // exercise the curated rule. Blocks are matched by the same predicate
        // that waits for the tower above.
        let close = app.buttons["Close photo"]
        let blocks = app.staticTexts.matching(
            NSPredicate(format: "label IN {'Sketch','Deep work','Walk','Inbox zero','Called Mum','Ten minutes','Stretched','Read a chapter','Tidied desk','Ran 5k','Wrote it down','Cooked dinner'}")
        )
        var opened = false
        for index in 0..<max(blocks.count, 1) {
            let block = blocks.element(boundBy: index)
            guard block.exists, block.isHittable else { continue }
            block.tap()
            if close.waitForExistence(timeout: 4) { opened = true; break }
        }
        XCTAssertTrue(opened, "tapping the blocks never opened a photo")

        // Saving is the one thing anybody wants to do with a photograph they
        // are looking at, and it has to be a visible button rather than a
        // gesture — anything hidden is a thing nobody finds.
        let save = app.buttons["Save to Photos"]
        XCTAssertTrue(save.waitForExistence(timeout: 5),
                      "the viewer offers no way to save the photo")
        save.tap()
        XCTAssertTrue(app.buttons["Saved to Photos"].waitForExistence(timeout: 20),
                      "saving to Photos did not report success")

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
