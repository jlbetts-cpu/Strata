import AVFoundation
import UIKit
import os

/// **Frames for the graded viewfinder**, which is a different job from
/// `CameraService.attachFrames` and therefore a different object.
///
/// That one is the head maker's: it drops the session to 1080p and takes the
/// zoom to 1, because Vision is measuring a face and the portrait crop breaks
/// its distance estimate. Neither is acceptable here. The viewfinder must keep
/// the `.photo` preset and the exact framing the shutter is about to use, or
/// the picture would not be the one that was composed. `.photo` already yields
/// preview-sized buffers, so there is nothing to gain by changing it.
///
/// **It attaches only once the session is RUNNING, and that is the whole point
/// of this class.** An earlier version of this feature crashed his phone,
/// inside `startRunning`:
///
///     Thread 5, closure #1 in CameraService.start()
///     -[AVCaptureSession startRunning] -> objc_exception_throw
///
/// `CameraService.start()` dispatches `startRunning` onto its own serial queue
/// and returns, so a caller's next line runs on the main actor WHILE the
/// session is starting. `AVCaptureSession` raises an Objective-C exception when
/// its configuration is mutated underneath a start, and an Objective-C
/// exception is not something Swift can catch: it goes straight to
/// `std::terminate`.
///
/// So nothing here touches the session until `isRunning` is true, which means
/// the start has already finished; `didStartRunningNotification` is what waits
/// for it. Every mutation then happens on the MAIN ACTOR, which is where
/// `CameraService` makes all of its own (`configure`, `flip`, `attachFrames`),
/// so the two can never be inside a configuration block at the same time.
///
/// **It cannot fail loudly.** If the output cannot be added for any reason, no
/// frames are ever delivered, the overlay stays hidden, and the camera is
/// exactly the camera it was before this feature existed.
@MainActor
final class CameraPreviewFrames {

    private var output: AVCaptureVideoDataOutput?
    private var session: AVCaptureSession?
    private var waiting: (any NSObjectProtocol)?
    /// Held here rather than captured by the notification block, so that block
    /// captures nothing but `self`. An `AVCaptureVideoDataOutput` is not
    /// `Sendable` and a notification block is, and a warning about that today
    /// is an error the day this target moves to Swift 6.
    private var pending: (output: AVCaptureVideoDataOutput, mirrored: Bool)?
    /// The preview layer's rotation, kept so a flip can restore it.
    private var angle: CGFloat = 90

    var isAttached: Bool { output != nil }

    /// Hands the session's frames to `output`, now or as soon as it is running.
    ///
    /// `angle` is the preview LAYER's own rotation, copied. The overlay has
    /// exactly one correctness condition, that it agree with the layer it is
    /// drawn on top of, and the way to satisfy a condition like that is to
    /// read the other side of it rather than to derive it a second time and
    /// hope the two derivations agree. They did not: asking an
    /// `AVCaptureDevice.RotationCoordinator` instead put the picture 180
    /// degrees out, twice, and the owner saw the same wrong thing both times.
    /// "The filter orientation ones are still flipped upside down."
    func attach(_ output: AVCaptureVideoDataOutput,
                to service: CameraService,
                matching angle: CGFloat,
                mirrored: Bool) {
        guard self.output == nil, waiting == nil else { return }
        self.angle = angle
        let session = service.session
        self.session = session
        guard session.isRunning else {
            pending = (output, mirrored)
            waiting = NotificationCenter.default.addObserver(
                forName: AVCaptureSession.didStartRunningNotification,
                object: session, queue: .main
            ) { [weak self] _ in
                // Everything below is main-actor state, and a notification
                // block is not something the compiler can see runs there.
                Task { @MainActor [weak self] in self?.addPending() }
            }
            return
        }
        add(output, mirrored: mirrored)
    }

    private func addPending() {
        if let token = waiting {
            NotificationCenter.default.removeObserver(token)
            waiting = nil
        }
        guard let pending else { return }
        self.pending = nil
        add(pending.output, mirrored: pending.mirrored)
    }

    /// **Adds the output exactly once**, because adding one a session already
    /// holds is one of the things `-[AVCaptureSession addOutput:]` raises on,
    /// and a raise here is a termination rather than an error. `canAddOutput`
    /// is the documented precondition and is checked rather than assumed.
    ///
    /// The connection is configured inside the same begin/commit pair, because
    /// a connection does not exist until the output is added and setting a
    /// property on it afterwards would be a second reconfiguration.
    private func add(_ output: AVCaptureVideoDataOutput, mirrored: Bool) {
        guard self.output == nil, let session else { return }
        guard !session.outputs.contains(where: { $0 === output }) else {
            self.output = output
            return
        }
        session.beginConfiguration()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            GradedViewfinder.log.error(
                "graded viewfinder: the session refused the frame output, staying on the plain preview")
            return
        }
        session.addOutput(output)
        Self.orient(output, angle: angle, mirrored: mirrored)
        session.commitConfiguration()
        self.output = output
    }

    /// Upright, and mirrored on the front lens, so the graded surface shows
    /// what the preview layer under it shows.
    nonisolated static func orient(_ output: AVCaptureVideoDataOutput,
                                   angle: CGFloat, mirrored: Bool) {
        guard let connection = output.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        GradedViewfinder.log.notice(
            "graded viewfinder: connection set to \(Int(angle), privacy: .public) degrees, mirrored \(connection.isVideoMirrored, privacy: .public)")
    }

    /// After a flip: the connection is new, so it has to be told which way up
    /// it is and whether it is a selfie. Connection properties are not session
    /// configuration, so this needs no begin/commit pair.
    func reorient(matching angle: CGFloat, mirrored: Bool) {
        guard let output else { return }
        self.angle = angle
        Self.orient(output, angle: angle, mirrored: mirrored)
    }

    /// **Called BEFORE `CameraService.stop()`, never after.** `stop` puts
    /// `stopRunning` on the service's own queue, and removing an output beside
    /// a stop in flight is the same hazard as adding one beside a start. While
    /// the session is still running there is nothing in flight to collide
    /// with.
    func detach() {
        if let waiting {
            NotificationCenter.default.removeObserver(waiting)
            self.waiting = nil
        }
        pending = nil
        guard let output, let session else {
            self.session = nil
            return
        }
        self.output = nil
        self.session = nil
        guard session.outputs.contains(where: { $0 === output }) else { return }
        session.beginConfiguration()
        session.removeOutput(output)
        session.commitConfiguration()
    }
}
