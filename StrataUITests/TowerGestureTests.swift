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
        return app
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

}
