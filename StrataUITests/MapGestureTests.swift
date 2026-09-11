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

    /// Dragging the filmstrip changes the photograph.
    ///
    /// The strip has always scrolled; what it did not do was SELECT, so the
    /// only way through a month was tap, look, tap, look. This is behind a
    /// drag, so a screenshot cannot settle it.
    func testDraggingTheFilmstripChangesThePhotograph() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-strataStartTab", "history",
            "-strataSeedHistory", "50",
            "-strataOpenDrawer", "full",
            "-strataOpenPhoto", "0"
        ]
        app.launch()

        // The viewer's caption names the photograph, so it is what changing.
        let caption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "·")
        ).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 45), "the photo viewer never opened")
        Thread.sleep(forTimeInterval: 4)
        let before = caption.label

        // **By identifier, not by shape.** This used to hunt for "the short
        // scroll view nearest the bottom", which stopped finding anything the
        // moment the strip stopped being a scroll view — and it stopped being
        // one so it could track the deck continuously rather than jumping
        // after each page settled.
        // SwiftUI hands the identifier to the descendants too, so `firstMatch`
        // lands on a 46pt thumbnail and swiping it does nothing. The strip is
        // the WIDEST thing carrying the name.
        let named = app.descendants(matching: .any).matching(identifier: "filmstrip")
        guard named.firstMatch.waitForExistence(timeout: 15) else {
            XCTFail("no element identified as filmstrip. On screen: \(app.debugDescription)")
            return
        }
        let candidates = (0..<named.count).map { named.element(boundBy: $0) }
        guard let strip = candidates.max(by: { $0.frame.width < $1.frame.width }) else {
            XCTFail("filmstrip matched nothing measurable")
            return
        }
        strip.swipeLeft()
        Thread.sleep(forTimeInterval: 3)

        XCTAssertNotEqual(before, caption.label,
                          "dragging the filmstrip \(strip.frame) did not change the "
                          + "photograph")
    }

    /// The onboarding slot resizes under the finger, like the tower's.
    ///
    /// The owner reported this twice: "the resize hold block is still not
    /// resizing like it should, it should actually just act like the tower in
    /// the main app." It was pinned inside a fixed square, so `onSizeChanged`
    /// had nowhere to go. This drags it out for real and checks the page
    /// unlocks — which it only does when a block bigger than 1x1 was drawn.
    func testOnboardingSlotDrawsABiggerBlock() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-strataShowOnboarding", "1", "-strataOnboardingStep", "1"]
        app.launch()

        let next = app.buttons["What else"]
        XCTAssertTrue(next.waitForExistence(timeout: 40), "the tutorial page never appeared")
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(next.isEnabled, "the page let you past before you drew anything")

        // **Find the slot, do not guess where it is.** It used to be centred;
        // it now stands at the tower's first free position, which is
        // bottom-left — so a drag from the middle of the screen missed it
        // entirely and the test reported the feature broken when the aim was.
        // `NextSlotButton` labels itself "Log a win".
        let slot = app.descendants(matching: .any)["Log a win"]
        XCTAssertTrue(slot.waitForExistence(timeout: 15), "no slot on the tutorial page")
        XCTAssertTrue(slot.isHittable, "the slot is in the tree but not on screen")
        let start = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 160, dy: 0))
        start.press(forDuration: 0.5, thenDragTo: end)
        Thread.sleep(forTimeInterval: 3)

        XCTAssertTrue(next.isEnabled,
                      "drawing a bigger block did not unlock the page — the slot is not resizing")
    }

    /// A clean first run, all the way through, ending on a tower with a block
    /// on it.
    ///
    /// **This is what a reviewer does first**, and until now nothing checked
    /// it: every other test in this project launches with harness flags that
    /// skip onboarding entirely, so the one path every single user takes was
    /// the one path never exercised. It walks the five pages, draws a real
    /// block on the tutorial, and then asserts the welcome win actually landed
    /// on the tower — which is the join between onboarding and the app, and
    /// the thing most likely to be quietly broken.
    func testAFirstRunEndsOnATowerWithABlockOnIt() throws {
        let app = XCUIApplication()
        // Deliberately no `-strataShowOnboarding`: this has to be the real
        // first-launch path, decided by `hasOnboarded`.
        // A first run means a store that has never been used. Without this
        // the test passes alone and fails in a suite, because an earlier test
        // has already left wins on the tower and the welcome block — which may
        // only ever be created once — is correctly skipped.
        app.launchArguments += ["-strataResetOnboarding", "1", "-strataResetStore", "1"]
        app.launch()

        XCTAssertTrue(app.buttons["Let me try"].waitForExistence(timeout: 45),
                      "a clean launch did not open onboarding")
        app.buttons["Let me try"].tap()
        Thread.sleep(forTimeInterval: 2)

        // The tutorial will not let you past until a block is drawn OUT.
        let slot = app.descendants(matching: .any)["Log a win"]
        XCTAssertTrue(slot.waitForExistence(timeout: 15), "no slot on the tutorial page")
        let start = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 160, dy: 0)))
        Thread.sleep(forTimeInterval: 2)

        for label in ["What else", "Go on"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 15), "no \(label) button")
            app.buttons[label].tap()
            Thread.sleep(forTimeInterval: 2)
        }
        // The map page's button asks for location when it can.
        let onward = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@", "Turn on places", "One more thing")).firstMatch
        XCTAssertTrue(onward.waitForExistence(timeout: 15), "no button on the map page")
        onward.tap()
        Thread.sleep(forTimeInterval: 3)
        dismissSystemAlerts(app)

        // **The head page, which did not exist when this test was written.**
        // Onboarding gained a step: `lastStep` went 4 to 5. Its primary button
        // opens the head maker, which needs a front camera and therefore
        // cannot run here at all — "Not now" is the secondary that moves on
        // without one, and is the only path a simulator has.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 10) {
            notNow.tap()
            Thread.sleep(forTimeInterval: 2)
        }

        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 15), "no Start button")
        app.buttons["Start"].tap()
        // CLAUDE.md: allow ~16s after the app comes up before expecting the
        // tower. A shorter wait catches the loading skeleton, and here it
        // caught a screen with no static text on it at all.
        Thread.sleep(forTimeInterval: 22)

        // **The join.** Onboarding queues the welcome win; `MainAppView` logs
        // it against the active tower. If that hand-off breaks, a new user
        // lands on an empty tower and the whole endowed-progress idea is
        // silently gone.
        let welcome = app.staticTexts["Welcome"]
        if !welcome.waitForExistence(timeout: 30) {
            // Dump the tree rather than guess. `XCTFail(app.debugDescription)`
            // is the only channel that reaches the xcodebuild log — test
            // `print` does not — and CLAUDE.md records that it has settled
            // two long-running failures in minutes after hours of theorising.
            let labels = app.staticTexts.allElementsBoundByIndex
                .prefix(30).map(\.label).joined(separator: " | ")
            XCTFail("the first run ended on a tower with no block on it. On screen: \(labels)")
        }
    }

    /// Location and camera prompts can land on top of the flow.
    private func dismissSystemAlerts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once", "OK", "Allow"] {
            let button = springboard.buttons[label]
            if button.exists { button.tap(); Thread.sleep(forTimeInterval: 1) }
        }
    }

    /// Swiping the picture moves to the next one.
    ///
    /// The owner: "the photos screen swiping to the right or left should move
    /// through the photos, right now it doesnt." The deck is a paging
    /// `ScrollView`, and its layout was rewritten today so the header overlays
    /// it — which is exactly the kind of change that can take a gesture with
    /// it without anything erroring. This is the assertion that would have
    /// caught that.
    func testSwipingThePictureMovesThroughTheDeck() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-strataStartTab", "history",
            "-strataSeedHistory", "40",
            "-strataOpenDrawer", "full",
            "-strataOpenPhoto", "3"
        ]
        app.launch()

        let caption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "·")
        ).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 45), "the photo viewer never opened")
        Thread.sleep(forTimeInterval: 4)
        let before = caption.label

        // Swipe across the PICTURE, not the strip: the middle of the screen.
        let middle = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.42))
        middle.press(forDuration: 0.02,
                     thenDragTo: app.windows.firstMatch
                        .coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.42)))
        Thread.sleep(forTimeInterval: 3)

        XCTAssertNotEqual(before, caption.label,
                          "swiping the picture did not move to the next photograph")
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
