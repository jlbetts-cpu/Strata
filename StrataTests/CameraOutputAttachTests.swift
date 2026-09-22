import Testing
import AVFoundation
@testable import Strata

/// **Adding the graded viewfinder's output must be impossible to get wrong.**
///
/// The app crashed on his phone inside `-[AVCaptureSession startRunning]`. Two
/// things were wrong and only one of them is testable here.
///
/// The untestable one, and the actual cause: the output was being added from
/// the MAIN actor while `startRunning` ran on the session queue, because
/// `start()` dispatches the start and returns immediately. That is a race
/// between two threads on a real session with a real camera and there is no
/// lens on this machine to reproduce it with. It is fixed by construction
/// instead — every session mutation the feature makes is now dispatched onto
/// the same serial queue, so it is ordered after the start rather than beside
/// it.
///
/// The testable one is the precondition. `-[AVCaptureSession addOutput:]`
/// raises an Objective-C exception, which Swift cannot catch and which
/// terminates the process, if the output is already in the session or if
/// `canAddOutput` is false. `addOnce` is the single place that is allowed to
/// add it, and these are its guarantees.
@Suite("Camera output attachment")
struct CameraOutputAttachTests {

    @Test("Adding the same output twice adds it once and does not raise")
    func addingTwiceIsIdempotent() {
        let session = AVCaptureSession()
        let output = AVCaptureVideoDataOutput()

        let first = CameraService.addOnce(output, to: session)
        let second = CameraService.addOnce(output, to: session)

        #expect(first, "a bare session should accept a video data output")
        #expect(second, "the second call reports success because the output IS attached")
        #expect(session.outputs.filter { $0 === output }.count == 1,
                "it must never be added twice: the second addOutput would raise and terminate")
    }

    @Test("The configure block runs inside the same begin/commit pair, after the add")
    func configureRunsOnceTheConnectionExists() {
        let session = AVCaptureSession()
        let output = AVCaptureVideoDataOutput()
        var sawItAttached = false

        _ = CameraService.addOnce(output, to: session) {
            // A connection only exists once the output is in the session, so
            // this is the only moment a connection property can be set without
            // a second reconfiguration.
            sawItAttached = session.outputs.contains { $0 === output }
        }

        #expect(sawItAttached, "configure must run after addOutput and before commitConfiguration")
    }

    @Test("A second call does not re-run the configure block")
    func configureDoesNotRepeat() {
        let session = AVCaptureSession()
        let output = AVCaptureVideoDataOutput()
        var runs = 0

        _ = CameraService.addOnce(output, to: session) { runs += 1 }
        _ = CameraService.addOnce(output, to: session) { runs += 1 }

        #expect(runs == 1, "the early return must happen before any reconfiguration")
    }

    @Test("Orienting an unattached output is a no-op rather than a crash")
    func orientingWithoutAConnectionIsSafe() {
        // No session, so no connection. This is the shape of the fourth
        // candidate cause: a connection property set before the output is
        // attached. It must do nothing rather than raise.
        CameraService.orient(AVCaptureVideoDataOutput(), angle: 90, mirrored: false)
    }
}
