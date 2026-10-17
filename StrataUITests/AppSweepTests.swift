import XCTest

/// **Every main screen, shot for the consistency audit** (the owner,
/// 2026-10-18: "Go screen by screen and make every control, glass, blur,
/// segmented control, button, sheet, spacing, type size, icon weight and
/// empty state match one system"). Looked at, not counted: one launch per
/// screen through the app's own debug openers, the same seed each time.
final class AppSweepTests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private let seed = ["-cameraTimerSeconds", "0", "-strataSeedWins", "6", "-strataSeedHistory", "40",
                        "-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "2", "-strataSeedCrewWins", "10",
                        "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES",
                        "-strataFakeLens", "/Users/jaydenbetts/Developer/Strata/docs/site/memories.mp4"]

    private func snap(_ name: String) {
        let s = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }

    private func shoot(_ name: String, _ extra: [String], wait: TimeInterval = 7, then: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        app.launchArguments = seed + extra
        app.launch()
        Thread.sleep(forTimeInterval: wait)
        snap("sweep-\(name)")
        if let then { then(app) }
        app.terminate()
    }

    /// The crew chip on the edit sheet and on the card, after 2026-10-18.
    func testCrewChip() {
        shoot("15-edit-chip", ["-strataStartTab", "tower", "-strataOpenSheet", "block"])
        shoot("16-card-photo-chip", ["-strataStartTab", "tower", "-strataOpenSheet", "addphoto"], wait: 9)
    }

    func testSweep() {
        shoot("01-wins", ["-strataStartTab", "tower"])
        shoot("02-card-lens", ["-strataStartTab", "tower", "-strataOpenSheet", "add"], wait: 8)
        shoot("03-card-photo", ["-strataStartTab", "tower", "-strataOpenSheet", "addphoto"], wait: 8)
        shoot("04-plan", ["-strataStartTab", "tower", "-strataOpenSheet", "plan"])
        shoot("05-yourday", ["-strataStartTab", "tower", "-strataOpenSheet", "yourday"])
        shoot("06-block", ["-strataStartTab", "tower", "-strataOpenSheet", "block"])
        shoot("07-edit", ["-strataStartTab", "tower", "-strataOpenSheet", "edit"])
        shoot("08-crews", ["-strataStartTab", "crews"])
        shoot("09-crew-tower", ["-strataStartTab", "tower", "-strataOpenCrew", "0"])
        shoot("10-memories", ["-strataStartTab", "memories"])
        shoot("11-profile", ["-strataStartTab", "memories", "-strataOpenSheet", "profile"])
        shoot("12-settings", ["-strataStartTab", "memories", "-strataOpenSheet", "settings"])
        shoot("13-planline", ["-strataStartTab", "tower", "-strataOpenSheet", "planline"])
        shoot("14-story-row", ["-strataStartTab", "crews", "-strataSeedStories", "3", "-strataStoryHour", "21",
                               "-strataStorySeen", "1"])
    }
}
