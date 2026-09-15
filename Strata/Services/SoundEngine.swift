import AVFoundation
import Accelerate
import os

/// Sound for Strata.
///
/// **Recorded samples first; synthesis only as the fallback.** Drop licensed
/// audio into `Strata/Resources/Sounds/` named after the cues in `Cue` and it
/// is used automatically, with no code change here — see
/// `docs/sound-direction.md` for what to source and what each cue has to do.
/// Until those files exist, everything below is synthesised.
///
/// ## Why the old synthesis sounded cheap
///
/// It was not "synthesised vs real". It was six specific things, and five of
/// them are fixable without a single recording:
///
/// 1. **Harmonic partials at 1:2:3.** That is an organ, not a struck object.
///    Real bars, glass and bells are INHARMONIC — a marimba bar's overtones sit
///    near 3.9x and 9.5x, a bell's near 2.8x and 5.4x. Integer ratios are the
///    single loudest "this is a computer" signal in the whole sound.
/// 2. **One envelope for every partial.** In anything physical the high
///    partials die away much faster than the fundamental; that decay is most of
///    what makes a sound feel like an object. Sharing one envelope makes it
///    static and buzzy.
/// 3. **No contact transient.** A struck thing makes a tiny burst of noise
///    where the mallet meets it, before the body rings. Without it there is
///    nothing to say two things touched.
/// 4. **A 2ms linear attack**, which is a click, and a LINEAR release, which
///    nothing in the physical world does. Decay is exponential.
/// 5. **Bone dry mono.** No room, no space, no width. A dry tone at 44.1kHz is
///    a test signal. A short room is most of the difference between "beep" and
///    "designed".
/// 6. **Byte-identical every time.** The ear habituates to an exact repeat
///    within a handful of plays and starts hearing it as cheap. Real recordings
///    vary; this now varies too.
///
/// ## Why it is consonant by construction
///
/// Every pitch is snapped to a **major pentatonic scale**. A pentatonic set
/// contains no minor seconds and no tritone, so no two cues — however they
/// overlap, and they do overlap when you log several wins quickly — can produce
/// a rough interval. Roughness is the measurable part of "unpleasant" (Plomp &
/// Levelt's critical-band work); removing the intervals that cause it is a
/// structural fix rather than a matter of taste.
///
/// The previous mapping gave `focus` F#4 against a C root — a tritone, the most
/// dissonant interval in the octave, on one of six equally likely categories.
enum SoundEngine {

