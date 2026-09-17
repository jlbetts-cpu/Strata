import XCTest

/// Real flings over the Memories camera roll, for the image-loading
/// measurements. **Not a pass/fail test**: it drives the gesture nothing else
/// on this machine can make, and `-strataPerfProbe` writes what happened to
/// `Documents/perf.log` for the person running it to read back.
///
/// Skipped unless `TEST_RUNNER_STRATA_PERF=1` is set on the xcodebuild line,
/// so the normal UI run neither pays for it nor depends on the store it finds.
/// It seeds nothing: it measures whatever store is on the simulator, which is
/// what lets a before and an after run against the same one.
final class ImageLoadingPerfTests: XCTestCase {
    func testFlingTheCameraRollColdThenWarm() throws {
        guard ProcessInfo.processInfo.environment["STRATA_PERF"] == "1" else {
            throw XCTSkip("perf driver; set TEST_RUNNER_STRATA_PERF=1")
        }
        let app = XCUIApplication()
        // Every flag carries a value: `DebugHarness.argument` reads the token
        // AFTER a flag, so a bare one at the end of the list reads as absent.
        app.launchArguments = ["-strataPerfProbe", "-strataStartTab", "memories",
                               "-strataOpenDrawer", "full", "-strataScrollMemories", "content"]
        app.launch()
        // Launch, the drawer, and the harness's own 3s scroll to the grid.
        sleep(10)
        // Cold: down through the roll. Each fling opens nothing new; the
        // first one opens a 10s window in `MemoriesView`.
        for _ in 0..<10 { app.swipeUp(velocity: .fast) }
        sleep(12)
        // Warm: back up over the same cells, in its own window.
        for _ in 0..<10 { app.swipeDown(velocity: .fast) }
        sleep(12)
    }
}
