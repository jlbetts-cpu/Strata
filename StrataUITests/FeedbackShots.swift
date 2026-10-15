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
        for step in [1, 4, 5, 6, 8, 9] {
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
        // The row that can be pressed: the block carries the same words as
        // an accessibility action, and `firstMatch` was sometimes that.
        _ = app.buttons["Move Photo"].firstMatch.waitForExistence(timeout: 3)
        let rows = app.buttons.matching(identifier: "Move Photo").allElementsBoundByIndex
        (rows.last { $0.isHittable } ?? rows.last)?.tap()
        wait(2); snap("move-2-crop")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        wait(1); snap("move-3-dragged")
        // A pinch zooms it (2026-10-13).
        let stage = app.descendants(matching: .any)["cropStage"].firstMatch
        let found = stage.waitForExistence(timeout: 3)
        let before = (stage.value as? String) ?? ""
        if found { stage.pinch(withScale: 2.2, velocity: 2) }
        wait(1); snap("move-4-zoomed")
        let after = (stage.value as? String) ?? ""
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap() }
        wait(2); snap("move-5-block")
        let add = app.buttons["Add"].firstMatch
        if add.exists { add.tap() }
        wait(5); snap("move-6-tower")
        print("PLANNING-move: stage \(found) before '\(before)' after '\(after)' add \(add.exists)")
        XCTAssertTrue(found, "no stage to pinch on Move Photo")
        XCTAssertEqual(before, "Zoom 100 percent")
        XCTAssertNotEqual(after, before, "a pinch did not zoom the photo")
    }

    /// Move Photo on a real photograph, for looking at: the box, the photo
    /// faded outside it, and the header's blur over what runs under it.
    func testMovePhotoLook() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "addphoto",
                          "-strataSeedRealPhotos", "demo"])
        wait(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).tap()
        wait(2)
        _ = app.buttons["Move Photo"].firstMatch.waitForExistence(timeout: 3)
        let rows = app.buttons.matching(identifier: "Move Photo").allElementsBoundByIndex
        (rows.last { $0.isHittable } ?? rows.last)?.tap()
        wait(2); snap("look-0-open")
        let stage = app.descendants(matching: .any)["cropStage"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 3), "Move Photo did not open")
        stage.pinch(withScale: 1.6, velocity: 1)
        wait(1); snap("look-1-zoomed")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.62)))
        wait(1); snap("look-2-moved")
    }

    /// Move Photo from a PRESS on a block that is not square: the box is the
    /// block's own shape (it opened square, found by review 2026-10-13).
    func testMovePhotoShapes() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "addphoto",
                          "-strataSeedRealPhotos", "demo"])
        wait(8)
        for size in ["Regular", "Deep"] {
            let pick = app.buttons[size].firstMatch
            if pick.waitForExistence(timeout: 3) { pick.tap() }
            wait(1); snap("shape-\(size)-0-sheet")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).tap()
            wait(2)
            _ = app.buttons["Move Photo"].firstMatch.waitForExistence(timeout: 3)
            let rows = app.buttons.matching(identifier: "Move Photo").allElementsBoundByIndex
            (rows.last { $0.isHittable } ?? rows.last)?.tap()
            wait(2)
            let stage = app.descendants(matching: .any)["cropStage"].firstMatch
            XCTAssertTrue(stage.waitForExistence(timeout: 3), "Move Photo did not open on a \(size) block")
            stage.pinch(withScale: 1.5, velocity: 1)
            wait(1); snap("shape-\(size)-1-editor")
            app.buttons["Done"].firstMatch.tap()
            wait(2); snap("shape-\(size)-2-block")
        }
    }

    /// **The camera's review as an editor** (2026-10-13): the still box, the
    /// tools in a row, the looks in their place, the doodle sheet over the
    /// photograph, and a zoomed, drawn-on photograph reaching the add sheet.
    func testReviewEditor() {
        let app = launch(["-strataStartTab", "camera", "-strataOpenReview", "medium",
                          "-strataReviewPhoto", "DemoPhoto1", "-strataSeedHead", "1", "-strataHeadOn", "camera",
                          "-strataReviewSticker", "-strataReviewMarks", "-strataReviewZoom", "1.6"])
        let use = app.buttons["Use Photo"]
        XCTAssertTrue(use.waitForExistence(timeout: 30), "no review screen")
        wait(2); snap("review-0-rest")
        let looks = app.buttons["Choose a look"]
        XCTAssertTrue(looks.exists, "no Looks tool on the review")
        let back = app.buttons["Back to the tools"]
        XCTAssertTrue(app.buttons["Doodle on the photo"].exists, "no Doodle tool on the review")
        XCTAssertTrue(app.buttons["Add a sticker to the photo"].exists, "no Sticker tool on the review")
        // Pressed until the looks are up (see `press` below for why).
        for _ in 1...3 where !back.isHittable { looks.press(forDuration: 0.12); wait(1) }
        snap("review-1-looks")
        let silver = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Silver'")).firstMatch
        if silver.exists { silver.tap(); wait(2) }
        snap("review-2-silver")
        XCTAssertTrue(back.isHittable, "no way back from the looks to the tools")
        back.press(forDuration: 0.12)
        wait(1)
        let doodle = app.buttons["Doodle on the photo"]
        print("PLANNING-review: doodle exists \(doodle.exists) hittable \(doodle.isHittable) frame \(doodle.frame)")
        // **A press with a finger's length to it, and once more if it did not
        // land.** The runner's own tap is over in an instant, and on this
        // glass it was missed for a few seconds after the review appeared or
        // the looks closed (2026-10-13), in the simulator by hand too, where
        // a 0.12s press landed. The app's other glass buttons share it.
        // Logged, so a change shows; a real finger is for the owner's phone.
        func press(_ button: XCUIElement, until shown: XCUIElement) -> Int {
            for attempt in 1...3 {
                button.press(forDuration: 0.12)
                if shown.waitForExistence(timeout: 3) { return attempt }
            }
            return 0
        }
        let done = app.buttons["Done"].firstMatch
        let attempts = press(doodle, until: done)
        let opened = attempts > 0
        print("PLANNING-review: doodle sheet opened on press \(attempts)")
        wait(1); snap("review-3-doodle")
        XCTAssertTrue(opened, "the doodle sheet did not open")
        done.tap()
        wait(2); snap("review-4-back")
        use.tap()
        let regular = app.buttons["Regular"].firstMatch
        XCTAssertTrue(regular.waitForExistence(timeout: 15), "the shot never reached the add sheet")
        wait(2); snap("review-5-sheet")
        let add = app.buttons["Add"].firstMatch
        if add.exists { add.tap() }
        wait(5); snap("review-6-tower")
    }

    /// **The add sheet's camera, framed as the tab's is** (the owner,
    /// 2026-10-14: "make sure the camera fixes are implemented everywhere the
    /// camera is for consistency").
    func testSheetCamera() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "addphoto",
                          "-strataFakeLens", "/Users/jaydenbetts/Developer/Strata/docs/site/tower.mp4"])
        wait(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).tap()
        wait(2)
        let take = app.buttons["Take Photo"].firstMatch
        if take.waitForExistence(timeout: 3) { take.tap() }
        wait(4); snap("sheet-camera")
    }

    /// **Does anything leave Wins raised?** (the owner, 2026-10-14: "randomly
    /// like the tower and all the ui would get higher than they usually
    /// are"). Wins photographed after each everyday thing: a sheet with the
    /// keyboard, the camera, a crew's chat with the keyboard, the plan.
    func testLayoutStaysPut() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedWins", "4",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none", "-strataStartTab", "tower"])
        wait(8); snap("put-0-start")
        // Add a win, keyboard up, cancelled.
        let slot = app.buttons["Log a win"].firstMatch
        if slot.exists { slot.press(forDuration: 0.08) }
        wait(2.5)
        app.typeText("x")
        wait(1)
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        let discard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Discard'")).firstMatch
        if discard.waitForExistence(timeout: 2) { discard.tap() }
        wait(2.5); snap("put-1-after-add")
        // The camera and back.
        app.tabBars.buttons["Camera"].firstMatch.tap(); wait(3)
        app.tabBars.buttons["Wins"].firstMatch.tap(); wait(2.5); snap("put-2-after-camera")
        // A crew's chat with the keyboard, then back.
        app.tabBars.buttons["Crews"].firstMatch.tap(); wait(2.5)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roommates'")).firstMatch
        if row.exists { row.tap() }
        wait(3)
        let field = app.buttons["Write a message"].firstMatch
        if field.exists { field.press(forDuration: 0.05) }
        wait(2.5)
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap() }
        wait(2)
        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Crews'")).firstMatch
        if back.exists { back.tap() }
        wait(2)
        app.tabBars.buttons["Wins"].firstMatch.tap(); wait(2.5); snap("put-3-after-chat")
        // The plan, keyboard up, then away.
        app.buttons["Plan"].firstMatch.tap(); wait(3)
        app.swipeDown(velocity: .fast); wait(2.5); snap("put-4-after-plan")
    }

    /// **Every drawing on its own screen, for the owner** (2026-10-14: "can
    /// you send me the drawings on all the screens they are there"). Each
    /// screen photographed mid-play and at rest.
    func testDrawingsOnTheirScreens() {
        func shoot(_ name: String, _ args: [String], at: [Double], before: ((XCUIApplication) -> Void)? = nil) {
            let app = launch(args)
            wait(at.first ?? 6)
            before?(app)
            for (i, t) in at.enumerated() {
                if i > 0 { wait(t) }
                snap("draw-\(name)-\(i)")
            }
            app.terminate()
        }
        // November's turkey, at the end of Memories.
        shoot("november", ["-strataStartTab", "memories", "-strataSeedHistory", "30", "-strataSeedHistoryPerDay", "2",
                           "-strataMonthArt", "November"], at: [8, 0.5, 2.5]) { app in
            for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        }
        // The store could not open: the cat.
        shoot("store", ["-strataFailStore", "both"], at: [4, 0.5, 2])
        // Restore failed (the cat) and done (the thumbs up).
        for stage in ["failed", "done"] {
            shoot("restore-\(stage)", ["-strataSeedBackup", "40", "-strataRestoreFrom", "strata-debug-backup.zip",
                                       "-strataRestoreStage", stage, "-strataOpenSheet", "settings"], at: [9, 0.5, 2])
        }
        // Crews: joining (the walking cat), joined (the thumbs up), signed out (the cloud).
        shoot("joining", ["-strataCrews", "1", "-strataStartTab", "crews", "-strataCrewsState", "joining"], at: [6, 0.5, 1.5])
        shoot("joined", ["-strataCrews", "1", "-strataStartTab", "crews", "-strataCrewsState", "joined"], at: [6, 0.4, 1.5])
        shoot("nocloud", ["-strataCrews", "1", "-strataStartTab", "crews"], at: [6, 0.8, 2])
        // The head maker, no face found: the box head.
        shoot("noface", ["-strataOpenHeadMaker", "failed"], at: [5, 0.6, 2])
        // Onboarding, Lock Journal: the lock.
        shoot("lock", ["-strataShowOnboarding", "1", "-strataOnboardingStep", "9"], at: [3, 0.5, 2])
        // The tip thanks: the thumbs up.
        shoot("tip", ["-strataStartTab", "tower", "-strataOpenSheet", "tipask", "-strataTipThanked"], at: [6, 0.4, 2])
        // The report thanks: the thumbs up on its card.
        shoot("report", ["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "info",
                         "-strataReportThanks"], at: [9, 0.4, 2])
        // Settings, Lock Journal switched on: the small thumbs up.
        shoot("settings-lock", ["-strataOpenSheet", "settings", "-strataScrollSettings", "journal"], at: [7, 0.4, 1.2]) { app in
            let toggle = app.switches["Lock Journal"].firstMatch
            if toggle.waitForExistence(timeout: 5) { toggle.tap() }
        }
    }

    /// **Wins after coming back to the app** (the owner, 2026-10-14: the
    /// tower and the UI "randomly ... higher than they usually are", when
    /// "coming back to the app").
    func testLayoutAfterReturning() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedWins", "4",
                          "-strataStartTab", "tower"])
        wait(8); snap("back-0-start")
        XCUIDevice.shared.press(.home); wait(3)
        app.activate(); wait(0.4); snap("back-1-at-once")
        wait(2); snap("back-2-settled")
        // From the camera tab, home, and back.
        app.tabBars.buttons["Camera"].firstMatch.tap(); wait(3)
        XCUIDevice.shared.press(.home); wait(3)
        app.activate(); wait(2)
        app.tabBars.buttons["Wins"].firstMatch.tap(); wait(2); snap("back-3-via-camera")
        // With the plan open (a sheet and the keyboard), home, and back.
        app.buttons["Plan"].firstMatch.tap(); wait(3)
        XCUIDevice.shared.press(.home); wait(3)
        app.activate(); wait(2)
        app.swipeDown(velocity: .fast); wait(2.5); snap("back-4-via-plan")
        // Locked and unlocked is not reachable here; a long background is.
        XCUIDevice.shared.press(.home); wait(25)
        app.activate(); wait(0.4); snap("back-5-long-at-once")
        wait(2.5); snap("back-6-long-settled")
    }

    /// **Every choice on the chat's +, opened** (the owner, 2026-10-14: "make
    /// sure the + button all the functions actually are useful and work
    /// properly").
    func testChatPlusChoices() {
        for word in ["Add a win to this crew", "Plan something with this crew", "Send a sticker or a doodle",
                     "Send today's photo strip"] {
            let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                              "-strataSeedCrewChat", "1", "-strataCrewFaces", "none", "-strataSeedWins", "3",
                              "-strataSeedRealPhotos", "demo"])
            wait(9)
            app.buttons["More to send"].firstMatch.press(forDuration: 0.08)
            wait(2.5)
            let choice = app.buttons.matching(NSPredicate(format: "label == %@", word)).allElementsBoundByIndex
                .last { $0.isHittable }
            print("PLANNING-plus \(word): \(choice != nil)")
            choice?.press(forDuration: 0.08)
            wait(3); snap("plus-\(word.split(separator: " ")[1])")
            app.terminate()
        }
    }

    /// **A held chat line's reactions beside a held win's** (the owner,
    /// 2026-10-14: "reactions to chat dont seem to work the same ... and the
    /// look is different").
    func testChatHoldMenu() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none"])
        wait(9)
        let line = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat'")).firstMatch
        line.press(forDuration: 0.05)
        wait(2.5)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.36, dy: 0.578)).press(forDuration: 0.8)
        wait(1.5); snap("hold-chat")
        let more = app.buttons["More reactions"].firstMatch
        print("PLANNING-hold: more \(more.exists)")
        if more.exists { more.tap() }
        wait(1.5); snap("hold-chat-more")
    }

    /// **The chat opening by a tap, to read and to write** (the owner,
    /// 2026-10-14: "the chat is still not smooth like the way it opens and
    /// when you click like it feels delayed"), for a recording read frame by
    /// frame. Each tap is a short press, as a finger's is.
    func testChatOpenFeel() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none", "-strataPerfProbe"])
        wait(9)
        let line = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat'")).firstMatch
        line.press(forDuration: 0.05)
        wait(2.5)
        app.buttons["Done"].firstMatch.tap()
        wait(2.5)
        app.buttons["Write a message"].firstMatch.press(forDuration: 0.05)
        wait(3); snap("feel-writing")
        app.typeText("on my way")
        wait(1)
        // The keys down by a drag on the thread, as a thumb puts them away.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)))
        wait(2); snap("feel-keys-down")
        app.buttons["Done"].firstMatch.tap()
        wait(2.5)
    }

    /// **A crew's photo grows out of its block** (the motion pass,
    /// 2026-10-14), for a recording.
    func testCrewPhotoZoom() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataCrewFaces", "none"])
        wait(9)
        let block = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Morning run'")).firstMatch
        if block.exists { block.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)).tap() }
        wait(3); snap("zoom-open")
        app.buttons["Close photo"].firstMatch.tap()
        wait(2); snap("zoom-closed")
    }

    /// **Reply from the hold** (the owner, 2026-10-14: "when you are holding
    /// to react reply should pop up as an option and the chat should pop up").
    func testReplyFromHold() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none"])
        wait(9)
        let block = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Shipped it'")).firstMatch
        let at = block.exists ? block.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                              : app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45))
        at.press(forDuration: 0.9)
        wait(1); snap("reply-0-held")
        let reply = app.buttons["Reply"].firstMatch
        print("PLANNING-reply: \(reply.exists) \(reply.frame)")
        if reply.exists { reply.press(forDuration: 0.12) }
        wait(2.5); snap("reply-1-chat")
        app.typeText("Proud of you")
        wait(1); snap("reply-2-typed")
    }

    /// **Add a Win opening from the empty slot, for a recording** (the owner,
    /// 2026-10-14: "the add a win animation ... elements on the screen arent
    /// clean and clear like the block shrinking").
    func testAddWinOpening() {
        let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3"])
        wait(8); snap("addopen-0-tower")
        let adds = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] 'log'")).allElementsBoundByIndex
        for b in adds { print("PLANNING-add: '\(b.label)' \(b.frame)") }
        let slot = adds.first { $0.frame.width > 40 && $0.frame.minY > 200 }
        if let slot { slot.press(forDuration: 0.08) } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.11, dy: 0.865)).tap() }
        wait(3); snap("addopen-1-sheet")
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        wait(3); snap("addopen-2-closed")
    }

    /// **The camera review's crop, as a thumb uses it** (the owner,
    /// 2026-10-14: "the cropping its super not smooth and black bars appear
    /// and it looks very jank ... mainly in the camera screen"). Slow drags
    /// into each edge, a pinch in and back out, and the three sizes, for a
    /// recording to be read frame by frame.
    func testReviewCropFeel() {
        let app = launch(["-strataStartTab", "camera", "-strataOpenReview", "regular",
                          "-strataReviewPhoto", "DemoPhoto1"])
        let use = app.buttons["Use Photo"]
        XCTAssertTrue(use.waitForExistence(timeout: 30), "no review screen")
        wait(2); snap("feel-0-rest")
        let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        func drag(_ dx: CGFloat, _ dy: CGFloat) {
            mid.press(forDuration: 0.05,
                      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + dx, dy: 0.42 + dy)),
                      withVelocity: 300, thenHoldForDuration: 0.3)
            wait(1)
        }
        drag(0.35, 0); snap("feel-1-right")
        drag(-0.35, 0)
        drag(0, 0.2); snap("feel-2-down")
        drag(0, -0.2)
        app.pinch(withScale: 2.0, velocity: 1); wait(1); snap("feel-3-zoomed")
        drag(0, 0.25); snap("feel-4-zoomed-down")
        drag(0.3, 0)
        app.pinch(withScale: 0.4, velocity: -1); wait(1); snap("feel-5-out")
        for size in ["Quick", "Deep", "Regular"] {
            let pick = app.buttons[size].firstMatch
            if pick.exists { pick.press(forDuration: 0.12) }
            wait(1); snap("feel-6-\(size)")
        }
    }

    /// **Memories, top and end** (the owner, 2026-10-13: "you left the huge
    /// gap above the memories calendar ... the skeleton is small now and is
    /// it still animated?"). The calendar under the header; the drawing at
    /// the end at its full height, photographed twice a second apart so a
    /// dance shows as two different poses.
    func testMemoriesEnd() {
        let app = launch(["-strataStartTab", "memories", "-strataSeedHistory", "30", "-strataSeedHistoryPerDay", "2",
                          "-strataSeedTodayPhotos", "all", "-strataSeedRealPhotos", "demo"])
        wait(8); snap("mem-0-top")
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        wait(0.6); snap("mem-1-end-a")
        wait(0.8); snap("mem-2-end-b")
        wait(4); snap("mem-3-end-rest")
        // A press on him plays it again.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        wait(0.4); snap("mem-4-tap-a")
        wait(0.6); snap("mem-5-tap-b")
    }

    /// **The photo viewer as Photos does it** (the owner, 2026-10-14): the
    /// page at rest, a tap and everything goes and the ground goes black, a
    /// tap brings it back.
    func testViewerImmersive() {
        let app = launch(["-strataStartTab", "memories", "-strataSeedHistory", "30", "-strataSeedHistoryPerDay", "2",
                          "-strataSeedTodayPhotos", "all", "-strataSeedRealPhotos", "demo"])
        wait(8)
        app.swipeUp(velocity: .slow); wait(1)
        // The first photograph under the Deep heading, where the slow swipe
        // leaves it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.34)).tap()
        wait(2.5); snap("viewer-0-rest")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        wait(1.5); snap("viewer-1-immersive")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        wait(1.5); snap("viewer-2-back")
    }

    /// **Memories split by size** (the owner, 2026-10-14: "keep the apple
    /// photos look while splitting it into sizes").
    func testMemoriesBySize() {
        let app = launch(["-strataStartTab", "memories", "-strataSeedHistory", "30", "-strataSeedHistoryPerDay", "2",
                          "-strataSeedTodayPhotos", "all", "-strataSeedRealPhotos", "demo"])
        wait(8)
        app.swipeUp(velocity: .slow); wait(1); snap("size-0")
        app.swipeUp(velocity: .slow); wait(1); snap("size-1")
        app.swipeUp(velocity: .slow); wait(1); snap("size-2")
    }

    /// **Every crew, in one press** (the owner, 2026-10-13): off, on (every
    /// crew ticked and the tag button at the row's end with no name under
    /// it), and off again.
    func testEveryCrew() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3",
                          "-strataCrewFaces", "none", "-strataStartTab", "tower", "-strataSeedWins", "3",
                          "-strataOpenSheet", "addphoto", "-strataSeedRealPhotos", "demo"])
        let every = app.buttons["Every crew"]
        XCTAssertTrue(every.waitForExistence(timeout: 20), "no Every crew on the add sheet")
        wait(1); snap("every-0-off")
        every.tap()
        wait(1); snap("every-1-on")
        let chosen = app.buttons.matching(NSPredicate(format: "label == 'Every crew, chosen'")).firstMatch
        XCTAssertTrue(chosen.exists, "Every crew did not choose every crew")
        let crews = ["Roommates", "Run Club"].map { app.buttons[$0] }
        for crew in crews where crew.exists {
            XCTAssertTrue(crew.isSelected, "\(crew.label) was not chosen with every crew")
        }
        chosen.tap()
        wait(1); snap("every-2-off-again")
        XCTAssertTrue(app.buttons["Every crew"].exists, "Every crew did not let them all go")
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
        if app.buttons["New Crew"].firstMatch.exists { app.buttons["New Crew"].firstMatch.tap(); wait(2); snap("crews-new") }
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
        let landed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat, '")).firstMatch.waitForExistence(timeout: 40)
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

    /// **Typed words stay inside the field as it grows** (a tester, through
    /// the owner, 2026-10-13): the journal's bar and the chat's.
    func testWritingFields() {
        let long = "Night market with the crew, then the long way home along the river, and nobody was in a hurry for once"
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenJournal", "today",
                          "-strataDayTab", "journal"])
        wait(8)
        // Tap until the keyboard is up: typing with no focus stops the run.
        func write(into field: XCUIElement) {
            guard field.waitForExistence(timeout: 6) else { return }
            for _ in 0..<3 where !app.keyboards.firstMatch.exists {
                field.tap()
                _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
            }
            if app.keyboards.firstMatch.exists { app.typeText(long) }
        }
        // The bar at the foot, by what it invites: the first field on the
        // page is the day's sticker.
        let bar = NSPredicate(format: "placeholderValue BEGINSWITH 'Write' OR label BEGINSWITH 'Write' OR value BEGINSWITH 'Write'")
        var field = app.textViews.matching(bar).firstMatch.exists ? app.textViews.matching(bar).firstMatch
            : app.textFields.matching(bar).firstMatch
        write(into: field)
        if !app.keyboards.firstMatch.exists {
            // By where it stands: the bar at the foot of the page.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.925)).tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 4) { app.typeText(long) }
        }
        wait(1); snap("fields-journal")
        print("PLANNING-fields journal: field \(field.exists) frame \(field.exists ? field.frame : .zero)")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "3", "-strataOpenCrew", "0",
                      "-strataCrewSheet", "chat", "-strataSeedCrewChat", "1"])
        wait(10)
        field = app.textFields["Message"].exists ? app.textFields["Message"] : app.textViews["Message"]
        write(into: field)
        wait(1); snap("fields-chat")
        print("PLANNING-fields chat: field \(field.exists) frame \(field.exists ? field.frame : .zero)")
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

    /// **A head out on a crew's tower, the chat opened and typed in, and
    /// closed again** (his phone note, 2026-10-13: the head "glitched when
    /// clicking back in chat going over blocks"). Snapped before and after;
    /// the head must be in the air above the tower, not over its blocks.
    func testHeadAfterChat() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataSeedHead", "1"])
        wait(9)
        // Light queries only: the heads draw every frame, so the app is never
        // idle and every element tree read waits out its timeout.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap(); wait(1.5)
        snap("headchat-fan")
        let mine = app.buttons["Your head"].firstMatch
        if mine.exists { mine.tap() }
        wait(6); snap("headchat-before")
        // The chat is the drawer's resting line now (2026-10-14).
        let chat = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat, '")).firstMatch
        XCTAssertTrue(chat.waitForExistence(timeout: 4), "no chat drawer")
        chat.tap(); wait(2)
        let field = app.textViews.firstMatch
        // The first tap folds the fan, if it is open.
        if !field.waitForExistence(timeout: 2) { chat.tap(); wait(2) }
        if field.waitForExistence(timeout: 4) { field.tap(); wait(1.5); field.typeText("on my way"); wait(1.5) }
        snap("headchat-typing")
        app.swipeDown(velocity: .fast); wait(1)
        app.swipeDown(velocity: .fast); wait(4)
        snap("headchat-after")
        wait(4); snap("headchat-after2")
    }

    /// **The crew's + is Wins' +** (the owner, 2026-10-13), Plan included:
    /// from a crew, Plan proposes to that crew.
    func testCrewPlusSheet() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0"])
        wait(9)
        let slot = app.descendants(matching: .any)["Log a win"].firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 5), "no slot on the crew tower")
        slot.tap(); wait(3)
        snap("crewplus-sheet")
        let row = app.descendants(matching: .any)["Plan for Later"].firstMatch
        let offered = row.exists
        print("PLANNING-crewplus: plan row \(offered)")
        if offered { row.tap(); wait(1.5) }
        let later = app.buttons["Tomorrow"].firstMatch
        if later.waitForExistence(timeout: 3) { later.tap(); wait(1.5) }
        snap("crewplus-tomorrow")
        app.typeText("Pickup game at 5\n"); wait(3)
        snap("crewplus-planned")
        XCTAssertTrue(offered, "no plan row on the crew's add sheet")
    }

    /// **A tall crew tower scrolls to its top** (the owner, 2026-10-13: "when
    /// the tower gets high on the crew but the scroll up doesnt get taller").
    func testTallCrewTower() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewWins", "40"] + (ProcessInfo.processInfo.environment["STRATA_NOFACES"] == nil ? [] : ["-strataCrewFaces", "none"]))
        wait(10); snap("tallcrew-start")
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<4 { scroll.swipeUp(velocity: .fast) }
        wait(2); snap("tallcrew-bottom")
        for _ in 0..<8 { scroll.swipeDown(velocity: .fast) }
        wait(2); snap("tallcrew-top")
    }

    /// **Holding a crew block still opens the reactions, and sliding onto
    /// one gives it** (2026-10-13, the hold moved to UIKit's long press so
    /// a tall tower scrolls).
    func testHoldToReact() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewFaces", "none"])
        wait(9)
        let block = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.62))
        block.press(forDuration: 0.9); wait(0.6)
        snap("hold-bar")
        let barOpen = app.buttons.matching(NSPredicate(format: "label CONTAINS 'React with' OR label CONTAINS 'More reactions'")).count
        print("PLANNING-hold: bar buttons \(barOpen)")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3)).tap(); wait(2)
        // Hold and slide up onto the bar, then let go.
        block.press(forDuration: 0.6, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.55)))
        wait(2); snap("hold-slid")
    }

    /// **A head let out over a tower taller than the screen** (the owner,
    /// 2026-10-13: "the head kinda glitches when the tower is that high").
    func testHeadOnTallTower() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewWins", "40", "-strataSeedHead", "1"])
        wait(10)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap(); wait(1.5)
        let mine = app.buttons["Your head"].firstMatch
        if mine.exists { mine.tap() }
        for i in 0..<4 { wait(0.7); snap("tallhead-\(i)") }
        wait(4); snap("tallhead-waited")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.3)).tap(); wait(1); snap("tallhead-folded")
        app.scrollViews.firstMatch.swipeUp(velocity: .fast); wait(1.5); snap("tallhead-scrolled")
        app.scrollViews.firstMatch.swipeDown(velocity: .fast); app.scrollViews.firstMatch.swipeDown(velocity: .fast)
        wait(1.5); snap("tallhead-back")
    }

    /// New Crew on the empty Crews tab, and a crew of one's tip (the
    /// invites research, 2026-10-13; Invite a Friend became New Crew on
    /// 2026-10-14, the owner's "Merge into one").
    func testInviteAFriend() {
        var app = launch(["-strataCrews", "1", "-strataStartTab", "crews", "-crews.rulesAccepted.v1", "YES", "-strataCrewsSignedIn", "1"])
        wait(8); snap("invite-empty")
        print("PLANNING-invite: button \(app.buttons["New Crew"].firstMatch.exists) line \(app.staticTexts["Got a link from a friend? Open it again to join."].exists)")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "1", "-strataOpenCrew", "0", "-crews.justYouShown", "()"])
        wait(6); snap("invite-alone")
        print("PLANNING-alone: tip \(app.staticTexts["Just you so far."].exists)")
    }

    /// **Hide for Me can be taken back**: the Undo line, then the crew's
    /// card lists it under Hidden for You with Show (2026-10-13).
    func testHideAndShow() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewFaces", "none"])
        wait(9)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.72)).tap(); wait(2.5)
        let more = app.buttons["Photo actions"].firstMatch
        if more.waitForExistence(timeout: 4) { more.tap(); wait(1.2) }
        let hide = app.buttons["Hide for Me"].firstMatch
        let offered = hide.exists
        if offered { hide.tap() }
        wait(1); snap("hide-undo")
        print("PLANNING-hide: offered \(offered) undo line \(app.staticTexts["Hidden for you"].exists)")
        wait(6)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.19)).tap(); wait(2.5)
        snap("hide-card-top")
        for _ in 0..<5 where !app.staticTexts["Hidden for You"].exists { app.swipeUp(); wait(0.8) }
        app.swipeUp(); wait(0.8)
        snap("hide-card")
        let show = app.buttons["Show"].firstMatch
        print("PLANNING-hidden: section \(app.staticTexts["Hidden for You"].exists) show \(show.exists)")
        if show.exists { show.tap(); wait(1.5); snap("hide-shown") }
    }

    /// **A win from earlier today, sent to a crew that did not get it**
    /// (the owner, 2026-10-13), from that crew's + sheet.
    func testEarlierToday() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedHistory", "1", "-strataSeedHistoryPerDay", "3", "-strataCrewFaces", "none"])
        wait(9)
        let slot = app.descendants(matching: .any)["Log a win"].firstMatch
        if slot.waitForExistence(timeout: 5) { slot.tap(); wait(3) }
        snap("earlier-sheet")
        let row = app.staticTexts["Earlier Today"].exists
        print("PLANNING-earlier: row \(row)")
        let chip = app.buttons.matching(NSPredicate(format: "label IN %@", ["Deep work", "Walk", "Inbox zero", "Sketch", "Ran 5k", "Stretched"])).firstMatch
        if chip.exists { chip.tap(); wait(2.5) }
        snap("earlier-sent")
    }

    /// **Everything the night's helpers built, photographed** (2026-10-14):
    /// the Wins crest, its head let out, reactions on your blocks, a
    /// friend's line over Wins; the chat, its plus row, a held line, a
    /// strip full screen.
    func testNightWalk() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedHead", "1",
                          "-strataHeadOn", "picture", "-strataSeedMyReactions", "1"])
        wait(8); snap("night-1-wins")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.11)).tap(); wait(3)
        snap("night-2-head-out")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataCrews", "1", "-strataSeedCrew", "4",
                      "-strataFriendSaysEvery", "6", "-strataSeedWins", "2"])
        for i in 0..<4 { wait(3); snap("night-3-banner-\(i)") }
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "chat",
                      "-strataSeedCrewChat", "1", "-strataSeedCrewStrip", "1"])
        wait(9); snap("night-4-chat")
        let plus = app.buttons["More to send"]
        if plus.waitForExistence(timeout: 4) { plus.tap(); wait(1.5) }
        snap("night-5-plus-row")
        print("PLANNING-night: row \(["Win", "Plan", "Sticker", "Strip", "Memory"].map { "\($0) \(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", $0)).count)" })")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "chat",
                      "-strataSeedCrewChat", "1", "-strataChatReact", "open"])
        wait(9); snap("night-6-hold")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "chat",
                      "-strataSeedCrewChat", "0"])
        wait(9); snap("night-7-empty-chat")
    }

    /// **The chat as a drawer under the crew's tower** (the owner's pick,
    /// 2026-10-13): at rest, opened by its line, closed again; opened by
    /// its field with the keyboard.
    func testChatDrawer() {
        var app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none"])
        wait(9); snap("drawer-rest")
        let field = app.buttons["Write a message"].firstMatch
        print("PLANNING-field: exists \(field.exists) hittable \(field.isHittable) frame \(field.frame)")
        if field.exists { field.press(forDuration: 0.12); wait(2.5) }
        snap("drawer-writing")
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap(); wait(2) }
        let plus = app.buttons["More to send"].firstMatch
        if plus.exists { plus.tap(); wait(2.5) }
        snap("drawer-plus")
        let grab = app.descendants(matching: .any)["Show All of the Chat"].firstMatch
        if grab.exists {
            grab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
            wait(2)
        }
        snap("drawer-full")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews"])
        wait(8); snap("crews-corners")
        print("PLANNING-corner: new crew \(app.buttons["New Crew"].firstMatch.exists)")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "2", "-strataSeedPlan", "3"])
        wait(8)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2) }
        app.buttons["Plan"].firstMatch.tap(); wait(2.5)
        snap("plan-alone")
    }

    /// **The drawer thrown as a thumb throws it** (the motion pass,
    /// 2026-10-14): a flick up from the resting bar, a short pull that
    /// springs back, a flick to the whole height, then down to part way
    /// and shut. For a recording read frame by frame.
    func testDrawerMotion() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none"])
        wait(9); snap("motion-0-rest")
        func flick(from: CGFloat, to: CGFloat, speed: CGFloat) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)),
                       withVelocity: XCUIGestureVelocity(speed), thenHoldForDuration: 0)
        }
        // The resting bar's line, flicked a short way.
        let line = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat'")).firstMatch
        let barY = line.exists ? line.frame.midY / app.frame.height : 0.9
        flick(from: barY, to: barY - 0.06, speed: 1500)
        wait(1.5); snap("motion-1-opened")
        let grab = app.descendants(matching: .any)["Show All of the Chat"].firstMatch
        let grabY = grab.exists ? grab.frame.midY / app.frame.height : 0.4
        print("PLANNING-drawer: opened \(grab.exists) grabber at \(grabY)")
        // A slow short pull down: back to part way.
        flick(from: grabY, to: grabY + 0.05, speed: 150)
        wait(1.5); snap("motion-2-sprang-back")
        // Flicked up: the whole height.
        flick(from: grabY, to: grabY - 0.08, speed: 1500)
        wait(1.5); snap("motion-3-full")
        let less = app.descendants(matching: .any)["Show Less of the Chat"].firstMatch
        print("PLANNING-drawer: full \(less.exists)")
        let lessY = less.exists ? less.frame.midY / app.frame.height : 0.08
        flick(from: lessY, to: lessY + 0.1, speed: 900)
        wait(1.5); snap("motion-4-part")
        let grab2 = app.descendants(matching: .any)["Show All of the Chat"].firstMatch
        let y2 = grab2.exists ? grab2.frame.midY / app.frame.height : 0.4
        flick(from: y2, to: y2 + 0.12, speed: 1500)
        wait(1.5); snap("motion-5-shut")
        print("PLANNING-drawer: shut \(!app.descendants(matching: .any)["Show All of the Chat"].firstMatch.isHittable)")
    }

    /// **Tips and plan blocks on Wins** (the owner, 2026-10-14: tips "arent
    /// popping up in the right spot", "when you have the plan blocks on your
    /// tower the text shows up behind").
    func testTipsAndPlanBlocks() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedPlan", "5", "-strataTipsReset", "1", "-strataTipsShow", "1"])
        wait(8)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2.5) }
        snap("tips-1-empty-plan")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedPlan", "5", "-strataTipsReset", "1", "-strataTipsShow", "1"])
        wait(8)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2.5) }
        snap("tips-2-wins-plan")
        let slot = app.descendants(matching: .any)["Log a win"].firstMatch
        if slot.exists, slot.isHittable {
            slot.press(forDuration: 0.6)
            snap("tips-3a-placing"); wait(0.25); snap("tips-3b-placing"); wait(0.25); snap("tips-3c-placing")
            wait(2.5); snap("tips-4-placed")
        }
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "1", "-strataTipsReset", "1", "-strataTipsShow", "1"])
        wait(8); snap("tips-5-one-win")
    }

    /// **Where the menus with an arrow open** (the owner, 2026-10-14: "a lot
    /// of tips with the arrow they arent popping up in the right spot").
    func testArrowMenus() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataOpenSheet", "add"])
        wait(7)
        app.buttons["Add a photo"].firstMatch.tap(); wait(2); snap("arrow-1-add-photo")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedTodayPhotos", "all", "-strataSeedRealPhotos", "demo"])
        wait(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.82)).tap(); wait(2); snap("arrow-2-block")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedPlan", "5"])
        wait(8)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap(); wait(2.5) }
        let box = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Run the loop'")).firstMatch
        if box.exists { box.tap(); wait(2) }
        snap("arrow-3-plan-box")
    }

    /// The day's second batch, photographed (2026-10-14): one New Crew, the
    /// crews drawing's hold, a crew photo's menu, earlier heads.
    func testDayBatchWalk() {
        let base = ["-crews.rulesAccepted.v1", "YES", "-strataCrewsSignedIn", "1", "-strataCrews", "1"]
        var app = launch(base + ["-strataStartTab", "crews"])
        wait(8); snap("batch-1-crews-empty")
        app.staticTexts["For the people you'd tell anyway."].firstMatch.press(forDuration: 0.8); wait(1.5)
        snap("batch-2-drawing-hold")
        app.terminate()
        app = launch(base + ["-strataStartTab", "crews", "-strataCrewSheet", "new"])
        wait(8); snap("batch-3-new-crew")
        app.terminate()
        app = launch(base + ["-strataSeedCrew", "4", "-strataOpenCrew", "0", "-strataCrewSheet", "info"])
        wait(9)
        let edit = app.buttons["Edit"].firstMatch
        if edit.exists { edit.tap(); wait(1.5) }
        snap("batch-4-crew-photo-menu")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataOpenSheet", "profile", "-strataSeedHead", "1",
                      "-strataSeedEarlierHeads", "3", "-strataScrollProfile", "head"])
        wait(9); snap("batch-5-profile-earlier")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataHeadCatchUp", "1", "-strataSeedEarlierHeads", "2"])
        wait(9); snap("batch-6-catchup-earlier")
    }

    func testEarlierAndCrewPhoto() {
        var app = launch(["-strataStartTab", "tower", "-strataOpenSheet", "profile", "-strataSeedHead", "1",
                          "-strataSeedEarlierHeads", "3", "-strataScrollProfile", "head"])
        wait(9); app.swipeUp(); wait(1.5); snap("ep-1-profile")
        app.terminate()
        app = launch(["-crews.rulesAccepted.v1", "YES", "-strataCrews", "1", "-strataSeedCrew", "4",
                      "-strataOpenCrew", "0", "-strataCrewSheet", "info"])
        wait(9)
        print("PLANNING-edit: \(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Edit' OR label CONTAINS 'Photo'")).allElementsBoundByIndex.prefix(6).map(\.label))")
        let edit = app.buttons["Edit the crew's photo"].firstMatch
        if edit.exists { edit.press(forDuration: 0.12); wait(2) }
        snap("ep-2-photo-menu")
    }

    /// **Full-screen pages' bottom controls, and the Crews list's Plan**
    /// (the owner, 2026-10-14: "the buttons are up too high if the tabs
    /// arent there").
    func testFullScreenBottoms() {
        let runs: [(String, [String], Double)] = [
            ("fs-1-replay", ["-strataStartTab", "memories", "-strataSeedHistory", "14", "-strataOpenReplay", "sampleWeek", "-strataReplayAt", "30"], 10),
            ("fs-2-photo", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedTodayPhotos", "all", "-strataSeedRealPhotos", "demo", "-strataOpenPhoto", "0"], 9),
            ("fs-3-booth", ["-strataStartTab", "tower", "-strataSeedWins", "3", "-strataSeedTodayPhotos", "all", "-strataSeedRealPhotos", "demo", "-strataOpenSheet", "booth"], 10),
            ("fs-4-maker", ["-strataStartTab", "tower", "-strataOpenSheet", "profile", "-strataOpenHeadMaker", "denied"], 9),
            ("fs-5-onboarding", ["-strataShowOnboarding", "1", "-strataOnboardingStep", "2"], 9),
        ]
        for (name, args, delay) in runs {
            let app = launch(args)
            wait(delay); snap(name)
            app.terminate()
        }
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews"])
        wait(8); snap("fs-6-crews-plan-corner")
        let plan = app.buttons["Plan"].firstMatch
        if plan.exists { plan.tap(); wait(2.5) }
        snap("fs-7-crews-plan-sheet")
    }

    func testCrewsPlanCorner() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews"])
        wait(8)
        app.buttons["Plan"].firstMatch.tap(); wait(2.5)
        snap("plan-corner-sheet")
        let other = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roommates'")).firstMatch
        if other.exists { other.tap(); wait(1) }
        snap("plan-corner-switched")
    }

    /// **Every tab's corner buttons, measured, and the tab bar coming back
    /// from a crew** (the owner, 2026-10-14: "the plan button and add crew
    /// button why are they so much bigger than the buttons on the other
    /// pages"; "the tab bar going back when exiting crew chats ... should
    /// just come back smoothly"). For a recording.
    func testCornersAndTabReturn() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews",
                          "-strataSeedWins", "3"])
        wait(8); snap("corners-crews")
        for name in ["Plan", "New Crew"] {
            print("PLANNING-corner crews \(name): \(app.buttons[name].firstMatch.frame)")
        }
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roommates'")).firstMatch
        if row.exists { row.tap() }
        wait(3); snap("corners-crew")
        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Crews'")).firstMatch
        print("PLANNING-corner crew back: \(back.exists) \(back.frame)")
        if back.exists { back.tap() } else { app.swipeRight() }
        wait(3); snap("corners-crews-back")
        app.tabBars.buttons["Wins"].firstMatch.tap()
        wait(3); snap("corners-wins")
        for name in ["Plan", "Journal"] {
            print("PLANNING-corner wins \(name): \(app.buttons[name].firstMatch.frame)")
        }
        app.tabBars.buttons["Memories"].firstMatch.tap()
        wait(3); snap("corners-memories")
    }

    /// **The native chat** (2026-10-15): resting, dragged to reading, the
    /// whole height to write, a block opened under it, and back to the list.
    func testNativeChat() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none"])
        wait(9); snap("native-0-rest")
        func drag(_ from: CGFloat, _ to: CGFloat, speed: CGFloat = 900) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)),
                       withVelocity: XCUIGestureVelocity(speed), thenHoldForDuration: 0)
        }
        // From the grabber, and then from the field's row, as thumbs do.
        drag(0.818, 0.5)
        wait(1.5); snap("native-1-reading")
        let grabbers = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'grabber' OR identifier CONTAINS[c] 'grabber'")).allElementsBoundByIndex
        for g in grabbers { print("PLANNING-native: grabber '\(g.label)' \(g.frame)") }
        drag(0.5, 0.82)
        wait(1.5)
        let field = app.textFields["Message"].firstMatch.exists ? app.textFields["Message"].firstMatch : app.textViews["Message"].firstMatch
        print("PLANNING-native: field \(field.exists) \(field.frame)")
        if field.exists { field.tap() }
        wait(2); snap("native-2-writing")
        app.typeText("on my way")
        wait(1)
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap() }
        wait(2); snap("native-3-rested")
        let block = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Morning run'")).firstMatch
        print("PLANNING-native: block \(block.exists) \(block.isHittable)")
        if block.exists { block.tap() }
        wait(2.5); snap("native-4-viewer")
        let close = app.buttons["Close photo"].firstMatch
        if close.exists { close.tap() }
        wait(2); snap("native-5-back")
        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Crews'")).firstMatch
        if back.exists { back.tap() }
        wait(2); snap("native-6-list")
    }

    /// The resting chat lifted by a drag on its line rather than its grabber.
    func testNativeChatDragOnLine() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataSeedCrewChat", "1", "-strataCrewFaces", "none"])
        wait(9)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.875))
            .press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45)),
                   withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.1)
        wait(1.5); snap("lineDrag-1")
    }

    /// The bars at the foot of every writing page, side by side
    /// (2026-10-15: "in the plan the bar doesnt use liquid glass").
    func testBarsCompared() {
        var app = launch(["-strataStartTab", "tower", "-strataSeedWins", "4", "-strataSeedPlan", "5",
                          "-strataOpenSheet", "plan", "-strataDayTab", "plan"])
        wait(6); snap("bars-1-plan")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataSeedWins", "4",
                      "-strataOpenSheet", "plan", "-strataDayTab", "journal"])
        wait(6); snap("bars-2-journal")
        app.terminate()
        app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews",
                      "-strataSeedWins", "3"])
        wait(7)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roommates'")).firstMatch
        if row.exists { row.tap() }
        wait(4); snap("bars-3-crew")
    }

    /// **Memories as your profile** (2026-10-15): the header, Your Score,
    /// Edit Profile and Settings from the gear.
    func testProfileOnMemories() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "memories",
                          "-strataSeedWins", "6"])
        wait(7); snap("profile-1-page")
        let score = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Score'")).firstMatch
        if score.exists { score.tap() }
        wait(2.5); snap("profile-2-score")
        app.swipeDown(velocity: .fast); wait(1.5)
        let head = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Edit Profile'")).firstMatch
        if head.exists { head.tap() }
        wait(2.5); snap("profile-3-edit")
        app.swipeDown(velocity: .fast); wait(1.5)
        let gear = app.buttons["Settings"].firstMatch
        if gear.exists { gear.tap() }
        wait(2.5); snap("profile-4-settings")
    }

    /// **The crew's week, offered on its tower** (2026-10-14), and played.
    func testCrewWeekCard() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews",
                          "-strataSeedWins", "3", "-strataCrewWeek", "1"])
        wait(8)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roommates'")).firstMatch
        if row.exists { row.tap() }
        wait(4); snap("week-1-card")
        let play = app.buttons["Play"].firstMatch
        if play.exists { play.tap() }
        wait(4); snap("week-2-playing")
    }

    /// **A plan made from the Crews list, in its crew's chat** (the owner,
    /// 2026-10-14: "when you plan does it enter the chat nicely?").
    func testPlanLandsInChat() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews",
                          "-strataSeedCrewChat", "1"])
        wait(8)
        app.buttons["Plan"].firstMatch.tap(); wait(2)
        // Roommates, the crew with the newest news, comes chosen; a tap
        // here would take it off.
        app.typeText("Gym at 6"); wait(0.8)
        snap("planchat-1-sheet")
        // Sent with the arrow since 2026-10-14, as your own plan is.
        app.buttons["Send"].firstMatch.tap(); wait(3)
        snap("planchat-2-list")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roommates'")).firstMatch
        if row.exists { row.tap(); wait(3) }
        snap("planchat-3-crew")
        let line = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat, '")).firstMatch
        if line.exists { line.tap(); wait(3) }
        snap("planchat-4-chat")
    }

    /// The TestFlight Crew Alerts check in Settings (2026-10-14).
    func testAlertCheck() {
        let app = launch(["-strataStartTab", "memories", "-strataOpenSheet", "settings", "-strataCrews", "1", "-strataSeedCrew", "2"])
        wait(8)
        for _ in 0..<3 where !app.staticTexts["Crew Alerts"].exists { app.swipeUp(); wait(1) }
        snap("alertcheck")
    }

    /// The day's third batch (2026-10-14): the Crews list on its first and a
    /// later launch, the round dot, a plan for several crews, Profile's head.
    func testThirdBatch() {
        let crews = ["-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "3", "-strataStartTab", "crews"]
        var app = launch(crews + ["-crews.drawingLaunch", ""])
        wait(8); snap("third-1-first-launch")
        app.terminate()
        app = launch(crews)
        wait(8); snap("third-2-later-launch")
        app.buttons["Plan"].firstMatch.tap(); wait(2.5)
        let every = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Every crew'")).firstMatch
        if every.exists { every.tap(); wait(1) }
        snap("third-3-plan-every")
        app.terminate()
        app = launch(["-strataStartTab", "tower", "-strataOpenSheet", "profile", "-strataSeedHead", "1", "-strataScrollProfile", "head"])
        wait(9); snap("third-4-profile")
    }

    /// The chat's Strip: today's strip shown, and Send puts it in the chat.
    func testChatStrip() {
        let app = launch(["-strataCrews", "1", "-strataSeedCrew", "4", "-strataOpenCrew", "0",
                          "-strataCrewSheet", "chat", "-strataSeedCrewChat", "1", "-strataSeedHistory", "2",
                          "-strataSeedHistoryPerDay", "5", "-strataSeedTodayPhotos", "all",
                          "-strataSeedRealPhotos", "demo", "-strataCrewFaces", "none"])
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
        // The thread from its first line, for a still: nothing is under the
        // header there, where at the end a message is always softened by it.
        let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        for _ in 0..<3 {
            middle.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        }
        wait(2); snap("chatstrip-top")
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
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chat, '")).firstMatch.tap(); wait(3)
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

    /// **A first month's drawing fits above the tab bar** (the owner,
    /// 2026-10-14), with one win and no photos.
    func testMemoriesNewUser() {
        var app = launch(["-strataStartTab", "memories", "-strataSeedWins", "1"])
        wait(8); snap("memories-new-card")
        // A house card is due at most once a day: the second look has the
        // drawing in its place.
        app.terminate()
        app = launch(["-strataStartTab", "memories", "-strataSeedWins", "1"])
        wait(8); snap("memories-new")
    }

    func testSheets() {
        for sheet in ["add", "settings", "profile"] {
            let app = launch(["-strataStartTab", "tower", "-strataSeedWins", "5", "-strataOpenSheet", sheet])
            wait(6); snap("sheet-\(sheet)")
            app.terminate()
        }
    }
}
