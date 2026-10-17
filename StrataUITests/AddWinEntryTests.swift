import XCTest

/// **Add a Win opens the camera card every single time** (the owner,
/// 2026-10-18: "pressing + on the Wins tower and on a crew tower sometimes
/// opens the OLD Add a Win sheet instead ... and the camera doesn't open").
/// Pressed again and again, from the tower and from a crew's tower, with the
/// crew's chat resting at its foot: the card's shutter is there and can be
/// pressed, and the old sheet never comes.
final class AddWinEntryTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-cameraTimerSeconds", "0", "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES",
                               "-strataFakeLens", "/Users/jaydenbetts/Developer/Strata/docs/site/memories.mp4"] + extra
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The card is up and its shutter can be pressed; the old sheet is not.
    private func expectCard(_ app: XCUIApplication, _ when: String) {
        let shutter = app.buttons["Take photo"].firstMatch
        let up = shutter.waitForExistence(timeout: 4) && shutter.isHittable
        let old = app.navigationBars.staticTexts["Add a win"].exists || app.staticTexts["Add a win"].exists
        print("ADDWIN \(when) card=\(up) old=\(old)")
        if !up || old { snap("addwin-fail-\(when)") }
        XCTAssertTrue(up, "\(when): the camera card did not open")
        XCTAssertFalse(old, "\(when): the old Add a Win sheet opened")
    }

    /// The card's own X, the one that can be pressed (the card stands in a
    /// window of its own over the app's, so a Close under it is in the list
    /// too).
    private func closeCard(_ app: XCUIApplication) {
        let all = app.buttons.matching(identifier: "Close").allElementsBoundByIndex
        print("ADDWIN closes \(all.map { "\($0.frame) hit=\($0.isHittable)" })")
        if let close = all.first(where: { $0.isHittable }) { close.tap() }
        Thread.sleep(forTimeInterval: 1.2)
        let gone = !app.buttons["Take photo"].firstMatch.exists
        print("ADDWIN closed=\(gone)")
        XCTAssertTrue(gone, "the card's close did not close it")
    }

    func testTheTowerSlotOpensTheCardEveryTime() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3"])
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        let slot = app.buttons["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 4)
        for i in 1...5 {
            let ready = slot.waitForExistence(timeout: 3) && slot.isHittable
            if !ready { snap("addwin-slot-blocked-\(i)") }
            print("ADDWIN slot-ready-\(i) \(ready)")
            slot.tap()
            Thread.sleep(forTimeInterval: 1.0)
            expectCard(app, "tower-\(i)")
            closeCard(app)
        }
        // Pressed twice quickly: still the card, never the sheet.
        // By position: once the card is up it covers the slot, as it should.
        let at = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        at.tap(); at.tap()
        Thread.sleep(forTimeInterval: 1.0)
        expectCard(app, "tower-double")
        closeCard(app)
    }

    func testACrewTowerSlotOpensTheCardEveryTime() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataCrews", "1", "-strataSeedCrew", "3",
                          "-strataSeedCrews", "2", "-strataSeedCrewWins", "6", "-strataOpenCrew", "0"])
        let slot = app.buttons["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 5)
        snap("addwin-crew-tower")
        for i in 1...4 {
            app.buttons["Log a win"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 1.2)
            expectCard(app, "crew-\(i)")
            if i == 1 { snap("addwin-crew-card") }
            closeCard(app)
        }
    }
}
