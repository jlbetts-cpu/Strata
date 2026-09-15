import AVFoundation
import Foundation
import os
import Testing
@testable import Strata

/// The engine stops underneath the app: a call, Siri, an alarm, AirPods
/// connecting and changing the output rate, or a media services reset. A
/// player told to play on a stopped engine raises, which is a crash, so every
/// sound and every system notification has to bring it back, and none of
/// that may make a sound wait or retry in a loop. These stop it the way the
/// system does and check.
///
/// Skipped, not failed, where this machine cannot run ANY audio engine. The
/// probe is a bare `AVAudioEngine`, not `SoundEngine`'s own start path: a
/// regression that stops that path starting must fail these tests, not turn
/// them into a green skip.
func bareAudioEngineCanRun() -> Bool {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode,
                   format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
    engine.prepare()
    guard (try? engine.start()) != nil else { return false }
    engine.stop()
    return true
}

/// A class so `deinit` can put the host's mute setting back after each test.
@MainActor
@Suite("Sound engine restart", .serialized,
       .enabled(if: bareAudioEngineCanRun(), "this machine cannot run an audio engine"))
final class SoundEngineRestartTests {
    private let wasMuted = UserDefaults.standard.object(forKey: "soundEngineMuted")

    init() {
        UserDefaults.standard.set(false, forKey: "soundEngineMuted")
        SoundEngine.debugFailStarts.withLock { $0 = false }
        SoundEngine.debugRestartDelay.withLock { $0 = 0 }
        SoundEngine.debugRebuildDelay.withLock { $0 = 0 }
        SoundEngine.debugStartEngine()
    }

    deinit {
        if let wasMuted {
            UserDefaults.standard.set(wasMuted, forKey: "soundEngineMuted")
        } else {
            UserDefaults.standard.removeObject(forKey: "soundEngineMuted")
        }
    }