    // MARK: - Preference

    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: mutedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: mutedKey)
            // Unmuting mid-session: start the engine and render the landings
            // now, not on the next sound. Launching muted never prepared.
            if !newValue { prepare() }
        }
    }

    nonisolated private static let mutedKey = "soundEngineMuted"

    // MARK: - Cues

    /// The sounds the app makes. The raw value is also the file name to look
    /// for, so `win.wav` in the bundle replaces the synthesised `.win`.
    nonisolated enum Cue: String {
        case win            // a habit or win completed
        case impact         // a block landing on the tower
        case chime          // the day is clear
        case milestone      // a round number reached
    }

    // MARK: - Graph

    // The graph is built, started and restarted on `setUpQueue`, and buffers
    // are scheduled on it too (a `sync` from the main thread, which costs
    // nothing when the queue is idle). Everything that touches the engine is
    // therefore serialised: a restart after an interruption can never race a
    // `play()` on a stopped engine, which AVFAudio answers with an exception.
    nonisolated(unsafe) private static let engine = AVAudioEngine()
    nonisolated(unsafe) private static let player = AVAudioPlayerNode()
    nonisolated(unsafe) private static let reverb = AVAudioUnitReverb()
    nonisolated(unsafe) private static let tone = AVAudioUnitEQ(numberOfBands: 2)
    /// The graph is attached and wired and the observers are installed. Says
    /// nothing about whether the engine is running right now; see
    /// `startIfNeeded`.
    nonisolated private static let setUpState = OSAllocatedUnfairLock(initialState: false)
    nonisolated private static var isSetUp: Bool { setUpState.withLock { $0 } }
    nonisolated private static let setUpQueue = DispatchQueue(label: "strata.sound.setup", qos: .utility)
    nonisolated private static let sampleRate: Double = 44100

    /// The format every voice is rendered in and the player is connected at.
    ///
    /// **Fixed, whatever the hardware does.** When the output changes rate
    /// (AirPods connecting, a call), the engine stops and posts a
    /// configuration change; `startIfNeeded` reconnects the player at THIS
    /// format and the main mixer resamples to the new hardware rate. So the
    /// rendered landings in `ImpactPool` stay valid across the change and
    /// nothing has to be re-rendered.
    nonisolated private static var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }

    /// Starts the audio engine now rather than on the first sound, OFF the
    /// main thread, and renders the tower's landings ahead of time.
    ///
    /// Starting the engine takes a moment (measured: the first landing of a
    /// replay held the frame 405 to 445ms; the tower's first landing after a
    /// cold launch held it 338 to 404ms on the iOS 26.3 simulator, 303 to
    /// 365ms of that in `setUp`). It used to run on the main thread at the
    /// moment of impact. Now `MainAppView` calls this once the first frame
    /// is up, a replay calls it before its clock starts, and unmuting calls
    /// it; all return at once. A sound asked for while this is still running
    /// waits for it, which is never longer than it used to take. Muted, it
    /// does nothing, as `play` would.
    static func prepare() {
        guard !isMuted else { return }
        setUpQueue.async { setUp() }
        // On the pool's own queue, so the setup queue is free for the first
        // sound the moment the engine is up.
        ImpactPool.shared.warm()
    }

    /// Builds and starts the graph. Blocks until any setup already running
    /// on the queue has finished.
    nonisolated private static func setUpNow() {
        guard !isSetUp else { return }
        setUpQueue.sync { setUp() }
    }

    /// Only ever called on `setUpQueue`. Safe to call again after a failed
    /// start: nodes are attached only if they are not already, and the
    /// observers are installed once.
    nonisolated private static func setUp() {
        guard !isSetUp else { return }
        #if DEBUG
        let probeStart = CACurrentMediaTime()
        defer { PerfProbe.duration("SoundEngine.setUp", since: probeStart) }
        #endif

        let session = AVAudioSession.sharedInstance()
        // `.ambient` + mixWithOthers: respects the silent switch and never
        // interrupts music. A habit app must not stop someone's podcast.
        try? session.setCategory(.ambient, options: .mixWithOthers)

        for node in [player, tone, reverb] as [AVAudioNode] where node.engine == nil {
            engine.attach(node)
        }

        // A small room at a low mix. Not an effect — the point is that the
        // sound appears to happen somewhere rather than inside the speaker.
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 14

        // Takes the glassy top off without dulling it, and clears the sub-bass
        // that a phone speaker can only turn into distortion.
        tone.bands[0].filterType = .lowPass
        tone.bands[0].frequency = 7400
        tone.bands[0].bypass = false
        tone.bands[1].filterType = .highPass
        tone.bands[1].frequency = 48
        tone.bands[1].bypass = false

        observeInterruptions()
        setUpState.withLock { $0 = true }
        // The app works fine without sound: a failed start is retried by the
        // next sound (`schedule`), not reported.
        _ = startIfNeeded()
    }

    /// Wires the graph at `format`. Reconnecting an existing connection
    /// replaces it, so this is also the repair after a configuration change.
    nonisolated private static func connectGraph() {
        let f = format
        engine.connect(player, to: tone, format: f)
        engine.connect(tone, to: reverb, format: f)
        engine.connect(reverb, to: engine.mainMixerNode, format: f)
    }

    /// On `setUpQueue`. Starts the engine if it is not running, returning
    /// whether it is now and whether this call started it.
    ///
    /// **The engine stops underneath us.** An interruption (a call, Siri,
    /// an alarm) or a route or sample-rate change (AirPods connecting) stops
    /// it, and a player told to `play()` on a stopped engine raises. Every
    /// sound comes through here first, and so do both notifications.
    nonisolated private static func startIfNeeded() -> (running: Bool, started: Bool) {
        guard isSetUp else { return (false, false) }
        if engine.isRunning { return (true, false) }
        try? AVAudioSession.sharedInstance().setActive(true)
        connectGraph()
        engine.prepare()
        do {
            try engine.start()
            return (true, true)
        } catch {
            return (false, false)
        }
    }

    nonisolated private static let observing = OSAllocatedUnfairLock(initialState: false)

    /// Restart when an interruption ends or the engine's configuration
    /// changes. Installed once, on the setup queue. Not while muted: the next
    /// sound starts it anyway, and a stopped engine costs nothing.
    nonisolated private static func observeInterruptions() {
        let first = observing.withLock { installed -> Bool in
            defer { installed = true }
            return !installed
        }
        guard first else { return }
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification,
                           object: AVAudioSession.sharedInstance(), queue: nil) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            setUpQueue.async { restartUnlessMuted() }
        }
        center.addObserver(forName: .AVAudioEngineConfigurationChange,
                           object: engine, queue: nil) { _ in
            setUpQueue.async { restartUnlessMuted() }
        }
    }

    /// On `setUpQueue`.
    nonisolated private static func restartUnlessMuted() {
        guard !UserDefaults.standard.bool(forKey: mutedKey) else { return }
        if startIfNeeded().started { player.play() }
    }

    #if DEBUG
    /// For `SoundEngineRestartTests`: the engine as a sound would find it.
    static var debugEngineIsRunning: Bool { setUpQueue.sync { engine.isRunning } }
    /// Stops the engine the way an interruption does, without one.
    static func debugStopEngine() { setUpQueue.sync { engine.stop() } }
    /// Posts the notification a route or sample-rate change posts.
    static func debugPostConfigurationChange() {
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engine)
    }
    /// Posts an interruption that has just ended.
    static func debugPostInterruptionEnded() {
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
    }
    /// Waits until the setup queue has drained, and builds the graph if it
    /// has not been built, without depending on the mute setting.
    static func debugSetUpNow() { setUpNow() }
    /// Starts a stopped engine directly, so one test's stop does not decide
    /// the next test's outcome.
    static func debugStartEngine() { setUpQueue.sync { _ = startIfNeeded() } }
    static func debugDrainSetUpQueue() { setUpQueue.sync {} }
    #endif

    // MARK: - Scale

    /// C major pentatonic, C3 to C6. No minor second, no tritone: any two of
    /// these sounding together are consonant.
    private static let scale: [Double] = {
        let degrees: [Double] = [0, 2, 4, 7, 9]   // semitones: C D E G A
        var out: [Double] = []
        for octave in -1...2 {
            for d in degrees {
                out.append(261.63 * pow(2.0, (d + Double(octave) * 12) / 12))
            }
        }
        return out.sorted()
    }()

    /// Pulls any frequency onto the nearest note of the scale.
    ///
    /// Call sites pass pitch offsets in Hz — an escalating streak, a wave
    /// reaching the top of the tower. Adding Hz to a pitch lands wherever it
    /// lands, which is how a tritone gets in. Snapping keeps the gesture
    /// (higher is still higher) and removes the possibility of a rough
    /// interval.
    private static func snapped(_ hz: Double) -> Double {
        scale.min(by: { abs($0 - hz) < abs($1 - hz) }) ?? hz
    }

    /// Each category gets a degree of the scale.
    private static func basePitch(for category: HabitCategory) -> Double {
        switch category {
        case .health:      return 261.63  // C4
        case .work:        return 293.66  // D4
        case .creativity:  return 329.63  // E4
        case .focus:       return 392.00  // G4 — was F#4, a tritone against C
        case .social:      return 440.00  // A4
        case .mindfulness: return 523.25  // C5
        case .unlabeled:   return 261.63  // C4, the root: no category was chosen
        }
    }

    // MARK: - Voice

    /// One partial of a resonant body: where it sits, how loud it starts, and
    /// how much faster than the fundamental it dies.
    nonisolated private struct Partial {
        let ratio: Double
        let level: Double
        let damping: Double
    }

    /// A struck wooden bar. A marimba bar is undercut so its first overtones
    /// land near four and ten times the fundamental — nowhere near 2x and 3x,
    /// which is exactly why this reads as wood and that read as an organ.
    nonisolated private static let woodBar = [
        Partial(ratio: 1.00, level: 1.00, damping: 1.0),
        Partial(ratio: 3.93, level: 0.26, damping: 2.8),
        Partial(ratio: 9.55, level: 0.08, damping: 5.4)
    ]

    /// Struck glass. Bell partials, thinned so it stays a hint rather than a
    /// church.
    nonisolated private static let glass = [
        Partial(ratio: 1.00, level: 1.00, damping: 1.0),
        Partial(ratio: 2.76, level: 0.30, damping: 1.9),
        Partial(ratio: 5.40, level: 0.11, damping: 3.4),
        Partial(ratio: 8.93, level: 0.04, damping: 5.8)
    ]

    /// A soft, heavy body landing. Low, close ratios, damped hard: the sound of
    /// something with mass that does not ring.
    nonisolated private static let body = [
        Partial(ratio: 1.00, level: 1.00, damping: 1.0),
        Partial(ratio: 1.58, level: 0.20, damping: 2.6),
        Partial(ratio: 2.41, level: 0.07, damping: 4.2)
    ]

    nonisolated private struct Voice {
        var cue: Cue
        var frequency: Double
        var partials: [Partial]
        var duration: Double
        var decay: Double
        var gain: Double
        var attack: Double = 0.004
        var noise: Double = 0
        var noiseDecay: Double = 90
        var pan: Double = 0
    }

    // MARK: - Playback

    private static var sampleCache: [Cue: AVAudioPCMBuffer?] = [:]

    /// A recorded file for this cue, if one has been added to the bundle.
    private static func sample(for cue: Cue) -> AVAudioPCMBuffer? {
        if let cached = sampleCache[cue] { return cached }
        var found: AVAudioPCMBuffer?
        for ext in ["caf", "wav", "aiff", "m4a"] {
            if let url = Bundle.main.url(forResource: cue.rawValue, withExtension: ext),
               let file = try? AVAudioFile(forReading: url),
               let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: AVAudioFrameCount(file.length)),
               (try? file.read(into: buf)) != nil {
                found = buf
                break
            }
        }
        sampleCache[cue] = found
        return found
    }

    private static func play(_ voice: Voice) {
        guard !isMuted else { return }
        setUpNow()
        guard isSetUp else { return }

        if let recorded = sample(for: voice.cue) {
            schedule(recorded)
        } else if let rendered = render(varied(voice)) {
            schedule(rendered)
        }
    }

    /// Plays `buffer`, restarting the engine first if something stopped it.
    /// Drops the sound, rather than raising, when the engine cannot run or the
    /// buffer is not in the format the player is connected at.
    private static func schedule(_ buffer: AVAudioPCMBuffer) {
        setUpQueue.sync {
            let state = startIfNeeded()
            guard state.running else { return }
            let connected = player.outputFormat(forBus: 0)
            guard buffer.format.sampleRate == connected.sampleRate,
                  buffer.format.channelCount == connected.channelCount else {
                NSLog("[strata-sound] dropped a %.0fHz/%dch buffer on a %.0fHz/%dch player",
                      buffer.format.sampleRate, buffer.format.channelCount,
                      connected.sampleRate, connected.channelCount)
                return
            }
            player.scheduleBuffer(buffer, completionHandler: nil)
            // After a restart the player has to be told again: it can still
            // report playing from before the engine stopped.
            if state.started || !player.isPlaying { player.play() }
        }
    }

    /// Round robin. Real recordings are never identical twice; an exact repeat
    /// is heard as mechanical within a few plays, which is most of what "cheap"
    /// means for a sound you will hear thousands of times.
    nonisolated private static func varied(_ voice: Voice) -> Voice {
        var v = voice
        v.frequency *= Double.random(in: 0.988...1.012)
        v.decay *= Double.random(in: 0.92...1.08)
        v.gain *= Double.random(in: 0.94...1.06)
        return v
    }

    /// `seed` fixes the contact noise, so a render can be repeated exactly;
    /// nil draws a fresh burst, as live playback does.
    nonisolated private static func render(_ v: Voice, seed fixedSeed: UInt64? = nil) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * v.duration)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let left = buffer.floatChannelData?[0],
              let right = buffer.floatChannelData?[1] else { return nil }
        buffer.frameLength = frames

        // Constant power, so a panned sound is no quieter than a centred one.
        let angle = (max(-1, min(1, v.pan)) + 1) * .pi / 4
        let gainL = cos(angle)
        let gainR = sin(angle)

        let attackFrames = max(1.0, v.attack * sampleRate)
        let levelSum = max(v.partials.reduce(0) { $0 + $1.level }, 0.0001)
        var noiseLP = 0.0
        var seed = fixedSeed ?? UInt64.random(in: 1...UInt64.max)

        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate

            // Raised cosine: reaches full level with zero slope, so there is no
            // click and no 2ms buzz.
            let attack = Double(i) < attackFrames
                ? 0.5 - 0.5 * cos(.pi * Double(i) / attackFrames)
                : 1.0

            // Each partial decays at its OWN rate. This is the line that makes
            // it sound like an object instead of a chord.
            var s = 0.0
            for p in v.partials {
                s += sin(2 * .pi * v.frequency * p.ratio * t)
                    * p.level
                    * exp(-v.decay * p.damping * t)
            }
            s /= levelSum

            // The contact: a very short, dulled noise burst where the two
            // things met, under the body of the sound rather than on top of it.
            if v.noise > 0 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let white = Double(Int64(bitPattern: seed >> 11)) / Double(1 << 52) - 1.0
                noiseLP += (white - noiseLP) * 0.32
                s += noiseLP * v.noise * exp(-v.noiseDecay * t)
            }

            let out = Float(s * attack * v.gain)
            left[i] = out * Float(gainL)
            right[i] = out * Float(gainR)
        }
        return buffer
    }

    // MARK: - Public API

    /// A win landed. Warm, wooden, short.
    static func completionTone(category: HabitCategory, pitchShift: Double = 0) {
        let pitch = snapped(basePitch(for: category) + pitchShift)
        play(Voice(
            cue: .win,
            frequency: pitch,
            partials: woodBar,
            duration: 0.55,
            decay: 7.5,
            gain: 0.20,
            noise: 0.05,
            noiseDecay: 150
        ))
    }

    /// A block touching down. Mass picks the octave; the column places it
    /// across the stereo field, so the sound comes from where you can see it
    /// happen.
    ///
    /// `gain` scales the voice's level. A replay plays a landing at a reduced
    /// level, so a month's downpour is a patter under the picture rather than
    /// the full knock of a win you just logged.
    ///
    /// **Not synthesised on the hit.** A landing is 0.45s of stereo rendered
    /// sample by sample, a few milliseconds of main thread in the middle of
    /// the squash. `ImpactPool` keeps a few rendered variants per mass and
    /// column, rendered on a background queue, and plays a different one
    /// from the last each time, so the round robin is kept.
    static func blockImpact(mass: Int, column: Int = 2, gain: Double = 1) {
        guard !isMuted else { return }
        if sample(for: .impact) != nil {
            play(impactVoice(mass: mass, column: column, gain: gain))
            return
        }
        setUpNow()
        guard isSetUp else { return }
        if let buffer = ImpactPool.shared.buffer(mass: mass, column: column) {
            schedule(gain == 1 ? buffer : scaled(buffer, by: gain) ?? buffer)
            return
        }
        // This key's variants are not rendered yet (the first seconds after
        // `prepare`). Synthesise this one landing live, off the main thread,
        // as a fresh variant that is never stored, so it cannot be repeated.
        ImpactPool.shared.renderLive(mass: mass, column: column) { rendered in
            guard let rendered else { return }
            let out = gain == 1 ? rendered : scaled(rendered, by: gain) ?? rendered
            DispatchQueue.main.async { MainActor.assumeIsolated { schedule(out) } }
        }
    }

    /// A copy of `buffer` at `gain`. Scaling a rendered landing is the same
    /// as rendering it with the gain folded in: gain is a plain multiplier
    /// on every sample (`render`'s last line).
    nonisolated private static func scaled(_ buffer: AVAudioPCMBuffer, by gain: Double) -> AVAudioPCMBuffer? {
        guard let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength),
              let src = buffer.floatChannelData, let dst = out.floatChannelData else { return nil }
        out.frameLength = buffer.frameLength
        var g = Float(gain)
        for channel in 0..<Int(buffer.format.channelCount) {
            vDSP_vsmul(src[channel], 1, &g, dst[channel], 1, vDSP_Length(buffer.frameLength))
        }
        return out
    }

    /// Rendered landings, a few per mass and column.
    ///
    /// Every live landing used to be rendered on the spot with fresh jitter
    /// (±1.2% pitch, ±8% decay, ±6% level) and a fresh contact burst. The pool
    /// keeps `variants` of those per (mass, column), made the same way, and
    /// never hands out the one it handed out last for that key.
    ///
    /// **A key's variants arrive together.** They are all rendered before any
    /// is handed out, so a key never has one variant to repeat while the
    /// others are still rendering. Until a key is filled, `buffer` returns nil
    /// and the caller synthesises that landing live, off the main thread.
    /// `warm()` fills all twelve keys on the pool's own queue: 36 buffers of
    /// 0.45s stereo Float32, about 5.7 MB.
    nonisolated final class ImpactPool: @unchecked Sendable {
        static let shared = ImpactPool()
        static let variants = 3
        private static let masses = 1...3
        /// `GridConstants.columnCount`, which is main-actor state and so out
        /// of reach of a pool filled on a background queue.
        private static let columns = 0..<4

        private let lock = NSLock()
        private var pool: [Int: [AVAudioPCMBuffer]] = [:]
        private var lastIndex: [Int: Int] = [:]
        private var filling: Set<Int> = []
        private let queue = DispatchQueue(label: "strata.sound.impacts", qos: .utility)
        private let liveQueue = DispatchQueue(label: "strata.sound.live", qos: .userInitiated)

        private func key(_ mass: Int, _ column: Int) -> Int { mass * 16 + column }

        /// Fills every tower landing, on the pool's queue. Returns at once.
        func warm() {
            queue.async { [self] in warmNow() }
        }

        /// Fills every tower landing on the calling thread.
        func warmNow() {
            for mass in Self.masses {
                for column in Self.columns { fill(mass: mass, column: column) }
            }
        }

        /// Renders all of a key's variants, then publishes them in one step.
        private func fill(mass: Int, column: Int) {
            let k = key(mass, column)
            let claimed = lock.withLock { () -> Bool in
                guard pool[k] == nil, !filling.contains(k) else { return false }
                filling.insert(k)
                return true
            }
            guard claimed else { return }
            let rendered = (0..<Self.variants).compactMap { _ in
                SoundEngine.render(SoundEngine.varied(
                    SoundEngine.impactVoice(mass: mass, column: column, gain: 1)))
            }
            lock.withLock {
                if rendered.count == Self.variants { pool[k] = rendered }
                filling.remove(k)
            }
        }

        /// A rendered landing, never the same variant twice running, or nil
        /// when this key is not filled yet (in which case filling starts).
        func buffer(mass: Int, column: Int) -> AVAudioPCMBuffer? {
            let k = key(mass, column)
            let picked: AVAudioPCMBuffer? = lock.withLock {
                guard let list = pool[k], !list.isEmpty else { return nil }
                var index = Int.random(in: 0..<list.count)
                if list.count > 1, index == lastIndex[k] {
                    index = (index + 1) % list.count
                }
                lastIndex[k] = index
                return list[index]
            }
            if picked == nil {
                queue.async { [self] in fill(mass: mass, column: column) }
            }
            return picked
        }

        /// One landing synthesised now, off the calling thread, and not kept.
        func renderLive(mass: Int, column: Int,
                        then deliver: @escaping @Sendable (AVAudioPCMBuffer?) -> Void) {
            liveQueue.async {
                deliver(SoundEngine.render(SoundEngine.varied(
                    SoundEngine.impactVoice(mass: mass, column: column, gain: 1))))
            }
        }
    }

    nonisolated private static func impactVoice(mass: Int, column: Int, gain: Double) -> Voice {
        let pitch: Double = switch mass {
        case 1: 130.81   // C3
        case 2: 98.00    // G2
        default: 65.41   // C2
        }
        // Four columns, gently spread. Wide panning on a phone speaker is a
        // gimmick; this is just enough to place it.
        let pan = (Double(column) - 1.5) / 1.5 * 0.35
        return Voice(
            cue: .impact,
            frequency: pitch,
            partials: body,
            duration: 0.45,
            decay: 13.0,
            gain: 0.26 * gain,
            attack: 0.002,
            noise: 0.16,
            noiseDecay: 190,
            pan: pan
        )
    }

    /// A landing, rendered to PCM for mixing into a saved replay.
    ///
    /// Unvaried, with a fixed contact burst, so the same replay always saves
    /// the same sound. Dry: the live room and tone are part of the playback
    /// graph, not the voice. Not muted-checked, for the reason
    /// `ReplayAudioMix` gives.
    ///
    /// **Always synthesised.** `play` prefers a recorded `impact` file from
    /// the bundle when one exists; this does not look for one. There is none
    /// today. Add one and the live replay and the saved video will sound
    /// different until this reads the same file.
    static func impactBuffer(mass: Int, column: Int, gain: Double) -> AVAudioPCMBuffer? {
        render(impactVoice(mass: mass, column: column, gain: gain),
               seed: 0x9E37_79B9_7F4A_7C15 &+ UInt64(max(mass, 0) * 8 + max(column, 0)))
    }

    /// The rate every rendered voice is at, and so the saved mix's.
    nonisolated static var mixSampleRate: Double { sampleRate }

    /// Everything is done.
    static func allClearChime() {
        play(Voice(
            cue: .chime,
            frequency: 523.25,   // C5
            partials: glass,
            duration: 1.30,
            decay: 2.4,
            gain: 0.16,
            attack: 0.006,
            noise: 0.02,
            noiseDecay: 220
        ))
    }

    /// A round number. An ascending pentatonic run — every interval consonant,
    /// rising, resolving on the octave.
    static func milestoneJingle() {
        guard !isMuted else { return }
        let run: [(Double, Double)] = [
            (261.63, 0.00),  // C4
            (329.63, 0.09),  // E4
            (392.00, 0.18),  // G4
            (523.25, 0.28)   // C5
        ]
        for (pitch, delay) in run {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                play(Voice(
                    cue: .milestone,
                    frequency: pitch,
                    partials: glass,
                    duration: pitch > 500 ? 1.40 : 0.60,
                    decay: pitch > 500 ? 2.2 : 5.0,
                    gain: 0.15,
                    attack: 0.005,
                    noise: 0.02,
                    noiseDecay: 220
                ))
            }
        }
    }
}
