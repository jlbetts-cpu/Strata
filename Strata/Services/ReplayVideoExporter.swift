import AVFoundation
import os
import SwiftUI
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "ReplayVideo")

/// A replay, written to an .mp4 the same way it plays: `ReplayFrame` at each
/// frame's time. 1080x1920, 30fps, H.264, with the landings as AAC.
///
/// **Every frame is `ReplayCard.sharedFrame`**, the function that draws the
/// Share still, at the still's size and render scale. So the video's last
/// frame is the still, and every frame before it is the replay at that `t`
/// in the same light scheme, `.large` type and story-safe top inset.
///
/// **On the main actor, in slices.** `ImageRenderer` is main-actor only, so
/// the frames cannot be drawn anywhere else. Before each frame the loop hands
/// the main actor back if drawing it would carry the slice past
/// `sliceBudget`, so a slice is one frame when frames are slow. Starting and
/// flushing the encoders, which blocked for up to 350ms, happen on a
/// background queue. A single frame cannot be split: a month's busiest
/// frames took about 110ms each in the simulator.
///
/// **Nothing is kept.** Each frame is drawn into a buffer from the writer's
/// pool inside its own autorelease pool, so its bitmap is released before
/// the next is drawn. The frames after the replay ends are one picture and
/// are drawn once.
@MainActor
final class ReplayVideoExporter {
    nonisolated enum Failure: Error {
        case writer(String)
        case cancelled
    }

    let replay: Replay
    let images: ReplayImages
    /// The `now` the header's range is worded against: the replay's own, so
    /// the video says what the screen said.
    let now: Date
    private(set) var progress: Double = 0
    private var cancelled = false

    nonisolated static let fps: Int32 = 30
    /// The video holds on the close, so it does not end as the count arrives.
    static let tail: Double = 2
    /// The card at 3x.
    static let pixelSize = CGSize(width: ReplayCard.size.width * 3, height: ReplayCard.size.height * 3)
    /// The longest one run of work holds the main actor before handing back.
    static let sliceBudget: Double = 0.05
    /// Audio is written in chunks this long, alongside the frames, so the
    /// writer can interleave the two tracks as it goes.
    nonisolated static let audioChunk: Double = 0.5

    #if DEBUG
    struct Stats {
        var frames = 0
        var drawn = 0
        var audioMix: Double = 0
        var wall: Double = 0
        var maxSlice: Double = 0
        var slices = 0
        var landings = 0
        var sounding = 0
        var duration: Double = 0
        /// Where the longest slice ended: a frame index, or a phase.
        var maxSliceAt = ""
        var soundingTimes: [Double] = []
        var draws: [Double] = []
        var sliceList: [(Double, String)] = []

        /// "p50 p90 p99 max" in ms.
        static func spread(_ values: [Double]) -> String {
            let s = values.sorted()
            guard !s.isEmpty else { return "-" }
            func p(_ q: Double) -> Double { s[min(s.count - 1, Int(Double(s.count) * q))] * 1000 }
            return String(format: "p50 %.0f p90 %.0f p99 %.0f max %.0fms", p(0.5), p(0.9), p(0.99), s.last! * 1000)
        }
    }
    private var sliceLabel = "start"
    private(set) var stats = Stats()
    #endif

    init(replay: Replay, images: ReplayImages, now: Date = Date()) {
        self.replay = replay
        self.images = images
        self.now = now
    }

    /// Stops the export at the next frame. `export` then deletes what it had
    /// written and throws `Failure.cancelled`.
    func cancel() { cancelled = true }

    func export(onProgress: @escaping (Double) -> Void = { _ in }) async throws -> URL {
        let started = CACurrentMediaTime()
        let url = URL.temporaryDirectory.appending(path: "replay-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        do {
            try await write(to: writer, onProgress: onProgress)
        } catch {
            if writer.status == .writing { writer.cancelWriting() }
            Self.remove(url)
            throw error
        }
        #if DEBUG
        stats.wall = CACurrentMediaTime() - started
        #endif
        return url
    }

