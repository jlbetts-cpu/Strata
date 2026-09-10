import XCTest

/// Can you actually move the map?
///
/// Nothing on this machine can tap the simulator with `osascript`, but
/// XCUITest drives it through the test runner and needs no accessibility
/// permission — the same reason `TowerGestureTests` exists. Pinch is the one
/// gesture on the Memories tab that a screenshot cannot settle: the tiles
/// change under a pan too, and the block count only moves when the INTEGER
/// zoom does. So the map publishes its zoom on a 1x1 invisible element and
/// these read it back.
final class MapGestureTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchedOnTheMap() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-strataStartTab", "history",
            "-strataSeedHistory", "50",
            "-strataSeedPlaces", "1"
        ]
        app.launch()
        return app
    }

    private func zoom(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["MapZoomProbe"].label
    }

    func testPinchingOutZoomsTheMapOut() throws {
        let app = launchedOnTheMap()
        let probe = app.descendants(matching: .any)["MapZoomProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 40), "the map never appeared")

        // Let the opening frame settle before touching anything.
        Thread.sleep(forTimeInterval: 6)
        let before = zoom(app)

        // Pinch in the middle of the map, well clear of the title row at the
        // top and the tab bar and recentre button at the bottom.
        let map = app.windows.firstMatch
        map.pinch(withScale: 0.25, velocity: -3)
        Thread.sleep(forTimeInterval: 3)
        let after = zoom(app)

        XCTAssertNotEqual(before, after,
                          "pinching did not change the map's zoom (stayed at \(before))")
    }

    /// Tapping a place opens what is there.
    ///
    /// The whole claim of the map is that a block is a thing you did somewhere
    /// and you can go and look at it. That is behind a tap, so it is
    /// unverifiable by screenshot — which is the standing rule in CLAUDE.md,
    /// and the reason this file exists.
    func testTappingAPlaceOpensItsPhotographs() throws {
        let app = launchedOnTheMap()
        XCTAssertTrue(app.descendants(matching: .any)["MapZoomProbe"]
            .waitForExistence(timeout: 40), "the map never appeared")
        Thread.sleep(forTimeInterval: 6)

        // The blocks carry no visible number any more, so they are found by
        // what they say to VoiceOver.
        let blocks = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "here"))
        XCTAssertTrue(blocks.firstMatch.waitForExistence(timeout: 15),
                      "no place block on the map")

        // **Not `firstMatch`.** Blocks near the edge of the map are half off
        // the screen, and an off-screen element is still in the accessibility
        // tree — `exists` is true and `isHittable` is false. Picking the first
        // match tests whichever block MapKit happened to order first, which is
        // a coin toss.
        let all = (0..<blocks.count).map { blocks.element(boundBy: $0) }
        guard let block = all.first(where: \.isHittable) else {
            let frames = all.map { "\($0.label) \($0.frame)" }.joined(separator: "\n")
            XCTFail("no place block is on screen. \(all.count) in the tree:\n\(frames)")
            return
        }
        block.tap()

        // The photographs from that place. `exists` is not enough — an
        // off-screen element is still in the tree.
        let grid = app.scrollViews.firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 10),
                      "tapping a place opened nothing")
        let images = app.images.count
        XCTAssertGreaterThan(images, 0, "the place opened with no photographs in it")
    }

    func testPinchingInZoomsTheMapIn() throws {
        let app = launchedOnTheMap()
        let probe = app.descendants(matching: .any)["MapZoomProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 40), "the map never appeared")
        Thread.sleep(forTimeInterval: 6)
        let before = zoom(app)

        app.windows.firstMatch.pinch(withScale: 4, velocity: 3)
        Thread.sleep(forTimeInterval: 3)
        let after = zoom(app)

        XCTAssertNotEqual(before, after,
                          "pinching in did not change the map's zoom (stayed at \(before))")
    }
}
