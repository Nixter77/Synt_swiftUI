//
//  AudioEngine.swift
//  Synt_swiftUI
//
//  Real-time audio render path rules:
//  - No NSLock / notesLock in generateSample
//  - No DispatchQueue.main from generateSample
//  - No direct preset.<field> reads on the audio path (use caches only)
//  - Note on/off via AudioCommandQueue; metering via AtomicMeteringState + UI poll
//

import AVFoundation
import Combine
import SwiftUI

final class AudioEngine: ObservableObject, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    let reverb = ReverbEffect()
    let delay = DelayEffect()
    let dspChorus = DSPChorus()

    // Stage 4 advanced FX — disabled by default so factory sound is unchanged.
    let distortion = Distortion()
    let parametricEQL = ParametricEQ(sampleRate: 44100)
    let parametricEQR = ParametricEQ(sampleRate: 44100)
    let phaser = Phaser(sampleRate: 44100)

    @Published var isPlaying = false
    @Published var preset: SynthPreset = .defaultPreset {
        didSet { applyPreset() }
    }

    // VU Meter levels (0.0 to 1.0) — written only on main via pollMetering()
    @Published var outputLevel: Float = 0.0
    @Published var peakLevel: Float = 0.0

    // UI Visualization
    @Published var pressedKeys: Set<Int> = []
    @Published var scopeData: [Float] = Array(repeating: 0.0, count: 512)

    var oscillator1 = Oscillator()
    var oscillator2 = Oscillator()
    var envelope = ADSREnvelope()
    var filterL = CachedBiquadFilter()
    var filterR = CachedBiquadFilter()
    var lfo = LFO()
    private let limiter = Compressor(sampleRate: 44100.0)

    /// Owned engines for `.wavetable` waveform only (Stage 3). Classical shapes unchanged.
    let wavetableEngine1 = WavetableOscillator()
    let wavetableEngine2 = WavetableOscillator()

    /// UI → audio command path (SPSC). Only audio thread mutates the voice pool.
    let commandQueue = AudioCommandQueue(capacity: 1024)
    /// Audio → UI metering path. Audio writes atomics; main polls.
    let meteringState = AtomicMeteringState()
    var cancellables = Set<AnyCancellable>()

    /// Fixed voice pool — no Dictionary on the audio thread (was a multi-note glitch source).
    static let maxVoices = 32
    var voices: [ActiveNote] = Array(repeating: .inactive, count: AudioEngine.maxVoices)
    var activeVoiceCountRT: Int = 0

    let sampleRate: Double = 44100.0

    // MARK: - Cached parameters (written on applyPreset / main; read on audio path)
    var cachedOsc2Enabled: Bool = true
    var cachedFilterCutoff: Float = 5000.0
    var cachedMasterVolume: Float = 0.5
    var cachedPortamento: Float = 0.0
    var cachedUnisonVoices: Int = 1
    var cachedUnisonDetune: Float = 0.0
    var cachedUnisonSpread: Float = 0.0
    var cachedBPM: Float = 120.0
    var cachedArpMode: ArpeggiatorMode = .off
    var cachedModMatrix: [ModMatrixEntry] = []
    var lastAppliedPresetID: UUID?
    var lastAppliedPresetName: String = ""

    // Portamento state (audio thread)
    var lastPlayedFrequency: Double? = nil

    // Level metering (audio-thread accumulators → AtomicMeteringState)
    var currentLevel: Float = 0.0
    var currentPeak: Float = 0.0
    var sampleCounter: Int = 0
    let levelUpdateInterval: Int = 2048
    let levelDecay: Float = 0.95
    let peakDecay: Float = 0.9995

    // Parameter Smoothing
    var smoothedFilterCutoff: Float = 5000.0
    var smoothedMasterVolume: Float = 0.5
    let smoothingCoeff: Float = 0.999
    /// Peak before the safety soft-clip (tests / gain staging).
    var lastPreClipAbs: Float = 0

    // Oscilloscope Capture (audio thread buffer → AtomicMeteringState)
    var scopeBuffer: [Float] = Array(repeating: 0.0, count: 512)
    var scopeIndex: Int = 0
    var isCapturingScope: Bool = true

    // Clock & Arpeggiator (audio-thread state)
    var clockPhase: Double = 0.0
    var samplesPerTick: Double = 0.0
    var arp = ArpeggiatorEngine()
    var heldKeysForArp: Set<Int> = []

    // Random noise seed (also used by arp random mode)
    var noiseSeed: UInt32 = 12345

    init() {
        // Attach wavetable engines before first render (used only if waveform == .wavetable).
        oscillator1.wavetableEngine = wavetableEngine1
        oscillator1.wavetableSampleRate = sampleRate
        oscillator2.wavetableEngine = wavetableEngine2
        oscillator2.wavetableSampleRate = sampleRate

        // Stage 4 defaults: advanced FX off (keep current factory sound).
        distortion.enabled = false
        parametricEQL.enabled = false
        parametricEQR.enabled = false
        phaser.bypass = true

        setupAudioSession()
        setupLimiter()
        setupAudioEngine()
        applyPreset()
        startMeteringPoll()
    }


    private func setupLimiter() {
        // Off on the live path. limiterMode ignores threshold/attack and brick-walls
        // every extra-note crest (2 notes ok, 3rd rasps). Safety is soft-clip only.
        limiter.enabled = false
        limiter.limiterMode = false
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
             let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        #endif
    }

    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            // Drain UI→audio commands ONCE per buffer (was once per sample = underruns).
            self.processCommandQueue()

            for frame in 0..<frames {
                let (sampleL, sampleR) = self.renderOneSample()

                if ablPointer.count >= 2 {
                    let bufL = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
                    let bufR = ablPointer[1].mData?.assumingMemoryBound(to: Float.self)
                    bufL?[frame] = sampleL
                    bufR?[frame] = sampleR
                } else if ablPointer.count == 1 {
                    let buf = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = (sampleL + sampleR) * 0.5
                }
            }

            return noErr
        }

        guard let sourceNode = sourceNode else { return }

        engine.attach(sourceNode)
        engine.attach(delay.delay)
        engine.attach(reverb.reverb)

        // Audio chain: Source → Delay → Reverb → Output
        engine.connect(sourceNode, to: delay.delay, format: format)
        engine.connect(delay.delay, to: reverb.reverb, format: format)
        engine.connect(reverb.reverb, to: engine.mainMixerNode, format: format)

        // Extra headroom after Apple Delay/Reverb (they sit past our clipper).
        engine.mainMixerNode.outputVolume = 0.62

        engine.prepare()
    }


    // MARK: - Public API (non-audio / UI thread)

    func start() {
        guard !engine.isRunning else { return }

        do {
            try engine.start()
            isPlaying = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
        clearAllNotes()
        outputLevel = 0.0
        peakLevel = 0.0
        currentLevel = 0.0
        currentPeak = 0.0
        meteringState.setOutputLevel(0)
        meteringState.setPeakLevel(0)
    }

    func noteOn(midiNote: Int, velocity: Float = 1.0) {
        // Read preset only on non-audio path; push RT-safe command
        if preset.arpMode != .off {
            _ = commandQueue.push(.arpKeyDown(midiNote: midiNote))
        } else {
            _ = commandQueue.push(.noteOn(midiNote: midiNote, velocity: velocity))
        }
        updatePressedKeys { $0.insert(midiNote) }
    }

    func noteOff(midiNote: Int) {
        if preset.arpMode != .off {
            _ = commandQueue.push(.arpKeyUp(midiNote: midiNote))
        } else {
            _ = commandQueue.push(.noteOff(midiNote: midiNote))
        }
        updatePressedKeys { $0.remove(midiNote) }
    }

    func clearAllNotes() {
        _ = commandQueue.push(.clearAll)
        updatePressedKeys { $0.removeAll() }
    }

    private func updatePressedKeys(_ body: @escaping (inout Set<Int>) -> Void) {
        if Thread.isMainThread {
            body(&pressedKeys)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                body(&self.pressedKeys)
            }
        }
    }


    // MARK: - Test / diagnostic hooks (drive shipped types without AVAudioEngine)

    /// Applies current preset caches (same path as didSet). Exposed for unit tests.
    func applyPresetForTesting() {
        applyPreset()
    }

    /// Snapshot values currently held for the audio path.
    func cachedAudioParamsForTesting() -> (
        bpm: Float,
        arpMode: ArpeggiatorMode,
        osc2Enabled: Bool,
        unisonVoices: Int,
        portamento: Float,
        filterCutoff: Float,
        masterVolume: Float,
        modMatrixCount: Int
    ) {
        (
            cachedBPM,
            cachedArpMode,
            cachedOsc2Enabled,
            cachedUnisonVoices,
            cachedPortamento,
            cachedFilterCutoff,
            cachedMasterVolume,
            cachedModMatrix.count
        )
    }

    var reverbFactoryLoadCountForTesting: Int { reverb.factoryPresetLoadCount }

    /// Wrapper 0…1 (not AU percent). Crystal Lead must stay ~0.28, never 28.
    var delayFeedbackForTesting: Float { delay.feedback }
    var delayWetPercentForTesting: Float { delay.wetDryMix }

    /// Advanced FX + morph state after `applyPreset` (for factory library tests).
    func appliedAdvancedFXForTesting() -> (
        distortionEnabled: Bool,
        distortionDrive: Float,
        eqEnabled: Bool,
        eqLowGain: Float,
        phaserEnabled: Bool,
        phaserMix: Float,
        osc1Morph: Float,
        osc2Morph: Float,
        osc1Waveform: WaveformType
    ) {
        (
            distortion.enabled,
            distortion.drive,
            parametricEQL.enabled,
            parametricEQL.lowGain,
            !phaser.bypass,
            phaser.mix,
            oscillator1.wavetableMorph,
            oscillator2.wavetableMorph,
            oscillator1.waveform
        )
    }

    /// Process pending commands as the audio thread would (for unit tests).
    func processCommandsForTesting() {
        processCommandQueue()
    }

    /// Offline render of the current voice pool (no AVAudioEngine device).
    func renderFramesForTesting(_ frameCount: Int) -> (peak: Float, nanCount: Int, nearClipCount: Int) {
        let d = renderFramesDetailedForTesting(frameCount)
        return (d.peak, d.nanCount, d.nearClipCount)
    }

    func renderFramesDetailedForTesting(_ frameCount: Int) -> (
        peak: Float, nanCount: Int, nearClipCount: Int, preClipPeak: Float
    ) {
        var peak: Float = 0
        var preClipPeak: Float = 0
        var nanCount = 0
        var nearClipCount = 0
        let frames = max(0, frameCount)
        for _ in 0..<frames {
            let (left, right) = renderOneSample()
            if lastPreClipAbs > preClipPeak { preClipPeak = lastPreClipAbs }
            if !left.isFinite || !right.isFinite {
                nanCount += 1
                continue
            }
            let absSample = max(abs(left), abs(right))
            if absSample > peak { peak = absSample }
            if absSample > 0.98 { nearClipCount += 1 }
        }
        return (peak, nanCount, nearClipCount, preClipPeak)
    }

    func unisonScaleForTesting(_ midiNote: Int) -> Float {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                return voices[i].unisonScale
            }
        }
        return 0
    }

    func voiceFilterEnergyForTesting(_ midiNote: Int) -> Float {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                return voices[i].filter.energy
            }
        }
        return 0
    }

    /// Active oscillator partials (unison voices), including those in release.
    var activePartialCountForTesting: Int {
        var count = 0
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive { count += 1 }
        }
        return count
    }

    /// Partials that are still held (not in release). Chord path should stay at 1 per note.
    var heldPartialCountForTesting: Int {
        var count = 0
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && !voices[i].isReleasing { count += 1 }
        }
        return count
    }

    /// Active unique MIDI note count after command processing (audio-thread state).
    var activeNoteCountForTesting: Int {
        var seen = Set<Int>()
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive { seen.insert(voices[i].midiNote) }
        }
        return seen.count
    }

    /// Whether a note has any active voice in the fixed pool.
    func isNoteActiveForTesting(_ midiNote: Int) -> Bool {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote { return true }
        }
        return false
    }

    /// Whether every active partial for a note is releasing.
    func isNoteReleasingForTesting(_ midiNote: Int) -> Bool {
        var found = false
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                found = true
                if !voices[i].isReleasing { return false }
            }
        }
        return found
    }

    /// Expose metering state for tests (write as audio would, read as UI would).
    var meteringStateForTesting: AtomicMeteringState { meteringState }

    /// Expose command queue for full-queue / FIFO tests that need the engine instance.
    var commandQueueForTesting: AudioCommandQueue { commandQueue }

    /// Offline render metrics for golden harness (peak + RMS; no device I/O).
    /// Does not alter DSP — only aggregates samples from `renderOneSample()`.
    func renderFramesMetricsForTesting(_ frameCount: Int) -> (
        peak: Float, rms: Float, nanCount: Int, nearClipCount: Int, preClipPeak: Float
    ) {
        var peak: Float = 0
        var preClipPeak: Float = 0
        var nanCount = 0
        var nearClipCount = 0
        var sumSq: Double = 0
        var finiteFrames = 0
        let frames = max(0, frameCount)
        for _ in 0..<frames {
            let (left, right) = renderOneSample()
            if lastPreClipAbs > preClipPeak { preClipPeak = lastPreClipAbs }
            if !left.isFinite || !right.isFinite {
                nanCount += 1
                continue
            }
            let absSample = max(abs(left), abs(right))
            if absSample > peak { peak = absSample }
            if absSample > 0.98 { nearClipCount += 1 }
            // Mono-equivalent energy for RMS (avg of L/R).
            let mono = Double(left + right) * 0.5
            sumSq += mono * mono
            finiteFrames += 1
        }
        let rms: Float
        if finiteFrames > 0 {
            rms = Float(sqrt(sumSq / Double(finiteFrames)))
        } else {
            rms = 0
        }
        return (peak, rms, nanCount, nearClipCount, preClipPeak)
    }

    /// Snapshot active voice oscillators / filter z-energy for continuity goldens.
    func voiceProbesForTesting(midiNote: Int? = nil) -> [(
        midiNote: Int,
        phase: Double,
        phase2: Double,
        targetFrequency: Double,
        currentFrequency: Double,
        filterEnergy: Float,
        isReleasing: Bool,
        unisonScale: Float
    )] {
        var out: [(
            midiNote: Int,
            phase: Double,
            phase2: Double,
            targetFrequency: Double,
            currentFrequency: Double,
            filterEnergy: Float,
            isReleasing: Bool,
            unisonScale: Float
        )] = []
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            if let midiNote, voices[i].midiNote != midiNote { continue }
            out.append((
                voices[i].midiNote,
                voices[i].phase,
                voices[i].phase2,
                voices[i].targetFrequency,
                voices[i].currentFrequency,
                voices[i].filter.energy,
                voices[i].isReleasing,
                voices[i].unisonScale
            ))
        }
        return out
    }
}
