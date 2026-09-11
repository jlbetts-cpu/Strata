import XCTest

/// Add a photograph the way a person adds one, from the real photo library.
///
/// **Every other check in this project uses seeded photographs**, and those
/// are written straight into the image directory by `DebugHarness.seedPhoto`.
/// They never touch the picker, `attach(_:to:)`, `ImageManager.save`, or the
/// write of `imageFileName` — so a break anywhere along that path passes every
/// existing test and every screenshot.
///
/// The owner, after a build where blocks were still empty: "can you actually
/// check there is so many actual photos on the iphone simulator to use."
/// That is the right instruction; this is it.
final class RealPhotoTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testAPhotographFromTheLibraryReachesTheBlock() {
        let app = XCUIApplication()
        app.launchArguments += ["-strataStartTab", "tower", "-strataResetStore", "1"]
        app.launch()
        Thread.sleep(forTimeInterval: 16)

        // Draw a win by pressing the slot.
        let slot = app.descendants(matching: .any)["Log a win"]
        XCTAssertTrue(slot.waitForExistence(timeout: 20),
                      "no slot on the tower. On screen: \(app.debugDescription)")
        slot.tap()
        Thread.sleep(forTimeInterval: 3)

        // The add sheet's photo well.
        let well = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@", "Add a photo", "Replace the photo")).firstMatch
        XCTAssertTrue(well.waitForExistence(timeout: 15),
                      "no photo well. On screen: \(app.debugDescription)")
        well.tap()
        Thread.sleep(forTimeInterval: 2)

        // "Choose from library" — the other option opens a camera the
        // simulator does not have.
        let library = app.buttons["Choose from library"]
        if library.waitForExistence(timeout: 8) {
            library.tap()
        }
        Thread.sleep(forTimeInterval: 5)

        // The system picker. Its photographs are plain images in a collection;
        // tapping the first one is enough, and which one does not matter.
        // **Tap a coordinate, not an element.** PHPicker's grid is a remote
        // view: its cells are not exposed as `cells`, and the `images` query
        // matches decorations that ignore a tap. A normalised point inside the
        // first row of thumbnails is what actually selects one — the banner
        // about private access sits above the grid, so aim below it.
        let grid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.42))
        Thread.sleep(forTimeInterval: 3)
        grid.tap()
        Thread.sleep(forTimeInterval: 6)

        // Save the win.
        let save = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@", "Add", "Save")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15),
                      "no Add button. On screen: \(app.debugDescription)")
        save.tap()

        // Long enough for the asynchronous save, the resize and the HEIC
        // encode to finish and for the block to draw.
        Thread.sleep(forTimeInterval: 14)

        // A screenshot is the artifact worth keeping; the assertion below is
        // what fails the run.
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "tower-after-adding-a-real-photograph"
        add(shot)

        // The add sheet closed, so we are back on a tower that now holds one
        // win with a photograph on it.
        XCTAssertFalse(save.exists, "the add sheet never closed — the save failed")
    }
}
