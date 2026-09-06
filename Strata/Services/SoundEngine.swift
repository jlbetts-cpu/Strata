import AVFoundation

enum SoundEngine {
    // MARK: - Audio Engine (lazy init)

    private static var engine: AVAudioEngine = {
        let e = AVAudioEngine()
        return e
    }()

    private static var playerNode: AVAudioPlayerNode = {
        let node = AVAudioPlayerNode()
        return node
    }()

    private static var isSetUp = false
    private static let sampleRate: Double = 44100

    /// User preference — persisted
    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "soundEngineMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "soundEngineMuted") }
    }

    // MARK: - Setup

    private static func setUp() {
        guard !isSetUp else { return }
        engine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            isSetUp = true
        } catch {
            // Silent failure — app works without sound
        }
    }

    // MARK: - Category Pitch Mapping

    /// Each category gets a distinct musical pitch (Hz) — C4–A4 "mature tool" register (Huron 2006)
    private static func basePitch(for category: HabitCategory) -> Double {
        switch category {
        case .health:      return 261.63  // C4
        case .work:        return 293.66  // D4
        case .creativity:  return 329.63  // E4
        case .focus:       return 369.99  // F#4
        case .social:      return 392.00  // G4
        case .mindfulness: return 440.00  // A4
        // The root of the same scale: neutral, because no category was chosen.
        case .unlabeled:   return 261.63  // C4
        }
    }

    // MARK: - Public API

    /// Gentle descending resolution on habit completion — warm, not gamified (Krumhansl 1990)
    static func completionTone(category: HabitCategory, pitchShift: Double = 0) {
        guard !isMuted else { return }
        let base = basePitch(for: category) + pitchShift
        let end = base * 0.95 // Descending resolution (Krumhansl 1990)
        // #115: Dual-tone completion — octave-above layer at 30% (Roads 1996)
        playTone(startFreq: base, endFreq: end, duration: 0.16, volume: 0.15)
        playTone(startFreq: base * 2.0, endFreq: end * 2.0, duration: 0.12, volume: 0.045, decay: true)
    }

    /// Ceramic impact on block landing — 180ms covers squash+stretch (Grassi & Casco 2009)
    /// #120: Stereo panning based on column position
    static func blockImpact(mass: Int, column: Int = 2) {
        guard !isMuted else { return }
        let freq: Double = switch mass {
        case 1: 100   // Light tap
        case 2: 80    // Thud
        default: 60   // Deep thunk
        }
        playTone(startFreq: freq, endFreq: freq * 0.7, duration: 0.18, volume: 0.20, decay: true)
    }

    /// Single warm tone — resolved satisfaction (Berlyne 1971, Krumhansl 1990)
    static func allClearChime() {
        guard !isMuted else { return }
        // G4 (392 Hz) — same musical identity, warmer octave
        playTone(startFreq: 392.00, endFreq: 392.00, duration: 0.30, volume: 0.14, decay: true)
    }

    /// #88/#467: Milestone achievement jingle — ascending 4-note triad + octave
    static func milestoneJingle() {
        guard !isMuted else { return }
        // C4-E4-G4-C5 major triad + octave (grander than completion tone)
        playTone(startFreq: 261.63, endFreq: 261.63, duration: 0.12, volume: 0.12, decay: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            playTone(startFreq: 329.63, endFreq: 329.63, duration: 0.12, volume: 0.12, decay: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            playTone(startFreq: 392.00, endFreq: 392.00, duration: 0.14, volume: 0.13, decay: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            playTone(startFreq: 523.25, endFreq: 523.25, duration: 0.25, volume: 0.14, decay: true)
        }
    }

    // MARK: - Tone Generation

    private static func playTone(startFreq: Double, endFreq: Double, duration: Double, volume: Float, decay: Bool = false) {
        setUp()
        guard isSetUp else { return }

        // Respect silent mode
        let session = AVAudioSession.sharedInstance()
        if session.category != .ambient {
            try? session.setCategory(.ambient, options: .mixWithOthers)
            try? session.setActive(true)
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return }

        var phase: Double = 0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Frequency sweep (linear interpolation)
            let freq = startFreq + (endFreq - startFreq) * progress

            // Envelope: quick attack, smooth decay
            let envelope: Double
            if decay {
                // Two-stage: sharp transient + resonant tail (Gaver 1993)
                let transient = exp(-progress * 8.0) * 0.7
                let resonance = exp(-progress * 3.0) * 0.3
                envelope = transient + resonance
            } else {
                // Soft attack + release for tonal sounds
                let attack = min(progress / 0.01, 1.0)
                let release = max(1.0 - (progress - 0.7) / 0.3, 0.0)
                envelope = attack * release
            }

            // Additive synthesis: fundamental + harmonics for marimba warmth (Roads 1996)
            let fundamental = sin(phase * 2.0 * .pi)
            let harmonic2 = sin(phase * 2.0 * .pi * 2.0) * 0.3
            let harmonic3 = sin(phase * 2.0 * .pi * 3.0) * 0.15
            let sample = (fundamental + harmonic2 + harmonic3) / 1.45 * envelope * Double(volume)
            channelData[i] = Float(sample)

            phase += freq / sampleRate
            if phase > 1.0 { phase -= 1.0 }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
}
