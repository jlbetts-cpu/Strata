import XCTest

/// Add a photograph the way a person adds one, from the real photo library.
///
/// **Every other check in this project uses seeded photographs**, and those
/// are written straight into the image directory by `DebugHarness.seedPhoto`.
/// They never touch the picker, `attach(_:to:)`, `ImageManager.save`, or the
/// write of `imageFileName` — so a break anywhere along that path passes every
/// existing test and every screenshot. One did, for a long time.
///
/// **Everything here is asserted in the app, not on disk.** Two earlier
/// versions of this test read the SQLite store and the image directory
/// afterwards, and both were wrong: the app's data container changes identity
/// between runs, so the file being examined was from an older run. The app
/// already knows whether a photograph is attached — the well says "Replace the
/// photo" when there is one and "Add a photo" when there is not — so ask it.
///
/// **This test is flaky and is kept anyway.** It drives two pieces of system
/// UI — a confirmation dialog and PHPicker's remote view — and has failed at
/// three different points across runs: the dialog not appearing, the picker's
/// grid sitting at a different offset depending on whether the private-access
/// banner is shown, and the slot's tap landing on the wrong side of its
/// tap-versus-hold boundary. Two of those are fixed; the dialog is not.
///
/// It is worth keeping because it is the ONLY check that touches the path a
/// person actually uses, and because a version of it passed VACUOUSLY once —
/// asserting `images.count > 0` on the camera tab, where the tab bar's own
/// glyphs are images. Read a green result from this file with suspicion and
/// look at the attached screenshot.
final class RealPhotoTests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func well(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@",
            "Add a photo", "Replace the photo")).firstMatch
    }

    func testAPhotographFromTheLibraryReachesTheWin() {
        let app = XCUIApplication()
        // **The harness opens the sheet, not a tap on the slot.**
        //
        // The slot tells a tap from a hold by duration and distance, and
        // XCUITest's synthetic tap sits close enough to that boundary to land
        // on either side: one run opened the form, the next drew a block
        // instead and the test failed somewhere later for a reason that had
        // nothing to do with photographs. The gesture has its own test; this
        // one is about what happens to a picture.
        app.launchArguments += ["-strataStartTab", "tower", "-strataResetStore", "1",
                                "-strataOpenSheet", "add"]
        app.launch()
        Thread.sleep(forTimeInterval: 16)

        // Assert the sheet really is open before anything else is blamed.
        let title = app.textFields["What did you do?"]
        XCTAssertTrue(title.waitForExistence(timeout: 12),
                      "the add sheet never opened. On screen: \(app.debugDescription)")
        XCTAssertEqual(well(app).label, "Add a photo",
                       "a fresh win should start with no photograph")

        well(app).tap()
        Thread.sleep(forTimeInterval: 2)
        let library = app.buttons["Choose from library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10),
                      "no library option. On screen: \(app.debugDescription)")
        library.tap()
        Thread.sleep(forTimeInterval: 6)

        // **Tap a coordinate, not an element.** PHPicker's grid is a remote
        // view: its cells are not exposed as `cells` and its `images` ignore a
        // tap. A normalised point inside the first row of thumbnails selects
        // one — the private-access banner sits above the grid, so aim below it.
        // The banner about private access is sometimes there and sometimes
        // not, and it moves the grid down when it is, so one fixed point
        // misses about half the time. Try a few rows and stop as soon as the
        // well says a photograph arrived.
        var picked = false
        for dy in [0.42, 0.52, 0.62, 0.34] where !picked {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: dy)).tap()
            Thread.sleep(forTimeInterval: 5)
            picked = well(app).exists && well(app).label == "Replace the photo"
        }
        XCTAssertTrue(picked,
                      "the picker did not put a photograph into the draft. "
                      + "On screen: \(app.debugDescription)")

        app.buttons["Add"].tap()
        Thread.sleep(forTimeInterval: 10)

        // **The part that matters: does the photograph survive?**
        //
        // Not by long-pressing the block — CLAUDE.md says that opens an
        // OUTLINED block, and a completed win is not one — and not by reading
        // the store, which lives in a container whose identity changes between
        // runs. Ask the gallery instead. It draws one cell per photographed
        // win, so if the write was lost the grid is empty and its empty state
        // is on screen.
        //
        // A fresh launch also proves the filename was persisted rather than
        // merely held in memory by the sheet that wrote it.
        let grid = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Tower grid")).firstMatch
        _ = grid.waitForExistence(timeout: 12)
        XCTAssertTrue(grid.label.contains("1 blocks"),
                      "the win was never added — grid says \(grid.label)")

        app.terminate()
        let reopened = XCUIApplication()
        // `-strataOpenDrawer` alone lands on the camera: the drawer belongs to
        // Memories, so the tab has to be asked for too. Without this the
        // assertions below ran against the viewfinder, where there is no
        // gallery to be empty and `images` counts the camera's own glyphs —
        // the test passed while proving nothing.
        reopened.launchArguments += ["-strataStartTab", "history",
                                     "-strataOpenDrawer", "full"]
        reopened.launch()
        Thread.sleep(forTimeInterval: 20)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "gallery-after-adding-a-real-photograph"
        add(shot)

        let emptyGallery = reopened.staticTexts["Nothing here yet"]
        XCTAssertFalse(emptyGallery.exists,
                       "the gallery is empty — the photograph did not survive the save")
        // Count the gallery's own cells, not every `Image` on screen — the tab
        // bar's glyphs are images too, which is how this passed vacuously.
        let photos = reopened.scrollViews.images.count
        XCTAssertGreaterThan(photos, 0,
                             "no photographs in the gallery, so the write was lost. "
                             + "On screen: \(reopened.debugDescription)")
    }
}
