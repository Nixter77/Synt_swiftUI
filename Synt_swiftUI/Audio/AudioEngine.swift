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
    private let wavetableEngine1 = WavetableOscillator()
    private let wavetableEngine2 = WavetableOscillator()

    /// UI → audio command path (SPSC). Only audio thread mutates the voice pool.
    private let commandQueue = AudioCommandQueue(capacity: 1024)
    /// Audio → UI metering path. Audio writes atomics; main polls.
    private let meteringState = AtomicMeteringState()
    private var cancellables = Set<AnyCancellable>()

    /// Fixed voice pool — no Dictionary on the audio thread (was a multi-note glitch source).
    private static let maxVoices = 32
    private var voices: [ActiveNote] = Array(repeating: .inactive, count: AudioEngine.maxVoices)
    private var activeVoiceCountRT: Int = 0

    private let sampleRate: Double = 44100.0

    // MARK: - Cached parameters (written on applyPreset / main; read on audio path)
    private var cachedOsc2Enabled: Bool = true
    private var cachedFilterCutoff: Float = 5000.0
    private var cachedMasterVolume: Float = 0.5
    private var cachedPortamento: Float = 0.0
    private var cachedUnisonVoices: Int = 1
    private var cachedUnisonDetune: Float = 0.0
    private var cachedUnisonSpread: Float = 0.0
    private var cachedBPM: Float = 120.0
    private var cachedArpMode: ArpeggiatorMode = .off
    private var cachedModMatrix: [ModMatrixEntry] = []
    private var lastAppliedPresetID: UUID?
    private var lastAppliedPresetName: String = ""

    // Portamento state (audio thread)
    private var lastPlayedFrequency: Double? = nil

    // Level metering (audio-thread accumulators → AtomicMeteringState)
    private var currentLevel: Float = 0.0
    private var currentPeak: Float = 0.0
    private var sampleCounter: Int = 0
    private let levelUpdateInterval: Int = 2048
    private let levelDecay: Float = 0.95
    private let peakDecay: Float = 0.9995

    // Parameter Smoothing
    private var smoothedFilterCutoff: Float = 5000.0
    private var smoothedMasterVolume: Float = 0.5
    private let smoothingCoeff: Float = 0.999
    /// Peak before the safety soft-clip (tests / gain staging).
    private var lastPreClipAbs: Float = 0

    // Oscilloscope Capture (audio thread buffer → AtomicMeteringState)
    private var scopeBuffer: [Float] = Array(repeating: 0.0, count: 512)
    private var scopeIndex: Int = 0
    private var isCapturingScope: Bool = true

    // Clock & Arpeggiator (audio-thread state)
    private var clockPhase: Double = 0.0
    private var samplesPerTick: Double = 0.0
    private var arp = ArpeggiatorEngine()
    private var heldKeysForArp: Set<Int> = []

    // Random noise seed (also used by arp random mode)
    private var noiseSeed: UInt32 = 12345

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

    private func startMeteringPoll() {
        // UI-side poll — never hop to main from the render callback
        Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollMetering()
            }
            .store(in: &cancellables)
    }

    /// Main-thread only: copy atomics into @Published properties for SwiftUI.
    private func pollMetering() {
        outputLevel = meteringState.getOutputLevel()
        peakLevel = meteringState.getPeakLevel()
        scopeData = meteringState.readScopeBuffer()
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

    // MARK: - Audio thread render path

    /// One sample of synthesis. Commands must already be drained for this buffer.
    private func renderOneSample() -> (Float, Float) {
        var mixedSampleL: Float = 0.0
        var mixedSampleR: Float = 0.0

        // --- CLOCK & ARP ---
        let bpm = cachedBPM
        let samplesPerBeat = sampleRate * 60.0 / Double(max(20, bpm))
        samplesPerTick = samplesPerBeat / 4.0

        if cachedArpMode != .off {
            arp.mode = cachedArpMode
            clockPhase += 1.0
            if clockPhase >= samplesPerTick {
                clockPhase -= samplesPerTick
                handleArpTick()
            }
        } else if let n = arp.currentNote {
            internalNoteOff(midiNote: n)
            arp.currentNote = nil
        }

        let lfoValue = lfo.getValue(sampleRate: sampleRate)
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let modMatrix = cachedModMatrix

        noiseSeed = noiseSeed &* 1664525 &+ 1013904223
        let noiseValue = Float(noiseSeed) / Float(UInt32.max) * 2.0 - 1.0

        if oscillator1.waveform == .wavetable {
            wavetableEngine1.targetFramePosition = max(0, min(1, oscillator1.wavetableMorph))
            wavetableEngine1.advanceMorph()
        }
        if oscillator2.waveform == .wavetable {
            wavetableEngine2.targetFramePosition = max(0, min(1, oscillator2.wavetableMorph))
            wavetableEngine2.advanceMorph()
        }

        smoothedFilterCutoff = smoothedFilterCutoff * smoothingCoeff + cachedFilterCutoff * (1 - smoothingCoeff)
        smoothedMasterVolume = smoothedMasterVolume * smoothingCoeff + cachedMasterVolume * (1 - smoothingCoeff)
        var cutoff = smoothedFilterCutoff
        if lfoEnabled && lfoTarget == .filter {
            cutoff = lfo.modulateFilter(cutoff, lfoValue: lfoValue)
        }
        filterL.cutoff = cutoff
        let filterCoeffs = filterL.currentCoefficients(sampleRate: Float(sampleRate))

        // Fixed pool scan — work on a local copy to satisfy exclusivity + keep RT simple.
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            var v = voices[i]

            if cachedPortamento > 0.001 {
                let glideRate = 1.0 - exp(-5.0 / (Double(cachedPortamento) * sampleRate))
                v.currentFrequency += (v.targetFrequency - v.currentFrequency) * glideRate
                if abs(v.currentFrequency - v.targetFrequency) < 0.1 {
                    v.currentFrequency = v.targetFrequency
                }
            } else {
                v.currentFrequency = v.targetFrequency
            }

            let baseFrequency = v.currentFrequency
            var osc1Freq = oscillator1.frequencyWithModifiers(baseFrequency)
            var osc2Freq = oscillator2.frequencyWithModifiers(baseFrequency)
            let velValue = v.velocity

            let releaseOverride: Float? = v.fastRelease ? ADSREnvelope.fastReleaseSeconds : nil
            let envelopeValue = envelope.process(
                currentValue: v.envelopeValue,
                phase: &v.envelopePhase,
                time: &v.envelopeTime,
                releaseStartValue: v.releaseStartValue,
                isReleasing: v.isReleasing,
                sampleRate: sampleRate,
                releaseOverride: releaseOverride
            )
            v.envelopeValue = envelopeValue

            var pitchMod1: Float = 0
            var pitchMod2: Float = 0
            var ampMod: Float = 0
            var panMod: Float = 0

            if !modMatrix.isEmpty {
                for entry in modMatrix {
                    let sourceVal: Float
                    switch entry.source {
                    case .lfo1: sourceVal = lfoValue
                    case .env1: sourceVal = envelopeValue
                    case .velocity: sourceVal = velValue
                    }
                    let modVal = sourceVal * entry.amount
                    switch entry.destination {
                    case .pitch1: pitchMod1 += modVal
                    case .pitch2: pitchMod2 += modVal
                    case .amp: ampMod += modVal
                    case .pan: panMod += modVal
                    default: break
                    }
                }
            }

            if pitchMod1 != 0 {
                osc1Freq *= pow(2.0, Double(max(-2, min(2, pitchMod1))))
            }
            if pitchMod2 != 0 {
                osc2Freq *= pow(2.0, Double(max(-2, min(2, pitchMod2))))
            }

            if lfoEnabled && lfoTarget == .pitch {
                let mod = Double(max(-1, min(1, lfoValue)))
                if mod != 0 {
                    let mul = pow(2.0, mod)
                    osc1Freq *= mul
                    osc2Freq *= mul
                }
            }

            osc1Freq = max(20.0, min(sampleRate * 0.45, osc1Freq))
            osc2Freq = max(20.0, min(sampleRate * 0.45, osc2Freq))

            let phaseInc1 = AudioMath.twoPi * osc1Freq / sampleRate
            let phaseInc2 = AudioMath.twoPi * osc2Freq / sampleRate

            var sample = oscillator1.generateSample(
                phase: v.phase,
                phaseIncrement: phaseInc1,
                noiseValue: noiseValue
            )
            if cachedOsc2Enabled {
                let s2 = oscillator2.generateSample(
                    phase: v.phase2,
                    phaseIncrement: phaseInc2,
                    noiseValue: noiseValue
                )
                sample = (sample + s2) * 0.5
            }

            v.phase += phaseInc1
            v.phase2 += phaseInc2
            if v.phase >= AudioMath.twoPi { v.phase -= AudioMath.twoPi }
            if v.phase < 0 { v.phase += AudioMath.twoPi }
            if v.phase2 >= AudioMath.twoPi { v.phase2 -= AudioMath.twoPi }
            if v.phase2 < 0 { v.phase2 += AudioMath.twoPi }

            var amplitude = sample * envelopeValue * max(0.15, min(1.0, velValue))
            amplitude *= max(0.0, 1.0 + ampMod)
            amplitude *= AudioMath.voiceGain * v.unisonScale
            if lfoEnabled && lfoTarget == .amplitude {
                amplitude = lfo.modulateAmplitude(amplitude, lfoValue: lfoValue)
            }
            if !amplitude.isFinite { amplitude = 0 }
            amplitude = v.filter.process(amplitude, coeffs: filterCoeffs)
            if !amplitude.isFinite { amplitude = 0 }

            var pan = v.pan + panMod
            if lfoEnabled && lfoTarget == .pan { pan += lfoValue }
            pan = max(-1, min(1, pan))
            let angle = (pan + 1.0) * Float.pi / 4.0

            mixedSampleL += amplitude * cos(angle)
            mixedSampleR += amplitude * sin(angle)

            if v.envelopePhase == .finished {
                v.deactivate()
                activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            }
            voices[i] = v
        }

        if !mixedSampleL.isFinite { mixedSampleL = 0 }
        if !mixedSampleR.isFinite { mixedSampleR = 0 }

        let headroom: Float = 0.65
        var fxL = mixedSampleL * smoothedMasterVolume * headroom
        var fxR = mixedSampleR * smoothedMasterVolume * headroom

        if distortion.enabled {
            (fxL, fxR) = distortion.processStereo(inputL: fxL, inputR: fxR)
        }
        if parametricEQL.enabled {
            if !parametricEQR.enabled { parametricEQR.enabled = true }
            fxL = parametricEQL.process(fxL)
            fxR = parametricEQR.process(fxR)
        }
        if !phaser.bypass {
            let p = phaser.process(inputL: fxL, inputR: fxR)
            fxL = p.left
            fxR = p.right
        }

        var (outL, outR) = dspChorus.process(inputL: fxL, inputR: fxR)

        if lfoEnabled && lfoTarget == .pan {
            let panVal = max(-1, min(1, lfoValue))
            let a = (panVal + 1) * Float.pi / 4
            outL *= cos(a)
            outR *= sin(a)
        }

        lastPreClipAbs = max(abs(outL), abs(outR))
        outL = AudioMath.softClip(outL, threshold: 0.95)
        outR = AudioMath.softClip(outR, threshold: 0.95)

        let absSample = max(abs(outL), abs(outR))
        currentLevel = max(currentLevel * levelDecay, absSample)
        if absSample > currentPeak { currentPeak = absSample }
        else { currentPeak *= peakDecay }

        sampleCounter += 1
        if sampleCounter >= levelUpdateInterval {
            sampleCounter = 0
            meteringState.setOutputLevel(min(currentLevel * 2, 1))
            meteringState.setPeakLevel(min(currentPeak * 2, 1))
        }

        if isCapturingScope {
            scopeBuffer[scopeIndex] = (outL + outR) * 0.5
            scopeIndex += 1
            if scopeIndex >= scopeBuffer.count {
                scopeIndex = 0
                meteringState.writeScopeBuffer(scopeBuffer)
            }
        }

        if !outL.isFinite { outL = 0 }
        if !outR.isFinite { outR = 0 }
        return (outL, outR)
    }

    private func processCommandQueue() {
        commandQueue.drain(limit: 128) { [self] command in
            switch command {
            case .noteOn(let midiNote, let velocity):
                createVoice(midiNote: midiNote, velocity: velocity)
            case .noteOff(let midiNote):
                internalNoteOff(midiNote: midiNote)
            case .clearAll:
                clearAllVoices()
                heldKeysForArp.removeAll()
                arp.reset()
                filterL.reset()
                filterR.reset()
                lfo.reset()
            case .arpKeyDown(let midiNote):
                heldKeysForArp.insert(midiNote)
                arp.mode = cachedArpMode
                arp.setHeldKeys(heldKeysForArp)
            case .arpKeyUp(let midiNote):
                heldKeysForArp.remove(midiNote)
                arp.mode = cachedArpMode
                arp.setHeldKeys(heldKeysForArp)
            }
        }
    }

    private func handleArpTick() {
        if let oldNote = arp.currentNote {
            internalNoteOff(midiNote: oldNote)
        }

        guard let newNote = arp.advanceTick(randomSource: &noiseSeed) else {
            return
        }
        createVoice(midiNote: newNote, velocity: 0.8)
    }

    private func clearAllVoices() {
        for i in 0..<AudioEngine.maxVoices {
            voices[i].deactivate()
        }
        activeVoiceCountRT = 0
        lastPlayedFrequency = nil
    }

    /// Fixed-pool allocation (audio thread). No Dictionary / heap ids.
    private func createVoice(midiNote: Int, velocity: Float) {
        // Soft re-trigger: fade previous partials of this MIDI note (hard kill = click).
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                voices[i].beginFastRelease()
            }
        }

        let baseFreq = AudioMath.midiToFrequency(midiNote)
        let startFreq: Double
        if activeVoiceCountRT == 0 || cachedPortamento <= 0.001 {
            startFreq = baseFreq
        } else {
            startFreq = lastPlayedFrequency ?? baseFreq
        }
        lastPlayedFrequency = baseFreq

        // Unison only for a single held note. Any second key collapses to 1 partial
        // per note so a 3–4 note chord does not spawn extra oscillators.
        let otherNotes = uniqueActiveMIDINoteCountExcluding(midiNote: midiNote)
        if otherNotes >= 1 {
            collapseExtraUnisonPartials()
        }
        let requested = max(1, min(5, cachedUnisonVoices))
        let unisonCount = otherNotes >= 1 ? 1 : min(3, requested)

        let detuneAmount = cachedUnisonDetune
        let spreadAmount = cachedUnisonSpread
        let partialScale = AudioMath.unisonScale(partials: unisonCount)

        for u in 0..<unisonCount {
            guard let slot = findFreeVoiceSlot() else { break }

            let targetFreq: Double
            let curFreq: Double
            let pan: Float
            if unisonCount <= 1 {
                targetFreq = baseFreq
                curFreq = startFreq
                pan = 0
            } else {
                let centerOffset = Float(u) - Float(unisonCount - 1) / 2.0
                let detuneCents = centerOffset * detuneAmount
                targetFreq = AudioMath.detuneFrequency(baseFreq, cents: detuneCents)
                curFreq = AudioMath.detuneFrequency(startFreq, cents: detuneCents)
                let panPos = (Float(u) / Float(unisonCount - 1)) * 2.0 - 1.0
                pan = panPos * spreadAmount
            }

            voices[slot].activate(
                midiNote: midiNote,
                velocity: velocity,
                frequency: curFreq,
                pan: pan,
                unisonScale: partialScale
            )
            voices[slot].targetFrequency = targetFreq
            voices[slot].currentFrequency = curFreq
            activeVoiceCountRT += 1
        }
    }

    /// Fade extra unison partials so each MIDI note keeps one sounding voice.
    private func collapseExtraUnisonPartials() {
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive, !voices[i].isReleasing else { continue }
            for j in (i + 1)..<AudioEngine.maxVoices {
                guard voices[j].isActive, !voices[j].isReleasing else { continue }
                guard voices[j].midiNote == voices[i].midiNote else { continue }
                if voices[j].envelopeValue > voices[i].envelopeValue {
                    voices[i].beginFastRelease()
                    voices[j].unisonScale = 1
                } else {
                    voices[j].beginFastRelease()
                    voices[i].unisonScale = 1
                }
            }
        }
    }

    private func uniqueActiveMIDINoteCountExcluding(midiNote: Int) -> Int {
        var lo: UInt64 = 0
        var hi: UInt64 = 0
        var count = 0
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            let n = voices[i].midiNote
            if n == midiNote { continue }
            if n >= 0 && n < 64 {
                let bit: UInt64 = 1 << n
                if lo & bit == 0 { lo |= bit; count += 1 }
            } else if n >= 64 && n < 128 {
                let bit: UInt64 = 1 << (n - 64)
                if hi & bit == 0 { hi |= bit; count += 1 }
            }
        }
        return count
    }

    private func findFreeVoiceSlot() -> Int? {
        for i in 0..<AudioEngine.maxVoices {
            if !voices[i].isActive { return i }
        }
        // Prefer reclaiming almost-silent / fast-releasing voices
        var quietRelease: Int?
        var quietEnv: Float = 0.05
        var bestSteal: Int?
        var bestStealEnv: Float = Float.greatestFiniteMagnitude
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            let env = voices[i].envelopeValue
            if voices[i].isReleasing && env < quietEnv {
                quietEnv = env
                quietRelease = i
            }
            if env < bestStealEnv {
                bestStealEnv = env
                bestSteal = i
            }
        }
        if let quietRelease {
            voices[quietRelease].deactivate()
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return quietRelease
        }
        // Soft-steal: start 6 ms fade; try to find another free after... we need a slot now.
        // Deactivate only if already very quiet; otherwise force-fade and take quietest.
        if let bestSteal, bestStealEnv < 0.08 {
            voices[bestSteal].deactivate()
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return bestSteal
        }
        if let bestSteal {
            // Last resort hard take after starting fade was not enough — take quietest
            voices[bestSteal].deactivate()
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return bestSteal
        }
        return nil
    }

    private func internalNoteOff(midiNote: Int) {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                voices[i].isReleasing = true
                voices[i].releaseStartValue = voices[i].envelopeValue
                voices[i].envelopePhase = .release
                voices[i].envelopeTime = 0
            }
        }
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

    private func applyPreset() {
        oscillator1.waveform = preset.osc1Waveform
        oscillator1.volume = preset.osc1Volume
        oscillator1.octave = preset.osc1Octave
        oscillator1.detune = preset.osc1Detune
        oscillator1.pulseWidth = preset.osc1PulseWidth
        oscillator1.wavetableMorph = max(0, min(1, preset.osc1WavetableMorph))

        oscillator2.waveform = preset.osc2Waveform
        oscillator2.volume = preset.osc2Volume
        oscillator2.octave = preset.osc2Octave
        oscillator2.detune = preset.osc2Detune
        oscillator2.pulseWidth = preset.osc2PulseWidth
        oscillator2.wavetableMorph = max(0, min(1, preset.osc2WavetableMorph))

        envelope.attack = preset.attack
        envelope.decay = preset.decay
        envelope.sustain = preset.sustain
        envelope.release = preset.release

        filterL.type = preset.filterType
        filterR.type = preset.filterType
        filterL.cutoff = preset.filterCutoff
        filterR.cutoff = preset.filterCutoff
        filterL.resonance = preset.filterResonance
        filterR.resonance = preset.filterResonance

        lfo.enabled = preset.lfoEnabled
        lfo.rate = preset.lfoRate
        lfo.depth = preset.lfoDepth
        lfo.waveform = preset.lfoWaveform
        lfo.target = preset.lfoTarget

        reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
        reverb.setRoomSize(preset.reverbRoomSize)

        dspChorus.rate = preset.chorusRate
        dspChorus.depth = preset.chorusDepth
        dspChorus.mix = preset.chorusMix

        delay.delayTime = preset.delayTime
        // Preset / knob are 0…1. DelayEffect converts to AU percent.
        // The old `* 100` wrote 28 into a 0…1 wrapper → AU 2800% → clamp 100%
        // → Crystal Lead (and any wet delay) never decayed after noteOff.
        delay.feedback = max(0, min(1, preset.delayFeedback))
        delay.wetDryMix = AudioMath.appleFXWetPercent(preset.delayMix)

        // Advanced FX (Stage 4) — loadable with factory / user presets
        distortion.enabled = preset.distortionEnabled
        distortion.type = preset.distortionType
        distortion.drive = preset.distortionDrive
        distortion.tone = preset.distortionTone
        distortion.mix = preset.distortionMix

        parametricEQL.enabled = preset.eqEnabled
        parametricEQR.enabled = preset.eqEnabled
        parametricEQL.lowGain = preset.eqLowGain
        parametricEQR.lowGain = preset.eqLowGain
        parametricEQL.lowFreq = preset.eqLowFreq
        parametricEQR.lowFreq = preset.eqLowFreq
        parametricEQL.midGain = preset.eqMidGain
        parametricEQR.midGain = preset.eqMidGain
        parametricEQL.midFreq = preset.eqMidFreq
        parametricEQR.midFreq = preset.eqMidFreq
        parametricEQL.midQ = preset.eqMidQ
        parametricEQR.midQ = preset.eqMidQ
        parametricEQL.highGain = preset.eqHighGain
        parametricEQR.highGain = preset.eqHighGain
        parametricEQL.highFreq = preset.eqHighFreq
        parametricEQR.highFreq = preset.eqHighFreq

        phaser.bypass = !preset.phaserEnabled
        phaser.mode = preset.phaserMode
        phaser.rate = preset.phaserRate
        phaser.depth = preset.phaserDepth
        phaser.feedback = preset.phaserFeedback
        phaser.centerFrequency = preset.phaserCenterFrequency
        phaser.stereoSpread = preset.phaserStereoSpread
        phaser.mix = preset.phaserMix

        // Snapshot all parameters the audio path needs
        cachedPortamento = preset.portamento
        cachedUnisonVoices = preset.unisonVoices
        cachedUnisonDetune = preset.unisonDetune
        cachedUnisonSpread = preset.unisonSpread
        cachedModMatrix = preset.modMatrix
        cachedOsc2Enabled = preset.osc2Enabled
        cachedFilterCutoff = preset.filterCutoff
        cachedMasterVolume = preset.masterVolume
        cachedBPM = preset.bpm
        cachedArpMode = preset.arpMode
        // Do NOT touch `arp` here — it is audio-thread state.
        // generateSample / processCommandQueue apply cachedArpMode on the audio path.

        let switchedPatch = lastAppliedPresetID != nil
            && (lastAppliedPresetID != preset.id || lastAppliedPresetName != preset.name)
        lastAppliedPresetID = preset.id
        lastAppliedPresetName = preset.name
        if switchedPatch {
            silenceForPresetChange()
        }
    }

    func loadPreset(_ preset: SynthPreset) {
        self.preset = preset
    }

    /// New factory/user patch: stop leftover voices and wipe Delay/Reverb tails.
    /// Knob edits keep the same id/name and must not cut the note.
    private func silenceForPresetChange() {
        clearAllNotes()
        filterL.reset()
        filterR.reset()
        dspChorus.reset()
        distortion.reset()
        parametricEQL.reset()
        parametricEQR.reset()
        phaser.reset()
        lfo.reset()
        delay.reset()
        reverb.reset()
        smoothedFilterCutoff = cachedFilterCutoff
        smoothedMasterVolume = cachedMasterVolume
        lastPlayedFrequency = nil
    }

    /// Mutate the published preset as a whole so `didSet` → `applyPreset()` always runs.
    /// UI must use this (or assign `preset = …`) for advanced FX / morph — never write
    /// only to live `distortion` / `phaser` / oscillator morph and leave `preset` stale.
    func updatePreset(_ body: (inout SynthPreset) -> Void) {
        var next = preset
        body(&next)
        preset = next
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
}
