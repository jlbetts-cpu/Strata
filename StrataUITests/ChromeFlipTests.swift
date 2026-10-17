import XCTest

/// **Bars stay our light glass, whatever scrolls behind them** (the owner,
/// 2026-10-18: "the message bar turns dark mode when it scrolls over the
/// recent photos. It must stay our light glass and blur at all times").
/// A person's page, scrolled so the photos pass under the message bar: the
/// bar's ground is measured from the screenshot, light before and after.
final class ChromeFlipTests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func shot(_ name: String) -> XCUIScreenshot {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        return s
    }

    /// The mean brightness of a strip of the bar, beside its words.
    private func barBrightness(_ s: XCUIScreenshot, at frame: CGRect) -> Double {
        guard let cg = s.image.cgImage else { return -1 }
        let scale = CGFloat(cg.width) / s.image.size.width
        let rect = CGRect(x: (frame.maxX - 60) * scale, y: frame.midY * scale - 4, width: 40 * scale, height: 8 * scale).integral
        guard let crop = cg.cropping(to: rect) else { return -1 }
        let w = crop.width, h = crop.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sum = 0.0
        for i in stride(from: 0, to: px.count, by: 4) { sum += Double(px[i]) + Double(px[i + 1]) + Double(px[i + 2]) }
        return sum / Double(w * h * 3)
    }

    func testTheMessageBarStaysLightOverPhotos() {
        let app = XCUIApplication()
        app.launchArguments = ["-cameraTimerSeconds", "0", "-strataCrews", "1", "-strataSeedCrew", "4", "-strataSeedCrews", "1",
                               "-strataStartTab", "crews", "-strataSeedStories", "3", "-strataStoryHour", "21",
                               "-strataStorySeen", "1", "-strataSeedCrewWins", "40"]
        app.launch()
        let head = app.buttons.matching(NSPredicate(format: "value == 'New story'")).firstMatch
        XCTAssertTrue(head.waitForExistence(timeout: 30))
        head.press(forDuration: 1.0)
        let profile = app.buttons["View Profile"].firstMatch
        if profile.waitForExistence(timeout: 3) {
            profile.tap()
        } else {
            // The press opened the story: their name in it opens them.
            let name = app.buttons.matching(NSPredicate(format: "label == 'Ana'")).firstMatch
            if name.waitForExistence(timeout: 3) { name.tap() }
        }
        Thread.sleep(forTimeInterval: 2.5)
        let bar = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Message '")).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "no message bar on the person's page")
        let before = barBrightness(shot("flip-1-top"), at: bar.frame)
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.5)
        let mid = barBrightness(shot("flip-2-scrolled"), at: bar.frame)
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.5)
        let end = barBrightness(shot("flip-3-more"), at: bar.frame)
        print("FLIP before \(before) scrolled \(mid) more \(end)")
        // Light mode: the bar's ground stays light (above 200 of 255).
        XCTAssertGreaterThan(mid, 200, "the bar went dark over the photos")
        XCTAssertGreaterThan(end, 200, "the bar went dark over the photos")
    }
}
