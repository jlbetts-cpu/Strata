import AVFoundation
import Foundation
import Testing
@testable import Strata

/// The engine stops underneath the app: a call, Siri, an alarm, AirPods
/// connecting and changing the output rate. A player told to play on a
/// stopped engine raises, which is a crash, so every sound and both system
/// notifications have to bring it back. These stop it the way the system
/// does and check it comes back, without crashing on the way.
@MainActor
@Suite("Sound engine restart", .serialized)
struct SoundEngineRestartTests {

    /// Unmuted for the test, restored after. Returns false when this
    /// simulator cannot run an audio engine at all, so nothing is claimed.
    private func startedEngine() -> Bool {
        SoundEngine.debugSetUpNow()
        SoundEngine.debugStartEngine()
        return SoundEngine.debugEngineIsRunning
    }

    private func waitUntilRunning() async {
        for _ in 0..<50 where !SoundEngine.debugEngineIsRunning {
            try? await Task.sleep(for: .milliseconds(20))
            SoundEngine.debugDrainSetUpQueue()
        }
    }

    private func withUnmuted(_ body: () async throws -> Void) async rethrows {
        let wasMuted = UserDefaults.standard.bool(forKey: "soundEngineMuted")
        UserDefaults.standard.set(false, forKey: "soundEngineMuted")
        defer { UserDefaults.standard.set(wasMuted, forKey: "soundEngineMuted") }
        try await body()
    }

    @Test("a landing on a stopped engine restarts it instead of raising")
    func soundRestarts() async throws {
        try await withUnmuted {
            try #require(startedEngine(), "no audio engine on this simulator")
            SoundEngine.debugStopEngine()
            #expect(!SoundEngine.debugEngineIsRunning)
            SoundEngine.blockImpact(mass: 2, column: 1)
            SoundEngine.completionTone(category: .health)
            #expect(SoundEngine.debugEngineIsRunning)
        }
    }

    @Test("a configuration change restarts a stopped engine")
    func configurationChangeRestarts() async throws {
        try await withUnmuted {
            try #require(startedEngine(), "no audio engine on this simulator")
            SoundEngine.debugStopEngine()
            SoundEngine.debugPostConfigurationChange()
            await waitUntilRunning()
            #expect(SoundEngine.debugEngineIsRunning)
        }
    }

    @Test("an interruption ending restarts a stopped engine")
    func interruptionEndRestarts() async throws {
        try await withUnmuted {
            try #require(startedEngine(), "no audio engine on this simulator")
            SoundEngine.debugStopEngine()
            SoundEngine.debugPostInterruptionEnded()
            await waitUntilRunning()
            #expect(SoundEngine.debugEngineIsRunning)
        }
    }
}
