import XCTest

/// **Pictures of the screens a round of feedback is about** (2026-10-08).
/// Not a check: each test opens one screen the way a launch argument can and
/// keeps a screenshot, so a change is judged by looking. Run with the
/// simulator in light, then again in dark (`xcrun simctl ui <dev> appearance`).
/// Skipped unless `STRATA_SHOTS=1` is in the environment, so the full plan
/// never pays for it.
final class FeedbackShots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TEST_RUNNER_STRATA_SHOTS"] == "1"
                          || ProcessInfo.processInfo.environment["STRATA_SHOTS"] == "1",
                          "screenshots only on request")
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func wait(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    func testFilm() {
        _ = launch(["-strataShowOnboarding", "1", "-strataResetOnboarding", "1"])
        wait(4); snap("film-04s")
        wait(10); snap("film-14s")
        wait(4); snap("film-18s")
        wait(1.5); snap("film-after")
    }

    func testOnboardingPages() {
        for step in [1, 4, 5, 6] {
            let app = launch(["-strataShowOnboarding", "1", "-strataOnboardingStep", "\(step)"])
            wait(step == 1 ? 7 : 4)
            snap("onb-\(step)")
            app.terminate()
        }
    }

    func testTowerFirstWinHint() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "0", "-strataSeedHabits", "0",
                          "-strataSeedUnlabeled", "0"])
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        wait(8); snap("tower-empty")
        let slot = app.buttons["Log a win"].firstMatch
        if slot.waitForExistence(timeout: 20) { slot.tap() }
        wait(3); snap("tower-after-tap")
        wait(6); snap("tower-hint")
    }

    func testTowerHintSeeded() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "1", "-hint.drawOut.shown", "NO",
                          "-winCueDay", ""])
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        wait(6); snap("tower-hint-seeded")
    }

    func testInviteTip() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "2", "-strataInviteCard", "1"])
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        wait(7); snap("tower-invite")
    }

    func testMarks() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenCrews", "1",
                          "-crews.rulesAccepted.v1", "NO"])
        wait(6); snap("marks-rules"); app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenCrews", "1",
                      "-crews.rulesAccepted.v1", "YES"])
        wait(6); snap("marks-crews"); app.terminate()
        app = launch(["-strataStartTab", "memories", "-strataSeedWins", "0", "-strataSeedHabits", "0",
                      "-strataOpenMap", "1"])
        wait(7); snap("marks-map"); app.terminate()
        app = launch(["-strataOpenWhy", "1", "-strataOpenSheet", "settings", "-strataStartTab", "tower", "-strataSeedWins", "3"])
        wait(6); snap("marks-why"); app.terminate()
    }

    func testPrimaryPages() {
        for step in [1, 6] {
            let app = launch(["-strataShowOnboarding", "1", "-strataOnboardingStep", "\(step)"])
            wait(4); snap("primary-\(step)")
            app.terminate()
        }
    }

    func testTowerPages() {
        for step in [1] {
            let app = launch(["-strataShowOnboarding", "1", "-strataOnboardingStep", "\(step)"])
            wait(step == 1 ? 6 : 4); snap("towerpage-\(step)")
            app.terminate()
        }
    }

    func testOnboardingBlocks() {
        let app = launch(["-strataShowOnboarding", "1", "-strataOnboardingStep", "1"])
        wait(5); snap("onbblocks-1"); app.terminate()
    }

    func testTabSwitch() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "4", "-strataFakeLens", "1"])
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        wait(5); snap("tabs-wins")
        app.buttons["Camera"].tap(); wait(3); snap("tabs-camera")
        app.buttons["Memories"].tap(); wait(3); snap("tabs-memories")
    }

    func testCrewsFilm() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenCrews", "1",
                          "-crews.filmSeen", "NO", "-crews.rulesAccepted.v1", "NO"])
        wait(2.5); snap("crewsfilm-1")
        wait(2.5); snap("crewsfilm-2")
        wait(4); snap("crewsfilm-after")
        for word in ["I Agree"] where app.buttons[word].exists { app.buttons[word].tap() }
        wait(3); snap("crewsfilm-intro")
    }

    func testTowerSome() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "7"])
        if app.buttons["Wins"].waitForExistence(timeout: 10) { app.buttons["Wins"].tap() }
        wait(10); snap("tower-seven")
    }

    func testCrewsEmpty() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenCrews", "1"])
        wait(6); snap("crews-first")
        for word in ["Agree", "I Agree", "Agree and Continue", "Continue"] where app.buttons[word].exists {
            app.buttons[word].tap(); break
        }
        wait(4); snap("crews-empty")
        if app.buttons["New Crew"].exists { app.buttons["New Crew"].tap(); wait(2); snap("crews-new") }
    }

    func testMemoriesOneMonth() {
        _ = launch(["-strataStartTab", "memories", "-strataSeedWins", "4", "-strataTipsReset", "1",
                    "-strataTipsShow", "1"])
        wait(8); snap("memories")
    }

    func testSheets() {
        for sheet in ["add", "settings", "profile"] {
            let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "5", "-strataOpenSheet", sheet])
            wait(6); snap("sheet-\(sheet)")
            app.terminate()
        }
    }
}