    /// Deletes a file this exporter wrote. A leftover temporary video is not
    /// worth failing anything over, but it is logged rather than ignored.
    static func remove(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("could not delete \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Writing

    private func write(to writer: AVAssetWriter, onProgress: @escaping (Double) -> Void) async throws {
        var slice = CACurrentMediaTime()
        #if DEBUG
        sliceLabel = "script"
        #endif
        let script = ReplayCard.script(replay)
        let fps = Double(Self.fps)
        let length = script.duration + Self.tail
        let total = Int((length * fps).rounded(.up))
        let width = Int(Self.pixelSize.width), height = Int(Self.pixelSize.height)
        try await pause(&slice)

        // Making the inputs and starting the encoders measured 80 to 140ms;
        // not on the main actor.
        let setup = await Self.inBackground(Handoff(writer)) { writer -> Handoff<(AVAssetWriterInput, AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor)>? in
            let (video, audio) = ReplayVideoExporter.inputs(width: width, height: height)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ])
            writer.shouldOptimizeForNetworkUse = true
            guard writer.canAdd(video), writer.canAdd(audio) else { return nil }
            writer.add(video)
            writer.add(audio)
            guard writer.startWriting() else { return nil }
            writer.startSession(atSourceTime: .zero)
            return Handoff((video, audio, adaptor))
        }
        guard let parts = setup?.value else { throw Failure.writer(writer.error?.localizedDescription ?? "start") }
        let (video, audio, adaptor) = parts
        // The wait was off the main actor; the slice starts again here.
        slice = CACurrentMediaTime()

        #if DEBUG
        sliceLabel = "mix"
        let mixStart = CACurrentMediaTime()
        #endif
        guard let pcm = ReplayAudioMix.mix(script, tail: Self.tail) else { throw Failure.writer("mix") }
        #if DEBUG
        stats.audioMix = CACurrentMediaTime() - mixStart
        stats.landings = script.landings.count
        let sounding = ReplayAudioMix.landingTimes(script.landings, limitPerSecond: GridConstants.replayFeedbackPerSecond)
        stats.sounding = sounding.count
        stats.soundingTimes = sounding.map(\.time)
        stats.duration = script.duration
        stats.frames = total
        #endif
        var audioCursor: AVAudioFramePosition = 0
        try await pause(&slice)

        #if DEBUG
        sliceLabel = "first frame"
        #endif
        let renderer = ImageRenderer(content: ReplayCard.sharedFrame(script, images: images, t: 0, now: now))
        renderer.scale = ReplayCard.rendererScale(pixelWidth: Self.pixelSize.width)
        renderer.isOpaque = true

        var held: CVPixelBuffer?
        var reported = -1.0
        var lastDraw: Double = 0
        for frame in 0..<total {
            try checkCancelled()
            let t = min(Double(frame) / fps, script.duration)
            let buffer: CVPixelBuffer
            if let held, t >= script.duration {
                buffer = held
            } else {
                // Hand back first if this frame would carry the slice past
                // its budget, rather than finding out after.
                if CACurrentMediaTime() - slice + lastDraw > Self.sliceBudget { try await pause(&slice) }
                guard let pool = adaptor.pixelBufferPool else { throw Failure.writer("pool") }
                let drawStart = CACurrentMediaTime()
                renderer.content = ReplayCard.sharedFrame(script, images: images, t: t, now: now)
                buffer = try autoreleasepool { try Self.draw(renderer, into: pool, width: width, height: height) }
                lastDraw = CACurrentMediaTime() - drawStart
                if t >= script.duration { held = buffer }
                #if DEBUG
                stats.drawn += 1
                stats.draws.append(lastDraw)
                sliceLabel = "frame \(frame)"
                #endif
            }
            while !video.isReadyForMoreMediaData {
                try checkCancelled()
                try await pause(&slice)
            }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: Self.fps)) else {
                throw Failure.writer(writer.error?.localizedDescription ?? "append video")
            }
            try Self.appendAudio(pcm, to: audio, cursor: &audioCursor, through: Double(frame) / fps + 1)

