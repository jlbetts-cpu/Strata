import XCTest

/// **The old camera's features, in the card** (`docs/camera-parity-2026-10-18.md`).
/// The simulator has no capture device, so a flip, a focus and a real zoom
/// cannot be driven here; the pill, the lens row, the timer's number and the
/// draw-out cue can, with the fake lens and fake lenses.
final class CameraParityTests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openCard(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-strataStartTab", "tower", "-strataSeedWins", "3",
                               "-strataFakeLens", "/Users/jaydenbetts/Developer/Strata/docs/site/memories.mp4",
                               "-strataFakeLenses", "0.5,1,2,3"] + extra
        app.launch()
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        let slot = app.buttons["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 4)
        slot.tap()
        return app
    }

    func testThePillWritesOutTheLenses() {
        let app = openCard(["-cameraTimerSeconds", "0", "-camera.drawCueShown", "0", "-camera.drawTaught", "NO"])
        Thread.sleep(forTimeInterval: 2.4)
        snap("parity-1-open-cue")
        let cue = app.staticTexts["Drag out for a bigger block"].exists
        print("PARITY cue \(cue)")
        XCTAssertTrue(cue, "no draw-out cue on the first visits")
        let pill = app.buttons["Lens, 1x"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 3), "no lens pill")
        pill.tap()
        Thread.sleep(forTimeInterval: 0.8)
        snap("parity-2-lenses")
        let row = ["Lens 0.5x", "Lens 2x", "Lens 3x"].map { app.buttons[$0].exists }
        print("PARITY row \(row)")
        XCTAssertTrue(row.allSatisfy { $0 }, "the lens row did not write out")
    }

    func testTheTimerShowsItsSeconds() {
        let app = openCard(["-cameraTimerSeconds", "3"])
        Thread.sleep(forTimeInterval: 1.4)
        snap("parity-3-timer")
        let more = app.buttons["More"].firstMatch
        print("PARITY timer '\(more.value as? String ?? "")'")
        XCTAssertEqual(more.value as? String, "Timer 3 seconds")
        XCTAssertTrue(app.staticTexts["3"].exists, "the timer's number is not shown")
    }
}
