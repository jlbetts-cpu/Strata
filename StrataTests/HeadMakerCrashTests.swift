import Foundation
import Testing
@testable import Strata

/// **The onboarding face screen's crash** (2026-10-09, a tester's phone).
/// The camera was started on its queue and reconfigured on the main thread
/// at once; a `startRunning` between `beginConfiguration` and its commit is
/// an NSGenericException. Only a real phone gets there, so this holds the
/// order in the source: configure, then run, and every reconfiguration waits
/// for the queue.
///
/// Self-test: restore `await camera.start()` at the top of `start()` and
/// `configuredBeforeRunning` fails.
@Suite("Head maker: no camera race")
struct HeadMakerCrashTests {
    @Test("the head maker configures the camera before it runs")
    func configuredBeforeRunning() throws {
        let model = SourceSweep.code(try SourceSweep.read("Strata/ViewModels/HeadMakerModel.swift"))
        let start = try #require(model.range(of: "func start() async {"))
        let body = String(model[start.upperBound...].prefix(1400))
        let prepare = try #require(body.range(of: "camera.prepare()"))
        let front = try #require(body.range(of: "camera.useFrontCamera()"))
        let frames = try #require(body.range(of: "camera.attachFrames("))
        let run = try #require(body.range(of: "camera.run()"))
        #expect(prepare.lowerBound < front.lowerBound && front.lowerBound < run.lowerBound)
        #expect(frames.lowerBound < run.lowerBound)
        #expect(!body.contains("camera.start()"))
        #expect(!model.contains("onUpdate = nil"), "clearing the frame callback races the capture queue")
    }

    @Test("every reconfiguration waits for a start or stop on the queue")
    func configurationWaits() throws {
        let camera = SourceSweep.code(try SourceSweep.read("Strata/Services/CameraService.swift"))
        let begins = camera.components(separatedBy: "session.beginConfiguration()").count - 1
        let settles = camera.components(separatedBy: "settleQueue()").count - 1
        // configure() runs before the session ever starts; every other
        // beginConfiguration settles the queue first.
        #expect(settles >= begins - 1, "\(begins) configurations, \(settles) waits")
    }
}
