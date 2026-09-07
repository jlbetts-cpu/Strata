import AVFoundation

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
        get { UserDefaults.standard.bool(forKey: "soundEngineMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "soundEngineMuted") }
    }

    // MARK: - Cues

    /// The sounds the app makes. The raw value is also the file name to look
    /// for, so `win.wav` in the bundle replaces the synthesised `.win`.
    enum Cue: String {
        case win            // a habit or win completed
        case impact         // a block landing on the tower
        case chime          // the day is clear
        case milestone      // a round number reached
    }

    // MARK: - Graph

    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    private static let reverb = AVAudioUnitReverb()
    private static let tone = AVAudioUnitEQ(numberOfBands: 2)
    private static var isSetUp = false
    private static let sampleRate: Double = 44100

    private static var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }

    private static func setUp() {
        guard !isSetUp else { return }

        let session = AVAudioSession.sharedInstance()
        // `.ambient` + mixWithOthers: respects the silent switch and never
        // interrupts music. A habit app must not stop someone's podcast.
        try? session.setCategory(.ambient, options: .mixWithOthers)
        try? session.setActive(true)

        engine.attach(player)
        engine.attach(tone)
        engine.attach(reverb)

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

        let f = format
        engine.connect(player, to: tone, format: f)
        engine.connect(tone, to: reverb, format: f)
        engine.connect(reverb, to: engine.mainMixerNode, format: f)

        do {
            try engine.start()
            isSetUp = true
        } catch {
            // The app works fine without sound.
        }
    }

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
    private struct Partial {
        let ratio: Double
        let level: Double
        let damping: Double
    }

    /// A struck wooden bar. A marimba bar is undercut so its first overtones
    /// land near four and ten times the fundamental — nowhere near 2x and 3x,
    /// which is exactly why this reads as wood and that read as an organ.
    private static let woodBar = [
        Partial(ratio: 1.00, level: 1.00, damping: 1.0),
        Partial(ratio: 3.93, level: 0.26, damping: 2.8),
        Partial(ratio: 9.55, level: 0.08, damping: 5.4)
    ]

    /// Struck glass. Bell partials, thinned so it stays a hint rather than a
    /// church.
    private static let glass = [
        Partial(ratio: 1.00, level: 1.00, damping: 1.0),
        Partial(ratio: 2.76, level: 0.30, damping: 1.9),
        Partial(ratio: 5.40, level: 0.11, damping: 3.4),
        Partial(ratio: 8.93, level: 0.04, damping: 5.8)
    ]

    /// A soft, heavy body landing. Low, close ratios, damped hard: the sound of
    /// something with mass that does not ring.
    private static let body = [
        Partial(ratio: 1.00, level: 1.00, damping: 1.0),
        Partial(ratio: 1.58, level: 0.20, damping: 2.6),
        Partial(ratio: 2.41, level: 0.07, damping: 4.2)
    ]

    private struct Voice {
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
        setUp()
        guard isSetUp else { return }

        if let recorded = sample(for: voice.cue) {
            player.scheduleBuffer(recorded, completionHandler: nil)
        } else if let rendered = render(varied(voice)) {
            player.scheduleBuffer(rendered, completionHandler: nil)
        } else {
            return
        }
        if !player.isPlaying { player.play() }
    }

    /// Round robin. Real recordings are never identical twice; an exact repeat
    /// is heard as mechanical within a few plays, which is most of what "cheap"
    /// means for a sound you will hear thousands of times.
    private static func varied(_ voice: Voice) -> Voice {
        var v = voice
        v.frequency *= Double.random(in: 0.988...1.012)
        v.decay *= Double.random(in: 0.92...1.08)
        v.gain *= Double.random(in: 0.94...1.06)
        return v
    }

    private static func render(_ v: Voice) -> AVAudioPCMBuffer? {
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
        var seed = UInt64.random(in: 1...UInt64.max)

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
    static func blockImpact(mass: Int, column: Int = 2) {
        let pitch: Double = switch mass {
        case 1: 130.81   // C3
        case 2: 98.00    // G2
        default: 65.41   // C2
        }
        // Four columns, gently spread. Wide panning on a phone speaker is a
        // gimmick; this is just enough to place it.
        let pan = (Double(column) - 1.5) / 1.5 * 0.35
        play(Voice(
            cue: .impact,
            frequency: pitch,
            partials: body,
            duration: 0.45,
            decay: 13.0,
            gain: 0.26,
            attack: 0.002,
            noise: 0.16,
            noiseDecay: 190,
            pan: pan
        ))
    }

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
