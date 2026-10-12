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
import AudioToolbox
import Combine
import os
import SwiftUI

final class PressedKeysModel: ObservableObject {
    @Published var keys: Set<Int> = []
}

final class AudioEngine: ObservableObject, @unchecked Sendable {
    private static let log = Logger(subsystem: "Home.Synt-swiftUI", category: "AudioEngine")
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    let reverb = ReverbEffect()
    let delay = DelayEffect()
    let dspChorus = DSPChorus()
    /// After Apple Reverb, before the mixer. Pre-gain 0, so levels under 0 dBFS stay put.
    let peakLimiter = AudioEngine.makePeakLimiter()
    /// Fixed 0.62 headroom in front of the limiter, so the limiter is truly last.
    let headroomMixer = AVAudioMixerNode()
    static let postFXHeadroom: Float = 0.62

    // Stage 4 advanced FX — disabled by default so factory sound is unchanged.
    let distortion = Distortion()
    let parametricEQL = ParametricEQ(sampleRate: 44100)
    let parametricEQR = ParametricEQ(sampleRate: 44100)
    let phaser = Phaser(sampleRate: 44100)

    @Published var isPlaying = false
    @Published var preset: SynthPreset = .defaultPreset {
        didSet { applyPreset() }
    }

    // UI Visualization. Levels live on `meters`, which ContentView does not observe.
    /// Lit keys live on their own model so a note does not redraw ContentView.
    let keyDisplay = PressedKeysModel()
    var pressedKeys: Set<Int> {
        get { keyDisplay.keys }
        set { keyDisplay.keys = newValue }
    }
    let meters = AudioMeterModel()

    var oscillator1 = Oscillator()
    var oscillator2 = Oscillator()
    var envelope = ADSREnvelope()
    var filterL = CachedBiquadFilter()
    var filterR = CachedBiquadFilter()
    var lfo = LFO()
    /// Linear gain rider in front of the waveshapers. Not the brick-wall limiter.
    let cleanBus = CleanBus()

    /// Owned engines for `.wavetable` waveform only (Stage 3). Classical shapes unchanged.
    let wavetableEngine1 = WavetableOscillator()
    let wavetableEngine2 = WavetableOscillator()

    /// UI → audio command path (SPSC). Only audio thread mutates the voice pool.
    let commandQueue = AudioCommandQueue(capacity: 1024)
    /// CoreMIDI thread → audio (SPSC). Separate ring: two producers on one SPSC ring race.
    let midiQueue = AudioCommandQueue(capacity: 1024)
    /// Audio → UI metering path. Audio writes atomics; main polls.
    let meteringState = AtomicMeteringState()
    var cancellables = Set<AnyCancellable>()

    /// Fixed voice pool — no Dictionary on the audio thread (was a multi-note glitch source).
    static let maxVoices = 32
    /// Released tails kept while other notes are still held. Older tails fast-fade.
    static let keptReleaseTails = 2
    /// At or below this, release is the pluck. Tail trimming would eat the sound.
    static let tailTrimSkipsReleaseAtOrBelow: Float = 0.20
    var voices: [ActiveNote] = Array(repeating: .inactive, count: AudioEngine.maxVoices)
    var activeVoiceCountRT: Int = 0
    /// Audio-thread note-off counter. Newer releases have a higher serial.
    var releaseSerialRT: Int = 1

    /// Offline and pre-start default. `start()` replaces this with the device rate.
    private(set) var sampleRate: Double = 44100.0
    private var graphSampleRate: Double = 44100.0
    private var isApplyingSampleRate = false
    private var configObserver: NSObjectProtocol?

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
    /// Read per sample on the render thread; never an array there.
    let rtModMatrix = RTModMatrix()
    var lastAppliedPresetID: UUID?
    var lastAppliedPresetName: String = ""

    // Portamento state (audio thread)
    var lastPlayedFrequency: Double? = nil

