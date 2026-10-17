import XCTest

/// **The stories standard, measured** (`docs/stories-standard.md`). Each test
/// is one rule of it, driven with real input on a seeded night, read back
/// from the card's own spoken label ("Ana's story, 2 of 3, ...") and its
/// frame. A page is 5 seconds, so every wait here is longer than a page:
/// if the timer ran while you were busy, the label has moved on.
final class StoryStandardTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Longer than a page (`StoryPage.pageLength`, 5s) and the slack a busy
    /// simulator adds.
    private let pastAPage: TimeInterval = 7

    private func night(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "1",
                                "-strataStartTab", "crews", "-strataSeedStories", "3", "-strataStoryHour", "21",
                                "-strataStorySeen", "1", "-cameraTimerSeconds", "0"] + extra
        app.launch()
        return app
    }

    /// Into the first friend's story, past the night's opening.
    @discardableResult
    private func openFirstStory(_ app: XCUIApplication) -> XCUIElement {
        let head = app.buttons.matching(NSPredicate(format: "value == 'New story'")).firstMatch
        XCTAssertTrue(head.waitForExistence(timeout: 30), "no friend with a new story in the row")
        head.tap()
        let card = self.card(app)
        if !card.waitForExistence(timeout: 3) {
            // The opening, once a night: a tap begins.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        if !card.waitForExistence(timeout: 8) {
            snap("std-never-opened")
            XCTFail("the story never opened")
        }
        return card
    }

    /// A screenshot kept with the result, to be looked at, not counted.
    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func card(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements.matching(NSPredicate(format: "label CONTAINS 'story, ' AND label CONTAINS ' of '")).firstMatch
    }

    /// "Ana's story, 2 of 3": who and which page, without the rest.
    private func where_(_ app: XCUIApplication) -> String {
        let label = card(app).label
        let parts = label.components(separatedBy: ", ")
        return parts.prefix(2).joined(separator: ", ")
    }

    /// Rule 1: the story waits while the "..." menu is open.
    func testStoryWaitsWhileItsMenuIsOpen() {
        let app = night()
        openFirstStory(app)
        let before = where_(app)
        app.buttons["Story actions"].firstMatch.tap()
        Thread.sleep(forTimeInterval: pastAPage)
        let during = where_(app)
        // Away, without choosing anything.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        print("STORYSTD menu before='\(before)' during='\(during)'")
        XCTAssertEqual(before, during, "the story moved on under its own menu")
    }

    /// Rule 1: the story waits while the reply's + menu is open.
    func testStoryWaitsWhileThePlusMenuIsOpen() {
        let app = night()
        openFirstStory(app)
        let before = where_(app)
        let plus = app.buttons.matching(NSPredicate(format: "label == 'Add' OR label == 'More' OR identifier == 'plus'")).firstMatch
        if plus.exists { plus.tap() } else {
            // The + is the first control of the reply row.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.07, dy: 0.935)).tap()
        }
        snap("std-plus-open")
        Thread.sleep(forTimeInterval: pastAPage)
        let during = where_(app)
        print("STORYSTD plus before='\(before)' during='\(during)' sticker=\(app.buttons["Send a Doodle"].exists)")
        XCTAssertEqual(before, during, "the story moved on under the + menu")
    }

    /// Rules 1 and 2: typing holds the story, and the keyboard does not
    /// squeeze the picture.
    func testTypingHoldsTheStoryAndTheCardKeepsItsSize() {
        let app = night()
        let card = openFirstStory(app)
        let before = where_(app)
        let frame = card.frame
        let field = app.textFields.matching(NSPredicate(format: "label BEGINSWITH 'Reply to'")).firstMatch
        let view = field.exists ? field : app.textViews.matching(NSPredicate(format: "label BEGINSWITH 'Reply to'")).firstMatch
        XCTAssertTrue(view.exists, "no reply field")
        view.tap()
        Thread.sleep(forTimeInterval: 1.5)
        snap("std-keyboard-focused")
        app.typeText("so good")
        let typing = card.frame
        snap("std-keyboard-typing")
        Thread.sleep(forTimeInterval: pastAPage)
        let during = where_(app)
        print("STORYSTD keyboard before=\(frame) typing=\(typing) where '\(before)' -> '\(during)'")
        XCTAssertEqual(before, during, "the story moved on while typing")
        XCTAssertEqual(frame.height, typing.height, accuracy: 2, "the keyboard squeezed the story card")
        XCTAssertEqual(frame.minY, typing.minY, accuracy: 2, "the keyboard moved the story card")
    }

    /// Rule 1, slowly, as a parent would: a hold of eight seconds, let go,
    /// and the story is still on the page it was.
    func testAHoldOfEightSecondsKeepsThePage() {
        let app = night()
        let card = openFirstStory(app)
        let before = where_(app)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).press(forDuration: 8)
        let after = where_(app)
        print("STORYSTD hold '\(before)' -> '\(after)'")
        XCTAssertEqual(before, after, "a long hold lost the page")
    }

    /// Rule 5: a quick reaction can be reached over the field, sends, and
    /// says so in the field's own place.
    func testAQuickReactionSaysItWasSent() {
        let app = night()
        openFirstStory(app)
        let field = app.textFields.matching(NSPredicate(format: "label BEGINSWITH 'Reply to'")).firstMatch
        let view = field.exists ? field : app.textViews.matching(NSPredicate(format: "label BEGINSWITH 'Reply to'")).firstMatch
        view.tap()
        let fire = app.buttons["🔥"].firstMatch
        XCTAssertTrue(fire.waitForExistence(timeout: 3), "no quick reactions over the field")
        XCTAssertTrue(fire.isHittable, "the quick reactions cannot be tapped")
        fire.tap()
        var said = ""
        for _ in 0..<10 where !said.contains("Sent") {
            said = (view.placeholderValue ?? "") + " " + (view.value as? String ?? "")
            if !said.contains("Sent") { Thread.sleep(forTimeInterval: 0.1) }
        }
        snap("std-reacted")
        print("STORYSTD reacted '\(said)'")
        XCTAssertTrue(said.contains("Sent"), "nothing said the reaction was sent")
    }

    /// Rules 6 and 7, the other way: left alone, a photograph's page still
    /// goes on in about five seconds, its picture ready, and the waits added
    /// for a slow picture never stall it.
    func testLeftAloneItGoesOn() {
        let app = night()
        openFirstStory(app)
        let before = where_(app)
        Thread.sleep(forTimeInterval: pastAPage)
        let after = where_(app)
        snap("std-left-alone")
        print("STORYSTD alone '\(before)' -> '\(after)'")
        XCTAssertNotEqual(before, after, "left alone, the story never went on")
    }
}
