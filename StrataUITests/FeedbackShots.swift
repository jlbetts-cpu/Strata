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
        // The remade film (2026-10-10) is 17.5 seconds, five shots.
        wait(2.5); snap("crewsfilm-1")
        wait(3.5); snap("crewsfilm-2")
        wait(4); snap("crewsfilm-3")
        wait(3.5); snap("crewsfilm-4")
        wait(3); snap("crewsfilm-5")
        wait(3.5); snap("crewsfilm-after")
        for word in ["I Agree"] where app.buttons[word].exists { app.buttons[word].tap() }
        wait(3); snap("crewsfilm-intro")
    }

    func testHouseCard() {
        var app = launch(["-strataStartTab", "memories", "-strataSeedWins", "4", "-strataHouseCard", "crew"])
        wait(7); snap("house-card"); app.terminate()
        app = launch(["-strataStartTab", "memories", "-strataSeedWins", "4", "-strataHouseCard", "tip"])
        wait(7); snap("house-tip"); app.terminate()
    }

    /// Answers a system permission prompt left standing over the app (a
    /// fresh install's camera prompt covers every later screenshot).
    func testDismissSystemPrompt() {
        _ = launch(["-strataStartTab", "tower"])
        let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Don\u{2019}t Allow"].firstMatch
        if deny.waitForExistence(timeout: 6) { deny.tap() }
        wait(1); snap("prompt-gone")
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
            // `-strataCrews 1 -strataSeedCrew <people>` is what seeds a crew;
            // without them these two photographed the no-iCloud page and
            // the plain tower (seen 2026-10-11).
            ("tour-crews", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataCrews", "1", "-strataSeedCrew", "3",
                            "-strataSeedCrews", "3", "-strataOpenCrews", "1",
                            "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"], 8),
            ("tour-crew", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataCrews", "1", "-strataSeedCrew", "3",
                           "-strataSeedCrews", "2", "-strataSeedCrewWins", "6",
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
            ("tour2-chat", ["-strataStartTab", "tower", "-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "1",
                            "-strataSeedCrewWins", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "chat"] + crew, 9),
            ("tour2-plan-tomorrow", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlanAhead", "1",
                                     "-strataOpenSheet", "plan", "-strataDayTab", "plan", "-strataPlanScope", "1"], 7),
            ("tour2-plan-repeating", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                                      "-strataOpenSheet", "plan", "-strataDayTab", "plan", "-strataPlanScope", "repeating"], 7),
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

    /// The ring coming forward for a win (`RingMoment`): a win is logged
    /// from the slot and the screen is left alone, for a recording.
    func testRingMoment() {
        // `-goalDanceDay none`: the goal has not danced today, so what
        // follows the ring when this win reaches it can be seen.
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "2", "-goalDanceDay", "none"])
        wait(8)
        app.descendants(matching: .any)["Log a win"].firstMatch.press(forDuration: 0.6)
        wait(1.1); snap("ring-1")
        wait(0.5); snap("ring-2")
        wait(0.6); snap("ring-3")
        wait(2.5); snap("ring-4-home")
        // And what follows when this win was the one that reached the goal.
        wait(7); snap("ring-5-after")
    }

    /// The same for an everyday win, well short of the goal.
    func testRingMomentEveryday() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "1", "-dailyGoal", "8"])
        wait(8)
        app.descendants(matching: .any)["Log a win"].firstMatch.press(forDuration: 0.6)
        wait(6); snap("ring-everyday")
    }

    /// **The test the owner set**: "a user should be able to plan their
    /// entire next day in under 15 seconds: open it, type a few bullet-point
    /// wins, done". Timed from the press on the slot to the tower again,
    /// with three lines typed at a thumb's pace (about four characters a
    /// second), not a script's.
    ///
    /// Through the add sheet, whose name is a SwiftUI field. The plan
    /// sheet's bar is one press shorter (the plan button, Tomorrow, type),
    /// but it is a UIKit field and the simulator's keyboard will not type
    /// into it reliably from a script, so that door is checked by hand.
    func testPlanningTomorrowIsQuick() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3"])
        wait(7)
        let started = Date()
        app.descendants(matching: .any)["Log a win"].firstMatch.tap()
        app.buttons["When: now"].firstMatch.tap()
        app.buttons["Tomorrow"].firstMatch.tap()
        for line in ["Email the professor", "Laundry", "Gym with Sam"] {
            let typing = Date()
            app.typeText(line + "\n")
            // Held to a thumb's pace: whatever the script saved is waited out.
            let human = Double(line.count) * 0.25
            let spent = Date().timeIntervalSince(typing)
            if spent < human { Thread.sleep(forTimeInterval: human - spent) }
        }
        snap("quick-1-typed")
        app.buttons["Done"].firstMatch.tap()
        let took = Date().timeIntervalSince(started)
        print("PLANNING-TOMORROW-SECONDS \(String(format: "%.1f", took))")
        XCTAssertLessThan(took, 15, "planning tomorrow took \(took) seconds")
        wait(2)
        app.buttons["Plan and Journal"].firstMatch.tap()
        wait(2)
        // The sheet opens on whichever tab was used last.
        let planTab = app.buttons["Plan"].firstMatch
        if planTab.exists { planTab.tap(); wait(1) }
        app.buttons["Tomorrow"].firstMatch.tap()
        wait(1); snap("quick-2-tomorrow")
    }

    /// A planned win finished from the tower: press the outline, the camera
    /// opens, the shot goes on a win named as the line was.
    func testFinishingAPlannedWin() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                          "-strataPlanOnTower", "1"])
        wait(8); snap("finish-0-tower")
        let outline = app.buttons["Planned: Run the loop"].firstMatch
        outline.press(forDuration: 1.2)
        wait(1); snap("finish-1-menu")
        app.buttons["Log Without a Photo"].firstMatch.tap()
        wait(3); snap("finish-2-sheet")
        app.buttons["Add"].firstMatch.tap()
        wait(7); snap("finish-3-landed")
        app.buttons["Planned: Call the landlord"].firstMatch.tap()
        wait(4); snap("finish-4-camera")
    }

    /// Planning from the add sheet (the owner, 2026-10-10): Now, then a
    /// day, a line a Return, Plan; and what was planned for later today
    /// standing on the tower as outlines.
    func testPlanningFromTheAddSheet() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(7); snap("plan-add-0")
        app.buttons["When: now"].firstMatch.tap()
        wait(1); snap("plan-add-1-row")
        app.buttons["Tomorrow"].firstMatch.tap()
        wait(1)
        app.typeText("Email the professor\n")
        app.typeText("Laundry\n")
        wait(1); snap("plan-add-2-tomorrow")
        app.buttons["Later today"].firstMatch.tap()
        wait(1)
        app.typeText("Call Mum\n")
        app.typeText("Stretch")
        wait(1); snap("plan-add-3-later")
        app.buttons["Plan"].firstMatch.tap()
        wait(3); snap("plan-add-4-tower")
    }

    /// Move Photo, from the block's hold menu on a sheet holding a picture
    /// (the owner, 2026-10-11): the editor, the photo dragged, the block after.
    func testMovePhoto() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "addphoto"])
        wait(8); snap("move-0-sheet")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).press(forDuration: 1.2)
        wait(1); snap("move-1-menu")
        let move = app.buttons["Move Photo"].firstMatch
        if move.waitForExistence(timeout: 3) { move.tap() }
        wait(2); snap("move-2-crop")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        wait(1); snap("move-3-dragged")
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap() }
        wait(2); snap("move-4-block")
    }

    /// "Gym @ 2": typed where any plan is typed, read back on the tower's
    /// outline and under the line in the plan (the owner, 2026-10-11).
    func testPlanTime() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add",
                          "-hint.planned.shown", "YES"])
        wait(7)
        app.buttons["When: now"].firstMatch.tap()
        wait(1)
        app.buttons["Later today"].firstMatch.tap()
        wait(1)
        app.typeText("Gym @ 2\n")
        app.typeText("Call Mum @ 6:30\n")
        app.typeText("Laundry")
        wait(1); snap("time-0-typed")
        app.buttons["Plan"].firstMatch.tap()
        wait(4); snap("time-1-tower")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataOpenSheet", "plan", "-strataDayTab", "plan", "-hint.planned.shown", "YES"])
        wait(8); snap("time-2-plan")
    }

    /// The `+` slot beside planned wins, and alone on an empty tower (the
    /// owner, 2026-10-11: "they should look the same").
    func testSlotBesideOutlines() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                          "-strataPlanOnTower", "1"])
        wait(8); snap("pane-0-with-plan")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "0"])
        wait(7); snap("pane-1-empty")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "14", "-strataSeedPlan", "5", "-strataPlanOnTower", "1"])
        wait(8); snap("pane-2-full")
    }

    /// Monday, Wednesday and Friday, chosen where the line is written (the
    /// owner, 2026-10-11): in the add sheet, then as the plan shows it.
    func testRepeatingOnSomeDays() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(7)
        app.buttons["When: now"].firstMatch.tap()
        wait(1)
        app.buttons["Repeating"].firstMatch.tap()
        wait(1); snap("days-0-every")
        for off in ["Every Tuesday", "Every Thursday", "Every Saturday", "Every Sunday"] {
            app.buttons[off].firstMatch.tap()
        }
        wait(1)
        app.typeText("Gym\n")
        app.typeText("Read for class")
        wait(1); snap("days-1-chosen")
        app.buttons["Plan"].firstMatch.tap()
        wait(3); snap("days-2-tower")
    }

    /// The same chips on the plan's own Repeating page.
    func testRepeatingPageHasTheDays() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                          "-strataOpenSheet", "plan", "-strataDayTab", "plan", "-strataPlanScope", "repeating"])
        wait(8); snap("days-plan-0")
        for off in ["Every Tuesday", "Every Thursday", "Every Saturday", "Every Sunday"] {
            let chip = app.buttons[off].firstMatch
            if chip.waitForExistence(timeout: 3) { chip.tap() }
        }
        wait(1); snap("days-plan-1")
        // The seeded weekday line's box: under Repeating it opens the line.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.07, dy: 0.24)).tap()
        wait(2); snap("days-plan-2-line")
    }

    /// The add sheet's strip with the pen tile gone: today's photographs
    /// straight after the block, and Doodle in the block's own menu (the
    /// owner, 2026-10-10).
    func testAddSheetDoodleInTheMenu() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add",
                          "-strataTodaysPhotos", "all"])
        wait(8)
        let ask = app.buttons["Show today's photos"].firstMatch
        if ask.waitForExistence(timeout: 3) {
            ask.tap()
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow Full Access"].firstMatch
            if allow.waitForExistence(timeout: 5) { allow.tap() }
        }
        wait(4); snap("add-strip")
        app.buttons["Add a photo"].firstMatch.tap()
        wait(2); snap("add-menu")
        let doodle = app.buttons["Doodle"].firstMatch
        if doodle.waitForExistence(timeout: 3) { doodle.tap() }
        wait(3); snap("add-doodle")
    }

    /// A doodle at the strip's bottom right, off the photos, stays there
    /// after Done (the owner, 2026-10-10: it "navigated to the middle").
    func testStripDoodleKeepsItsPlace() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedTodayPhotos", "3",
                          "-strataOpenSheet", "booth", "-strataBoothDeveloped", "1"])
        wait(9); snap("place-booth")
        app.buttons["Doodle on the strip"].firstMatch.tap()
        wait(3); snap("place-editor")
        let window = app.windows.firstMatch
        func at(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
        }
        let spot = ProcessInfo.processInfo.environment["STRATA_SPOT"]?.split(separator: ",").compactMap { Double($0) } ?? []
        if spot.count == 2 {
            let x = CGFloat(spot[0]), y = CGFloat(spot[1])
            at(x - 14, y - 10).press(forDuration: 0.05, thenDragTo: at(x + 14, y + 10))
            at(x - 14, y + 10).press(forDuration: 0.05, thenDragTo: at(x + 14, y - 10))
            wait(1); snap("place-drawn")
            app.buttons["Done"].firstMatch.tap()
            wait(3); snap("place-done")
            app.buttons["Doodle on the strip"].firstMatch.tap()
            wait(3); snap("place-reopened")
        }
    }

    /// Your strip into a crew: the share sheet with the crew in it, then the
    /// strip in that crew's chat (`CrewStripActivity`).
    func testStripToCrew() {
        let crew = ["-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "1",
                    "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"]
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedTodayPhotos", "1",
                          "-strataOpenSheet", "booth", "-strataStory", "1"] + crew)
        wait(9); snap("strip-story")
        app.buttons["Share strip"].firstMatch.tap()
        wait(3); snap("strip-sheet")
        let target = app.descendants(matching: .any)["Roommates"].firstMatch
        if target.waitForExistence(timeout: 4) { target.tap() }
        wait(3); snap("strip-sent")
        app.terminate()
        _ = launch(["-strataStartTab", "tower", "-strataOpenCrew", "0", "-strataCrewSheet", "chat",
                    "-strataSeedCrewStrip", "1"] + crew)
        wait(9); snap("strip-chat")
    }

    /// The crew streak's flame in the list (unification §5c).
    func testCrewFlame() {
        let app = launch(["-strataStartTab", "tower", "-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "3",
                          "-strataSeedCrewHistory", "9", "-strataOpenCrews", "1",
                          "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"])
        wait(8); snap("crew-flame")
        app.terminate()
    }

    /// One crew's own screen and its top-middle container, opened.
    func testCrewScreen() {
        let crew = ["-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "1", "-strataSeedCrewHistory", "14",
                    "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"]
        let app = launch(["-strataStartTab", "tower", "-strataOpenCrew", "0", "-strataCrewSheet", "info",
                          "-strataSeedHistory", "10", "-strataSeedRealPhotos", "1", "-strataSeedSentToCrew", "1"] + crew)
        wait(8); snap("crew-info-1")
        app.swipeUp(velocity: .slow)
        wait(2); snap("crew-info-2")
        app.swipeUp(velocity: .slow)
        wait(2); snap("crew-info-3")
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
        if app.buttons["Start a Crew"].firstMatch.exists { app.buttons["Start a Crew"].firstMatch.tap(); wait(2); snap("crews-new") }
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