    /// Audio-thread performance controls. UI only pushes commands.
    var pitchBendTarget: Float = 0
    var pitchBendSmoothed: Float = 0
    var cachedPitchBendRange: Float = 2
    /// 0 keeps the preset LFO depth; CC1 adds on top, up to full depth at 127.
    var modWheel: Float = 0
    var cachedLfoDepth: Float = 0.5
    var sustainPedalDown = false
    var sustainedLo: UInt64 = 0
    var sustainedHi: UInt64 = 0

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
    /// 0.999 per sample at 44.1 kHz (~23 ms). Rescaled so the time stays put at
    /// other rates; pow(0.999, 1) is exact, so 44.1 kHz renders are unchanged.
    var smoothingCoeff: Float = 0.999
    static func smoothingCoefficient(sampleRate: Double) -> Float {
        Float(pow(0.999, 44_100.0 / max(8_000, sampleRate)))
    }
    /// Peak before the safety soft-clip (tests / gain staging).
    var lastPreClipAbs: Float = 0
    /// Previous LFO sample, used only when a row modulates LFO rate or depth.
    var lastMatrixLFO: Float = 0

    // Oscilloscope Capture (audio thread buffer → AtomicMeteringState)
    var scopeBuffer: [Float] = Array(repeating: 0.0, count: 512)
    var scopeIndex: Int = 0
    var isCapturingScope: Bool = true

    // Clock & Arpeggiator (audio-thread state)
    var clockPhase: Double = 0.0
    var samplesPerTick: Double = 0.0
    var arp = ArpeggiatorEngine()
    var heldKeysForArp = MIDIKeySet()

