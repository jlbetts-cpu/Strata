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

    /// Share, once the replay has finished: a control under the tower is the
    /// control's tap, not the player's. Before the close its hit testing is
    /// off, so a tap on the same spot is still a skip.
    ///
    /// **Share shares the video** (2026-09-15), so the sheet opens only after
    /// the export: the press shows the export's ring first, and the sheet
    /// can take as long as a save.
    ///
    /// **Named for what it can prove: AFTER the close, not during it.** The
    /// close takes 0.46s from `closeStart` to `duration`. Tried: a second
    /// coordinate tap fired straight after the skip opened the sheet, but the
    /// next clock read was already at `duration` (13.948 of 13.948, close at
    /// 13.488), and XCUITest waits for the app to idle between actions, so
    /// there is no way to know or force the tap into that window.
    @MainActor
    func testShareAfterTheCloseIsNotASkip() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        let share = app.buttons["Share"]
        let early = clock(app)
        XCTAssertLessThan(early.t, early.closeStart - 3, "too late to check Share before the close")
        // Before the close Share is drawn at opacity 0 and its hit testing is
        // off, but it is still an accessibility element, so `isHittable`
        // cannot answer. Press where it is instead: that must be the player's
        // skip, not a sheet.
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
        let control = app.descendants(matching: .any).matching(identifier: "shareVideo").firstMatch
        let preparing = control.value as? String ?? ""
        keep(app, "share-preparing")
        let sheet = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        let appeared = sheet.waitForExistence(timeout: 240) || copy.exists
        let after = clock(app)
        XCTAssertTrue(preparing.hasPrefix("Preparing") || appeared,
                      "Share neither showed the export nor opened a sheet (value \(preparing))")
        XCTAssertTrue(appeared, "tapping Share showed no share sheet. On screen: \(app.debugDescription)")
        keep(app, "share-sheet")
        // The clock reads the same either side of the tap and sits at the
        // end: the replay was neither skipped nor left paused.
        XCTAssertEqual(after.t, before.t, accuracy: 0.001, "tapping Share moved the clock \(before.t) -> \(after.t)")
        XCTAssertEqual(after.t, after.duration, accuracy: 0.001, "the replay was not left finished (t \(after.t))")

        // Put the sheet away and check the replay is still there under it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        if sheet.exists { sheet.swipeDown(velocity: .fast) }
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(sheet.exists, "the share sheet did not go away")
        XCTAssertTrue(probe(app).exists, "dismissing the share sheet closed the replay")
    }

    /// Replay, at the close: the clock goes back to the start and plays,
    /// and the controls are out of the way again until the next close.
    @MainActor
    func testReplayRestartsFromTheStart() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let replay = app.buttons["Replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5), "no Replay at the close. On screen: \(app.debugDescription)")
        let closed = clock(app)
        XCTAssertEqual(closed.t, closed.duration, accuracy: 0.001, "the replay had not finished (t \(closed.t))")
        XCTAssertTrue(replay.isHittable, "Replay is at the close but not hittable: \(replay.frame)")

        replay.tap()
        let restarted = clock(app)
        XCTAssertLessThan(restarted.t, 2.0, "Replay left the clock at \(restarted.t)")
        Thread.sleep(forTimeInterval: 1.5)
        let running = clock(app)
        XCTAssertGreaterThan(running.t, restarted.t + 1.0, "the clock did not run after Replay (\(restarted.t) -> \(running.t))")
        XCTAssertLessThan(running.t, running.closeStart, "Replay skipped to the close")
        keep(app, "after-replay")
        // A tap still skips, so the restarted build behaves as the first.
        middle(app).tap()
        Thread.sleep(forTimeInterval: 0.6)
        let skipped = clock(app)
        XCTAssertGreaterThanOrEqual(skipped.t, skipped.closeStart - 0.001, "a tap after Replay did not skip (t \(skipped.t))")
    }

    /// Save Video at the close: the press is the control's, not the player's,
    /// the control says "Saving…" at once, and the save runs through to a
    /// terminal word.
    ///
    /// **The Photos prompt.** Add-only permission is asked for after the
    /// export, as a system alert owned by SpringBoard. `waitForSaveToFinish`
    /// taps its allow button if it appears (an interruption monitor only fires on the
    /// next interaction with the app, and there is none while waiting), so on
    /// a simulator that has never been asked this passes through the prompt,
    /// and on one that has already allowed it there is no prompt at all.
    @MainActor
    func testSaveVideoAtTheCloseIsNotASkip() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let save = app.buttons["Save Video"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "no Save Video at the close. On screen: \(app.debugDescription)")
        XCTAssertTrue(save.isHittable, "Save Video is at the close but not hittable: \(save.frame)")
        let before = clock(app)
        XCTAssertEqual(before.t, before.duration, accuracy: 0.001, "the replay had not finished (t \(before.t))")

        save.tap()
        let control = saveControl(app)
        XCTAssertTrue(waitForLabel(control, "Saving…", timeout: 5), "the control did not change to Saving… (\(control.label))")
        XCTAssertNotEqual(control.elementType, .button, "Saving… does nothing when pressed but is still announced as a button")
        keep(app, "saving")
        let after = clock(app)
        XCTAssertEqual(after.t, before.t, accuracy: 0.001, "pressing Save Video moved the clock \(before.t) -> \(after.t)")
        XCTAssertTrue(probe(app).exists, "pressing Save Video closed the replay")

        let (terminal, prompted) = waitForSaveToFinish(app)
        keep(app, prompted ? "after-photos-prompt" : "after-save")
        XCTAssertEqual(terminal, "Saved to Photos", "Photos prompt seen: \(prompted)")
        let end = clock(app)
        XCTAssertEqual(end.t, end.duration, accuracy: 0.001, "the replay moved during the save (t \(end.t))")
    }

    /// The Save Video control, read by identifier: in its Saving… and Saved
    /// states it is no longer announced as a button.
    private func saveControl(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "saveVideo").firstMatch
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.label == label { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// Waits for Saved to Photos or Couldn't save the video, allowing the
    /// Photos prompt if SpringBoard shows it. Returns the final label.
    private func waitForSaveToFinish(_ app: XCUIApplication, timeout: TimeInterval = 240) -> (String, Bool) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let control = saveControl(app)
        let deadline = Date().addingTimeInterval(timeout)
        var prompted = false
        while Date() < deadline {
            if control.exists, control.label != "Saving…" { return (control.label, prompted) }
            for label in ["Allow Access", "Allow Full Access", "Allow", "OK"] {
                let button = springboard.alerts.buttons[label]
                if button.exists {
                    button.tap()
                    prompted = true
                    break
                }
            }
            Thread.sleep(forTimeInterval: 1)
        }
        return (control.exists ? control.label : "(gone)", prompted)
    }

    /// Opening a block's photograph over the replay mid-save, and closing it
    /// again, does not stop the save: nothing closed the replay.
    @MainActor
    func testSaveVideoSurvivesOpeningAPhoto() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataResetStore", "1", "-strataSeedHistory", "20",
                               "-strataOpenReplay", "lastWeek", "-strataReplayProbe"]
        app.launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 45), "the replay never started")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let save = app.buttons["Save Video"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "no Save Video at the close")
        save.tap()
        let control = saveControl(app)
        XCTAssertTrue(waitForLabel(control, "Saving…", timeout: 5), "the control did not change to Saving… (\(control.label))")

        // "x y w h|file|title"
        let blockProbe = app.descendants(matching: .any)["replayPhotoBlock"]
        XCTAssertTrue(blockProbe.exists, "last week has no block with a stored photograph")
        let parts = blockProbe.label.split(separator: "|").first.map { $0.split(separator: " ").compactMap { Double($0) } } ?? []
        XCTAssertEqual(parts.count, 4, "block probe unreadable: \(blockProbe.label)")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: parts[0], dy: parts[1])).tap()
        let viewerClose = app.buttons["Close photo"]
        XCTAssertTrue(viewerClose.waitForExistence(timeout: 15), "tapping the photo block opened nothing")
        keep(app, "photo-over-save")
        Thread.sleep(forTimeInterval: 1.0)
        viewerClose.tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(probe(app).exists, "closing the photograph closed the replay")
        let midway = control.label
        keep(app, "after-photo-closed")
        // Otherwise the save could have finished before the viewer opened,
        // and the test would prove nothing.
        XCTAssertEqual(midway, "Saving…", "the save was not still running when the photograph closed")

        let (terminal, prompted) = waitForSaveToFinish(app)
        keep(app, "save-after-photo")
        XCTAssertEqual(terminal, "Saved to Photos",
                       "the save did not survive the photo viewer (label after closing it: \(midway), Photos prompt seen: \(prompted))")
    }

    /// Leaving the app mid-save stops it, and the control comes back as Save
    /// Video, not as an error: nothing went wrong.
    @MainActor
    func testLeavingTheAppCancelsTheSaveQuietly() throws {
        let app = launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 30), "the replay never started")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let save = app.buttons["Save Video"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "no Save Video at the close")
        save.tap()
        let control = saveControl(app)
        XCTAssertTrue(waitForLabel(control, "Saving…", timeout: 5), "the control did not change to Saving… (\(control.label))")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.activate()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 10), "the replay was not there on return")
        XCTAssertTrue(waitForLabel(control, "Save Video", timeout: 15),
                      "after leaving the app mid-save the control reads \(control.label), not Save Video")
        keep(app, "after-leaving-mid-save")
        Thread.sleep(forTimeInterval: 1.5)
        keep(app, "after-leaving-mid-save-settled")
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

        // "x y w h|file|title"
        let fields = blockProbe.label.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(fields.count, 3, "block probe unreadable: \(blockProbe.label)")
        let parts = fields[0].split(separator: " ").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 4, "block probe unreadable: \(blockProbe.label)")
        XCTAssertFalse(fields[1].isEmpty, "the probe's block has no stored file")
        let title = fields[2]
        XCTAssertFalse(title.isEmpty, "seeded wins are named; the probe's block has no title")
        keep(app, "close-before-block-tap")
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: parts[0], dy: parts[1]))
        point.tap()
        XCTAssertTrue(viewerClose.waitForExistence(timeout: 8),
                      "tapping the photo block at (\(parts[0]), \(parts[1])) opened nothing. On screen: \(app.debugDescription)")
        Thread.sleep(forTimeInterval: 1.0)
        keep(app, "photo-from-block")
        // The photograph of THAT block, not merely a viewer: its title is the
        // viewer's heading.
        // Measured by position, since the filmstrip below can carry the same
        // title for a different photograph.
        let headings = app.staticTexts.matching(identifier: title).allElementsBoundByIndex
            .filter { $0.frame.minY < 160 }
        XCTAssertFalse(headings.isEmpty,
                       "the viewer's heading is not \"\(title)\" (\(fields[1])). On screen: \(app.debugDescription)")
        viewerClose.tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(viewerClose.exists, "the photo viewer did not close")
        XCTAssertTrue(probe(app).exists, "closing the photograph closed the replay too")
    }

    /// A photograph removed from the viewer a block opened: the replay still
    /// draws the picture it decoded, but the block no longer opens anything,
    /// since the file is gone.
    @MainActor
    func testADeletedPhotoBlockOpensNothing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataResetStore", "1", "-strataSeedHistory", "20",
                               "-strataOpenReplay", "lastWeek", "-strataReplayProbe"]
        app.launch()
        XCTAssertTrue(probe(app).waitForExistence(timeout: 45), "the replay never started")
        middle(app).tap()
        Thread.sleep(forTimeInterval: 1.5)
        let blockProbe = app.descendants(matching: .any)["replayPhotoBlock"]
        XCTAssertTrue(blockProbe.exists, "last week has no block with a stored photograph")
        let fields = blockProbe.label.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let parts = fields[0].split(separator: " ").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 4, "block probe unreadable: \(blockProbe.label)")
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: parts[0], dy: parts[1]))
        let viewerClose = app.buttons["Close photo"]

        point.tap()
        XCTAssertTrue(viewerClose.waitForExistence(timeout: 8), "the block did not open its photograph")
        Thread.sleep(forTimeInterval: 1.0)
        app.buttons["Photo actions"].tap()
        let menuRemove = app.buttons["Remove Photo"].firstMatch
        XCTAssertTrue(menuRemove.waitForExistence(timeout: 5), "no Remove Photo in the viewer's menu")
        menuRemove.tap()
        Thread.sleep(forTimeInterval: 1.0)
        let confirm = app.buttons.matching(identifier: "Remove Photo").allElementsBoundByIndex.last
        XCTAssertNotNil(confirm, "no confirmation for Remove Photo")
        confirm?.tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertFalse(viewerClose.exists, "removing the photograph did not close the viewer")
        XCTAssertTrue(probe(app).exists, "removing the photograph closed the replay")
        keep(app, "after-photo-removed")

        point.tap()
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertFalse(viewerClose.exists, "a block whose photograph was removed opened the viewer again")
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