            progress = Double(frame + 1) / Double(total) * 0.97
            if progress - reported >= 0.01 {
                reported = progress
                onProgress(progress)
            }
        }
        #if DEBUG
        recordSlice(since: slice)
        #endif

        // Flushing the encoders blocked the main actor for 350ms measured,
        // so the end of the file is written from the background.
        try checkCancelled()
        let finished = await Self.inBackground(Handoff((writer, video, audio, pcm, audioCursor))) { parts -> Bool in
            let (writer, video, audio, pcm, start) = parts
            video.markAsFinished()
            var cursor = start
            while cursor < AVAudioFramePosition(pcm.frameLength) {
                guard writer.status == .writing else { return false }
                if audio.isReadyForMoreMediaData {
                    do { try ReplayVideoExporter.appendAudio(pcm, to: audio, cursor: &cursor, through: length) } catch { return false }
                } else {
                    Thread.sleep(forTimeInterval: 0.002)
                }
            }
            audio.markAsFinished()
            writer.endSession(atSourceTime: CMTime(seconds: length, preferredTimescale: 600))
            return true
        }
        guard finished else { throw Failure.writer(writer.error?.localizedDescription ?? "audio") }
        slice = CACurrentMediaTime()
        await writer.finishWriting()
        try checkCancelled()
        guard writer.status == .completed else {
            throw Failure.writer(writer.error?.localizedDescription ?? "finish \(writer.status.rawValue)")
        }
        progress = 1
        onProgress(1)
    }

    nonisolated private static func inputs(width: Int, height: Int) -> (video: AVAssetWriterInput, audio: AVAssetWriterInput) {
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            // The frames are sRGB; tagged as HD video so a player shows the
            // ground and the blocks in the colours the still has.
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps
            ]
        ])
        video.expectsMediaDataInRealTime = false

        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: SoundEngine.mixSampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
            AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
        ])
        audio.expectsMediaDataInRealTime = false
        return (video, audio)
    }

    private func checkCancelled() throws {
        if cancelled { throw Failure.cancelled }
    }

    /// Hands the main actor back for a moment and starts a new slice.
    ///
    /// A short sleep rather than `Task.yield()`, so nothing of the export is
    /// waiting on the main queue while the run loop takes touches and draws.
    private func pause(_ slice: inout CFTimeInterval) async throws {
        #if DEBUG
        recordSlice(since: slice)
        #endif
        try await Task.sleep(for: .milliseconds(2))
        slice = CACurrentMediaTime()
    }

    #if DEBUG
    private func recordSlice(since start: CFTimeInterval) {
        let length = CACurrentMediaTime() - start
        if length > stats.maxSlice {
            stats.maxSlice = length
            stats.maxSliceAt = sliceLabel
        }
        stats.slices += 1
        stats.sliceList.append((length, sliceLabel))
    }
    #endif

    /// Runs `work` on a background queue. The writer's objects are safe to
    /// drive from any one thread at a time, and the export awaits this, so
    /// nothing touches them meanwhile.
    nonisolated private static func inBackground<T, R>(_ handoff: Handoff<T>,
                                                     _ work: @escaping @Sendable (T) -> R) async -> R {
        await withCheckedContinuation { (continuation: CheckedContinuation<Handoff<R>, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Handoff(work(handoff.value)))
            }
        }.value
    }

    /// One frame, drawn by the renderer into a buffer from the pool.
    ///
    /// Most of a frame's cost is here, in the draw: the renderer's image is
    /// rasterised when it is first read (about 20ms a frame, simulator).
    private static func draw(_ renderer: ImageRenderer<some View>, into pool: CVPixelBufferPool,
                             width: Int, height: Int) throws -> CVPixelBuffer {
        guard let image = renderer.cgImage else { throw Failure.writer("render") }
        // The render scale is chosen to land on the whole pixel size; a frame
        // a pixel off would be stretched, and blurred, to fit.
        guard image.width == width, image.height == height else {
            throw Failure.writer("frame \(image.width)x\(image.height)")
        }
        var out: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out) == kCVReturnSuccess, let buffer = out else {
            throw Failure.writer("pixel buffer")
        }
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { throw Failure.writer("context") }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    /// Appends whole chunks of the mix while their start is at or before
    /// `through` seconds and the input will take them.
    nonisolated private static func appendAudio(_ pcm: AVAudioPCMBuffer, to input: AVAssetWriterInput,
                                                cursor: inout AVAudioFramePosition, through seconds: Double) throws {
        let rate = pcm.format.sampleRate
        let total = AVAudioFramePosition(pcm.frameLength)
        let chunk = AVAudioFramePosition(audioChunk * rate)
        while cursor < total, Double(cursor) / rate <= seconds, input.isReadyForMoreMediaData {
            let count = min(chunk, total - cursor)
            guard let sample = pcm.sampleBuffer(from: cursor, count: count) else { throw Failure.writer("audio sample") }
            guard input.append(sample) else { throw Failure.writer("append audio") }
            cursor += count
        }
    }
}

/// Carries the writer's objects to the background queue that finishes them.
/// Unchecked because AVFoundation does not mark them Sendable; safe because
/// the export awaits the hand-off, so only one side holds them at a time.
nonisolated struct Handoff<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

private extension AVAudioPCMBuffer {
    /// `count` frames from `start`, as a CMSampleBuffer at their own time.
    nonisolated func sampleBuffer(from start: AVAudioFramePosition, count: AVAudioFramePosition) -> CMSampleBuffer? {
        guard count > 0,
              let piece = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let source = floatChannelData, let target = piece.floatChannelData else { return nil }
        piece.frameLength = AVAudioFrameCount(count)
        for channel in 0..<Int(format.channelCount) {
            target[channel].update(from: source[channel] + Int(start), count: Int(count))
        }

        var formatDescription: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: format.streamDescription, layoutSize: 0, layout: nil,
                                             magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                             formatDescriptionOut: &formatDescription) == noErr,
              let formatDescription else { return nil }
        let rate = CMTimeScale(format.sampleRate)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: rate),
                                        presentationTimeStamp: CMTime(value: start, timescale: rate),
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreate(allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil,
                                   refcon: nil, formatDescription: formatDescription, sampleCount: CMItemCount(count),
                                   sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0,
                                   sampleSizeArray: nil, sampleBufferOut: &sample) == noErr,
              let sample else { return nil }
        guard CMSampleBufferSetDataBufferFromAudioBufferList(sample, blockBufferAllocator: nil,
                                                             blockBufferMemoryAllocator: nil, flags: 0,
                                                             bufferList: piece.audioBufferList) == noErr else { return nil }
        return sample
    }
}
