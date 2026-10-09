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
            "-strataSeedPlaces", "1",
            // The map is a push from Memories now, behind a tap, so landing on
            // the tab no longer shows it; these three waited 40s for a probe
            // on a screen that was never opened.
            "-strataOpenMap", "1"
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

        // **The waiting pill is NOT a button, and that is the fix rather than a
        // regression.** It used to be a `Button` with `.disabled(true)`, which
        // a plain button style dims by halving its whole label: the ring
        // measured 188 on 243 and the word 176 on 243, both exactly half their
        // declared alpha, which is the "the button is lowkey invisible during
        // the onboarding flow" the owner reported twice. `PrimaryCapsule`'s
        // waiting state builds no `Button` at all, so there is nothing for a
        // `.disabled` to be put on.
        //
        // So the assertion moves rather than relaxing: it used to be "the
        // button exists and is disabled", and it is now "the button does not
        // exist yet, and the waiting label is on screen in its place". Both
        // halves can fail. If the pill ever becomes pressable before a block
        // is drawn, the first assertion catches it.
        let next = app.buttons["What else"]
        let waiting = app.staticTexts["What else"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 40), "the tutorial page never appeared")
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(next.exists, "the page let you past before you drew anything")

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

    /// A clean first run, all the way through, ending on the tower.
    ///
    /// **This is what a reviewer does first**, and until now nothing checked
    /// it: every other test in this project launches with harness flags that
    /// skip onboarding entirely, so the one path every single user takes was
    /// the one path never exercised.
    ///
    /// **Rewritten for the rebuilt onboarding** (2026-10-08, `docs/superpowers/
    /// specs/2026-10-08-onboarding-rebuild-design.md`). The film opens it; the
    /// try-it board is the first page; the camera, map, Your three and first-win
    /// pages are gone (the owner: "that should be explained in the app"). So
    /// the walk is Skip, draw a block, What else, Not now, One more thing, Set
    /// my goal, and the join it asserts is the tower with its slot ready: the
    /// first win is now made on the real tower, not queued from onboarding.
    func testAFirstRunEndsOnTheTower() throws {
        let app = XCUIApplication()
        // Deliberately no `-strataShowOnboarding`: this has to be the real
        // first-launch path, decided by `hasOnboarded`.
        app.launchArguments += ["-strataResetOnboarding", "1", "-strataResetStore", "1"]
        app.launch()

        // The film, which a person can leave from its first frame.
        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 45), "a clean launch did not open on the film")
        skip.tap()
        Thread.sleep(forTimeInterval: 2)

        // The tutorial will not let you past until a block is drawn OUT.
        let slot = app.descendants(matching: .any)["Log a win"]
        XCTAssertTrue(slot.waitForExistence(timeout: 15), "no slot on the tutorial page")
        let start = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 160, dy: 0)))
        Thread.sleep(forTimeInterval: 2)

        XCTAssertTrue(app.buttons["What else"].waitForExistence(timeout: 15), "no What else button")
        app.buttons["What else"].tap()
        Thread.sleep(forTimeInterval: 2)

        // The head page. Its primary opens the head maker, which needs a front
        // camera and cannot run here; "Not now" moves on without one. A
        // simulator that already holds a head (an earlier test made one) shows
        // "One more thing" instead, since there is nothing to offer.
        let onFromHead = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@", "Not now", "One more thing")).firstMatch
        XCTAssertTrue(onFromHead.waitForExistence(timeout: 15),
                      "no head page. On screen: \(app.buttons.allElementsBoundByIndex.prefix(12).map(\.label))")
        onFromHead.tap()
        Thread.sleep(forTimeInterval: 2)

        XCTAssertTrue(app.buttons["One more thing"].waitForExistence(timeout: 15), "no thank-you page")
        app.buttons["One more thing"].tap()
        Thread.sleep(forTimeInterval: 2)

        // The day's goal, its number left at the default. The last page.
        XCTAssertTrue(app.buttons["Set my goal"].waitForExistence(timeout: 15), "no goal page")
        app.buttons["Set my goal"].tap()
        dismissSystemAlerts(app)
        // CLAUDE.md: allow ~16s after the app comes up before expecting the
        // tower. A shorter wait catches the loading skeleton.
        Thread.sleep(forTimeInterval: 18)

        // **The join.** Onboarding hands over to the tower, and the tower's
        // own slot is where the first win is made. If the hand-off breaks, a
        // new user lands somewhere with nothing to press.
        // The empty tower is its own branch (`towerEmptyStateMessage` hung on
        // the slot) and carries no `todaysTower` identifier, so the join is
        // the line that only an empty Wins tab shows, and its slot, pressable.
        let hint = app.staticTexts["Tap the slot to log today's first win."]
        let firstSlot = app.buttons["Log a win"]
        if !(hint.waitForExistence(timeout: 30) && firstSlot.waitForExistence(timeout: 10)
             && firstSlot.isHittable) {
            XCTFail("the first run did not end on the tower with its slot. Tree: \(app.debugDescription.prefix(6000))")
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
