//
//  AudioEngine.swift
//  Synt_swiftUI
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

    // VU Meter levels (0.0 to 1.0)
    @Published var outputLevel: Float = 0.0
    @Published var peakLevel: Float = 0.0
    
    // UI Visualization
    @Published var pressedKeys: Set<Int> = []

    var oscillator1 = Oscillator()
    var oscillator2 = Oscillator()
    var envelope = ADSREnvelope()
    var filterL = CachedBiquadFilter()
    var filterR = CachedBiquadFilter()
    var lfo = LFO()
    private let limiter = Compressor(sampleRate: 44100.0)
    private let commandQueue = AudioCommandQueue(capacity: 1024)

    private var activeNotes: [Int: [ActiveNote]] = [:] // Key: MIDI Note, Value: Array of unison voices
    private let notesLock = NSLock()

    private let sampleRate: Double = 44100.0

    private var cachedOsc2Enabled: Bool = true
    private var cachedFilterCutoff: Float = 5000.0
    private var cachedMasterVolume: Float = 0.5
    private var cachedPortamento: Float = 0.0
    private var cachedUnisonVoices: Int = 1
    private var cachedUnisonDetune: Float = 0.0
    private var cachedUnisonSpread: Float = 0.0
    private var cachedBPM: Float = 120.0
    private var cachedArpMode: ArpeggiatorMode = .off
    
    // Mod Matrix Cache
    private var cachedModMatrix: [ModMatrixEntry] = []
    
    // Portamento state
    private var lastPlayedFrequency: Double? = nil

    // Level metering
    private var currentLevel: Float = 0.0
    private var currentPeak: Float = 0.0
    private var sampleCounter: Int = 0
    private let levelUpdateInterval: Int = 2048  // Update UI every N samples
    private let levelDecay: Float = 0.95
    private let peakDecay: Float = 0.9995

    // Parameter Smoothing
    private var smoothedFilterCutoff: Float = 5000.0
    private var smoothedMasterVolume: Float = 0.5
    private let smoothingCoeff: Float = 0.999
    
    // Oscilloscope Capture
    @Published var scopeData: [Float] = Array(repeating: 0.0, count: 512)
    private var scopeBuffer: [Float] = Array(repeating: 0.0, count: 512)
    private var scopeIndex: Int = 0
    private let scopeUpdateInterval: Int = 5 
    private var isCapturingScope: Bool = true

    // Clock & Arpeggiator
    private var clockPhase: Double = 0.0
    private var samplesPerTick: Double = 0.0
    private var currentTick: Int = 0
    private var arpNoteIndex: Int = 0
    private var arpSortedNotes: [Int] = [] // Notes held down sorted for arp
    private var currentArpNote: Int? = nil // Currently playing arp note
    private var arpTimer: Int = 0
    private var heldKeysForArp: Set<Int> = [] // Physical keys held

    // Random noise seed
    private var noiseSeed: UInt32 = 12345


    init() {
        setupAudioSession()
        setupLimiter()
        setupAudioEngine()
        applyPreset()
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

    private func generateSample() -> (Float, Float) {
        notesLock.lock()
        defer { notesLock.unlock() }

        var mixedSampleL: Float = 0.0
        var mixedSampleR: Float = 0.0
        var notesToRemove: [Int] = []
        
        // --- CLOCK & ARP PROCESSING ---
        // Calculate samples per tick (16th note)
        // BPM / 60 = BPS
        // BPS * 4 = Beats (quarter notes)
        // BPS * 4 * 4 = 16th notes per second?
        // Wait: 120 BPM = 2 beats per sec = 8 16th notes per sec.
        // SamplesPerTick = SampleRate / (BPM / 60 * 4)
        
        let bpm = preset.bpm
        let ticksPerBeat = 4.0 // 16th notes
        let samplesPerBeat = sampleRate * 60.0 / Double(max(20, bpm))
        samplesPerTick = samplesPerBeat / ticksPerBeat
        
        // Advance Clock
        if preset.arpMode != .off {
           clockPhase += 1.0
           if clockPhase >= samplesPerTick {
               clockPhase -= samplesPerTick
               handleArpTick()
           }
        } else {
            // Reset state if arp disabled
            if currentArpNote != nil {
                // Panic/Kill arp note
                if let n = currentArpNote {
                    // Use internal noteOff NO LOCK because we are inside generateSample Lock
                    internalNoteOffNoLock(midiNote: n)
                }
                currentArpNote = nil
            }
        }

        let lfoValue = lfo.getValue(sampleRate: sampleRate)
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let modMatrix = cachedModMatrix

        // Fast Random Noise Generation
        noiseSeed = noiseSeed &* 1664525 &+ 1013904223
        let noiseValue = Float(noiseSeed) / Float(UInt32.max) * 2.0 - 1.0

        // Flatten active notes for processing
        // We iterate over the dictionary values (arrays of ActiveNote)
        for (midiNote, var notes) in activeNotes {
            var allNotesEnded = true
            
            for i in 0..<notes.count {
                var activeNote = notes[i]
                
                let targetFrequency = activeNote.targetFrequency // Use specific target (detuned)
                
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
                
                // --- MATRIX MODULATION & AUDIO GENERATION ---
                
                // 1. Initial Values
                let baseFrequency = activeNote.currentFrequency
                var osc1Freq = oscillator1.frequencyWithModifiers(baseFrequency)
                var osc2Freq = oscillator2.frequencyWithModifiers(baseFrequency)
                
                let velValue = activeNote.velocity
                
                // Step 1: Envelope (Control Signal)
                // We process envelope first to get value for modulation
                let envelopeValue = envelope.process(
                    currentValue: activeNote.envelopeValue,
                    phase: &activeNote.envelopePhase,
                    time: &activeNote.envelopeTime,
                    releaseStartValue: activeNote.releaseStartValue,
                    isReleasing: activeNote.isReleasing,
                    sampleRate: sampleRate
                )
                activeNote.envelopeValue = envelopeValue
                
                // Step 2: Matrix Modulation (Pitch & Cutoff Pre-calculation)
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
                    
                    let amount = entry.amount
                    let modVal = sourceVal * amount
                    
                    switch entry.destination {
                    case .pitch1:  pitchMod1 += modVal
                    case .pitch2:  pitchMod2 += modVal
                    case .cutoff:  break
                    case .amp:     ampMod += modVal
                    case .pan:     panMod += modVal
                    default: break
                    }
                }
                
                // Apply Pitch Mod
                // 1.0 mod = 1 octave (doubling frequency)
                osc1Freq *= pow(2.0, Double(pitchMod1))
                osc2Freq *= pow(2.0, Double(pitchMod2))
                
                // Legacy LFO Pitch (keep for compatibility if matrix empty?)
                if lfoEnabled && lfoTarget == .pitch {
                     let mod = lfoValue
                     osc1Freq *= pow(2.0, Double(mod))
                     osc2Freq *= pow(2.0, Double(mod))
                }

                // Step 3: Oscillators
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

                // Step 4: Amplitude & Pan
                let unisonScale = 1.0 / sqrt(Double(max(1, cachedUnisonVoices)))
                var amplitude = sample * envelopeValue * Float(unisonScale)
                
                // Apply Amp Mod
                amplitude *= max(0.0, 1.0 + ampMod)
                
                // Legacy LFO Amp
                if lfoEnabled && lfoTarget == .amplitude {
                    amplitude = lfo.modulateAmplitude(amplitude, lfoValue: lfoValue)
                }
                
                var pan = activeNote.pan
                pan += panMod
                
                // Legacy LFO Pan
                if lfoEnabled && lfoTarget == .pan {
                    pan += lfoValue
                }
                
                pan = max(-1.0, min(1.0, pan))
                
                // Check ended
                if activeNote.envelopePhase != .finished {
                    allNotesEnded = false
                }
                notes[i] = activeNote
                
                // Mix
                let angle = (pan + 1.0) * Float.pi / 4.0
                let gainL = cos(angle)
                let gainR = sin(angle)
                
                mixedSampleL += amplitude * gainL
                mixedSampleR += amplitude * gainR
               
            }
            
            // If all unison voices for this note are finished, mark for removal
            if allNotesEnded {
                notesToRemove.append(midiNote)
            } else {
                activeNotes[midiNote] = notes
            }
        }

        for midiNote in notesToRemove {
            activeNotes.removeValue(forKey: midiNote)
        }

        // Apply parameter smoothing
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
        
        // Apply Chorus
        var (chorusL, chorusR) = dspChorus.process(inputL: finalSampleL, inputR: finalSampleR)
        
        // Apply Pan Modulation GLOBALLY here (Post-Filter, Post-Chorus/Pre-Chorus?)
        // If we Pan Post-Chorus, we pan the reverb/chorus tail too? No, Chorus is insert.
        // Let's Pan the result of Chorus.
             if lfoEnabled && lfoTarget == .pan {
                 let panVal = max(-1.0, min(1.0, lfoValue))
                 let angle = (panVal + 1.0) * Float.pi / 4.0
                 chorusL *= cos(angle)
                 chorusR *= sin(angle)
            }

        (chorusL, chorusR) = limiter.processStereo(inputL: chorusL, inputR: chorusR)

        // Level metering (use max of L/R)
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
            let level = min(currentLevel * 2.0, 1.0)  // Scale for better visibility
            let peak = min(currentPeak * 2.0, 1.0)
            DispatchQueue.main.async { [weak self] in
                self?.outputLevel = level
                self?.peakLevel = peak
            }
        }
        
        // Oscilloscope Capture (Mono mix for viz)
        if isCapturingScope {
            let monoOut = (chorusL + chorusR) * 0.5
            scopeBuffer[scopeIndex] = monoOut
            scopeIndex += 1
            
            if scopeIndex >= scopeBuffer.count {
                scopeIndex = 0
                // Publish copy
                let dataCopy = scopeBuffer
                DispatchQueue.main.async { [weak self] in
                    self?.scopeData = dataCopy
                }
            }
        }
        
        // Final safety clamp after limiter envelope response.
        chorusL = max(-1.0, min(1.0, chorusL))
        chorusR = max(-1.0, min(1.0, chorusR))

        return (chorusL, chorusR)
    }

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
        // Reset levels
        outputLevel = 0.0
        peakLevel = 0.0
        currentLevel = 0.0
        currentPeak = 0.0
    }



    // Split NoteOn into Public (External/UI) and Internal (Engine)
    // External handles Arp logic. Internal handles Voice allocation.
    
    func noteOn(midiNote: Int, velocity: Float = 1.0) {
        // If ARP is ON, we don't trigger sound immediately. We add to Arp pool.
        if preset.arpMode != .off {
            notesLock.lock()
            heldKeysForArp.insert(midiNote)
            updateArpSequence()
            
            // If this is the FIRST note and nothing is playing, maybe start arp immediately?
            // Or wait for next clock? Let's align to grid for now, but ensure clock starts.
            notesLock.unlock()
            
            DispatchQueue.main.async {
                self.pressedKeys.insert(midiNote)
            }
        } else {
             internalNoteOn(midiNote: midiNote, velocity: velocity)
        }
    }

    private func internalNoteOn(midiNote: Int, velocity: Float) {
        notesLock.lock()
        defer { notesLock.unlock() }
        
        if activeNotes[midiNote] != nil {
            activeNotes.removeValue(forKey: midiNote)
        }

        let note = Note(midiNote: midiNote)
        
        // Portamento Logic
        let startFreq: Double
        if activeNotes.isEmpty {
           startFreq = note.frequency
        } else {
             startFreq = preset.portamento > 0 ? (lastPlayedFrequency ?? note.frequency) : note.frequency
        }
        lastPlayedFrequency = note.frequency

        // Unison Logic
        let voices = preset.unisonVoices
        let detuneAmount = preset.unisonDetune
        let spreadAmount = preset.unisonSpread
        
        var newNotes: [ActiveNote] = []
        
        if voices <= 1 {
            // Single voice
            var activeNote = ActiveNote(note: note, velocity: velocity)
            activeNote.currentFrequency = startFreq
            activeNote.targetFrequency = note.frequency
            activeNote.pan = 0.0
            newNotes.append(activeNote)
        } else {
            // Multi-voice Unison
            for i in 0..<voices {
                var activeNote = ActiveNote(note: note, velocity: velocity)
                
                // Calculate Detune
                // Spread voices around center. e.g. -2, -1, 0, 1, 2 for 5 voices
                // Formula: (i - (voices-1)/2)
                let centerOffset = Float(i) - Float(voices - 1) / 2.0
                let detuneCents = centerOffset * detuneAmount
                
                let targetDetuned = AudioMath.detuneFrequency(note.frequency, cents: detuneCents)
                let startDetuned = AudioMath.detuneFrequency(startFreq, cents: detuneCents)

                activeNote.currentFrequency = startDetuned
                activeNote.targetFrequency = targetDetuned
                
                // Spread (Pan)
                // Spread linearly from -spread to +spread
                if voices > 1 {
                     let panPos = (Float(i) / Float(voices - 1)) * 2.0 - 1.0 // -1 to 1 normal
                     activeNote.pan = panPos * spreadAmount
                }
                
                newNotes.append(activeNote)
            }
        }
        
        activeNotes[midiNote] = newNotes
        
        if preset.arpMode == .off {
           // Only update pressedKeys if not handled by Arp NoteOn
           DispatchQueue.main.async {
               self.pressedKeys.insert(midiNote)
           }
        }
    }
    
    // Arpeggiator Tick Handler (Called from Audio Thread)
    private func handleArpTick() {
        // Stop previous note
        if let oldNote = currentArpNote {
            internalNoteOffNoLock(midiNote: oldNote)
        }
        
        if arpSortedNotes.isEmpty {
            currentArpNote = nil
            return
        }
        
        // Advance Index
        // Simple UP for now
        // TODO: Implement modes properly
        switch preset.arpMode {
        case .up:
             arpNoteIndex = (arpNoteIndex + 1) % arpSortedNotes.count
        case .down:
              if arpNoteIndex <= 0 { arpNoteIndex = arpSortedNotes.count - 1 }
              else { arpNoteIndex -= 1 }
        case .random:
              arpNoteIndex = Int.random(in: 0..<arpSortedNotes.count)
        default: break
        }
        
        let newNote = arpSortedNotes[arpNoteIndex]
        currentArpNote = newNote
        
        // Trigger Note On (Internal) - must NOT lock again if we are already in lock?
        // YES. generateSample locks. handleArpTick is called from generateSample.
        // internalNoteOn ALSO locks. DEADLOCK.
        // We must split internalNoteOn into "logic" (no lock) and "wrapper" (lock).
        // Or simply refactor code to inline note creation here.
        // For safety, let's create `internalNoteOnNoLock`.
        
        createVoiceNoLock(midiNote: newNote, velocity: 0.8)
    }
    
    private func createVoiceNoLock(midiNote: Int, velocity: Float) {
        // COPY PASTE of Voice Creation Logic but WITHOUT Lock
         if activeNotes[midiNote] != nil {
             activeNotes.removeValue(forKey: midiNote)
         }

         let note = Note(midiNote: midiNote)
         
         let startFreq: Double
         if activeNotes.isEmpty {
            startFreq = note.frequency
         } else {
              startFreq = preset.portamento > 0 ? (lastPlayedFrequency ?? note.frequency) : note.frequency
         }
         lastPlayedFrequency = note.frequency

         let voices = cachedUnisonVoices // Use CACHED values in Audio Thread
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

    private func updateArpSequence() {
        // Called when keys change
        let keys = Array(heldKeysForArp).sorted()
        
        // Re-sort based on mode? For now just keep sorted
        arpSortedNotes = keys
        
        // If mode is Down, maybe reverse?
        if preset.arpMode == .down {
            arpSortedNotes = keys.reversed()
        }
       
       // Reset index if out of bounds
       if arpNoteIndex >= arpSortedNotes.count {
           arpNoteIndex = 0
       }
    }

    func noteOff(midiNote: Int) {
        if preset.arpMode != .off {
            notesLock.lock()
            heldKeysForArp.remove(midiNote)
            updateArpSequence()
            notesLock.unlock()
            
            DispatchQueue.main.async {
                self.pressedKeys.remove(midiNote)
            }
        } else {
            notesLock.lock()
            internalNoteOffNoLock(midiNote: midiNote)
            notesLock.unlock()
            
            DispatchQueue.main.async {
                self.pressedKeys.remove(midiNote)
            }
        }
    }
    
    // Must be called with Lock held!
    private func internalNoteOffNoLock(midiNote: Int) {
        if var notes = activeNotes[midiNote] {
            // Release ALL unison voices for this key
            for i in 0..<notes.count {
                notes[i].isReleasing = true
                notes[i].releaseStartValue = notes[i].envelopeValue
            }
            activeNotes[midiNote] = notes
        }
    }

    func clearAllNotes() {
        notesLock.lock()
        activeNotes.removeAll()
        filterL.reset()
        filterR.reset()
        lfo.reset()
        notesLock.unlock()
        
        DispatchQueue.main.async {
            self.pressedKeys.removeAll()
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

        // Update cached values for audio thread
        cachedPortamento = preset.portamento
        cachedUnisonVoices = preset.unisonVoices
        cachedUnisonDetune = preset.unisonDetune
        cachedUnisonSpread = preset.unisonSpread
        cachedModMatrix = preset.modMatrix
        cachedOsc2Enabled = preset.osc2Enabled
        cachedFilterCutoff = preset.filterCutoff
        cachedMasterVolume = preset.masterVolume
    }

    func loadPreset(_ preset: SynthPreset) {
        self.preset = preset
    }
}
