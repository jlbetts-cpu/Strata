import XCTest

/// The replay's two gestures and its close button, actually pressed.
///
/// A replay's picture is a function of its clock, so the clock is what these
/// read: `-strataReplayProbe` publishes `t`, the close's start and the
/// duration as one accessibility element. A screenshot cannot tell a pause
/// from a replay that simply had nothing moving.
final class ReplayGestureTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private struct Clock { let t: Double; let closeStart: Double; let duration: Double }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataOpenReplay", "sampleWeek", "-strataReplayProbe"]
        app.launch()
        return app
    }

    private func probe(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["replayProbe"]
    }

    private func clock(_ app: XCUIApplication) -> Clock {
        let parts = probe(app).label.split(separator: " ").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 3, "probe label unreadable: \(probe(app).label)")
        return Clock(t: parts[0], closeStart: parts[1], duration: parts[2])
    }

    /// Somewhere on the tower, clear of the close button and the controls.
    private func middle(_ app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    }

    /// A screenshot kept in the xcresult, to look at rather than trust.
    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testTapSkipsToTheClose() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        let before = clock(app)
        XCTAssertLessThan(before.t, before.closeStart - 3, "too late to tell a skip from playback")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 0.6)
        let after = clock(app)
        XCTAssertGreaterThanOrEqual(after.t, after.closeStart - 0.001,
                                    "a tap at t=\(before.t) left the clock at \(after.t), not the close (\(after.closeStart))")
    }

    @MainActor
    func testHoldPausesAndReleaseResumes() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        let start = Date()
        let before = clock(app)
        middle(app).press(forDuration: 3.0)
        let held = clock(app)
        let wall = Date().timeIntervalSince(start)
        // Unpaused, the clock would have run the whole wall time. Paused, it
        // runs only the hold delay plus the reads either side.
        XCTAssertLessThan(held.t - before.t, wall - 2.0,
                          "clock ran \(held.t - before.t)s of \(wall)s wall during a 3s hold")
        XCTAssertLessThan(held.t, held.closeStart, "releasing a hold skipped to the close")
        Thread.sleep(forTimeInterval: 1.5)
        let resumed = clock(app)
        XCTAssertGreaterThan(resumed.t - held.t, 1.0, "the clock did not resume after the hold (\(held.t) -> \(resumed.t))")
        // Read again after a wait: a skip fired by the release could land
        // after the first read.
        XCTAssertLessThan(resumed.t, resumed.closeStart, "releasing a hold skipped to the close")
        // And the hold is forgotten: the next plain tap still skips.
        middle(app).tap()
        Thread.sleep(forTimeInterval: 0.6)
        let tapped = clock(app)
        XCTAssertGreaterThanOrEqual(tapped.t, tapped.closeStart - 0.001, "a tap after a hold did not skip (t \(tapped.t))")
    }

    /// A press just past the hold delay (0.2s): long enough to pause, too
    /// long to be a tap. Its release must not skip.
    @MainActor
    func testShortHoldReleaseIsNotASkip() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        let before = clock(app)
        XCTAssertLessThan(before.t, before.closeStart - 5, "too late to tell a skip from playback")
        middle(app).press(forDuration: 0.35)
        Thread.sleep(forTimeInterval: 0.8)
        let after = clock(app)
        XCTAssertLessThan(after.t, after.closeStart, "a 0.35s press skipped to the close (t \(before.t) -> \(after.t))")
        XCTAssertGreaterThan(after.t, before.t, "the clock did not run on after a 0.35s press")
    }

    @MainActor
    func testCloseButtonCloses() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        // A fixed wait and a plain read, not `expectation(for:evaluatedWith:)`:
        // that form timed out once with the cover already gone.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(probe(app).exists, "the replay is still showing after Close (t \(probe(app).exists ? probe(app).label : "-"))")
    }

    /// Share, at the close: a control under the tower is the control's tap,
    /// not the player's. Before the close its hit testing is off, so a tap
    /// on the same spot is still a skip.
    @MainActor
    func testShareAtTheCloseIsNotASkip() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        let share = app.buttons["Share"]
        let early = clock(app)
        XCTAssertLessThan(early.t, early.closeStart - 3, "too late to check Share before the close")
        // Before the close Share is drawn at opacity 0 and its hit testing is
        // off, but it is still an accessibility element (ShareLink does not
        // take `accessibilityHidden`), so `isHittable` cannot answer. Press
        // where it is instead: that must be the player's skip, not a sheet.
        XCTAssertTrue(share.waitForExistence(timeout: 5), "no Share in the tree. On screen: \(app.debugDescription)")
        // Its frame can read as zero for the first moments of play (seen
        // once in three runs), so wait for layout rather than tap (0, 0).
        var spot = share.frame
        for _ in 0..<20 where spot.width == 0 {
            Thread.sleep(forTimeInterval: 0.15)
            spot = share.frame
        }
        XCTAssertGreaterThan(spot.width, 0, "Share has no frame before the close")
        XCTAssertLessThan(clock(app).t, early.closeStart - 1, "waited for Share's frame until too near the close")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: spot.midX, dy: spot.midY)).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let closed = clock(app)
        XCTAssertGreaterThanOrEqual(closed.t, closed.closeStart - 0.001,
                                    "a tap on Share's spot before the close was not a skip (t \(early.t) -> \(closed.t))")
        XCTAssertFalse(app.otherElements["ActivityListView"].exists, "a tap before the close opened the share sheet")
        XCTAssertTrue(share.isHittable, "Share is at the close but not hittable: \(share.frame)")
        keep(app, "close-with-share")

        let before = clock(app)
        share.tap()
        let sheet = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        let appeared = sheet.waitForExistence(timeout: 8) || copy.exists
        let after = clock(app)
        XCTAssertTrue(appeared, "tapping Share showed no share sheet. On screen: \(app.debugDescription)")
        keep(app, "share-sheet")
        // Finished, the clock sits at the end. A skip could not move it and a
        // pause would hold it below; either way it must read the same.
        XCTAssertEqual(after.t, before.t, accuracy: 0.001, "tapping Share moved the clock \(before.t) -> \(after.t)")
        XCTAssertEqual(after.t, after.duration, accuracy: 0.001, "the replay was not left finished (t \(after.t))")

        // Put the sheet away and check the replay is still there under it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        if sheet.exists { sheet.swipeDown(velocity: .fast) }
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(sheet.exists, "the share sheet did not go away")
        XCTAssertTrue(probe(app).exists, "dismissing the share sheet closed the replay")
    }

    /// After the close, a block with a photograph opens it in the photo
    /// viewer. Before the close, the same tap is a skip.
    ///
    /// A real week of seeded history, not the sample: sample wins carry
    /// bundled pictures, which are not in the store and open nothing.
    @MainActor
    func testTapABlockAfterTheCloseOpensItsPhoto() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataResetStore", "1", "-strataSeedHistory", "20",
                               "-strataOpenReplay", "lastWeek", "-strataReplayProbe"]
        app.launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 45), "the replay never started")
        let blockProbe = app.descendants(matching: .any)["replayPhotoBlock"]
        XCTAssertTrue(blockProbe.exists, "last week has no block with a stored photograph")
        let viewerClose = app.buttons["Close photo"]

        let early = clock(app)
        XCTAssertLessThan(early.t, early.closeStart - 1, "too late to tell a skip from playback")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let skipped = clock(app)
        XCTAssertGreaterThanOrEqual(skipped.t, skipped.closeStart - 0.001, "a tap before the close was not a skip")
        XCTAssertFalse(viewerClose.exists, "a tap before the close opened a photograph")

        let parts = blockProbe.label.split(separator: " ").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 4, "block probe unreadable: \(blockProbe.label)")
        keep(app, "close-before-block-tap")
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: parts[0], dy: parts[1]))
        point.tap()
        XCTAssertTrue(viewerClose.waitForExistence(timeout: 8),
                      "tapping the photo block at (\(parts[0]), \(parts[1])) opened nothing. On screen: \(app.debugDescription)")
        Thread.sleep(forTimeInterval: 1.0)
        keep(app, "photo-from-block")
        viewerClose.tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(viewerClose.exists, "the photo viewer did not close")
        XCTAssertTrue(probe(app).exists, "closing the photograph closed the replay too")
    }

    /// Settings' preview rows play the real replay.
    @MainActor
    func testSettingsPreviewPlays() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataOpenSheet", "settings", "-strataReplayProbe"]
        app.launch()
        let row = app.buttons["Preview Your Month"]
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 30), "no Preview Your Month row in Settings")
        row.tap()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 15), "the preview did not start")
        let c = clock(app)
        XCTAssertGreaterThan(c.duration, 20, "a month preview should run a month's length, got \(c.duration)s")
    }
}
