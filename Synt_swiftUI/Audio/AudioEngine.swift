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

    /// UI → audio command path (SPSC). Only audio thread mutates activeNotes.
    private let commandQueue = AudioCommandQueue(capacity: 1024)
    /// Audio → UI metering path. Audio writes atomics; main polls.
    private let meteringState = AtomicMeteringState()
    private var cancellables = Set<AnyCancellable>()

    /// Active notes: audio-thread only after command drain (no lock).
    private var activeNotes: [Int: [ActiveNote]] = [:]

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
        limiter.enabled = true
        limiter.limiterMode = true
        limiter.threshold = -0.1
        limiter.kneeWidth = 0.0
        limiter.setAttack(0.001)
        limiter.setRelease(0.05)
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

            for frame in 0..<Int(frameCount) {
                let (sampleL, sampleR) = self.generateSample()

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

        // Audio chain: Source (with Chorus) → Delay → Reverb → Output
        engine.connect(sourceNode, to: delay.delay, format: format)
        engine.connect(delay.delay, to: reverb.reverb, format: format)
        engine.connect(reverb.reverb, to: engine.mainMixerNode, format: format)

        engine.prepare()
    }

    // MARK: - Audio thread render path

    private func generateSample() -> (Float, Float) {
        // Drain UI commands first (only mutator of activeNotes / arp held keys)
        processCommandQueue()

        var mixedSampleL: Float = 0.0
        var mixedSampleR: Float = 0.0
        var notesToRemove: [Int] = []

        // --- CLOCK & ARP PROCESSING (cached BPM / mode only) ---
        let bpm = cachedBPM
        let ticksPerBeat = 4.0 // 16th notes
        let samplesPerBeat = sampleRate * 60.0 / Double(max(20, bpm))
        samplesPerTick = samplesPerBeat / ticksPerBeat

        if cachedArpMode != .off {
            arp.mode = cachedArpMode
            clockPhase += 1.0
            if clockPhase >= samplesPerTick {
                clockPhase -= samplesPerTick
                handleArpTick()
            }
        } else {
            if let n = arp.currentNote {
                internalNoteOff(midiNote: n)
                arp.currentNote = nil
            }
        }

        let lfoValue = lfo.getValue(sampleRate: sampleRate)
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let modMatrix = cachedModMatrix

        // Fast Random Noise Generation
        noiseSeed = noiseSeed &* 1664525 &+ 1013904223
        let noiseValue = Float(noiseSeed) / Float(UInt32.max) * 2.0 - 1.0

        for (midiNote, var notes) in activeNotes {
            var allNotesEnded = true

            for i in 0..<notes.count {
                var activeNote = notes[i]

                let targetFrequency = activeNote.targetFrequency

                // Portamento / Glide Update
                if cachedPortamento > 0.001 {
                    let glideRate = 1.0 - exp(-5.0 / (Double(cachedPortamento) * sampleRate))
                    activeNote.currentFrequency += (targetFrequency - activeNote.currentFrequency) * glideRate

                    if abs(activeNote.currentFrequency - targetFrequency) < 0.1 {
                        activeNote.currentFrequency = targetFrequency
                    }
                } else {
                    activeNote.currentFrequency = targetFrequency
                }

                let baseFrequency = activeNote.currentFrequency
                var osc1Freq = oscillator1.frequencyWithModifiers(baseFrequency)
                var osc2Freq = oscillator2.frequencyWithModifiers(baseFrequency)

                let velValue = activeNote.velocity

                let envelopeValue = envelope.process(
                    currentValue: activeNote.envelopeValue,
                    phase: &activeNote.envelopePhase,
                    time: &activeNote.envelopeTime,
                    releaseStartValue: activeNote.releaseStartValue,
                    isReleasing: activeNote.isReleasing,
                    sampleRate: sampleRate
                )
                activeNote.envelopeValue = envelopeValue

                var pitchMod1: Float = 0.0
                var pitchMod2: Float = 0.0
                var ampMod: Float = 0.0
                var panMod: Float = 0.0

                for entry in modMatrix {
                    var sourceVal: Float = 0.0
                    switch entry.source {
                    case .lfo1: sourceVal = lfoValue
                    case .env1: sourceVal = envelopeValue
                    case .velocity: sourceVal = velValue
                    }

                    let modVal = sourceVal * entry.amount

                    switch entry.destination {
                    case .pitch1:  pitchMod1 += modVal
                    case .pitch2:  pitchMod2 += modVal
                    case .cutoff:  break
                    case .amp:     ampMod += modVal
                    case .pan:     panMod += modVal
                    default: break
                    }
                }

                osc1Freq *= pow(2.0, Double(pitchMod1))
                osc2Freq *= pow(2.0, Double(pitchMod2))

                if lfoEnabled && lfoTarget == .pitch {
                    let mod = lfoValue
                    osc1Freq *= pow(2.0, Double(mod))
                    osc2Freq *= pow(2.0, Double(mod))
                }

                let phaseIncrement1 = AudioMath.twoPi * osc1Freq / sampleRate
                let phaseIncrement2 = AudioMath.twoPi * osc2Freq / sampleRate

                var sample = oscillator1.generateSample(phase: activeNote.phase, phaseIncrement: phaseIncrement1, noiseValue: noiseValue)

                if cachedOsc2Enabled {
                    let osc2Sample = oscillator2.generateSample(phase: activeNote.phase2, phaseIncrement: phaseIncrement2, noiseValue: noiseValue)
                    sample = (sample + osc2Sample) * 0.5
                }

                activeNote.phase += phaseIncrement1
                activeNote.phase2 += phaseIncrement2

                if activeNote.phase >= AudioMath.twoPi { activeNote.phase -= AudioMath.twoPi }
                if activeNote.phase2 >= AudioMath.twoPi { activeNote.phase2 -= AudioMath.twoPi }

                let unisonScale = 1.0 / sqrt(Double(max(1, cachedUnisonVoices)))
                var amplitude = sample * envelopeValue * Float(unisonScale)

                amplitude *= max(0.0, 1.0 + ampMod)

                if lfoEnabled && lfoTarget == .amplitude {
                    amplitude = lfo.modulateAmplitude(amplitude, lfoValue: lfoValue)
                }

                var pan = activeNote.pan
                pan += panMod

                if lfoEnabled && lfoTarget == .pan {
                    pan += lfoValue
                }

                pan = max(-1.0, min(1.0, pan))

                if activeNote.envelopePhase != .finished {
                    allNotesEnded = false
                }
                notes[i] = activeNote

                let angle = (pan + 1.0) * Float.pi / 4.0
                let gainL = cos(angle)
                let gainR = sin(angle)

                mixedSampleL += amplitude * gainL
                mixedSampleR += amplitude * gainR
            }

            if allNotesEnded {
                notesToRemove.append(midiNote)
            } else {
                activeNotes[midiNote] = notes
            }
        }

        for midiNote in notesToRemove {
            activeNotes.removeValue(forKey: midiNote)
        }

        smoothedFilterCutoff = smoothedFilterCutoff * smoothingCoeff + cachedFilterCutoff * (1.0 - smoothingCoeff)
        smoothedMasterVolume = smoothedMasterVolume * smoothingCoeff + cachedMasterVolume * (1.0 - smoothingCoeff)

        var cutoff = smoothedFilterCutoff
        if lfoEnabled && lfoTarget == .filter {
            cutoff = lfo.modulateFilter(cutoff, lfoValue: lfoValue)
        }
        filterL.cutoff = cutoff
        filterR.cutoff = cutoff

        let filteredSampleL = filterL.process(mixedSampleL, sampleRate: Float(sampleRate))
        let filteredSampleR = filterR.process(mixedSampleR, sampleRate: Float(sampleRate))
        let finalSampleL = filteredSampleL * smoothedMasterVolume
        let finalSampleR = filteredSampleR * smoothedMasterVolume

        var (chorusL, chorusR) = dspChorus.process(inputL: finalSampleL, inputR: finalSampleR)

        if lfoEnabled && lfoTarget == .pan {
            let panVal = max(-1.0, min(1.0, lfoValue))
            let angle = (panVal + 1.0) * Float.pi / 4.0
            chorusL *= cos(angle)
            chorusR *= sin(angle)
        }

        (chorusL, chorusR) = limiter.processStereo(inputL: chorusL, inputR: chorusR)

        // Level metering → atomics only (no main-queue hop)
        let absSample = max(abs(chorusL), abs(chorusR))
        currentLevel = max(currentLevel * levelDecay, absSample)
        if absSample > currentPeak {
            currentPeak = absSample
        } else {
            currentPeak *= peakDecay
        }

        sampleCounter += 1
        if sampleCounter >= levelUpdateInterval {
            sampleCounter = 0
            let level = min(currentLevel * 2.0, 1.0)
            let peak = min(currentPeak * 2.0, 1.0)
            meteringState.setOutputLevel(level)
            meteringState.setPeakLevel(peak)
        }

        if isCapturingScope {
            let monoOut = (chorusL + chorusR) * 0.5
            scopeBuffer[scopeIndex] = monoOut
            scopeIndex += 1

            if scopeIndex >= scopeBuffer.count {
                scopeIndex = 0
                meteringState.writeScopeBuffer(scopeBuffer)
            }
        }

        chorusL = max(-1.0, min(1.0, chorusL))
        chorusR = max(-1.0, min(1.0, chorusR))

        return (chorusL, chorusR)
    }

    private func processCommandQueue() {
        commandQueue.drain(limit: 128) { [self] command in
            switch command {
            case .noteOn(let midiNote, let velocity):
                createVoice(midiNote: midiNote, velocity: velocity)
            case .noteOff(let midiNote):
                internalNoteOff(midiNote: midiNote)
            case .clearAll:
                activeNotes.removeAll()
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

    /// Audio-thread voice allocation using cached unison/portamento only.
    private func createVoice(midiNote: Int, velocity: Float) {
        if activeNotes[midiNote] != nil {
            activeNotes.removeValue(forKey: midiNote)
        }

        let note = Note(midiNote: midiNote)

        let startFreq: Double
        if activeNotes.isEmpty {
            startFreq = note.frequency
        } else {
            startFreq = cachedPortamento > 0 ? (lastPlayedFrequency ?? note.frequency) : note.frequency
        }
        lastPlayedFrequency = note.frequency

        let voices = cachedUnisonVoices
        let detuneAmount = cachedUnisonDetune
        let spreadAmount = cachedUnisonSpread

        var newNotes: [ActiveNote] = []

        if voices <= 1 {
            var activeNote = ActiveNote(note: note, velocity: velocity)
            activeNote.currentFrequency = startFreq
            activeNote.targetFrequency = note.frequency
            activeNote.pan = 0.0
            newNotes.append(activeNote)
        } else {
            for i in 0..<voices {
                var activeNote = ActiveNote(note: note, velocity: velocity)
                let centerOffset = Float(i) - Float(voices - 1) / 2.0
                let detuneCents = centerOffset * detuneAmount
                let targetDetuned = AudioMath.detuneFrequency(note.frequency, cents: detuneCents)
                let startDetuned = AudioMath.detuneFrequency(startFreq, cents: detuneCents)
                activeNote.currentFrequency = startDetuned
                activeNote.targetFrequency = targetDetuned
                if voices > 1 {
                    let panPos = (Float(i) / Float(voices - 1)) * 2.0 - 1.0
                    activeNote.pan = panPos * spreadAmount
                }
                newNotes.append(activeNote)
            }
        }
        activeNotes[midiNote] = newNotes
    }

    private func internalNoteOff(midiNote: Int) {
        if var notes = activeNotes[midiNote] {
            for i in 0..<notes.count {
                notes[i].isReleasing = true
                notes[i].releaseStartValue = notes[i].envelopeValue
            }
            activeNotes[midiNote] = notes
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

        oscillator2.waveform = preset.osc2Waveform
        oscillator2.volume = preset.osc2Volume
        oscillator2.octave = preset.osc2Octave
        oscillator2.detune = preset.osc2Detune
        oscillator2.pulseWidth = preset.osc2PulseWidth

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

        reverb.wetDryMix = preset.reverbMix * 100
        reverb.setRoomSize(preset.reverbRoomSize)

        dspChorus.rate = preset.chorusRate
        dspChorus.depth = preset.chorusDepth
        dspChorus.mix = preset.chorusMix

        delay.delayTime = preset.delayTime
        delay.feedback = preset.delayFeedback
        delay.wetDryMix = preset.delayMix * 100

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
    }

    func loadPreset(_ preset: SynthPreset) {
        self.preset = preset
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

    /// Process pending commands as the audio thread would (for unit tests).
    func processCommandsForTesting() {
        processCommandQueue()
    }

    /// Active note count after command processing (audio-thread state).
    var activeNoteCountForTesting: Int {
        activeNotes.count
    }

    /// Whether a note key is present in the active voice map.
    func isNoteActiveForTesting(_ midiNote: Int) -> Bool {
        activeNotes[midiNote] != nil
    }

    /// Whether a note is in release after noteOff was processed.
    func isNoteReleasingForTesting(_ midiNote: Int) -> Bool {
        guard let notes = activeNotes[midiNote] else { return false }
        return notes.allSatisfy { $0.isReleasing }
    }

    /// Expose metering state for tests (write as audio would, read as UI would).
    var meteringStateForTesting: AtomicMeteringState { meteringState }

    /// Expose command queue for full-queue / FIFO tests that need the engine instance.
    var commandQueueForTesting: AudioCommandQueue { commandQueue }
}
