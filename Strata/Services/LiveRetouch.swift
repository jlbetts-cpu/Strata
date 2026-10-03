import AVFoundation
import CoreImage
import Metal
import QuartzCore
import os

/// **The viewfinder, with `FaceRetouch` on it, live.**
///
/// The plain preview layer cannot be filtered, so for the front camera the
/// frames come through here instead: each one is drawn, already upright and
/// mirrored by its connection, straight into a Metal layer at the size it is
/// shown, with the face touch applied on the way. Faces and eyes are found
/// five times a second on a small copy and eased between finds, so the touch
/// follows a face without jumping.
///
/// **Cheap on purpose.** Late frames are dropped rather than queued; the
/// picture is scaled to the screen BEFORE anything is computed (Core Image
/// only works at the size it draws); detection runs on its own queue on a
/// 480px copy, never on the frame path; and with no face in view a frame is
/// only scaled and drawn.
final class LiveRetouch: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let output = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "camera.retouch", qos: .userInteractive)
    private let detectQueue = DispatchQueue(label: "camera.retouch.faces", qos: .userInitiated)
    private static let log = Logger(subsystem: "Strata", category: "camera.retouch")

    private let device = MTLCreateSystemDefaultDevice()
    private lazy var commandQueue = device?.makeCommandQueue()
    private lazy var context: CIContext? = commandQueue.map {
        CIContext(mtlCommandQueue: $0, options: [.cacheIntermediates: false, .name: "retouch"])
    }

    /// Guarded by `lock`: what the main thread hands the frame path.
    private let lock = NSLock()
    private var layer: CAMetalLayer?
    private var drawableSize: CGSize = .zero
    private var enabled = false
    /// Faces in the frame's own coordinates, eased.
    private var faces: [FaceRetouch.Face] = []
    private var lastFaceAt: CFTimeInterval = 0
    private var detecting = false
    private var frameCount = 0

    /// Called once on the main thread when the first touched frame is on
    /// screen, so the plain preview can step back.
    var onFirstFrame: (@MainActor () -> Void)?
    private var announced = false

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    /// The layer to draw into, and its size in pixels. From the main thread.
    func attach(_ layer: CAMetalLayer, size: CGSize) {
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false
        layer.contentsGravity = .resizeAspectFill
        lock.withLock {
            self.layer = layer
            drawableSize = size
            layer.drawableSize = size
        }
    }

    func resize(to size: CGSize) {
        lock.withLock {
            drawableSize = size
            layer?.drawableSize = size
        }
    }

    /// On for the front camera, off otherwise: the back camera keeps the
    /// plain preview and pays nothing.
    func setEnabled(_ on: Bool) {
        lock.withLock {
            enabled = on
            if !on { announced = false; faces = [] }
        }
        output.connection(with: .video)?.isEnabled = on
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        draw(CIImage(cvPixelBuffer: pixels))
    }

    #if DEBUG
    /// `-strataRetouchStill`: a still portrait fed through the very same path,
    /// thirty times a second, so the live touch can be seen in the simulator,
    /// which has no camera.
    func debugFeed(_ image: CIImage) {
        lock.withLock { enabled = true }
        queue.async { [weak self] in
            while let self, self.lock.withLock({ self.enabled }) {
                self.draw(image)
                Thread.sleep(forTimeInterval: 1.0 / 30)
            }
        }
    }
    #endif

    private func draw(_ frame: CIImage) {
        let (layer, size, on) = lock.withLock { (self.layer, drawableSize, enabled) }
        guard on, let layer, size.width > 0, size.height > 0, let context, let commandQueue else { return }

        // Aspect fill into the drawable, centred, as the preview layer does:
        // scaled FIRST, so everything after works at screen size.
        let extent = frame.extent
        let scale = max(size.width / extent.width, size.height / extent.height)
        let fill = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: (size.width - extent.width * scale) / 2,
                                             y: (size.height - extent.height * scale) / 2))
        let shown = frame.transformed(by: fill)

        detectIfDue(frame)
        let now = CACurrentMediaTime()
        let current = lock.withLock { now - lastFaceAt < 0.6 ? faces : [] }
        let touched = FaceRetouch.render(shown, faces: current.map { $0.applying(fill) })
            .cropped(to: CGRect(origin: .zero, size: size))

        guard let drawable = layer.nextDrawable(), let buffer = commandQueue.makeCommandBuffer() else { return }
        // A Metal texture's first row is its top; Core Image's is its
        // bottom. The destination is told so, or the face is upside down.
        let destination = CIRenderDestination(mtlTexture: drawable.texture, commandBuffer: buffer)
        destination.isFlipped = true
        destination.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        _ = try? context.startTask(toRender: touched, to: destination)
        buffer.present(drawable)
        buffer.commit()

        let first = lock.withLock { () -> Bool in
            guard !announced else { return false }
            announced = true
            return true
        }
        if first, let onFirstFrame {
            Task { @MainActor in onFirstFrame() }
        }
    }

    /// Every sixth frame (five a second at thirty), when the last find is
    /// done: faces and eyes on a small copy, eased into the ones in use.
    private func detectIfDue(_ frame: CIImage) {
        let due = lock.withLock { () -> Bool in
            frameCount &+= 1
            guard frameCount % 6 == 0, !detecting else { return false }
            detecting = true
            return true
        }
        guard due else { return }
        detectQueue.async { [weak self] in
            guard let self else { return }
            let found = FaceRetouch.detect(in: frame, longEdge: 480)
            self.lock.withLock {
                if !found.isEmpty {
                    if self.faces.count == found.count {
                        self.faces = zip(self.faces, found).map { $0.easing(to: $1, by: 0.55) }
                    } else {
                        self.faces = found
                    }
                    self.lastFaceAt = CACurrentMediaTime()
                }
                self.detecting = false
            }
        }
    }
}