    @Test("SoundEngine's own start path starts the engine")
    func ownStartPathWorks() {
        #expect(SoundEngine.debugEngineIsRunning)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
            SoundEngine.debugDrainSetUpQueue()
        }
    }

    /// Through `blockImpact`'s own path: a filled pool buffer, scheduled on a
    /// stopped engine.
    @Test("a tower landing on a stopped engine restarts it instead of raising")
    func landingRestarts() async throws {
        SoundEngine.ImpactPool.shared.warmNow()
        #expect(SoundEngine.ImpactPool.shared.buffer(mass: 2, column: 1) != nil)
        SoundEngine.debugStopEngine()
        #expect(!SoundEngine.debugEngineIsRunning)
        SoundEngine.blockImpact(mass: 2, column: 1)
        #expect(SoundEngine.debugEngineIsRunning)
    }

    @Test("a configuration change restarts a stopped engine")
    func configurationChangeRestarts() async {
        SoundEngine.debugStopEngine()
        SoundEngine.debugPostConfigurationChange()
        await waitUntil { SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugEngineIsRunning)
    }

    @Test("an interruption ending restarts a stopped engine")
    func interruptionEndRestarts() async {
        SoundEngine.debugStopEngine()
        SoundEngine.debugPostInterruptionEnded()
        await waitUntil { SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugEngineIsRunning)
    }

    @Test("a media services reset builds a fresh engine and starts it")
    func mediaServicesResetRebuilds() async {
        let before = SoundEngine.debugGraphID
        SoundEngine.debugPostMediaServicesReset()
        await waitUntil { SoundEngine.debugGraphID != before && SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugGraphID != before)
        #expect(SoundEngine.debugEngineIsRunning)
        SoundEngine.blockImpact(mass: 1, column: 0)
        #expect(SoundEngine.debugEngineIsRunning)
    }

    /// The engine stopped while sound was off; turning it back on must bring
    /// it back without waiting for a sound to find it stopped.
    @Test("unmuting restarts an engine that stopped while muted")
    func unmutingRestarts() async {
        SoundEngine.isMuted = true
        SoundEngine.debugStopEngine()
        SoundEngine.isMuted = false
        await waitUntil { SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugEngineIsRunning)
    }

    /// An interruption that will not end: a downpour of landings must not
    /// each pay a start attempt on the main thread.
    @Test("after a failed start, sounds are dropped for the cooldown without another attempt")
    func failedStartCoolsDown() async throws {
        SoundEngine.ImpactPool.shared.warmNow()
        SoundEngine.debugStopEngine()
        SoundEngine.debugFailStarts.withLock { $0 = true }
        defer {
            SoundEngine.debugFailStarts.withLock { $0 = false }
            SoundEngine.debugResetRestartState()
        }
        let attemptsBefore = SoundEngine.debugStartAttempts.withLock { $0 }
        let droppedBefore = SoundEngine.debugDropped.withLock { $0 }
        for _ in 0..<20 { SoundEngine.blockImpact(mass: 1, column: 2) }
        #expect(SoundEngine.debugStartAttempts.withLock { $0 } - attemptsBefore == 1)
        #expect(SoundEngine.debugDropped.withLock { $0 } - droppedBefore == 19)
        #expect(!SoundEngine.debugEngineIsRunning)

        // After the cooldown, and with the device willing again, the next
        // sound tries once more and gets its engine back.
        SoundEngine.debugFailStarts.withLock { $0 = false }
        try await Task.sleep(for: .seconds(SoundEngine.startCooldown + 0.1))
        SoundEngine.blockImpact(mass: 1, column: 2)
        #expect(SoundEngine.debugStartAttempts.withLock { $0 } - attemptsBefore == 2)
        #expect(SoundEngine.debugEngineIsRunning)
    }

    @Test("the first sound after a route change does not wait for the restart in flight")
    func soundDuringRestartDoesNotBlock() async {
        SoundEngine.ImpactPool.shared.warmNow()
        SoundEngine.debugRestartDelay.withLock { $0 = 0.5 }
        defer { SoundEngine.debugRestartDelay.withLock { $0 = 0 } }
        SoundEngine.debugStopEngine()
        let droppedBefore = SoundEngine.debugDropped.withLock { $0 }
        SoundEngine.debugPostConfigurationChange()
        let start = CACurrentMediaTime()
        SoundEngine.blockImpact(mass: 3, column: 3)
        let waited = CACurrentMediaTime() - start
        #expect(waited < 0.1, "the sound waited \(waited)s on the restart")
        #expect(SoundEngine.debugDropped.withLock { $0 } - droppedBefore == 1)
        await waitUntil { SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugEngineIsRunning)
    }

    // MARK: - Round 3

    /// A media services reset clears the setup flag and then rebuilds for
    /// the best part of a second. A sound in that window used to `sync`
    /// behind the whole rebuild on the main thread.
    @Test("a sound during a media services rebuild does not wait for it")
    func soundDuringRebuildDoesNotBlock() async {
        SoundEngine.ImpactPool.shared.warmNow()
        SoundEngine.debugRebuildDelay.withLock { $0 = 0.5 }
        defer { SoundEngine.debugRebuildDelay.withLock { $0 = 0 } }
        let droppedBefore = SoundEngine.debugDropped.withLock { $0 }
        SoundEngine.debugPostMediaServicesReset()
        // Into the window itself: the old engine stopped and the setup flag
        // cleared, the new graph not yet set up. Stopping the old engine can
        // take a few hundred ms, and a sound before then never reached the
        // blocking path, which is how this test first passed with the guard
        // removed.
        for _ in 0..<150 where SoundEngine.debugIsSetUp {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(!SoundEngine.debugIsSetUp, "never reached the rebuild window")
        let start = CACurrentMediaTime()
        SoundEngine.blockImpact(mass: 2, column: 0)
        SoundEngine.completionTone(category: .work)
        let waited = CACurrentMediaTime() - start
        #expect(waited < 0.1, "the sounds waited \(waited)s on the rebuild")
        #expect(SoundEngine.debugDropped.withLock { $0 } - droppedBefore == 2)
        await waitUntil { !SoundEngine.debugRestarting && SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugEngineIsRunning)
    }

    /// The system saying "you can play again" is exactly when to try, even
    /// if a sound's start failed a moment ago.
    @Test("an interruption ending inside a failed start's cooldown still restarts")
    func notificationBypassesCooldown() async {
        SoundEngine.ImpactPool.shared.warmNow()
        SoundEngine.debugStopEngine()
        SoundEngine.debugFailStarts.withLock { $0 = true }
        SoundEngine.blockImpact(mass: 1, column: 1)          // fails, cooldown begins
        #expect(!SoundEngine.debugEngineIsRunning)
        SoundEngine.debugFailStarts.withLock { $0 = false }
        SoundEngine.debugPostInterruptionEnded()             // well inside 1s
        await waitUntil { SoundEngine.debugEngineIsRunning }
        #expect(SoundEngine.debugEngineIsRunning)
        SoundEngine.debugResetRestartState()
    }

    /// Two requests while one restart runs: both are honoured by one more
    /// round, and a reset among them still rebuilds.
    @Test("requests arriving during a restart run it once more, and a reset among them rebuilds")
    func requestsCoalesce() async {
        SoundEngine.debugRestartDelay.withLock { $0 = 0.3 }
        defer { SoundEngine.debugRestartDelay.withLock { $0 = 0 } }
        let graphBefore = SoundEngine.debugGraphID
        let runsBefore = SoundEngine.debugRestartRuns.withLock { $0 }
        SoundEngine.debugStopEngine()
        SoundEngine.debugPostConfigurationChange()
        try? await Task.sleep(for: .milliseconds(100))       // the first round is running
        SoundEngine.debugPostInterruptionEnded()
        SoundEngine.debugPostMediaServicesReset()
        #expect(SoundEngine.debugRestarting)
        await waitUntil { !SoundEngine.debugRestarting }
        #expect(SoundEngine.debugRestartRuns.withLock { $0 } - runsBefore == 2)
        #expect(SoundEngine.debugGraphID != graphBefore, "the reset was dropped")
        #expect(SoundEngine.debugEngineIsRunning)
    }

    @Test("preparing an engine that is already running marks no restart")
    func prepareOnRunningEngineMarksNothing() async {
        let runsBefore = SoundEngine.debugRestartRuns.withLock { $0 }
        SoundEngine.prepare()
        #expect(!SoundEngine.debugRestarting)
        SoundEngine.debugDrainSetUpQueue()
        #expect(!SoundEngine.debugRestarting)
        #expect(SoundEngine.debugRestartRuns.withLock { $0 } == runsBefore)
    }

    // MARK: - Formats, on a running engine

    @Test("a converted recording schedules on the player")
    func convertedRecordingSchedules() throws {
        let source = try sineBuffer(rate: 48000, channels: 1, seconds: 0.2)
        let out = try #require(SoundEngine.debugConvertToRenderFormat(source))
        #expect(SoundEngine.debugSchedule(out))
    }

    @Test("a buffer the player is not connected for is dropped, not scheduled")
    func mismatchedBufferIsDropped() throws {
        let wrong = try sineBuffer(rate: 48000, channels: 2, seconds: 0.1)
        #expect(!SoundEngine.debugSchedule(wrong))
        #expect(SoundEngine.debugEngineIsRunning)
    }
}

