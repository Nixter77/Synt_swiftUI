//
//  AudioEngine+Render.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI
import Synchronization

public extension AudioEngine {
    // MARK: - Audio thread render path

    /// One sample of synthesis. Commands must already be drained for this buffer.
    func renderOneSample() -> (Float, Float) {
        var mixedSampleL: Float = 0.0
        var mixedSampleR: Float = 0.0
        advanceCCSmoothers()
        midiClockSample &+= 1
        adoptSyncSourceRT()

        // --- CLOCK & ARP ---
        let bpm = cachedBPM
        let samplesPerBeat = sampleRate * 60.0 / Double(max(20, bpm))
        let divisionMultiplier = 4.0 / Double(cachedArpRate.denominator)
        samplesPerTick = samplesPerBeat * divisionMultiplier

        // Internal sync always runs this block. External MIDI clock runs it only
        // while a Start/Continue is in effect. A plugin uses the host transport
        // instead, and only while that transport is moving.
        let transportRunning = usesHostTransport
            ? hostTransportMoving
            : (cachedSyncSource != .midiClock || midiClockRunning)
        if transportRunning {
        if cachedArpMode != .off {
            arp.mode = cachedArpMode
            arp.octaves = cachedArpOctaves

            if arpGateSamplesLeft > 0 {
                arpGateSamplesLeft -= 1
                if arpGateSamplesLeft == 0 {
                    if let n = arp.currentNote {
                        releaseHeldNote(n)
                        arp.currentNote = nil
                    }
                }
            }

            clockPhase += 1.0
            let stepDuration = currentArpStepDuration()
            if clockPhase >= stepDuration {
                clockPhase -= stepDuration
                arpStepIndex &+= 1
                handleArpTick(stepDuration: currentArpStepDuration())
            }
        } else if let n = arp.currentNote {
            // Machine gates ignore the pedal; the pedal holds only played keys.
            releaseHeldNote(n)
            arp.currentNote = nil
            arpGateSamplesLeft = 0
            arpStepIndex = 0
        }

        advanceSequencerOneSample()
        }

        let envIn = max(abs(lastRenderedSampleL), abs(lastRenderedSampleR))
        if envIn > envelopeFollowerRT {
            envelopeFollowerRT += envFollowerAttCoeff * (envIn - envelopeFollowerRT)
        } else {
            envelopeFollowerRT += envFollowerRelCoeff * (envIn - envelopeFollowerRT)
        }
        envelopeFollowerValue = AudioMath.clamp(envelopeFollowerRT, min: 0.0, max: 1.0)

        // Single writer: preset (main) and CC1 (MIDI) only feed the inputs.
        lfo.depth = cachedLfoDepth + (1 - cachedLfoDepth) * modWheel
        let pitchBendMultiplier = advancePitchBend()
        let currentAftertouch = advanceAftertouch()
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let (modSlots, modCount) = rtModMatrix.snapshot()
        var smoothRandomValue: Float = 0
        var wantsMSEG = false
        var wantsMSEG2 = false
        if modCount > 0 {
            var wantsSmooth = false
            for m in 0..<modCount {
                if modSlots[m].source == .smoothRandom { wantsSmooth = true }
                if modSlots[m].source == .mseg { wantsMSEG = true }
                if modSlots[m].source == .mseg2 { wantsMSEG2 = true }
            }
            if wantsSmooth {
                smoothRandomValue = smoothRandom.advance(hz: cachedPerlinHz, sampleRate: sampleRate)
            }
        }
        var msegValue: Float = 0
        var mseg2Value: Float = 0
        if wantsMSEG || mseg.hasPoints || wantsMSEG2 || mseg2.hasPoints {
            var gate = false
            for i in 0..<AudioEngine.maxVoices where voices[i].isActive && !voices[i].isReleasing {
                gate = true
                break
            }
            if wantsMSEG || mseg.hasPoints {
                msegValue = mseg.tick(gate: gate, bpm: Double(cachedBPM))
            }
            if wantsMSEG2 || mseg2.hasPoints {
                mseg2Value = mseg2.tick(gate: gate, bpm: Double(cachedBPM))
            }
        }

        // Global destinations (cutoff, resonance, LFO rate/depth) share one source
        // per sample. `.loudest` is the old scan. Other policies run only when selected.
        // LFO self-modulation uses the previous sample so this one can still advance.
        var matrixWantsLFO = false
        var matrixWantsLFO2 = false
        var globalEnv: Float = 0
        var globalVel: Float = 0
        var globalRelease: Float = 0.5
        var globalKeyTrack: Float = 0
        var globalMpeBend: Float = 0
        var globalMpePres: Float = 0
        var globalMpeTimb: Float = 0
        var globalPoly: Float = 0
        var globalAftertouch = currentAftertouch
        var rateMod: Float = 0
        var depthMod: Float = 0
        var chorusMixMod: Float = 0
        var delayMixMod: Float = 0
        var reverbMixMod: Float = 0
        if modCount > 0 {
            switch cachedGlobalVoiceSourcePolicy {
            case .loudest:
                var loudest: Float = -1
                for i in 0..<AudioEngine.maxVoices where voices[i].isActive {
                    let env = voices[i].envelopeValue
                    if env >= loudest {
                        loudest = env
                        globalEnv = env
                        globalVel = voices[i].velocity
                        globalRelease = voices[i].releaseVelocity
                        globalKeyTrack = Float(voices[i].midiNote - 60) / 12.0
                        globalMpeBend = voices[i].smoothedMpePitchBend
                        globalMpePres = voices[i].smoothedMpePressure
                        globalMpeTimb = voices[i].smoothedMpeTimbre
                        globalPoly = voices[i].polyAftertouch
                    }
                }
            case .lastPlayed:
                let slot = lastTriggeredSlot
                if slot >= 0, slot < AudioEngine.maxVoices, voices[slot].isActive {
                    globalEnv = voices[slot].envelopeValue
                    globalVel = voices[slot].velocity
                    globalRelease = voices[slot].releaseVelocity
                    globalKeyTrack = Float(voices[slot].midiNote - 60) / 12.0
                    globalMpeBend = voices[slot].smoothedMpePitchBend
                    globalMpePres = voices[slot].smoothedMpePressure
                    globalMpeTimb = voices[slot].smoothedMpeTimbre
                    globalPoly = voices[slot].polyAftertouch
                } else {
                    var loudest: Float = -1
                    for i in 0..<AudioEngine.maxVoices where voices[i].isActive {
                        let env = voices[i].envelopeValue
                        if env >= loudest {
                            loudest = env
                            globalEnv = env
                            globalVel = voices[i].velocity
                            globalRelease = voices[i].releaseVelocity
                            globalKeyTrack = Float(voices[i].midiNote - 60) / 12.0
                            globalMpeBend = voices[i].smoothedMpePitchBend
                            globalMpePres = voices[i].smoothedMpePressure
                            globalMpeTimb = voices[i].smoothedMpeTimbre
                            globalPoly = voices[i].polyAftertouch
                        }
                    }
                }
            case .highest:
                var bestNote = Int.min
                var found = false
                for i in 0..<AudioEngine.maxVoices where voices[i].isActive {
                    let note = voices[i].midiNote
                    if !found || note >= bestNote {
                        found = true
                        bestNote = note
                        globalEnv = voices[i].envelopeValue
                        globalVel = voices[i].velocity
                        globalRelease = voices[i].releaseVelocity
                        globalKeyTrack = Float(note - 60) / 12.0
                        globalMpeBend = voices[i].smoothedMpePitchBend
                        globalMpePres = voices[i].smoothedMpePressure
                        globalMpeTimb = voices[i].smoothedMpeTimbre
                        globalPoly = voices[i].polyAftertouch
                    }
                }
            }
            globalAftertouch = max(currentAftertouch, shapeAftertouch(globalPoly))
            for m in 0..<modCount {
                let entry = modSlots[m]
                if entry.source == .lfo1 { matrixWantsLFO = true }
                if entry.source == .lfo2 { matrixWantsLFO2 = true }
                guard entry.destination == .lfoRate || entry.destination == .lfoDepth else { continue }
                let modVal = rowAmount(
                    entry,
                    slot: m,
                    lfo: lastMatrixLFO,
                    lfo2: lastMatrixLFO2,
                    env: globalEnv,
                    velocity: globalVel,
                    modWheel: modWheel,
                    keyTrack: globalKeyTrack,
                    aftertouch: globalAftertouch,
                    smoothRandom: smoothRandomValue,
                    mseg: msegValue,
                    mseg2: mseg2Value,
                    mpePitchBend: globalMpeBend,
                    mpePressure: globalMpePres,
                    mpeTimbre: globalMpeTimb,
                    releaseVelocity: globalRelease
                )
                switch entry.destination {
                case .lfoRate: rateMod += modVal
                case .lfoDepth: depthMod += modVal
                case .pitch1, .pitch2, .cutoff, .resonance, .amp, .pan, .pwm1, .pwm2, .mix, .wtMorph1, .wtMorph2, .finePitch, .fm, .chorusMix, .delayMix, .reverbMix, .vowel, .ampAttack, .ampDecay, .ampRelease, .filterAttack, .filterDecay, .filterRelease, .drive, .osc1Level, .osc2Level, .subLevel, .noiseLevel, .filterEnvAmount, .unisonDetune:
                    break
                }
            }
        }
        if depthMod != 0 {
            lfo.depth = max(0, min(1, lfo.depth + depthMod))
        }
        // Raw bipolar LFO; the direct target gets raw × Depth (same product as before).
        let lfoRawL: Float
        let lfoRawR: Float
        if lfoEnabled || matrixWantsLFO {
            if rateMod != 0 {
                let scaled = lfo.rate * pow(2, 2 * rateMod)
                let clamped = max(0.01, min(40, scaled))
                (lfoRawL, lfoRawR) = lfo.nextStereoRawValue(sampleRate: sampleRate, rateOverride: clamped)
            } else {
                (lfoRawL, lfoRawR) = lfo.nextStereoRawValue(sampleRate: sampleRate)
            }
        } else {
            lfoRawL = 0
            lfoRawR = 0
        }
        let lfoRaw = lfoRawL
        let lfoValue = lfoRaw * lfo.depth
        let lfoValueL = lfoRawL * lfo.depth
        let lfoValueR = lfoRawR * lfo.depth
        // Matrix rows: Amount is the depth. Older patches keep rows × Depth.
        let matrixLFO = cachedLfoRowsFollowDepth ? lfoValue : lfoRaw
        lastMatrixLFO = matrixLFO

        // LFO 2
        lfo2.depth = cachedLfo2Depth
        let lfo2Enabled = lfo2.enabled
        let lfo2Target = lfo2.target
        let lfo2RawL: Float
        let lfo2RawR: Float
        if lfo2Enabled || matrixWantsLFO2 {
            (lfo2RawL, lfo2RawR) = lfo2.nextStereoRawValue(sampleRate: sampleRate)
        } else {
            lfo2RawL = 0
            lfo2RawR = 0
        }
        let lfo2Raw = lfo2RawL
        let lfo2Value = lfo2Raw * lfo2.depth
        let lfo2ValueL = lfo2RawL * lfo2.depth
        let lfo2ValueR = lfo2RawR * lfo2.depth
        let matrixLFO2 = lfo2Raw
        lastMatrixLFO2 = matrixLFO2

        // One noise draw per sample. Each voice hashes it so noise chords
        // do not stack as N identical copies (that sum is just a loud clip).
        noiseSeed = noiseSeed &* 1664525 &+ 1013904223
        let noiseBase = noiseSeed

        smoothedFilterCutoff = smoothedFilterCutoff * smoothingCoeff + cachedFilterCutoff * (1 - smoothingCoeff)
        smoothedMasterVolume = smoothedMasterVolume * smoothingCoeff + cachedMasterVolume * (1 - smoothingCoeff)
        var cutoff = smoothedFilterCutoff
        if lfoEnabled && lfoTarget == .filter {
            cutoff = lfo.modulateFilter(cutoff, lfoValue: lfoValue)
        }
        if lfo2Enabled && lfo2Target == .filter {
            cutoff = lfo2.modulateFilter(cutoff, lfoValue: lfo2Value)
        }
        var cutoffMod: Float = 0
        var resonanceMod: Float = 0
        var wtMorphMod1: Float = 0
        var wtMorphMod2: Float = 0
        var vowelMod: Float = 0
        if modCount > 0 {
            for m in 0..<modCount {
                let entry = modSlots[m]
                switch entry.destination {
                case .cutoff:
                    if cachedPerVoiceCutoffSources && Self.isPerVoiceCutoffSource(entry.source) {
                        continue
                    }
                case .wtMorph1, .wtMorph2:
                    if cachedPerVoiceCutoffSources && Self.isPerVoiceMorphSlot(entry) {
                        continue
                    }
                case .resonance, .chorusMix, .delayMix, .reverbMix, .vowel:
                    break
                case .pitch1, .pitch2, .amp, .pan, .pwm1, .pwm2, .lfoRate, .lfoDepth, .mix, .finePitch, .fm, .ampAttack, .ampDecay, .ampRelease, .filterAttack, .filterDecay, .filterRelease, .drive, .osc1Level, .osc2Level, .subLevel, .noiseLevel, .filterEnvAmount, .unisonDetune:
                    continue
                }
                let modVal = rowAmount(
                    entry,
                    slot: m,
                    lfo: matrixLFO,
                    lfo2: matrixLFO2,
                    env: globalEnv,
                    velocity: globalVel,
                    modWheel: modWheel,
                    keyTrack: globalKeyTrack,
                    aftertouch: globalAftertouch,
                    smoothRandom: smoothRandomValue,
                    mseg: msegValue,
                    mseg2: mseg2Value,
                    mpePitchBend: globalMpeBend,
                    mpePressure: globalMpePres,
                    mpeTimbre: globalMpeTimb,
                    releaseVelocity: globalRelease
                )
                switch entry.destination {
                case .cutoff:
                    cutoffMod += modVal
                case .resonance: resonanceMod += modVal
                case .wtMorph1: wtMorphMod1 += modVal
                case .wtMorph2: wtMorphMod2 += modVal
                case .chorusMix: chorusMixMod += modVal
                case .delayMix: delayMixMod += modVal
                case .reverbMix: reverbMixMod += modVal
                case .vowel: vowelMod += modVal
                case .pitch1, .pitch2, .amp, .pan, .pwm1, .pwm2, .lfoRate, .lfoDepth, .mix, .finePitch, .fm, .ampAttack, .ampDecay, .ampRelease, .filterAttack, .filterDecay, .filterRelease, .drive, .osc1Level, .osc2Level, .subLevel, .noiseLevel, .filterEnvAmount, .unisonDetune:
                    break
                }
            }
            liveModulation.store(cutoffMod, for: .cutoff)
            liveModulation.store(resonanceMod, for: .resonance)
            liveModulation.store(wtMorphMod1, for: .wtMorph1)
            liveModulation.store(wtMorphMod2, for: .wtMorph2)
            liveModulation.store(chorusMixMod, for: .chorusMix)
            liveModulation.store(delayMixMod, for: .delayMix)
            liveModulation.store(reverbMixMod, for: .reverbMix)
            liveModulation.store(vowelMod, for: .vowel)
        } else {
            liveModulation.store(0, for: .cutoff)
            liveModulation.store(0, for: .resonance)
            liveModulation.store(0, for: .wtMorph1)
            liveModulation.store(0, for: .wtMorph2)
            liveModulation.store(0, for: .chorusMix)
            liveModulation.store(0, for: .delayMix)
            liveModulation.store(0, for: .reverbMix)
            liveModulation.store(0, for: .vowel)
            liveModulation.store(0, for: .lfoRate)
            liveModulation.store(0, for: .lfoDepth)
        }
        if oscillator1.waveform == .wavetable {
            wavetableEngine1.targetFramePosition = max(0, min(1, oscillator1.wavetableMorph + wtMorphMod1))
            wavetableEngine1.advanceMorph()
        }
        if oscillator2.waveform == .wavetable {
            wavetableEngine2.targetFramePosition = max(0, min(1, oscillator2.wavetableMorph + wtMorphMod2))
            wavetableEngine2.advanceMorph()
        }
        // Amount 1 moves cutoff by 4 octaves. The filter is global, so this is too.
        if cutoffMod != 0 {
            let scaled = cutoff * pow(2, cutoffMod * 4)
            if scaled.isFinite {
                cutoff = max(20, min(Float(sampleRate) * 0.45, scaled))
            }
        }
        filterL.cutoff = cutoff
        // Offset is local to the render; `filterL.resonance` has one writer (main).
        // A resonance CC rides on the same offset, until main moves the base.
        var resonanceOffset = resonanceMod
        if ccResonanceRT >= 0 {
            let base = filterL.resonance
            if base != ccResonanceBaseRT {
                ccResonanceRT = -1
            } else {
                resonanceOffset += ccResonanceRT - base
            }
        }
        let filterCoeffs = filterL.currentCoefficients(
            sampleRate: Float(sampleRate),
            resonanceOffset: resonanceOffset
        )
        let filterEnvAmt = cachedFilterEnvAmount
        let filterKeyTrk = cachedFilterKeyTracking
        let velToCutoff = cachedVelocityToCutoff
        let velToEnvAmt = cachedVelocityToEnvAmount
        let perVoiceFilter = filterEnvAmt != 0 || filterKeyTrk != 0 || cachedAnalogDrift > 0 || velToCutoff > 0 || velToEnvAmt != 0
        let voiceFilterBaseCutoff = filterL.smoothedCutoffValue
        let voiceFilterResonance = filterL.effectiveResonance
        let voiceFilterType = filterL.type
        let voiceFilterMaxCutoff = Float(sampleRate) * 0.45
        let formantActive = voiceFilterType == .formant || cachedFilter2Type == .formant
        let vowelNow: Float = formantActive
            ? max(0, min(4, cachedFilterVowel + vowelMod * 4))
            : 0

        // Phase 3: Sub-Osc, FM, and Hard Sync cached settings
        let fmAmount = cachedFmAmount
        let oscSync = cachedOscSyncEnabled
        let subVol = cachedSubOscVolume
        let subOctave = cachedSubOscOctave
        let subWave = cachedSubOscWaveform

        // Same for every voice: one exp() per sample, not one per voice.
        let glides = cachedPortamento > 0.001
        let glideRate = glides ? portamentoGlideRate() : 0
        if cachedTranceEnabled {
            advanceTranceGateRT()
        }

        // Latest active slot wins. Stored once after the scan; zeros when the pool is idle.
        var sawActiveVoice = false
        var hlPitch1: Float = 0
        var hlPitch2: Float = 0
        var hlAmp: Float = 0
        var hlPan: Float = 0
        var hlPwm1: Float = 0
        var hlPwm2: Float = 0
        var hlMix: Float = 0
        var hlFine: Float = 0
        var hlFm: Float = 0
        var hlDrive: Float = 0
        var hlOsc1: Float = 0
        var hlOsc2: Float = 0
        var hlSub: Float = 0
        var hlNoise: Float = 0
        var hlFilterEnv: Float = 0
        var hlUni: Float = 0
        var hlWtMorph1: Float = 0
        var hlWtMorph2: Float = 0

        // Fixed pool scan — work on a local copy to satisfy exclusivity + keep RT simple.
        // SYNT_22 Stage 2: one (trivial, ARC-free) copy of each Oscillator per sample instead of one
        // per voice call, and octave/detune pow() only on change instead of per voice. Bit-identical.
        let osc1 = oscillator1
        let osc2 = oscillator2
        // pow() only when octave/detune actually changed (not per sample).
        rtOsc1FreqMul.update(octave: osc1.octave, detune: osc1.detune)
        rtOsc2FreqMul.update(octave: osc2.octave, detune: osc2.detune)
        let osc1OctMul = rtOsc1FreqMul.octMul, osc1DetMul = rtOsc1FreqMul.detMul
        let osc2OctMul = rtOsc2FreqMul.octMul, osc2DetMul = rtOsc2FreqMul.detMul
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            var v = voices[i]

            if glides {
                let effectiveGlideRate: Double
                if cachedGlideMode == .rate {
                    let semitones = Double(max(0.01, v.glideIntervalSemitones))
                    let voicePortTime = Double(cachedPortamento) * (semitones / 12.0)
                    effectiveGlideRate = 1.0 - exp(-5.0 / (max(0.0001, voicePortTime) * sampleRate))
                } else {
                    effectiveGlideRate = glideRate
                }
                v.currentFrequency += (v.targetFrequency - v.currentFrequency) * effectiveGlideRate
                if abs(v.currentFrequency - v.targetFrequency) < 0.1 {
                    v.currentFrequency = v.targetFrequency
                }
            } else {
                v.currentFrequency = v.targetFrequency
            }

            let baseFrequency = v.currentFrequency
            var osc1Freq = baseFrequency
            if osc1.octave != 0 { osc1Freq *= osc1OctMul }
            if osc1.detune != 0 { osc1Freq = osc1Freq * osc1DetMul }
            var osc2Freq = baseFrequency
            if osc2.octave != 0 { osc2Freq *= osc2OctMul }
            if osc2.detune != 0 { osc2Freq = osc2Freq * osc2DetMul }
            let velValue = v.velocity

            let releaseOverride: Float? = v.fastRelease ? ADSREnvelope.fastReleaseSeconds : nil
            if cachedEnvTimeMod {
                latchEnvTime(
                    &v,
                    slots: modSlots,
                    count: modCount,
                    lfo: matrixLFO,
                    lfo2: matrixLFO2,
                    aftertouch: currentAftertouch,
                    smoothRandom: smoothRandomValue,
                    mseg: msegValue,
                    mseg2: mseg2Value
                )
            }
            let envelopeValue = envelope.process(
                currentValue: v.envelopeValue,
                phase: &v.envelopePhase,
                time: &v.envelopeTime,
                releaseStartValue: v.releaseStartValue,
                isReleasing: v.isReleasing,
                sampleRate: sampleRate,
                releaseOverride: releaseOverride,
                attackScale: v.attackScale * v.ampAttackMul,
                decayScale: v.decayScale * v.ampDecayMul,
                releaseScale: v.releaseScale * v.ampReleaseMul
            )
            v.envelopeValue = envelopeValue

            let filterEnvVal: Float
            if cachedFilterEnvUseDedicatedADSR {
                filterEnvVal = filterEnvelope.process(
                    currentValue: v.filterEnvelopeValue,
                    phase: &v.filterEnvelopePhase,
                    time: &v.filterEnvelopeTime,
                    releaseStartValue: v.filterReleaseStartLevel,
                    isReleasing: v.isReleasing,
                    sampleRate: sampleRate,
                    releaseOverride: releaseOverride,
                    attackScale: v.attackScale * v.filterAttackMul,
                    decayScale: v.decayScale * v.filterDecayMul,
                    releaseScale: v.releaseScale * v.filterReleaseMul
                )
                v.filterEnvelopeValue = filterEnvVal
            } else {
                filterEnvVal = envelopeValue
                v.filterEnvelopeValue = envelopeValue
            }

            let modEnvVal = modEnvelope.process(
                currentValue: v.modEnvelopeValue,
                phase: &v.modEnvelopePhase,
                time: &v.modEnvelopeTime,
                releaseStartValue: v.modReleaseStartLevel,
                isReleasing: v.isReleasing,
                sampleRate: sampleRate,
                releaseOverride: releaseOverride,
                attackScale: v.attackScale,
                decayScale: v.decayScale,
                releaseScale: v.releaseScale
            )
            v.modEnvelopeValue = modEnvVal

            var pitchMod1: Float = 0
            var pitchMod2: Float = 0
            var ampMod: Float = 0
            var panMod: Float = 0
            var pwmMod1: Float = 0
            var pwmMod2: Float = 0
            var mixMod: Float = 0
            var fineMod: Float = 0
            var fmMod: Float = 0
            var driveMod: Float = 0
            var osc1LevelMod: Float = 0
            var osc2LevelMod: Float = 0
            var subLevelMod: Float = 0
            var noiseLevelMod: Float = 0
            var filterEnvMod: Float = 0
            var unisonDetuneMod: Float = 0
            var voiceCutoffMod: Float = 0
            var wtMorphMod1Voice: Float = 0
            var wtMorphMod2Voice: Float = 0

            v.smoothedMpePitchBend += (v.mpePitchBend - v.smoothedMpePitchBend) * 0.05
            v.smoothedMpePressure += (v.mpePressure - v.smoothedMpePressure) * 0.05
            v.smoothedMpeTimbre += (v.mpeTimbre - v.smoothedMpeTimbre) * 0.05

            let keyTrackVal = Float(v.midiNote - 60) / 12.0
            if modCount > 0 {
                for m in 0..<modCount {
                    let entry = modSlots[m]
                    switch entry.destination {
                    case .pitch1, .pitch2, .amp, .pan, .pwm1, .pwm2, .mix, .finePitch, .fm, .drive, .osc1Level, .osc2Level, .subLevel, .noiseLevel, .filterEnvAmount, .unisonDetune:
                        break
                    case .cutoff:
                        guard cachedPerVoiceCutoffSources && Self.isPerVoiceCutoffSource(entry.source) else {
                            continue
                        }
                    case .wtMorph1, .wtMorph2:
                        guard cachedPerVoiceCutoffSources && Self.isPerVoiceMorphSlot(entry) else {
                            continue
                        }
                    case .resonance, .lfoRate, .lfoDepth, .chorusMix, .delayMix, .reverbMix, .vowel, .ampAttack, .ampDecay, .ampRelease, .filterAttack, .filterDecay, .filterRelease:
                        continue
                    }
                    let modVal = rowAmount(
                        entry,
                        slot: m,
                        lfo: matrixLFO,
                        lfo2: matrixLFO2,
                        env: envelopeValue,
                        velocity: velValue,
                        modWheel: modWheel,
                        keyTrack: keyTrackVal,
                        env2: filterEnvVal,
                        aftertouch: max(currentAftertouch, shapeAftertouch(v.polyAftertouch)),
                        modEnv: modEnvVal,
                        pitchBend: pitchBendSmoothed,
                        random: v.randomValue,
                        sampleAndHold: self.lfo.lastRandomValue,
                        smoothRandom: smoothRandomValue,
                        mseg: msegValue,
                        mseg2: mseg2Value,
                        mpePitchBend: v.smoothedMpePitchBend,
                        mpePressure: v.smoothedMpePressure,
                        mpeTimbre: v.smoothedMpeTimbre,
                        releaseVelocity: v.releaseVelocity
                    )
                    switch entry.destination {
                    case .pitch1: pitchMod1 += modVal
                    case .pitch2: pitchMod2 += modVal
                    case .amp: ampMod += modVal
                    case .pan: panMod += modVal
                    case .pwm1: pwmMod1 += modVal
                    case .pwm2: pwmMod2 += modVal
                    case .mix: mixMod += modVal
                    case .finePitch: fineMod += modVal
                    case .fm: fmMod += modVal
                    case .drive: driveMod += modVal
                    case .osc1Level: osc1LevelMod += modVal
                    case .osc2Level: osc2LevelMod += modVal
                    case .subLevel: subLevelMod += modVal
                    case .noiseLevel: noiseLevelMod += modVal
                    case .filterEnvAmount: filterEnvMod += modVal
                    case .unisonDetune: unisonDetuneMod += modVal
                    case .cutoff: voiceCutoffMod += modVal
                    case .wtMorph1: wtMorphMod1Voice += modVal
                    case .wtMorph2: wtMorphMod2Voice += modVal
                    case .resonance, .lfoRate, .lfoDepth, .chorusMix, .delayMix, .reverbMix, .vowel, .ampAttack, .ampDecay, .ampRelease, .filterAttack, .filterDecay, .filterRelease:
                        break
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
            if lfo2Enabled && lfo2Target == .pitch {
                let mod = Double(max(-1, min(1, lfo2Value)))
                if mod != 0 {
                    let mul = pow(2.0, mod)
                    osc1Freq *= mul
                    osc2Freq *= mul
                }
            }

            if pitchBendMultiplier != 1 {
                osc1Freq *= pitchBendMultiplier
                osc2Freq *= pitchBendMultiplier
            }

            if cachedMpeEnabled && v.mpePitchBendMultiplier != 1.0 {
                osc1Freq *= v.mpePitchBendMultiplier
                osc2Freq *= v.mpePitchBendMultiplier
            }

            if cachedAnalogDrift > 0 {
                if v.filterControlTick & 7 == 0 {
                    v.driftPhase += 0.00045
                    if v.driftPhase >= Float.pi * 2 { v.driftPhase -= Float.pi * 2 }
                    let driftCents = sin(v.driftPhase) * cachedAnalogDrift * 5.0
                    v.driftState = driftCents
                    v.driftMul = pow(2.0, Double(driftCents) / 1200.0)
                    v.driftCutoffMul = pow(2.0, (driftCents * 0.1) / 1200.0)
                }
                osc1Freq *= v.driftMul
                osc2Freq *= v.driftMul
            }

            if cachedOsc2Fixed {
                osc2Freq = Double(cachedOsc2Hz)
            }
            if fineMod != 0 {
                let mul = pow(2.0, Double(max(-1, min(1, fineMod))) / 12.0)
                osc1Freq *= mul
                osc2Freq *= mul
            }
            osc1Freq = max(20.0, min(sampleRate * 0.45, osc1Freq))
            osc2Freq = max(20.0, min(sampleRate * 0.45, osc2Freq))
            if unisonDetuneMod != 0 && v.partialCount > 1 {
                let center = Float(v.partial) - Float(v.partialCount - 1) * 0.5
                let cents = center * unisonDetuneMod * 50
                if cents != 0 {
                    let mul = pow(2.0, Double(cents) / 1200.0)
                    osc1Freq *= mul
                    osc2Freq *= mul
                }
            }

            let voiceSeed = (noiseBase &+ UInt32(i) &* 747_796_405 &+ 2_891_336_453) &* 1_664_525 &+ 1_013_904_223
            let rawNoise = Float(voiceSeed) / Float(UInt32.max) * 2.0 - 1.0
            let noiseValue: Float
            if noiseLevelMod != 0 || osc1.waveform == .noise || osc2.waveform == .noise {
                noiseValue = v.filterNoise(rawNoise, color: cachedNoiseColor)
            } else {
                noiseValue = 0
            }

            let phaseInc1 = AudioMath.twoPi * osc1Freq / sampleRate
            var phaseInc2 = AudioMath.twoPi * osc2Freq / sampleRate
            let pulse2 = pwmMod2 == 0 ? nil : max(0.05, min(0.95, osc2.pulseWidth + pwmModulationSpan * pwmMod2))
            let pulse1 = pwmMod1 == 0 ? nil : max(0.05, min(0.95, osc1.pulseWidth + pwmModulationSpan * pwmMod1))

            let s2: Float
            var osc1Phase = v.phase
            let s1: Float
            if cachedFMRatio && !cachedOsc2Fixed {
                let ratio = max(0.25, min(32, Double(cachedFMCoarse) + Double(cachedFMFine)))
                let voiceFM = fmMod == 0 ? fmAmount : max(0, min(1, fmAmount + fmMod))
                if cachedFMRoute == .osc1ToOsc2 {
                    s1 = osc1.generateSample(
                        phase: v.phase,
                        phaseIncrement: phaseInc1,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse1,
                        pullWavetable: false,
                        frameOffset: wtMorphMod1Voice
                    )
                    let modFreq = min(sampleRate * 0.45, osc1Freq * ratio)
                    phaseInc2 = AudioMath.twoPi * modFreq / sampleRate
                    var osc2Phase = v.phase2
                    if voiceFM > 0 {
                        osc2Phase += Double(s1 * voiceFM * Float.pi)
                        osc2Phase = osc2Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                        if osc2Phase < 0 { osc2Phase += AudioMath.twoPi }
                    }
                    if cachedOsc2Enabled || voiceFM > 0 || cachedRingModAmount > 0 {
                        s2 = osc2.generateSample(
                            phase: osc2Phase,
                            phaseIncrement: phaseInc2,
                            noiseValue: noiseValue,
                            pulseWidthOverride: pulse2,
                            pullWavetable: false,
                            frameOffset: wtMorphMod2Voice
                        )
                    } else {
                        s2 = 0
                    }
                } else {
                    let modFreq = min(sampleRate * 0.45, osc1Freq * ratio)
                    phaseInc2 = AudioMath.twoPi * modFreq / sampleRate
                    if cachedOsc2Enabled || voiceFM > 0 || cachedRingModAmount > 0 {
                        s2 = osc2.generateSample(
                            phase: v.phase2,
                            phaseIncrement: phaseInc2,
                            noiseValue: noiseValue,
                            pulseWidthOverride: pulse2,
                            pullWavetable: false,
                            frameOffset: wtMorphMod2Voice
                        )
                    } else {
                        s2 = 0
                    }
                    if voiceFM > 0 {
                        osc1Phase += Double(s2 * voiceFM * Float.pi)
                        osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                        if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
                    }
                    s1 = osc1.generateSample(
                        phase: osc1Phase,
                        phaseIncrement: phaseInc1,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse1,
                        pullWavetable: false,
                        frameOffset: wtMorphMod1Voice
                    )
                }
            } else if fmMod == 0 {
                if cachedOsc2Enabled || fmAmount > 0 || cachedRingModAmount > 0 {
                    s2 = osc2.generateSample(
                        phase: v.phase2,
                        phaseIncrement: phaseInc2,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse2,
                        pullWavetable: false,
                        frameOffset: wtMorphMod2Voice
                    )
                } else {
                    s2 = 0
                }
                if fmAmount > 0 {
                    osc1Phase += Double(s2 * fmAmount * Float.pi)
                    osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                    if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
                }
                s1 = osc1.generateSample(
                    phase: osc1Phase,
                    phaseIncrement: phaseInc1,
                    noiseValue: noiseValue,
                    pulseWidthOverride: pulse1,
                    pullWavetable: false,
                    frameOffset: wtMorphMod1Voice
                )
            } else {
                let voiceFM = max(0, min(1, fmAmount + fmMod))
                if cachedOsc2Enabled || voiceFM > 0 || cachedRingModAmount > 0 {
                    s2 = osc2.generateSample(
                        phase: v.phase2,
                        phaseIncrement: phaseInc2,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse2,
                        pullWavetable: false,
                        frameOffset: wtMorphMod2Voice
                    )
                } else {
                    s2 = 0
                }
                if voiceFM > 0 {
                    osc1Phase += Double(s2 * voiceFM * Float.pi)
                    osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                    if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
                }
                s1 = osc1.generateSample(
                    phase: osc1Phase,
                    phaseIncrement: phaseInc1,
                    noiseValue: noiseValue,
                    pulseWidthOverride: pulse1,
                    pullWavetable: false,
                    frameOffset: wtMorphMod1Voice
                )
            }
            let s1Out = osc1LevelMod == 0 ? s1 : s1 * max(0, 1 + osc1LevelMod)
            let s2Out = osc2LevelMod == 0 ? s2 : s2 * max(0, 1 + osc2LevelMod)
            var sample = s1Out
            if cachedOsc2Enabled {
                if mixMod != 0 {
                    let bias = max(-1, min(1, mixMod))
                    sample = (s1Out * (1 - bias) + s2Out * (1 + bias)) * 0.5
                } else {
                    sample = (s1Out + s2Out) * 0.5
                }
            }
            if noiseLevelMod != 0 {
                sample += noiseValue * noiseLevelMod
            }

            if cachedRingModAmount > 0 {
                let ring = s1 * s2 * 2.0
                sample = sample * (1.0 - cachedRingModAmount) + ring * cachedRingModAmount
            }

            let voiceSub = subLevelMod == 0 ? subVol : max(0, subVol + subLevelMod)
            if voiceSub > 0 {
                let subFreq = osc1Freq * (subOctave == -2 ? 0.25 : 0.5)
                let subInc = AudioMath.twoPi * subFreq / sampleRate
                let subDt = subInc / AudioMath.twoPi
                let normSub = v.subPhase / AudioMath.twoPi
                let subSample: Float
                switch subWave {
                case .sine:
                    subSample = Float(sin(v.subPhase))
                case .triangle:
                    var val = 4.0 * abs(normSub - 0.5) - 1.0
                    val += 8.0 * Oscillator.polyBLAMP(t: normSub, dt: subDt)
                    var shifted = normSub - 0.5
                    if shifted < 0 { shifted += 1.0 }
                    val -= 8.0 * Oscillator.polyBLAMP(t: shifted, dt: subDt)
                    subSample = Float(val)
                case .square:
                    var val = normSub < 0.5 ? 1.0 : -1.0
                    val += Oscillator.polyBLEP(t: normSub, dt: subDt)
                    var shifted = normSub - 0.5
                    if shifted < 0 { shifted += 1.0 }
                    val -= Oscillator.polyBLEP(t: shifted, dt: subDt)
                    subSample = Float(val)
                default:
                    subSample = Float(sin(v.subPhase))
                }
                sample = (sample + subSample * voiceSub) / (1.0 + voiceSub * 0.4)

                v.subPhase += subInc
                if v.subPhase >= AudioMath.twoPi { v.subPhase -= AudioMath.twoPi }
                if v.subPhase < 0 { v.subPhase += AudioMath.twoPi }
            }

            v.phase += phaseInc1
            let osc1Reset = v.phase >= AudioMath.twoPi
            if osc1Reset { v.phase -= AudioMath.twoPi }
            if v.phase < 0 { v.phase += AudioMath.twoPi }

            if oscSync && osc1Reset {
                let frac = phaseInc1 > 0 ? v.phase / phaseInc1 : 0
                v.phase2 = frac * phaseInc2
            } else {
                v.phase2 += phaseInc2
                if v.phase2 >= AudioMath.twoPi { v.phase2 -= AudioMath.twoPi }
                if v.phase2 < 0 { v.phase2 += AudioMath.twoPi }
            }

            if v.velGain != v.velGainTarget {
                if velGainGlideSampleRate != sampleRate {
                    velGainGlideSampleRate = sampleRate
                    velGainGlideCoeff = sampleRate > 0
                        ? Float(1 - exp(-1.0 / (sampleRate * 0.004)))
                        : 1
                }
                v.velGain += velGainGlideCoeff * (v.velGainTarget - v.velGain)
                if abs(v.velGain - v.velGainTarget) < 1e-5 {
                    v.velGain = v.velGainTarget
                }
            }
            var amplitude = sample * envelopeValue * v.velGain
            if cachedShortAttack, v.microFadeRemaining > 0 {
                amplitude *= v.microFadeGain
                v.microFadeGain += v.microFadeStep
                if v.microFadeGain > 1 { v.microFadeGain = 1 }
                v.microFadeRemaining -= 1
            }
            amplitude *= max(0.0, 1.0 + ampMod)
            amplitude *= AudioMath.voiceGain * v.unisonScale
            if lfoEnabled && lfoTarget == .amplitude && lfo.stereoPhaseOffsetDegrees == 0 {
                amplitude = lfo.modulateAmplitude(amplitude, lfoValue: lfoValue)
            }
            if lfo2Enabled && lfo2Target == .amplitude && lfo2.stereoPhaseOffsetDegrees == 0 {
                amplitude = lfo2.modulateAmplitude(amplitude, lfoValue: lfo2Value)
            }
            if !amplitude.isFinite { amplitude = 0 }
            let preFilterAmplitude = amplitude
            var voiceCoeffs = filterCoeffs
            let voiceDrive = driveMod == 0 ? cachedFilterDrive : max(0, min(1, cachedFilterDrive + driveMod))
            let voiceFilterLive = perVoiceFilter || filterEnvMod != 0 || voiceCutoffMod != 0
            var voiceF1Cutoff: Float = voiceFilterBaseCutoff
            var hasVoiceF1Cutoff = false
            if voiceFilterLive {
                if v.filterControlTick & 3 == 0 {
                    let c = voiceCutoffHz(
                        base: voiceFilterBaseCutoff,
                        envAmt: filterEnvAmt,
                        filterEnvMod: filterEnvMod,
                        filterEnvVal: filterEnvVal,
                        velToEnvAmt: velToEnvAmt,
                        velocity: v.velocity,
                        keyTrk: filterKeyTrk,
                        midiNote: v.midiNote,
                        velToCutoff: velToCutoff,
                        drift: cachedAnalogDrift,
                        driftMul: v.driftCutoffMul,
                        maxCutoff: voiceFilterMaxCutoff,
                        voiceCutoffMod: voiceCutoffMod
                    )
                    voiceF1Cutoff = c
                    hasVoiceF1Cutoff = true
                    v.voiceFilterCoeffs = CachedBiquadFilter.coefficients(
                        type: voiceFilterType,
                        cutoff: c,
                        resonance: voiceFilterResonance,
                        sampleRate: Float(sampleRate)
                    )
                }
                v.filterControlTick &+= 1
                voiceCoeffs = v.voiceFilterCoeffs
            }
            if voiceFilterType == .formant {
                let formant = voiceFormantPtr[i].takeUnretainedValue()
                formant.vowel = vowelNow
                let formed = formant.process(max(-6, min(6, amplitude)))
                amplitude = formed.isFinite ? formed : 0
            } else if voiceFilterType == .comb {
                let comb = voiceCombPtr[i].takeUnretainedValue()
                let c: Float
                if cachedCombUsesVoiceCutoff {
                    let base = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                    if perVoiceFilter || filterEnvMod != 0 || voiceCutoffMod != 0 {
                        c = voiceCutoffHz(
                            base: base,
                            envAmt: filterEnvAmt,
                            filterEnvMod: filterEnvMod,
                            filterEnvVal: filterEnvVal,
                            velToEnvAmt: velToEnvAmt,
                            velocity: v.velocity,
                            keyTrk: filterKeyTrk,
                            midiNote: v.midiNote,
                            velToCutoff: velToCutoff,
                            drift: cachedAnalogDrift,
                            driftMul: v.driftCutoffMul,
                            maxCutoff: voiceFilterMaxCutoff,
                            voiceCutoffMod: voiceCutoffMod
                        )
                        if perVoiceFilter {
                            voiceF1Cutoff = c
                            hasVoiceF1Cutoff = true
                        }
                    } else {
                        c = base
                    }
                } else {
                    var bare = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                    if perVoiceFilter {
                        bare = max(20, min(voiceFilterMaxCutoff, bare))
                    }
                    c = bare
                }
                let combed = comb.process(
                    amplitude,
                    cutoff: c,
                    resonance: voiceFilterResonance,
                    sampleRate: Float(sampleRate),
                    damping: cachedCombUsesVoiceCutoff ? 0.22 : 0
                )
                amplitude = combed.isFinite ? combed : 0
            } else if cachedFilterFeedback != 0 {
                let fb = min(1, max(-1, cachedFilterFeedback))
                let dry = amplitude
                let fed = amplitude + v.filterFeedbackState * fb
                // A non-finite feedback sample is clamped to a finite tanh inside
                // the filter, so the recovery below would never run. Skip the
                // filter and take that branch: restore dry and reset the biquad.
                if !fed.isFinite {
                    amplitude = .nan
                } else if voiceFilterType == .ladder {
                    let cutoffBase = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                    let c: Float
                    if perVoiceFilter || filterEnvMod != 0 || voiceCutoffMod != 0 {
                        c = voiceCutoffHz(
                            base: cutoffBase,
                            envAmt: filterEnvAmt,
                            filterEnvMod: filterEnvMod,
                            filterEnvVal: filterEnvVal,
                            velToEnvAmt: velToEnvAmt,
                            velocity: v.velocity,
                            keyTrk: filterKeyTrk,
                            midiNote: v.midiNote,
                            velToCutoff: velToCutoff,
                            drift: cachedAnalogDrift,
                            driftMul: v.driftCutoffMul,
                            maxCutoff: voiceFilterMaxCutoff,
                            voiceCutoffMod: voiceCutoffMod
                        )
                        if perVoiceFilter {
                            voiceF1Cutoff = c
                            hasVoiceF1Cutoff = true
                        }
                    } else {
                        c = cutoffBase
                    }
                    amplitude = v.ladder.process(
                        fed,
                        cutoff: c,
                        resonance: voiceFilterResonance,
                        drive: voiceDrive,
                        sampleRate: Float(sampleRate)
                    )
                } else if voiceDrive != 0 {
                    let driven = AudioMath.fastTanh(fed * (1 + voiceDrive * 8))
                    amplitude = v.filter.process(driven, coeffs: voiceCoeffs)
                } else {
                    let filtered = v.filter.process(fed, coeffs: voiceCoeffs)
                    if filtered.isFinite {
                        amplitude = AudioMath.fastTanh(filtered)
                    } else {
                        amplitude = .nan
                    }
                }
                if amplitude.isFinite {
                    v.filterFeedbackState = amplitude
                } else {
                    v.filterFeedbackState = 0
                    amplitude = dry
                    v.filter.reset()
                }
            } else if voiceFilterType == .ladder {
                let cutoffBase = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                let c: Float
                if perVoiceFilter || filterEnvMod != 0 || voiceCutoffMod != 0 {
                    c = voiceCutoffHz(
                        base: cutoffBase,
                        envAmt: filterEnvAmt,
                        filterEnvMod: filterEnvMod,
                        filterEnvVal: filterEnvVal,
                        velToEnvAmt: velToEnvAmt,
                        velocity: v.velocity,
                        keyTrk: filterKeyTrk,
                        midiNote: v.midiNote,
                        velToCutoff: velToCutoff,
                        drift: cachedAnalogDrift,
                        driftMul: v.driftCutoffMul,
                        maxCutoff: voiceFilterMaxCutoff,
                        voiceCutoffMod: voiceCutoffMod
                    )
                    if perVoiceFilter {
                        voiceF1Cutoff = c
                        hasVoiceF1Cutoff = true
                    }
                } else {
                    c = cutoffBase
                }
                amplitude = v.ladder.process(
                    amplitude,
                    cutoff: c,
                    resonance: voiceFilterResonance,
                    drive: voiceDrive,
                    sampleRate: Float(sampleRate)
                )
            } else if voiceDrive != 0 {
                let driven = AudioMath.fastTanh(amplitude * (1 + voiceDrive * 8))
                amplitude = v.filter.process(driven, coeffs: voiceCoeffs)
            } else {
                amplitude = v.filter.process(amplitude, coeffs: voiceCoeffs)
            }
            if !amplitude.isFinite { amplitude = 0 }
            if cachedFilter2Routing != .off {
                let dual = voiceDualPtr[i].takeUnretainedValue()
                dual.routing = cachedFilter2Routing
                dual.type2 = cachedFilter2Type
                if voiceFilterLive && voiceFilterBaseCutoff > 20 {
                    let f1Cutoff: Float
                    if hasVoiceF1Cutoff {
                        f1Cutoff = voiceF1Cutoff
                    } else {
                        f1Cutoff = voiceCutoffHz(
                            base: voiceFilterBaseCutoff,
                            envAmt: filterEnvAmt,
                            filterEnvMod: filterEnvMod,
                            filterEnvVal: filterEnvVal,
                            velToEnvAmt: velToEnvAmt,
                            velocity: v.velocity,
                            keyTrk: filterKeyTrk,
                            midiNote: v.midiNote,
                            velToCutoff: velToCutoff,
                            drift: cachedAnalogDrift,
                            driftMul: v.driftCutoffMul,
                            maxCutoff: voiceFilterMaxCutoff,
                            voiceCutoffMod: voiceCutoffMod
                        )
                    }
                    let scaled = cachedFilter2Cutoff * (f1Cutoff / max(20, voiceFilterBaseCutoff))
                    dual.cutoff2 = scaled.isFinite ? max(20, min(voiceFilterMaxCutoff, scaled)) : cachedFilter2Cutoff
                } else {
                    dual.cutoff2 = cachedFilter2Cutoff
                }
                dual.resonance2 = cachedFilter2Resonance
                dual.balance = cachedFilter2Balance
                if cachedFilter2Type == .formant {
                    dual.vowel = vowelNow
                }
                amplitude = dual.processFilter2(dry: preFilterAmplitude, filtered: amplitude)
                if !amplitude.isFinite { amplitude = 0 }
            }
            if cachedTranceEnabled {
                amplitude *= tranceGain
            }

            var pan = v.pan + panMod
            if ccPanRT != 0 { pan += ccPanRT }

            let ampL: Float
            let ampR: Float
            if (lfoEnabled && lfoTarget == .amplitude && lfo.stereoPhaseOffsetDegrees != 0) ||
               (lfo2Enabled && lfo2Target == .amplitude && lfo2.stereoPhaseOffsetDegrees != 0) {
                var aL = amplitude
                var aR = amplitude
                // A zero-offset LFO was already applied once on the mono amplitude.
                if lfoEnabled && lfoTarget == .amplitude && lfo.stereoPhaseOffsetDegrees != 0 {
                    aL = lfo.modulateAmplitude(aL, lfoValue: lfoValueL)
                    aR = lfo.modulateAmplitude(aR, lfoValue: lfoValueR)
                }
                if lfo2Enabled && lfo2Target == .amplitude && lfo2.stereoPhaseOffsetDegrees != 0 {
                    aL = lfo2.modulateAmplitude(aL, lfoValue: lfo2ValueL)
                    aR = lfo2.modulateAmplitude(aR, lfoValue: lfo2ValueR)
                }
                ampL = aL
                ampR = aR
            } else {
                ampL = amplitude
                ampR = amplitude
            }

            let angleL: Float
            let angleR: Float
            if (lfoEnabled && lfoTarget == .pan && lfo.stereoPhaseOffsetDegrees != 0) ||
               (lfo2Enabled && lfo2Target == .pan && lfo2.stereoPhaseOffsetDegrees != 0) {
                var pL = pan
                var pR = pan
                if lfoEnabled && lfoTarget == .pan {
                    pL += lfoValueL
                    pR += lfoValueR
                }
                if lfo2Enabled && lfo2Target == .pan {
                    pL += lfo2ValueL
                    pR += lfo2ValueR
                }
                angleL = (max(-1, min(1, pL)) + 1.0) * Float.pi / 4.0
                angleR = (max(-1, min(1, pR)) + 1.0) * Float.pi / 4.0
            } else {
                var p = pan
                if lfoEnabled && lfoTarget == .pan { p += lfoValue }
                if lfo2Enabled && lfo2Target == .pan { p += lfo2Value }
                p = max(-1, min(1, p))
                let angle = (p + 1.0) * Float.pi / 4.0
                angleL = angle
                angleR = angle
            }

            mixedSampleL += ampL * cos(angleL)
            mixedSampleR += ampR * sin(angleR)

            if v.envelopePhase == .finished {
                v.deactivate()
                resetVoiceToneBanks(at: i)
                activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            } else {
                sawActiveVoice = true
                hlPitch1 = pitchMod1
                hlPitch2 = pitchMod2
                hlAmp = ampMod
                hlPan = panMod
                hlPwm1 = pwmMod1
                hlPwm2 = pwmMod2
                hlMix = mixMod
                hlFine = fineMod
                hlFm = fmMod
                hlDrive = driveMod
                hlOsc1 = osc1LevelMod
                hlOsc2 = osc2LevelMod
                hlSub = subLevelMod
                hlNoise = noiseLevelMod
                hlFilterEnv = filterEnvMod
                hlUni = unisonDetuneMod
                hlWtMorph1 = wtMorphMod1Voice
                hlWtMorph2 = wtMorphMod2Voice
            }
            voices[i] = v
        }

        if sawActiveVoice {
            liveModulation.store(hlPitch1, for: .pitch1)
            liveModulation.store(hlPitch2, for: .pitch2)
            liveModulation.store(hlAmp, for: .amp)
            liveModulation.store(hlPan, for: .pan)
            liveModulation.store(hlPwm1, for: .pwm1)
            liveModulation.store(hlPwm2, for: .pwm2)
            liveModulation.store(hlMix, for: .mix)
            liveModulation.store(hlFine, for: .finePitch)
            liveModulation.store(hlFm, for: .fm)
            liveModulation.store(hlDrive, for: .drive)
            liveModulation.store(hlOsc1, for: .osc1Level)
            liveModulation.store(hlOsc2, for: .osc2Level)
            liveModulation.store(hlSub, for: .subLevel)
            liveModulation.store(hlNoise, for: .noiseLevel)
            liveModulation.store(hlFilterEnv, for: .filterEnvAmount)
            liveModulation.store(hlUni, for: .unisonDetune)
            if cachedPerVoiceCutoffSources && modCount > 0 {
                liveModulation.store(wtMorphMod1 + hlWtMorph1, for: .wtMorph1)
                liveModulation.store(wtMorphMod2 + hlWtMorph2, for: .wtMorph2)
            }
        } else {
            liveModulation.store(0, for: .pitch1)
            liveModulation.store(0, for: .pitch2)
            liveModulation.store(0, for: .amp)
            liveModulation.store(0, for: .pan)
            liveModulation.store(0, for: .pwm1)
            liveModulation.store(0, for: .pwm2)
            liveModulation.store(0, for: .mix)
            liveModulation.store(0, for: .finePitch)
            liveModulation.store(0, for: .fm)
            liveModulation.store(0, for: .drive)
            liveModulation.store(0, for: .osc1Level)
            liveModulation.store(0, for: .osc2Level)
            liveModulation.store(0, for: .subLevel)
            liveModulation.store(0, for: .noiseLevel)
            liveModulation.store(0, for: .filterEnvAmount)
            liveModulation.store(0, for: .unisonDetune)
        }

        if !mixedSampleL.isFinite { mixedSampleL = 0 }
        if !mixedSampleR.isFinite { mixedSampleR = 0 }

        let headroom: Float = 0.65
        var outL = mixedSampleL * smoothedMasterVolume * headroom
        var outR = mixedSampleR * smoothedMasterVolume * headroom
        // Both flags off skips the smoother and the multiply, so goldens stay bit-exact.
        if cachedRespondToExpressionCC || cachedGlobalExpressionCC {
            let expression = expressionGain()
            if expression != 1 {
                outL *= expression
                outR *= expression
            }
        }
        if cachedSceneHPF {
            let high = sceneHPF.process(
                left: outL,
                right: outR,
                hz: cachedSceneHPFHz,
                sampleRate: Float(sampleRate)
            )
            outL = high.0
            outR = high.1
        }

        // FX mix rows are global. Separate modulated values keep the main-thread
        // fields untouched, avoiding data races and restoring dry early-outs.
        let chorusMixNow = chorusMixMod == 0
            ? dspChorus.mix
            : max(0, min(1, dspChorus.mix + chorusMixMod))
        let delayMixNow = delayMixMod == 0
            ? pingPongDelay.mix
            : max(0, min(1, pingPongDelay.mix + delayMixMod))
        let reverbMixNow = reverbMixMod == 0
            ? cachedReverbMix
            : max(0, min(1, cachedReverbMix + reverbMixMod))

        // Parallel sends tap pre-insert (post-HPF dry) or post-insert. Level 0 skips the buses.
        let preInsertL = outL
        let preInsertR = outR
        dynamicsPreCleanBusL = preInsertL
        dynamicsPreCleanBusR = preInsertR

        // EQ before the rider. A boost after it walked straight into the ceiling
        // and rasped; the rider now holds that extra level with one linear gain.
        var processedCleanBus = false
        for i in 0..<6 {
            let slot = cachedFXOrder[i]
            if !processedCleanBus && slot != .eq {
                (outL, outR) = cleanBus.process(
                    left: outL,
                    right: outR,
                    sampleRate: Float(sampleRate)
                )
                processedCleanBus = true
            }
            switch slot {
            case .eq:
                if parametricEQL.enabled {
                    if !parametricEQR.enabled { parametricEQR.enabled = true }
                    outL = parametricEQL.process(outL)
                    outR = parametricEQR.process(outR)
                }
            case .distortion:
                if distortion.enabled {
                    (outL, outR) = distortion.processStereo(inputL: outL, inputR: outR)
                }
            case .phaser:
                if !phaser.bypass {
                    let p = phaser.process(inputL: outL, inputR: outR)
                    outL = p.left
                    outR = p.right
                }
            case .chorus:
                (outL, outR) = dspChorus.process(inputL: outL, inputR: outR, mix: chorusMixNow)
            case .delay:
                if cachedDelayPingPong {
                    (outL, outR) = pingPongDelay.process(inputL: outL, inputR: outR, mix: delayMixNow)
                }
            case .reverb:
                if cachedDSPReverb {
                    let wet = dspReverb.process(
                        inputL: outL,
                        inputR: outR,
                        room: cachedReverbRoom,
                        damp: cachedReverbDamping
                    )
                    let mix = reverbMixNow
                    outL = outL * (1 - mix) + wet.0 * mix
                    outR = outR * (1 - mix) + wet.1 * mix
                }
                if cachedReverbShimmer > 0 {
                    let (shimL, shimR) = shimmer.process(inputL: outL, inputR: outR)
                    outL += shimL * cachedReverbShimmer
                    outR += shimR * cachedReverbShimmer
                }
            }
            if !processedCleanBus && slot == .eq {
                (outL, outR) = cleanBus.process(
                    left: outL,
                    right: outR,
                    sampleRate: Float(sampleRate)
                )
                processedCleanBus = true
            }
        }
        if !processedCleanBus {
            (outL, outR) = cleanBus.process(
                left: outL,
                right: outR,
                sampleRate: Float(sampleRate)
            )
        }

        // SYNT_68: optional bus-glue compressor, post-CleanBus, default OFF.
        if cachedBusGlueEnabled {
            (outL, outR) = busGlueCompressor.processStereo(inputL: outL, inputR: outR)
        }

        let sendSourceL = cachedSendPostInsert ? outL : preInsertL
        let sendSourceR = cachedSendPostInsert ? outR : preInsertR

        if cachedSendA > 0 {
            if sendReverb.isClearing { sendReverb.cancelIncrementalClear() }
            sendFadeA += (cachedSendA - sendFadeA) * 0.05
            lastSendA = cachedSendA
            let wet = sendReverb.process(
                inputL: sendSourceL,
                inputR: sendSourceR,
                room: cachedReverbRoom,
                damp: cachedReverbDamping
            )
            outL += wet.0 * sendFadeA
            outR += wet.1 * sendFadeA
        } else {
            lastSendA = 0
            if sendFadeA > 0 {
                // R9-2: Smooth 10–20 ms tail fade (~15 ms) without click/discontinuity
                sendFadeA = max(0, sendFadeA - sendFadeStep)
                let wet = sendReverb.process(
                    inputL: 0,
                    inputR: 0,
                    room: cachedReverbRoom,
                    damp: cachedReverbDamping
                )
                outL += wet.0 * sendFadeA
                outR += wet.1 * sendFadeA
                if sendFadeA == 0 {
                    sendReverb.startIncrementalClear()
                }
            } else if sendReverb.isClearing {
                sendReverb.clearIncremental(count: (sendReverb.totalCount / 64) + 1)
            }
        }

        if cachedSendB > 0 {
            if sendDelay.isClearing { sendDelay.cancelIncrementalClear() }
            sendFadeB += (cachedSendB - sendFadeB) * 0.05
            lastSendB = cachedSendB
            sendDelay.delayTime = cachedSendDelayTime
            sendDelay.feedback = cachedSendDelayFeedback
            let wet = sendDelay.process(inputL: sendSourceL, inputR: sendSourceR, mix: 1)
            outL += wet.0 * sendFadeB
            outR += wet.1 * sendFadeB
        } else {
            lastSendB = 0
            if sendFadeB > 0 {
                // R9-2: Smooth 10–20 ms tail fade (~15 ms) without click/discontinuity
                sendFadeB = max(0, sendFadeB - sendFadeStep)
                sendDelay.delayTime = cachedSendDelayTime
                sendDelay.feedback = cachedSendDelayFeedback
                let wet = sendDelay.process(inputL: 0, inputR: 0, mix: 1)
                outL += wet.0 * sendFadeB
                outR += wet.1 * sendFadeB
                if sendFadeB == 0 {
                    sendDelay.startIncrementalClear()
                }
            } else if sendDelay.isClearing {
                sendDelay.clearIncremental(count: (sendDelay.totalCount / 64) + 1)
            }
        }

        if cachedRotaryEnabled {
            let spun = rotary.process(
                inputL: outL,
                inputR: outR,
                hornSlow: cachedRotaryHornSlow,
                hornFast: cachedRotaryHornFast,
                drumSlow: cachedRotaryDrumSlow,
                drumFast: cachedRotaryDrumFast,
                fast: cachedRotaryFast,
                drive: cachedRotaryDrive,
                mix: cachedRotaryMix,
                accelHz: cachedRotaryAccel
            )
            outL = spun.0
            outR = spun.1
        }

        if cachedTransientEnabled {
            let shaped = transientShaper.process(
                left: outL,
                right: outR,
                attack: cachedTransientAttack,
                sustain: cachedTransientSustain,
                output: cachedTransientOutput,
                mix: cachedTransientMix
            )
            outL = shaped.0
            outR = shaped.1
        }

        if cachedFrequencyShifterEnabled {
            let shifted = frequencyShifter.process(
                inputL: outL,
                inputR: outR,
                shiftHz: cachedFrequencyShifterShiftHz,
                mix: cachedFrequencyShifterMix,
                feedback: cachedFrequencyShifterFeedback,
                sampleRate: Float(sampleRate)
            )
            outL = shifted.left
            outR = shifted.right
        }

        if lfoEnabled && lfoTarget == .pan {
            let panVal = max(-1, min(1, lfoValue))
            let a = (panVal + 1) * Float.pi / 4
            outL *= cos(a)
            outR *= sin(a)
        }

        if cachedStereoEnabled {
            let widened = stereoTool.process(
                left: outL,
                right: outR,
                width: cachedStereoWidth,
                midSide: cachedStereoMidSide,
                haasMs: cachedStereoHaasMs,
                monoBassHz: cachedStereoMonoBassHz,
                sampleRate: Float(sampleRate)
            )
            outL = widened.0
            outR = widened.1
        }

        if cachedCharacter != .off {
            outL = characterToneL.process(outL, mode: cachedCharacter, sampleRate: Float(sampleRate))
            outR = characterToneR.process(outR, mode: cachedCharacter, sampleRate: Float(sampleRate))
        }

        lastPreClipAbs = max(abs(outL), abs(outR))
        outL = AudioMath.cleanCeiling(outL)
        outR = AudioMath.cleanCeiling(outR)

        let absL = abs(outL)
        let absR = abs(outR)
        let absSample = max(absL, absR)
        currentLevel = max(currentLevel * levelDecay, absSample)
        currentLevelL = max(currentLevelL * levelDecay, absL)
        currentLevelR = max(currentLevelR * levelDecay, absR)
        if absSample > currentPeak { currentPeak = absSample }
        else { currentPeak *= peakDecay }
        if absL > currentPeakL { currentPeakL = absL }
        else { currentPeakL *= peakDecay }
        if absR > currentPeakR { currentPeakR = absR }
        else { currentPeakR *= peakDecay }

        sampleCounter += 1
        if sampleCounter >= levelUpdateInterval {
            sampleCounter = 0
            meteringState.setOutputLevel(min(currentLevel * 2, 1))
            meteringState.setPeakLevel(min(currentPeak * 2, 1))
            meteringState.setOutputLevelStereo(left: min(currentLevelL * 2, 1), right: min(currentLevelR * 2, 1))
            meteringState.setPeakLevelStereo(left: min(currentPeakL * 2, 1), right: min(currentPeakR * 2, 1))
        }

        if isCapturingScope {
            scopeBuffer[scopeIndex] = (outL + outR) * 0.5
            scopeIndex += 1
            if scopeIndex >= scopeBuffer.count {
                scopeIndex = 0
                scopeBuffer.withUnsafeBufferPointer { ptr in
                    meteringState.writeScopeBuffer(ptr)
                }
            }
        }

        if !outL.isFinite { outL = 0 }
        if !outR.isFinite { outR = 0 }
        lastRenderedSampleL = outL
        lastRenderedSampleR = outR
        return (outL, outR)
    }

    @inline(__always)
    private static func isPerVoiceMorphSource(_ source: ModSource) -> Bool {
        switch source {
        case .env1, .env2, .modEnv, .velocity, .releaseVelocity, .keyTrack, .random,
             .mpePitchBend, .mpePressure, .mpeTimbre, .aftertouch:
            return true
        case .lfo1, .lfo2, .modWheel, .macro1, .macro2, .macro3, .macro4, .macro5, .macro6, .macro7, .macro8,
             .pitchBend, .sampleAndHold, .smoothRandom, .mseg, .mseg2, .envelopeFollower:
            return false
        }
    }

    @inline(__always)
    private static func isPerVoiceMorphSlot(_ entry: RTModSlot) -> Bool {
        isPerVoiceMorphSource(entry.source) || (entry.viaSource.map(isPerVoiceMorphSource) ?? false)
    }
}


/// SYNT_22 Stage 2: render-owned cache of the oscillator frequency multipliers. Recomputes the
/// two pow() only when octave/detune change; same values as `Oscillator.frequencyWithModifiers`.
struct OscFreqMulCache {
    private var octave = 0
    private var detune: Float = 0
    private(set) var octMul: Double = 1
    private(set) var detMul: Double = 1
    @inline(__always)
    mutating func update(octave o: Int, detune d: Float) {
        if o != octave { octave = o; octMul = pow(2.0, Double(o)) }
        if d.bitPattern != detune.bitPattern { detune = d; detMul = pow(2.0, Double(d) / 1200.0) }
    }
}
