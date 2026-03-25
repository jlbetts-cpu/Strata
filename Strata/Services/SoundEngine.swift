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

    /// Each category gets a distinct musical pitch (Hz)
    /// Health=C5, Work=D5, Creativity=E5, Focus=F#5, Social=G5, Mindfulness=A5
    private static func basePitch(for category: HabitCategory) -> Double {
        switch category {
        case .health:      return 523.25  // C5
        case .work:        return 587.33  // D5
        case .creativity:  return 659.25  // E5
        case .focus:       return 739.99  // F#5
        case .social:      return 783.99  // G5
        case .mindfulness: return 880.00  // A5
        }
    }

    // MARK: - Public API

    /// Soft ascending tone on habit completion — category-specific pitch
    static func completionTone(category: HabitCategory, pitchShift: Double = 0) {
        guard !isMuted else { return }
        let base = basePitch(for: category) + pitchShift
        let end = base * 1.5 // Ascending sweep
        playTone(startFreq: base, endFreq: end, duration: 0.12, volume: 0.15)
    }

    /// Low ceramic thud on block landing — mass-dependent depth
    static func blockImpact(mass: Int) {
        guard !isMuted else { return }
        let freq: Double = switch mass {
        case 1: 100   // Light tap
        case 2: 80    // Thud
        default: 60   // Deep thunk
        }
        playTone(startFreq: freq, endFreq: freq * 0.6, duration: 0.08, volume: 0.20, decay: true)
    }

    /// C-major arpeggio on all-clear celebration
    static func allClearChime() {
        guard !isMuted else { return }
        let notes: [Double] = [523.25, 659.25, 783.99, 1046.50] // C5, E5, G5, C6
        for (i, freq) in notes.enumerated() {
            let delay = Double(i) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playTone(startFreq: freq, endFreq: freq, duration: 0.10, volume: 0.12)
            }
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
                // Exponential decay for impact sounds
                envelope = exp(-progress * 6.0)
            } else {
                // Soft attack + release for tonal sounds
                let attack = min(progress / 0.01, 1.0)
                let release = max(1.0 - (progress - 0.7) / 0.3, 0.0)
                envelope = attack * release
            }

            // Sine wave
            let sample = sin(phase * 2.0 * .pi) * envelope * Double(volume)
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