    /// UI publishes a pattern snapshot; the audio thread owns the clock.
    let sequencerTransport = SequencerTransport()
    var seqMirror = SequencerTransport.Mirror()

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
        setupAudioEngine()
        applyPreset()
        startMeteringPoll()
    }


    private func setupAudioSession() {
        #if os(iOS)
        do {
             let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            Self.log.error("Failed to set up audio session: \(error.localizedDescription, privacy: .public)")
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
        engine.attach(peakLimiter)
        engine.attach(headroomMixer)

        // Source → Delay → Reverb → Headroom (×0.62) → Peak Limiter → Mixer (×1).
        // Below the ceiling this is the old gain exactly; the limiter is now last,
        // so it holds ~0 dBFS instead of an unreachable −4 dBFS.
        connectPostFX(format: format)
        configurePeakLimiter()
        headroomMixer.outputVolume = Self.postFXHeadroom
        engine.mainMixerNode.outputVolume = 1

        engine.prepare()
        graphSampleRate = sampleRate
    }

    deinit {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    private static func makePeakLimiter() -> AVAudioUnitEffect {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: description)
    }

    /// Main thread only, and only while the render callback is stopped.
    private func applySampleRate(_ rate: Double, rebuildGraph: Bool) {
        guard !isApplyingSampleRate else { return }
        let rate = min(192_000, max(8_000, rate))
        isApplyingSampleRate = true
        defer { isApplyingSampleRate = false }

        let needsGraph = rebuildGraph && abs(rate - graphSampleRate) > 0.5
        // Stop the render callback BEFORE touching DSP state it reads.
        let wasRunning = needsGraph && engine.isRunning
        if wasRunning { engine.stop() }

        if abs(rate - sampleRate) > 0.5 {
            sampleRate = rate
            pushSampleRateToDSP(rate)
        }
        guard needsGraph else { return }

        reconnectGraph(sampleRate: rate)
        if wasRunning {
            try? engine.start()
        }
    }

    /// Coefficients and mip maps. Must not run from the render callback.
    private func pushSampleRateToDSP(_ rate: Double) {
        let rateF = Float(rate)
        smoothingCoeff = Self.smoothingCoefficient(sampleRate: rate)
        parametricEQL.setSampleRate(rateF)
        parametricEQR.setSampleRate(rateF)
        phaser.setSampleRate(rateF)
        dspChorus.setSampleRate(rate)
        wavetableEngine1.setSampleRate(rate)
        wavetableEngine2.setSampleRate(rate)
        oscillator1.wavetableSampleRate = rate
        oscillator2.wavetableSampleRate = rate
        cleanBus.setSampleRate(rateF)
        filterL.setSampleRate(rateF)
        filterR.setSampleRate(rateF)
    }

    private func reconnectGraph(sampleRate: Double) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let sourceNode else { return }
        engine.disconnectNodeOutput(sourceNode)
        engine.disconnectNodeOutput(delay.delay)
        engine.disconnectNodeOutput(reverb.reverb)
        engine.disconnectNodeOutput(peakLimiter)
        engine.disconnectNodeOutput(headroomMixer)
        connectPostFX(format: format)
        configurePeakLimiter()
        graphSampleRate = sampleRate
        engine.prepare()
    }

    private func installConfigurationObserver() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleEngineConfigurationChange()
        }
    }

    private func handleEngineConfigurationChange() {
        guard !isApplyingSampleRate else { return }
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard rate >= 8_000 else { return }
        let shouldRun = isPlaying
        applySampleRate(rate, rebuildGraph: true)
        guard shouldRun, !engine.isRunning else { return }
        do {
            try engine.start()
            isPlaying = true
        } catch {
            Self.log.error("Failed to restart audio engine after a device change: \(error.localizedDescription, privacy: .public)")
            isPlaying = false
        }
    }

    private func connectPostFX(format: AVAudioFormat) {
        guard let sourceNode else { return }
        engine.connect(sourceNode, to: delay.delay, format: format)
        engine.connect(delay.delay, to: reverb.reverb, format: format)
        engine.connect(reverb.reverb, to: headroomMixer, format: format)
        engine.connect(headroomMixer, to: peakLimiter, format: format)
        engine.connect(peakLimiter, to: engine.mainMixerNode, format: format)
    }

    /// Attack 1 ms, release 50 ms, pre-gain 0 dB. Ceiling is the AU's 0 dBFS.
    private func configurePeakLimiter() {
        let au = peakLimiter.audioUnit
        let params: [(AudioUnitParameterID, AudioUnitParameterValue)] = [
            (kLimiterParam_AttackTime, 0.001),
            (kLimiterParam_DecayTime, 0.050),
            (kLimiterParam_PreGain, 0),
        ]
        for (id, value) in params {
            let status = AudioUnitSetParameter(au, id, kAudioUnitScope_Global, 0, value, 0)
            if status != noErr {
                Self.log.error("Peak limiter param \(id) failed: \(status)")
            }
        }
    }


    // MARK: - Public API (non-audio / UI thread)

    func start() {
        guard !engine.isRunning else { return }
        installConfigurationObserver()
        let deviceRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if deviceRate >= 8_000 {
            applySampleRate(deviceRate, rebuildGraph: true)
        }

        do {
            try engine.start()
            isPlaying = true
        } catch {
            Self.log.error("Failed to start audio engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
        clearAllNotes()
        meters.resetDisplay()
        currentLevel = 0.0
        currentPeak = 0.0
        meteringState.setOutputLevel(0)
        meteringState.setPeakLevel(0)
    }

    func pitchBend(_ normalized: Float) {
        let bend = min(1, max(-1, normalized))
        _ = commandQueue.push(.setPitchBend(bend))
    }

    func modWheel(_ amount: Float) {
        let wheel = min(1, max(0, amount))
        _ = commandQueue.push(.setModWheel(wheel))
    }

    func sustainPedal(down: Bool) {
        _ = commandQueue.push(.setSustain(down))
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

    // MARK: - MIDI input (CoreMIDI thread only; producer of `midiQueue`)

    /// Does not read `preset`: the audio thread picks arp vs voice.
    func midiNoteOn(midiNote: Int, velocity: Float) {
        _ = midiQueue.push(.keyDown(midiNote: midiNote, velocity: velocity))
        updatePressedKeys { $0.insert(midiNote) }
    }

    func midiNoteOff(midiNote: Int) {
        _ = midiQueue.push(.keyUp(midiNote: midiNote))
        updatePressedKeys { $0.remove(midiNote) }
    }

    func midiPitchBend(_ normalized: Float) {
        _ = midiQueue.push(.setPitchBend(min(1, max(-1, normalized))))
    }

    func midiModWheel(_ amount: Float) {
        _ = midiQueue.push(.setModWheel(min(1, max(0, amount))))
    }

    func midiSustainPedal(down: Bool) {
        _ = midiQueue.push(.setSustain(down))
    }

    func clearAllNotes() {
        _ = commandQueue.push(.clearAll)
        updatePressedKeys { $0.removeAll() }
    }

    /// UI thread. Copies swing, BPM, root and the 16 steps into the lock-free snapshot.
    func updateSequencerSnapshot(
        playing: Bool,
        swing: Float,
        bpm: Float,
        rootNote: Int,
        length: Int,
        generation: UInt32,
        steps: [SequencerStep],
        gate: Float = SequencerTransport.defaultGate
    ) {
        sequencerTransport.publish(
            playing: playing,
            swing: swing,
            bpm: bpm,
            rootNote: rootNote,
            length: length,
            generation: generation,
            gate: gate,
            patternSteps: steps
        )
    }

    /// Audio → UI playhead. The view polls this at 30 Hz.
    var sequencerDisplayStep: Int { sequencerTransport.currentDisplayStep }

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

    /// Offline tests pin the render rate without touching the device graph.
    func setSampleRateForTesting(_ rate: Double) {
        applySampleRate(rate, rebuildGraph: false)
    }

    /// Rebuilds the AU graph at `rate`. Not used by the offline golden path.
    func applySampleRateForTesting(_ rate: Double, rebuildGraph: Bool) {
        applySampleRate(rate, rebuildGraph: rebuildGraph)
    }

    var graphSampleRateForTesting: Double { graphSampleRate }
    var mainMixerVolumeForTesting: Float { engine.mainMixerNode.outputVolume }

    var sourceNodeSampleRateForTesting: Double {
        sourceNode?.outputFormat(forBus: 0).sampleRate ?? 0
    }

    /// Live graph: reverb's output is the peak limiter, which feeds the mixer.
    func postFXChainForTesting() -> (
        limiterFollowsReverb: Bool,
        limiterFeedsMixer: Bool,
        limiterIsAttached: Bool,
        attack: Float,
        decay: Float,
        preGain: Float
    ) {
        let reverbToHeadroom = engine.outputConnectionPoints(for: reverb.reverb, outputBus: 0)
            .contains { $0.node === headroomMixer }
        let headroomToLimiter = engine.outputConnectionPoints(for: headroomMixer, outputBus: 0)
            .contains { $0.node === peakLimiter }
        let afterReverb = reverbToHeadroom && headroomToLimiter
        let intoMixer = engine.outputConnectionPoints(for: peakLimiter, outputBus: 0)
            .contains { $0.node === engine.mainMixerNode }
        let attached = engine.attachedNodes.contains { $0 === peakLimiter }
        var attack: AudioUnitParameterValue = -999
        var decay: AudioUnitParameterValue = -999
        var preGain: AudioUnitParameterValue = -999
        AudioUnitGetParameter(peakLimiter.audioUnit, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, &attack)
        AudioUnitGetParameter(peakLimiter.audioUnit, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, &decay)
        AudioUnitGetParameter(peakLimiter.audioUnit, kLimiterParam_PreGain, kAudioUnitScope_Global, 0, &preGain)
        return (afterReverb, intoMixer, attached, attack, decay, preGain)
    }

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
            rtModMatrix.publishedCount
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

    func voiceReleaseFlagsForTesting() -> [(
        midiNote: Int,
        isReleasing: Bool,
        fastRelease: Bool,
        releaseSerial: Int,
        envelopeValue: Float
    )] {
        var out: [(midiNote: Int, isReleasing: Bool, fastRelease: Bool, releaseSerial: Int, envelopeValue: Float)] = []
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            out.append((
                voices[i].midiNote,
                voices[i].isReleasing,
                voices[i].fastRelease,
                voices[i].releaseSerial,
                voices[i].envelopeValue
            ))
        }
        return out
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

    /// MIDI notes that are still held (not in release). Test helper, not the render path.
    func heldMIDINotesForTesting() -> Set<Int> {
        var notes = Set<Int>()
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && !voices[i].isReleasing {
                notes.insert(voices[i].midiNote)
            }
        }
        return notes
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
