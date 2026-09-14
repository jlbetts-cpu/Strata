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
