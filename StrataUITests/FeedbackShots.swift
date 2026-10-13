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
        // **Retired with the add sheet's own plan mode** (2026-10-11):
        // choosing a day on Now opens the plan sheet itself, and a UI test
        // cannot type into that sheet's UIKit bar on the simulator.
        guard ProcessInfo.processInfo.environment["STRATA_OLD_PLAN_MODE"] != nil else { return }
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3"])
        wait(7)
        let started = Date()
        app.descendants(matching: .any)["Log a win"].firstMatch.tap()
        app.buttons["Plan for later"].firstMatch.tap()
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
        // A press opens the menu now (2026-10-11); it was a hold.
        let outline = app.buttons["Planned: Run the loop"].firstMatch
        outline.tap()
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
        // **Retired with the add sheet's own plan mode** (2026-10-11):
        // choosing a day on Now opens the plan sheet itself, and a UI test
        // cannot type into that sheet's UIKit bar on the simulator.
        guard ProcessInfo.processInfo.environment["STRATA_OLD_PLAN_MODE"] != nil else { return }
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(7); snap("plan-add-0")
        app.buttons["Plan for later"].firstMatch.tap()
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
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).tap()
        wait(2); snap("move-1-menu")
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

    /// "Gym @ 2" typed on the add sheet, then a day chosen on Now: the plan
    /// sheet opens on that day with the line in it and its time read back
    /// (the owner, 2026-10-11).
    func testPlanTime() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add",
                          "-hint.planned.shown", "YES"])
        wait(7)
        app.typeText("Gym @ 2")
        wait(1); snap("time-0-typed")
        app.buttons["Plan for later"].firstMatch.tap()
        wait(1); snap("time-1-row")
        app.buttons["Later today"].firstMatch.tap()
        wait(4); snap("time-2-plan")
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 3) { done.tap() }
        wait(3); snap("time-3-tower")
    }

    /// The block's own menu on the add sheet: three ways to fill it and its
    /// colour, which left the sheet's own row (the owner, 2026-10-11).
    func testBlockMenu() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(7); snap("block-0-sheet")
        app.buttons["Add a photo"].firstMatch.tap()
        wait(2); snap("block-1-menu")
        let work = app.buttons["work"].firstMatch
        if work.waitForExistence(timeout: 3) { work.tap() }
        wait(1); snap("block-2-colour")
        let doodle = app.buttons["Doodle"].firstMatch
        if doodle.waitForExistence(timeout: 3) { doodle.tap() }
        wait(3); snap("block-3-doodle")
    }

    /// The flows pass (2026-10-11, `docs/flows.md`): a block holding a
    /// photo opens its menu on a press; Repeating stands at the end of the
    /// plan's row; an album's own page can remove it; the empty tower says
    /// both things the slot does; the strip says it can be tapped.
    func testFlowsPass() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "addphoto"])
        wait(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).tap()
        wait(2); snap("flows-0-photo-menu")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                      "-strataOpenSheet", "plan", "-strataDayTab", "plan"])
        wait(8); snap("flows-1-plan-row")
        app.buttons["Repeating"].firstMatch.tap()
        wait(2); snap("flows-2-repeating")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "0", "-strataSeedHabits", "0"])
        wait(7); snap("flows-3-empty")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedTodayPhotos", "3",
                      "-strataOpenSheet", "booth"])
        wait(10); snap("flows-4-strip")
        app.terminate()
        app = launch(["-strataStartTab", "memories", "-strataSeedHistory", "30", "-strataSeedRealPhotos", "1",
                      "-strataCrews", "1", "-strataSeedCrew", "3", "-strataSeedCrews", "1", "-strataSeedSentToCrew", "1",
                      "-crews.rulesAccepted.v1", "YES", "-crews.filmSeen", "YES"])
        wait(7)
        app.swipeUp(velocity: .slow)
        wait(2)
        let album = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'With '")).firstMatch
        if album.waitForExistence(timeout: 4) { album.tap() }
        wait(3); snap("flows-5-album")
        let more = app.buttons["More"].firstMatch
        if more.waitForExistence(timeout: 3) { more.tap() }
        wait(2); snap("flows-6-album-menu")
    }

    /// Your name, onboarding's last page: Start is off until one is written
    /// (the owner, 2026-10-12).
    func testOnboardingName() {
        let app = launch(["-strataShowOnboarding", "1", "-strataOnboardingStep", "8", "-profileName", ""])
        wait(5); snap("name-0-empty")
        app.typeText("Jayden")
        wait(1); snap("name-1-typed")
    }

    /// A tip arriving and leaving: the page under it must not move (the
    /// owner, 2026-10-12: "the tips kinda push the page down for a second").
    func testTipTakesNoRoom() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                          "-strataPlanOnTower", "1", "-hint.planned.shown", "NO"])
        wait(11); snap("tip-0-showing")
        let close = app.buttons["Close"].firstMatch
        if close.waitForExistence(timeout: 2) { close.tap() }
        wait(2); snap("tip-1-gone")
        // And the ripple a touch on the bare page leaves, caught mid-ring.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        Thread.sleep(forTimeInterval: 0.18); snap("tip-2-ripple")
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
        // **Retired with the add sheet's own plan mode** (2026-10-11):
        // choosing a day on Now opens the plan sheet itself, and a UI test
        // cannot type into that sheet's UIKit bar on the simulator.
        guard ProcessInfo.processInfo.environment["STRATA_OLD_PLAN_MODE"] != nil else { return }
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(7)
        app.buttons["Plan for later"].firstMatch.tap()
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

    /// **Things that hang below a pinned header still take a touch**
    /// (2026-10-13): the Wins tip's close, and I'm In on the crew's screen.
    /// The header became a bar (`pinnedBar`), and whether a bar passes
    /// touches to what overflows it could not be known without trying.
    func testTapsUnderTheBar() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5",
                          "-strataPlanOnTower", "1", "-hint.planned.shown", "NO"])
        // The hint is up for nine seconds: looked for from the start.
        let close = app.buttons["Close"].firstMatch
        let shown = close.waitForExistence(timeout: 25)
        snap("bar-tip-shown")
        if shown { close.tap() }
        wait(2); snap("bar-tip-closed")
        print("PLANNING-tip: shown \(shown) hittable-before \(shown) gone-after-tap \(!app.buttons["Close"].firstMatch.exists)")
        XCTAssertTrue(shown, "no tip to test with")
        XCTAssertFalse(app.buttons["Close"].firstMatch.exists, "the tip's close took no touch under the bar")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                      "-strataSeedCrewChat", "1", "-strataSeedCrewPlan", "1"])
        wait(10)
        let join = app.buttons["I'm In"].firstMatch
        let offered = join.waitForExistence(timeout: 3)
        if offered { join.tap() }
        wait(2); snap("bar-plan-joined")
        print("PLANNING-plan: offered \(offered) gone-after-tap \(!app.buttons["I'm In"].firstMatch.exists) undo \(app.buttons["Undo"].firstMatch.exists)")
        XCTAssertTrue(offered, "no plan card on the crew's screen")
        XCTAssertFalse(app.buttons["I'm In"].firstMatch.exists, "I'm In took no touch under the bar")
    }

    /// **A tap on a crew's invitation, start to finish** (the owner,
    /// 2026-10-13: "send me the flow of clicking on a crew link making sure
    /// it has all the features and is simple"): the rules the first time,
    /// then the crew.
    func testInviteFlow() {
        // Someone new to crews: the rules first. (The launch argument holds
        // the rules at "not agreed" for the whole launch, so the join itself
        // is walked in the second launch.)
        var app = launch(["-strataCrews", "1", "-strataSeedInvite", "1", "-strataStartTab", "tower",
                          "-strataSeedWins", "2", "-crews.rulesAccepted.v1", "NO"])
        let agree = app.buttons["I Agree"].firstMatch
        let asked = agree.waitForExistence(timeout: 25)
        wait(1); snap("invite-1-rules")
        if asked { agree.tap() }
        wait(2); snap("invite-2-joining")
        print("PLANNING-invite: rules \(asked) joining \(app.staticTexts["Joining your crew"].exists)")
        app.terminate()
        // With the rules agreed: the link, then the crew.
        app = launch(["-strataCrews", "1", "-strataSeedInvite", "1", "-strataStartTab", "tower",
                      "-strataSeedWins", "2", "-crews.rulesAccepted.v1", "YES"])
        let landed = app.buttons["Chat"].firstMatch.waitForExistence(timeout: 40)
        wait(3); snap("invite-3-in-the-crew")
        print("PLANNING-invite: in crew \(landed) alerts \(app.alerts.count) \(app.alerts.firstMatch.exists ? app.alerts.firstMatch.label : "")")
        XCTAssertTrue(asked, "someone new was not shown the rules")
        XCTAssertTrue(landed, "the invitation did not end in the crew")
    }

    /// **In Add a Win the block's menu opens whole while the name is being
    /// typed** (the owner, 2026-10-13: "when I click to add a photo in the
    /// add a win it doesn't pop up right when the keyboard is there").
    func testAddMenuOverKeyboard() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(6)
        let keysUp = app.keyboards.firstMatch.exists
        snap("addmenu-before")
        let block = app.buttons["Add a photo"].firstMatch
        let found = block.waitForExistence(timeout: 4)
        if found { block.tap() }
        wait(2); snap("addmenu-open")
        let screen = app.windows.firstMatch.frame
        var rows: [String] = []
        var whole = true
        for name in ["Take Photo", "Choose from Library", "Doodle"] {
            let row = app.buttons[name].firstMatch
            let ok = row.exists && row.isHittable && screen.contains(row.frame)
            if row.exists { rows.append("\(name) \(Int(row.frame.minY))-\(Int(row.frame.maxY)) hittable \(row.isHittable)") }
            if name != "Doodle", !ok { whole = false }
        }
        print("PLANNING-addmenu: keyboard-before \(keysUp) block \(found) keyboard-after \(app.keyboards.firstMatch.exists) rows \(rows) screen \(Int(screen.height))")
        XCTAssertTrue(found, "no block in the add sheet")
        XCTAssertTrue(whole, "the block's menu did not open whole")
    }

    /// **A repeating line renamed asks: just today, or every time** (the
    /// owner, 2026-10-13).
    func testPlanRename() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "2", "-strataSeedPlan", "3",
                          "-strataPlanOnTower", "1", "-hint.planned.shown", "YES"])
        wait(8)
        func openEdit() -> Bool {
            let box = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Planned: '")).firstMatch
            guard box.waitForExistence(timeout: 6) else { return false }
            box.tap(); wait(1)
            let edit = app.buttons["Edit"].firstMatch
            guard edit.waitForExistence(timeout: 3) else { return false }
            edit.tap(); wait(2)
            return true
        }
        let opened = openEdit()
        let repeats = app.switches.firstMatch
        if repeats.exists, (repeats.value as? String) == "0" {
            repeats.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap(); wait(1)
        }
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2) }
        let again = openEdit()
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if field.exists { field.tap(); wait(1); app.typeText(" with Sam") }
        snap("planrename-typed")
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2) }
        snap("planrename-asked")
        let today = app.buttons["Just Today"].firstMatch
        let asked = today.waitForExistence(timeout: 3)
        print("PLANNING-planrename: opened \(opened) again \(again) field \(field.exists) asked \(asked) every \(app.buttons["Every Time"].firstMatch.exists)")
        XCTAssertTrue(asked, "a renamed repeating line did not ask")
        if asked { today.tap(); wait(3) }
        snap("planrename-after")
        let renamed = app.buttons.matching(NSPredicate(format: "label CONTAINS 'with Sam'")).firstMatch.exists
        print("PLANNING-planrename: renamed box on the tower \(renamed)")
        XCTAssertTrue(renamed, "today's box does not carry the new name")
    }

    /// **A note on a win, and the day's wins in that day's journal**
    /// (`WinNote`, 2026-10-13).
    func testWinNote() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3",
                          "-hint.winNote.shown", "NO", "-hint.winNote.due", "NO"])
        wait(8)
        // A press on a win's own block: the edit sheet that holds the win,
        // not the harness's, which has only its name and colour.
        let block = app.buttons["Your win, Walk"].firstMatch
        if block.waitForExistence(timeout: 6) { block.tap(); wait(2) }
        snap("winnote-edit")
        let field = app.textFields["Add a note"].exists ? app.textFields["Add a note"] : app.textViews["Add a note"]
        let offered = field.waitForExistence(timeout: 4)
        if offered { field.tap(); wait(1); app.typeText("Slow, but I went.") }
        snap("winnote-typed")
        let save = app.buttons["Save"].firstMatch
        if save.exists { save.tap() }
        // The hint, once, under the header.
        let hint = app.staticTexts["A note on a win"]
        let hinted = hint.waitForExistence(timeout: 14)
        snap("winnote-hint")
        let journal = app.buttons["Plan and Journal"].firstMatch
        if journal.waitForExistence(timeout: 4) { journal.tap(); wait(3) }
        let tab = app.buttons["Journal"].firstMatch
        if tab.exists { tab.tap(); wait(2) }
        snap("winnote-journal")
        let shown = app.textFields.matching(NSPredicate(format: "value CONTAINS 'Slow, but I went.'")).firstMatch.exists
            || app.textViews.matching(NSPredicate(format: "value CONTAINS 'Slow, but I went.'")).firstMatch.exists
            || app.staticTexts["Slow, but I went."].exists
        print("PLANNING-winnote: field \(offered) save \(save.exists) hint \(hinted) in-journal \(shown) buttons \(app.buttons.allElementsBoundByIndex.prefix(10).map(\.label))")
        XCTAssertTrue(offered, "no note line on a win being edited")
        XCTAssertTrue(shown, "the note is not in that day's journal")
    }

    /// The chat's Strip: today's strip shown, and Send puts it in the chat.
    func testChatStrip() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataCrewSheet", "chat", "-strataSeedCrewChat", "1", "-strataSeedHistory", "2",
                          "-strataSeedTodayPhotos", "all"])
        wait(9)
        let plus = app.buttons["More to send"]
        if plus.waitForExistence(timeout: 5) { plus.tap(); wait(1) }
        let strip = app.buttons["Send today's photo strip"]
        let offered = strip.exists
        if offered { strip.tap(); wait(3) }
        snap("chatstrip-sheet")
        let send = app.buttons["Send"].firstMatch
        let before = app.images.matching(NSPredicate(format: "label == 'A photo strip'")).count
            + app.otherElements.matching(NSPredicate(format: "label == 'A photo strip'")).count
        print("PLANNING-chatstrip: offered \(offered) send \(send.exists) enabled \(send.exists && send.isEnabled) empty-line \(app.staticTexts["No photos today. Yet."].exists)")
        if send.exists, send.isEnabled { send.tap(); wait(3) }
        snap("chatstrip-sent")
        let after = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'A photo strip'")).count
        print("PLANNING-chatstrip: strips before \(before) after \(after)")
    }

    /// **A crew's plan you are in is a box on the crew's tower, and its line
    /// stays in the chat** (the owner, 2026-10-13: "when you plan something
    /// in the crew chat they should show up as a checkbox block in the crew
    /// tower", and "why did it disappear from the chat when I dismissed the
    /// notification").
    func testCrewPlanBlock() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataSeedCrewPlan", "1"])
        wait(10)
        let box = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Planned: Evening walk'")).firstMatch
        // Waiting for an answer: a card, and no box yet.
        let join = app.buttons["I'm In"].firstMatch
        let offered = join.waitForExistence(timeout: 3)
        let before = box.exists
        snap("planblock-offered")
        // Closing the card on this screen must not take the line from the chat.
        let close = app.buttons["Close"].firstMatch
        if close.exists { close.tap(); wait(1) }
        let closedHere = !app.buttons["I'm In"].firstMatch.exists
        app.buttons["Chat"].firstMatch.tap(); wait(3)
        let inChat = app.buttons["I'm In"].firstMatch
        let stillInChat = inChat.waitForExistence(timeout: 4)
        snap("planblock-chat-after-close")
        // The line's own card has nothing to close it with.
        let closesInChat = app.buttons.matching(identifier: "Close").count
        if stillInChat { inChat.tap(); wait(2) }
        snap("planblock-chat-joined")
        // Back to the crew: the box stands on its tower.
        app.swipeDown(velocity: .fast); wait(2)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2) }
        let standing = box.waitForExistence(timeout: 6)
        snap("planblock-on-tower")
        print("PLANNING-planblock: offered \(offered) box-before \(before) closed-here \(closedHere) still-in-chat \(stillInChat) closes-in-chat \(closesInChat) box-after \(standing) frame \(standing ? box.frame : .zero)")
        XCTAssertTrue(offered, "no plan card on the crew's screen")
        XCTAssertFalse(before, "a box before anyone said I'm In")
        XCTAssertTrue(stillInChat, "closing the card on the crew's screen took the plan's line out of the chat")
        XCTAssertTrue(standing, "no box on the crew's tower after I'm In")
        if standing {
            box.tap(); wait(1); snap("planblock-menu")
            let log = app.buttons["Log Without a Photo"].firstMatch
            print("PLANNING-planblock menu: photo \(app.buttons["Take Photo"].firstMatch.exists) library \(app.buttons["Choose from Library"].firstMatch.exists) log \(log.exists)")
            XCTAssertTrue(log.exists, "the box's menu did not open")
            if log.exists { log.tap(); wait(3); snap("planblock-add-sheet") }
        }
    }

    /// Memories scrolled under its header (the soft edge), and the tower's
    /// blocks without a shadow (both 2026-10-13).
    func testEdgeAndBlocks() {
        var app = launch(["-strataStartTab", "memories", "-strataSeedHistory", "40"])
        wait(8); snap("edge-memories-top")
        let page = app.scrollViews.firstMatch
        let from = page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        from.press(forDuration: 0.05, thenDragTo: page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)))
        wait(2); snap("edge-memories-scrolled")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "9"])
        wait(7); snap("blocks-tower")
        app.terminate()
        // A tower tall enough to scroll under its header.
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "44"])
        wait(8)
        let tower = app.scrollViews.firstMatch
        tower.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            .press(forDuration: 0.05, thenDragTo: tower.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        wait(2); snap("edge-tower-scrolled")
    }

    /// The rest of the crew list (2026-10-13): the crew's week and Show a
    /// Code on its page, Invite on a crew of one, and Sticker on a win.
    func testCrewRest() {
        var app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataCrewSheet", "info", "-strataSeedCrewHistory", "10"])
        wait(9); snap("crewrest-info")
        let code = app.buttons["Show a code"].firstMatch
        print("PLANNING-info: code \(code.exists) this week \(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'This Week'")).firstMatch.exists)")
        app.swipeUp(); wait(2); snap("crewrest-info-days")
        print("PLANNING-days: this week \(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'This Week'")).firstMatch.exists) last week \(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Last Week'")).firstMatch.exists)")
        for _ in 0..<4 where !(code.exists && code.isHittable) { app.swipeUp(); wait(1) }
        snap("crewrest-people")
        if code.exists, code.isHittable { code.tap(); wait(3); snap("crewrest-code") }
        print("PLANNING-code: row \(code.exists) image \(app.images["Invite code"].exists)")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "1", "-strataOpenCrew", "0"])
        wait(8); snap("crewrest-one")
        print("PLANNING-one: no invite on the screen \(!app.buttons["Invite"].firstMatch.exists)")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "win"])
        wait(9)
        let react = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'React'")).firstMatch
        if react.exists { react.tap(); wait(2) }
        snap("crewrest-win")
        print("PLANNING-win: react \(react.exists) sticker \(app.buttons["Sticker"].firstMatch.exists) doodle \(app.buttons["Doodle"].firstMatch.exists)")
        app.terminate()
        // Your own win takes your reaction (2026-10-13).
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "mine"])
        wait(9)
        let own = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'React'")).firstMatch
        if own.exists { own.tap(); wait(2) }
        snap("crewrest-own-win")
        print("PLANNING-own: react \(own.exists) reply \(app.buttons["Reply"].firstMatch.exists) sticker \(app.buttons["Sticker"].firstMatch.exists)")
        app.terminate()
        // The crew's plan on the crew's own screen.
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                      "-strataSeedCrewChat", "1", "-strataSeedCrewPlan", "1"])
        wait(10); snap("crewrest-plan-on-page")
        print("PLANNING-page: plan card \(app.buttons["I'm In"].firstMatch.exists)")
    }

    /// The crew chat's plus row, a group plan's card, a sticker and a photo
    /// brought back (`docs/crew-plus-design.md`), on a seeded crew.
    func testCrewPlus() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataCrewSheet", "chat", "-strataSeedCrewChat", "1", "-strataSeedCrewPlan", "1"])
        wait(9); snap("crewplus-chat")
        let join = app.buttons["I'm In"].firstMatch
        print("PLANNING-plan card: I'm In \(join.exists); did it line \(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'did it'")).firstMatch.exists)")
        if join.exists { join.tap(); wait(2); snap("crewplus-joined") }
        print("PLANNING-after joining: I'm In \(app.buttons["I'm In"].firstMatch.exists) undo \(app.buttons["Undo"].firstMatch.exists)")
        let plus = app.buttons["More to send"]
        print("PLANNING-plus: \(plus.exists)")
        if plus.exists { plus.tap(); wait(1); snap("crewplus-row") }
        for name in ["Add a win to this crew", "Plan something with this crew", "Send today's photo strip",
                     "Bring back a day this crew saw", "Send a sticker or a doodle"] {
            let b = app.buttons[name]
            print("PLANNING-\(name): \(b.exists) \(b.exists ? b.frame : .zero)")
        }
        let plan = app.buttons["Plan something with this crew"]
        if plan.exists { plan.tap(); wait(2); snap("crewplus-plan-sheet") }
        if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap(); wait(1) }
        if plus.exists { plus.tap(); wait(1) }
        let sticker = app.buttons["Send a sticker or a doodle"]
        if sticker.exists { sticker.tap(); wait(2); snap("crewplus-sticker-sheet") }
    }

    /// The camera's lens row and the flash's states (`docs/camera.md`). The
    /// simulator has no lens, so the row is drawn for a made-up phone.
    func testCameraLenses() {
        let app = launch(["-strataStartTab", "camera", "-strataFakeLenses", "1,2,4,6"])
        wait(6); snap("camera-lenses")
        let flash = app.buttons["flashToggle"]
        if flash.waitForExistence(timeout: 3) {
            print("PLANNING-flash before: \(flash.value ?? "nil")")
            flash.tap(); wait(1); snap("camera-flash-1")
            print("PLANNING-flash after one: \(flash.value ?? "nil")")
            flash.tap(); wait(1)
            print("PLANNING-flash after two: \(flash.value ?? "nil")")
        }
        // Folded at rest: one pill, and no row.
        let pill = app.buttons["Lens, 0.5x"]
        print("PLANNING-folded: pill \(pill.exists) frame \(pill.exists ? pill.frame : .zero) row \(app.buttons["Lens 2x"].exists)")
        if pill.exists { pill.tap(); wait(1); snap("camera-lenses-open") }
        for name in ["Lens 0.5x", "Lens 1x", "Lens 2x", "Lens 3x"] {
            let lens = app.buttons[name]
            print("PLANNING-\(name): exists \(lens.exists) frame \(lens.exists ? lens.frame : .zero) selected \(lens.exists && lens.isSelected)")
        }
        // Left alone it folds by itself.
        wait(4); snap("camera-lenses-folded")
        print("PLANNING-after 4s: pill \(pill.exists) row \(app.buttons["Lens 2x"].exists)")
        // Choosing folds it at once.
        if pill.exists { pill.tap(); wait(1) }
        if app.buttons["Lens 2x"].exists { app.buttons["Lens 2x"].tap(); wait(1) }
        print("PLANNING-after choosing: pill \(pill.exists) row \(app.buttons["Lens 2x"].exists)")
    }

    /// On this day (`Flashback`, `docs/flashback.md`): alone, among a
    /// month's albums, opened, and with its menu.
    func testFlashback() {
        var app = launch(["-strataStartTab", "memories", "-strataSeedFlashback", "1",
                          "-memories.flashback.lastUnderAYear", ""])
        wait(8); snap("flashback-alone")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'This day last month'")).firstMatch
        if card.waitForExistence(timeout: 4) {
            card.press(forDuration: 1.0); wait(2); snap("flashback-menu")
            if app.buttons["Remove Album"].exists { app.buttons["Remove Album"].tap(); wait(2); snap("flashback-removed") }
            if app.buttons["Undo"].firstMatch.exists { app.buttons["Undo"].firstMatch.tap(); wait(2); snap("flashback-undone") }
            card.tap(); wait(3); snap("flashback-day")
        }
        app.terminate()
        app = launch(["-strataStartTab", "memories", "-strataSeedFlashback", "1", "-strataSeedHistory", "20",
                      "-memories.flashback.lastUnderAYear", ""])
        wait(8); snap("flashback-among")
        app.terminate()
        // None due: the page as it was.
        _ = launch(["-strataStartTab", "memories", "-strataSeedHistory", "20", "-memories.flashback.lastUnderAYear", ""])
        wait(8); snap("flashback-none")
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