func sineBuffer(rate: Double, channels: AVAudioChannelCount, seconds: Double) throws -> AVAudioPCMBuffer {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels))
    let frames = AVAudioFrameCount(rate * seconds)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
    buffer.frameLength = frames
    for c in 0..<Int(channels) {
        for i in 0..<Int(frames) {
            buffer.floatChannelData![c][i] = Float(sin(2 * .pi * 440 * Double(i) / rate) * 0.5)
        }
    }
    return buffer
}

/// Conversion needs no engine, so it is never skipped with the suite above.
@Suite("Sound formats")
struct SoundFormatTests {
    /// A recording dropped into the bundle at 48kHz mono.
    @Test("a 48kHz mono recording is converted to 44.1kHz stereo with both sides sounding")
    func monoRecordingIsConverted() throws {
        let source = try sineBuffer(rate: 48000, channels: 1, seconds: 0.5)
        let out = try #require(SoundEngine.debugConvertToRenderFormat(source))
        #expect(out.format.sampleRate == 44100)
        #expect(out.format.channelCount == 2)
        #expect(abs(Int(out.frameLength) - 22050) < 200, "\(out.frameLength) frames")
        let left = (0..<Int(out.frameLength)).map { abs(out.floatChannelData![0][$0]) }.max() ?? 0
        let right = (0..<Int(out.frameLength)).map { abs(out.floatChannelData![1][$0]) }.max() ?? 0
        #expect(left > 0.4 && right > 0.4, "left \(left) right \(right)")
    }

    @Test("a buffer already in the render format is returned as is")
    func matchingBufferIsUntouched() throws {
        let source = try sineBuffer(rate: 44100, channels: 2, seconds: 0.1)
        #expect(SoundEngine.debugConvertToRenderFormat(source) === source)
    }
}
