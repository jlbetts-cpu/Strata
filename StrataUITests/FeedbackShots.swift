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

    func testHouseCard() {
        var app = launch(["-strataStartTab", "memories", "-strataSeedWins", "4", "-strataHouseCard", "crew"])
        wait(7); snap("house-card"); app.terminate()
        app = launch(["-strataStartTab", "memories", "-strataSeedWins", "4", "-strataHouseCard", "tip"])
        wait(7); snap("house-tip"); app.terminate()
    }

    /// Every main screen once, for a look across the whole app.
    func testTour() {
        let screens: [(String, [String], Double)] = [
            ("tour-wins", ["-strataStartTab", "tower", "-strataSeedWins", "14", "-strataSeedRealPhotos", "1"], 9),
            ("tour-day", ["-strataStartTab", "memories", "-strataSeedWins", "14", "-strataOpenDay", "1"], 8),
            ("tour-block", ["-strataStartTab", "tower", "-strataSeedWins", "6", "-strataOpenSheet", "block"], 8),
            ("tour-plan", ["-strataStartTab", "tower", "-strataSeedWins", "4", "-strataSeedPlan", "5", "-strataOpenSheet", "plan"], 7),
            ("tour-profile", ["-strataStartTab", "tower", "-strataSeedWins", "20", "-strataOpenSheet", "profile"], 7),
            ("tour-settings", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "settings"], 6),
            ("tour-crews", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataCrews", "1", "-strataSeedCrews", "3", "-strataOpenCrews", "1",
                            "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"], 8),
            ("tour-crew", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedCrews", "2", "-strataSeedCrewWins", "6",
                           "-strataOpenCrew", "0", "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"], 9),
            ("tour-replay", ["-strataStartTab", "memories", "-strataSeedWins", "14", "-strataOpenReplay", "sampleWeek"], 6),
        ]
        for (name, args, seconds) in screens {
            let app = launch(args)
            wait(seconds); snap(name)
            app.terminate()
        }
    }

    func testTour2() {
        let crew = ["-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"]
        let screens: [(String, [String], Double)] = [
            ("tour2-today", ["-strataStartTab", "memories", "-strataSeedWins", "8", "-strataSeedRealPhotos", "1", "-strataOpenDay", "0"], 8),
            ("tour2-map", ["-strataStartTab", "memories", "-strataSeedWins", "12", "-strataSeedPlaces", "1", "-strataSeedRealPhotos", "1", "-strataOpenMap", "1"], 9),
            ("tour2-chat", ["-strataStartTab", "tower", "-strataSeedCrews", "1", "-strataSeedCrewWins", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "chat"] + crew, 9),
            ("tour2-add", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"], 6),
            ("tour2-month", ["-strataStartTab", "memories", "-strataSeedHistory", "60", "-strataSeedRealPhotos", "1"], 8),
        ]
        for (name, args, seconds) in screens {
            let app = launch(args)
            wait(seconds); snap(name)
            app.terminate()
        }
    }

    /// Yesterday's tower leaving for Memories on a fresh morning
    /// (`DayHandoff`), caught standing, travelling and gone.
    func testDayHandoff() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedHistory", "3", "-strataSeedHistoryNotToday", "1",
                    "-handoff.lastDay", "x"])
        wait(2.6); snap("handoff-0")
        for i in 1...8 { wait(0.12); snap("handoff-\(i)") }
        wait(2); snap("handoff-after")
        app.tabBars.buttons["Memories"].tap()
        for i in 0...4 { wait(0.1); snap("arrive-\(i)") }
        wait(1.5); snap("arrive-after")
    }

    /// The month's albums under the photo count (`Album.monthShelf`).
    func testMonthShelf() {
        let app = launch(["-strataStartTab", "memories", "-strataSeedHistory", "30", "-strataSeedRealPhotos", "1",
                          "-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "1", "-strataSeedSentToCrew", "1",
                          "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"])
        wait(7)
        app.swipeUp(velocity: .slow)
        wait(2); snap("shelf-1")
        app.swipeUp(velocity: .slow)
        wait(2); snap("shelf-2")
    }

    func testCrewCap() {
        let app = launch(["-strataStartTab", "tower", "-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "5",
                          "-strataOpenCrews", "1", "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"])
        wait(8); snap("crew-list")
        let pencil = app.buttons["square.and.pencil"].firstMatch
        if pencil.exists { pencil.tap() }
        wait(2); snap("crew-cap")
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
