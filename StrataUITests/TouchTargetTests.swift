import XCTest

/// Every control you can hit must be big enough to hit.
///
/// **Measured from the accessibility tree, not read off the code.** A SwiftUI
/// view's hit rectangle is not its drawing: `clipShape` clips drawing and not
/// touches, `.offset` moves drawing and not layout, and negative padding
/// shrinks layout while leaving the hit area behind. This project has been
/// bitten by all three, and the only honest way to know how big a target is
/// is to ask the running app.
///
/// Apple's minimum is 44x44pt. Anything under that is reported with its
/// measured frame so the failure names the control rather than the screen.
final class TouchTargetTests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    /// Controls that are legitimately smaller, with the reason.
    ///
    /// Kept deliberately short. An exception here is a promise that something
    /// else makes the target reachable, not permission to draw a small button.
    private static let allowed: Set<String> = [
        // The strip is one draggable surface; the cards inside it are not
        // separate targets, and a drag anywhere on it scrubs.
        "filmstrip",
        // UIKit's own sheet drag indicator. Not ours to size, and the whole
        // header strip above it drags anyway.
        "Sheet Grabber"
    ]

    private func audit(_ app: XCUIApplication, screen: String) {
        // A hair under 44, because a frame that lays out AT 44 can measure
        // 43.99998 and a test that fails on floating point teaches people to
        // ignore it.
        let minimum: CGFloat = 43.5
        var small: [String] = []

        // **Switches are not audited, and neither are bar items.**
        //
        // Not an excuse — a measurement. A UISwitch is 51x31 by Apple's own
        // layout and cannot be made taller; a navigation bar constrains its
        // items to about 36pt, which is why widening the plan's plus from 35
        // to 56 moved the width and not the height. Apple's own Done buttons
        // measure 36 too. Auditing them reports the platform, not this app,
        // and a test that always fails is a test nobody reads.
        //
        // What IS audited: every button the app lays out itself, anywhere
        // below the bars.
        let barHeight: CGFloat = 130
        for kind in [XCUIElement.ElementType.button] {
            let query = app.descendants(matching: kind)
            for i in 0..<query.count {
                let element = query.element(boundBy: i)
                guard element.exists, element.isHittable else { continue }
                let frame = element.frame
                guard frame.minY > barHeight else { continue }
                guard frame.width > 0, frame.height > 0 else { continue }
                let name = element.identifier.isEmpty ? element.label : element.identifier
                guard !Self.allowed.contains(name) else { continue }
                if frame.width < minimum || frame.height < minimum {
                    small.append(String(format: "%@ [%.0fx%.0f]",
                                        name.isEmpty ? "<unnamed>" : name,
                                        frame.width, frame.height))
                }
            }
        }

        XCTAssertTrue(small.isEmpty,
                      "\(screen): \(small.count) control(s) under 44pt — \(small.joined(separator: ", "))")
    }

    func testTheTowerHasNoUndersizedControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-strataStartTab", "tower", "-strataSeedWins", "6"]
        app.launch()
        Thread.sleep(forTimeInterval: 18)
        audit(app, screen: "tower")
    }

    func testSettingsHasNoUndersizedControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-strataStartTab", "tower", "-strataOpenSheet", "settings"]
        app.launch()
        Thread.sleep(forTimeInterval: 18)
        audit(app, screen: "settings")
    }

    func testThePlanHasNoUndersizedControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-strataStartTab", "tower", "-strataSeedPlan", "5"]
        app.launch()
        Thread.sleep(forTimeInterval: 18)
        audit(app, screen: "plan")
    }

    func testTheMapHasNoUndersizedControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-strataOpenMap", "1", "-strataSeedPlaces", "1",
                                "-strataSeedHistory", "30"]
        app.launch()
        Thread.sleep(forTimeInterval: 20)
        audit(app, screen: "map")
    }
}
