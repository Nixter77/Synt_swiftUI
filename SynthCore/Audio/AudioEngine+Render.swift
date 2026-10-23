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

/// Lookahead peak rider. Multiplies the whole waveform by a slow gain so a chord
/// that would have entered the tanh clipper stays linear. Gain does not track
/// individual waveform cycles (that would be another waveshaper).
public final class CleanBus {
    public static let capacity = 512
    public static let lookahead = 256
    public static let threshold = AudioMath.cleanBusThreshold

    private var bufL = [Float](repeating: 0, count: CleanBus.capacity)
    private var bufR = [Float](repeating: 0, count: CleanBus.capacity)
    private var write = 0
    private var env: Float = 0
    private var gain: Float = 1
    private var hold = 0
    private var envCoeff: Float = 1
    private var attCoeff: Float = 1
    private var relCoeff: Float = 0
    private var holdMax = 1
    private var coeffRate: Float = 0
    private var dcPole: Float = 0.9983
    private var dcXL: Float = 0
    private var dcXR: Float = 0
    private var dcYL: Float = 0
    private var dcYR: Float = 0

    public init(sampleRate: Float = 44100) {
        updateCoefficients(sampleRate: sampleRate)
    }

    public func setSampleRate(_ sampleRate: Float) {
        updateCoefficients(sampleRate: max(8_000, sampleRate))
    }

    public func reset() {
        for i in 0..<bufL.count {
            bufL[i] = 0
            bufR[i] = 0
        }
        write = 0
        env = 0
        gain = 1
        hold = 0
        dcXL = 0
        dcXR = 0
        dcYL = 0
        dcYR = 0
    }

    public func process(left: Float, right: Float, sampleRate: Float) -> (Float, Float) {
        let sr = sampleRate > 1000 ? sampleRate : coeffRate
        if sr != coeffRate { updateCoefficients(sampleRate: sr) }

        let xL = dcBlock(left.isFinite ? left : 0, x1: &dcXL, y1: &dcYL)
        let xR = dcBlock(right.isFinite ? right : 0, x1: &dcXR, y1: &dcYR)

        bufL[write] = xL
        bufR[write] = xR

        let peak = max(abs(xL), abs(xR))
        if peak >= env {
            env = peak
            hold = holdMax
        } else if hold > 0 {
            hold -= 1
        } else {
            env = max(peak, env * envCoeff)
        }

        let desired: Float = env > Self.threshold ? Self.threshold / env : 1
        let coeff: Float
        if desired < gain * 0.985 {
            coeff = attCoeff
        } else if desired > gain {
            coeff = relCoeff
        } else {
            coeff = 0
        }
        if coeff > 0 {
            gain += (desired - gain) * coeff
        }
        if !gain.isFinite || gain < 0 { gain = 1 }
        if gain > 1 { gain = 1 }

        let read = (write + Self.capacity - Self.lookahead) & (Self.capacity - 1)
        write = (write + 1) & (Self.capacity - 1)
        return (bufL[read] * gain, bufR[read] * gain)
    }

    private func updateCoefficients(sampleRate: Float) {
        coeffRate = sampleRate
        let sr = Double(sampleRate)
        envCoeff = Float(exp(-1.0 / (sr * 0.200)))
        attCoeff = Float(1.0 - exp(-1.0 / (sr * 0.0015)))
        relCoeff = Float(1.0 - exp(-1.0 / (sr * 0.150)))
        holdMax = max(1, Int(sampleRate * 0.040))
        dcPole = Float(exp(-2.0 * Double.pi * 12.0 / sr))
    }

    private func dcBlock(_ x: Float, x1: inout Float, y1: inout Float) -> Float {
        let y = x - x1 + dcPole * y1
        x1 = x
        if !y.isFinite || abs(y) > 16 {
            y1 = 0
            return 0
        }
        y1 = y
        return y
    }
}

public extension AudioEngine {
    @inline(__always)
    public func matrixSource(
        _ source: ModSource,
        lfo: Float,
        lfo2: Float,
        env: Float,
        velocity: Float,
        modWheel: Float,
        keyTrack: Float,
        env2: Float = 0,
        aftertouch: Float = 0,
        modEnv: Float = 0,
        pitchBend: Float = 0,
        random: Float = 0,
        sampleAndHold: Float = 0,
        smoothRandom: Float = 0,
        mseg: Float = 0,
        mseg2: Float = 0
    ) -> Float {
        switch source {
        case .lfo1: return lfo
        case .env1: return env
        case .velocity: return velocity
        case .lfo2: return lfo2
        case .modWheel: return modWheel
        case .keyTrack: return keyTrack
        case .env2: return env2
        case .aftertouch: return aftertouch
        case .macro1: return cachedMacro1
        case .macro2: return cachedMacro2
        case .macro3: return cachedMacro3
        case .macro4: return cachedMacro4
        case .macro5: return cachedMacro5
        case .macro6: return cachedMacro6
        case .macro7: return cachedMacro7
        case .macro8: return cachedMacro8
        case .modEnv: return modEnv
        case .pitchBend: return pitchBend
        case .random: return random
        case .sampleAndHold: return sampleAndHold
        case .smoothRandom: return smoothRandom
        case .mseg: return mseg
        case .mseg2: return mseg2
        case .envelopeFollower: return envelopeFollowerValue
        }
    }

    /// Linear rows multiply the raw source. Other curves read the bank published off the audio thread.
    @inline(__always)
    func modulatedAmount(_ entry: RTModSlot, slot: Int, source: Float) -> Float {
        let shaped: Float
        if entry.curve == .linear {
            shaped = source
        } else {
            shaped = rtModMatrix.lookup(bank: entry.tableBank, slot: slot, source: source)
        }
        return shaped * entry.amount
    }

    /// One step clock for every voice. Runs only while the gate is enabled.
    /// A host beat (musical context) owns the step, including after a locate or loop.
    /// Without one, the gate free-runs from the cached tempo.
    func advanceTranceGateRT() {
        let isHostPlaying = !usesHostTransport || hostTransportMoving
        if tranceHostLocked && isHostPlaying {
            let bpm = Double(max(20, min(300, cachedBPM)))
            let beatsPerStep = max(1e-6, Double(cachedTranceDivision.duration(bpm: Float(bpm))) * bpm / 60.0)
            let stepPos = tranceHostBeat / beatsPerStep
            if stepPos.isFinite {
                let wrapped = stepPos - floor(stepPos / 16.0) * 16.0
                var step = Int(wrapped)
                if step < 0 { step = 0 }
                if step > 15 { step = 15 }
                tranceStep = step
            }
            tranceHostBeat += bpm / (60.0 * max(sampleRate, 1))
        } else {
            if tranceHostLocked {
                let bpm = Double(max(20, min(300, cachedBPM)))
                let beatsPerStep = max(1e-6, Double(cachedTranceDivision.duration(bpm: Float(bpm))) * bpm / 60.0)
                let stepPos = tranceHostBeat / beatsPerStep
                if stepPos.isFinite && tranceCursor == 0 {
                    let wrapped = stepPos - floor(stepPos / 16.0) * 16.0
                    var step = Int(wrapped)
                    if step < 0 { step = 0 }
                    if step > 15 { step = 15 }
                    tranceStep = step
                }
            }
            let dur = Double(cachedTranceDivision.duration(bpm: cachedBPM))
            let stepSamples = max(1, dur * sampleRate)
            tranceCursor += 1
            if tranceCursor >= stepSamples {
                tranceCursor -= stepSamples
                tranceStep = (tranceStep + 1) & 15
            }
        }
        let bit = UInt16(1) << UInt16(tranceStep)
        let on = cachedTranceSteps & bit != 0
        let target: Float = on ? 1 : (1 - cachedTranceDepth)
        if cachedTranceSmooth <= 0.0001 {
            tranceGain = target
            return
        }
        if cachedTranceSmooth != tranceSmoothForCoeff || sampleRate != tranceCoeffRate {
            tranceSmoothForCoeff = cachedTranceSmooth
            tranceCoeffRate = sampleRate
            let ms = 0.001 + Double(cachedTranceSmooth) * 0.040
            tranceSmoothCoeff = Float(1 - exp(-1.0 / (ms * sampleRate)))
        }
        tranceGain += (target - tranceGain) * tranceSmoothCoeff
    }

    // MARK: - Audio thread render path

    /// One sample of synthesis. Commands must already be drained for this buffer.
    public func renderOneSample() -> (Float, Float) {
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
        // per sample. Env and velocity come from the loudest active voice.
        // LFO self-modulation uses the previous sample so this one can still advance.
        var matrixWantsLFO = false
        var matrixWantsLFO2 = false
        var globalEnv: Float = 0
        var globalVel: Float = 0
        var globalKeyTrack: Float = 0
        var rateMod: Float = 0
        var depthMod: Float = 0
        var chorusMixMod: Float = 0
        var delayMixMod: Float = 0
        var reverbMixMod: Float = 0
        if modCount > 0 {
            var loudest: Float = -1
            for i in 0..<AudioEngine.maxVoices where voices[i].isActive {
                let env = voices[i].envelopeValue
                if env >= loudest {
                    loudest = env
                    globalEnv = env
                    globalVel = voices[i].velocity
                    globalKeyTrack = Float(voices[i].midiNote - 60) / 12.0
                }
            }
            for m in 0..<modCount {
                let entry = modSlots[m]
                if entry.source == .lfo1 { matrixWantsLFO = true }
                if entry.source == .lfo2 { matrixWantsLFO2 = true }
                let src = matrixSource(
                    entry.source,
                    lfo: lastMatrixLFO,
                    lfo2: lastMatrixLFO2,
                    env: globalEnv,
                    velocity: globalVel,
                    modWheel: modWheel,
                    keyTrack: globalKeyTrack,
                    aftertouch: currentAftertouch,
                    smoothRandom: smoothRandomValue,
                    mseg: msegValue,
                    mseg2: mseg2Value
                )
                let modVal = modulatedAmount(entry, slot: m, source: src)
                switch entry.destination {
                case .lfoRate: rateMod += modVal
                case .lfoDepth: depthMod += modVal
                case .pitch1, .pitch2, .cutoff, .resonance, .amp, .pan, .pwm1, .pwm2, .mix, .wtMorph1, .wtMorph2, .finePitch, .fm, .chorusMix, .delayMix, .reverbMix, .vowel:
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
                let src = matrixSource(
                    entry.source,
                    lfo: matrixLFO,
                    lfo2: matrixLFO2,
                    env: globalEnv,
                    velocity: globalVel,
                    modWheel: modWheel,
                    keyTrack: globalKeyTrack,
                    aftertouch: currentAftertouch,
                    smoothRandom: smoothRandomValue,
                    mseg: msegValue,
                    mseg2: mseg2Value
                )
                let modVal = modulatedAmount(entry, slot: m, source: src)
                switch entry.destination {
                case .cutoff: cutoffMod += modVal
                case .resonance: resonanceMod += modVal
                case .wtMorph1: wtMorphMod1 += modVal
                case .wtMorph2: wtMorphMod2 += modVal
                case .chorusMix: chorusMixMod += modVal
                case .delayMix: delayMixMod += modVal
                case .reverbMix: reverbMixMod += modVal
                case .vowel: vowelMod += modVal
                case .pitch1, .pitch2, .amp, .pan, .pwm1, .pwm2, .lfoRate, .lfoDepth, .mix, .finePitch, .fm:
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

        // Fixed pool scan — work on a local copy to satisfy exclusivity + keep RT simple.
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

            let voiceSeed = (noiseBase &+ UInt32(i) &* 747_796_405 &+ 2_891_336_453) &* 1_664_525 &+ 1_013_904_223
            let rawNoise = Float(voiceSeed) / Float(UInt32.max) * 2.0 - 1.0
            let noiseValue = v.filterNoise(rawNoise, color: cachedNoiseColor)

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

            let filterEnvVal: Float
            if cachedFilterEnvUseDedicatedADSR {
                filterEnvVal = filterEnvelope.process(
                    currentValue: v.filterEnvelopeValue,
                    phase: &v.filterEnvelopePhase,
                    time: &v.filterEnvelopeTime,
                    releaseStartValue: v.filterReleaseStartLevel,
                    isReleasing: v.isReleasing,
                    sampleRate: sampleRate,
                    releaseOverride: releaseOverride
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
                releaseOverride: releaseOverride
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

            let keyTrackVal = Float(v.midiNote - 60) / 12.0
            if modCount > 0 {
                for m in 0..<modCount {
                    let entry = modSlots[m]
                    let sourceVal = matrixSource(
                        entry.source,
                        lfo: matrixLFO,
                        lfo2: matrixLFO2,
                        env: envelopeValue,
                        velocity: velValue,
                        modWheel: modWheel,
                        keyTrack: keyTrackVal,
                        env2: filterEnvVal,
                        aftertouch: max(currentAftertouch, v.polyAftertouch),
                        modEnv: modEnvVal,
                        pitchBend: pitchBendSmoothed,
                        random: v.randomValue,
                        sampleAndHold: lfo.lastRandomValue,
                        smoothRandom: smoothRandomValue,
                        mseg: msegValue,
                        mseg2: mseg2Value
                    )
                    let modVal = modulatedAmount(entry, slot: m, source: sourceVal)
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
                    case .cutoff, .resonance, .lfoRate, .lfoDepth, .wtMorph1, .wtMorph2, .chorusMix, .delayMix, .reverbMix, .vowel:
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

            let phaseInc1 = AudioMath.twoPi * osc1Freq / sampleRate
            var phaseInc2 = AudioMath.twoPi * osc2Freq / sampleRate
            let pulse2 = pwmMod2 == 0 ? nil : max(0.05, min(0.95, oscillator2.pulseWidth + pwmModulationSpan * pwmMod2))
            let pulse1 = pwmMod1 == 0 ? nil : max(0.05, min(0.95, oscillator1.pulseWidth + pwmModulationSpan * pwmMod1))

            let s2: Float
            var osc1Phase = v.phase
            let s1: Float
            if cachedFMRatio && !cachedOsc2Fixed {
                let ratio = max(0.25, min(32, Double(cachedFMCoarse) + Double(cachedFMFine)))
                let voiceFM = fmMod == 0 ? fmAmount : max(0, min(1, fmAmount + fmMod))
                if cachedFMRoute == .osc1ToOsc2 {
                    s1 = oscillator1.generateSample(
                        phase: v.phase,
                        phaseIncrement: phaseInc1,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse1
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
                        s2 = oscillator2.generateSample(
                            phase: osc2Phase,
                            phaseIncrement: phaseInc2,
                            noiseValue: noiseValue,
                            pulseWidthOverride: pulse2
                        )
                    } else {
                        s2 = 0
                    }
                } else {
                    let modFreq = min(sampleRate * 0.45, osc1Freq * ratio)
                    phaseInc2 = AudioMath.twoPi * modFreq / sampleRate
                    if cachedOsc2Enabled || voiceFM > 0 || cachedRingModAmount > 0 {
                        s2 = oscillator2.generateSample(
                            phase: v.phase2,
                            phaseIncrement: phaseInc2,
                            noiseValue: noiseValue,
                            pulseWidthOverride: pulse2
                        )
                    } else {
                        s2 = 0
                    }
                    if voiceFM > 0 {
                        osc1Phase += Double(s2 * voiceFM * Float.pi)
                        osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                        if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
                    }
                    s1 = oscillator1.generateSample(
                        phase: osc1Phase,
                        phaseIncrement: phaseInc1,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse1
                    )
                }
            } else if fmMod == 0 {
                if cachedOsc2Enabled || fmAmount > 0 || cachedRingModAmount > 0 {
                    s2 = oscillator2.generateSample(
                        phase: v.phase2,
                        phaseIncrement: phaseInc2,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse2
                    )
                } else {
                    s2 = 0
                }
                if fmAmount > 0 {
                    osc1Phase += Double(s2 * fmAmount * Float.pi)
                    osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                    if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
                }
                s1 = oscillator1.generateSample(
                    phase: osc1Phase,
                    phaseIncrement: phaseInc1,
                    noiseValue: noiseValue,
                    pulseWidthOverride: pulse1
                )
            } else {
                let voiceFM = max(0, min(1, fmAmount + fmMod))
                if cachedOsc2Enabled || voiceFM > 0 || cachedRingModAmount > 0 {
                    s2 = oscillator2.generateSample(
                        phase: v.phase2,
                        phaseIncrement: phaseInc2,
                        noiseValue: noiseValue,
                        pulseWidthOverride: pulse2
                    )
                } else {
                    s2 = 0
                }
                if voiceFM > 0 {
                    osc1Phase += Double(s2 * voiceFM * Float.pi)
                    osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                    if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
                }
                s1 = oscillator1.generateSample(
                    phase: osc1Phase,
                    phaseIncrement: phaseInc1,
                    noiseValue: noiseValue,
                    pulseWidthOverride: pulse1
                )
            }
            var sample = s1
            if cachedOsc2Enabled {
                if mixMod != 0 {
                    let bias = max(-1, min(1, mixMod))
                    sample = (s1 * (1 - bias) + s2 * (1 + bias)) * 0.5
                } else {
                    sample = (s1 + s2) * 0.5
                }
            }

            if cachedRingModAmount > 0 {
                let ring = s1 * s2 * 2.0
                sample = sample * (1.0 - cachedRingModAmount) + ring * cachedRingModAmount
            }

            if subVol > 0 {
                let subSample: Float
                let normSub = v.subPhase / AudioMath.twoPi
                switch subWave {
                case .sine:
                    subSample = Float(sin(v.subPhase))
                case .triangle:
                    subSample = Float(4.0 * abs(normSub - 0.5) - 1.0)
                case .square:
                    subSample = normSub < 0.5 ? 1.0 : -1.0
                default:
                    subSample = Float(sin(v.subPhase))
                }
                sample = (sample + subSample * subVol) / (1.0 + subVol * 0.4)

                let subFreq = osc1Freq * (subOctave == -2 ? 0.25 : 0.5)
                let subInc = AudioMath.twoPi * subFreq / sampleRate
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

            let curvedVel: Float
            switch cachedVelocityCurve {
            case .linear:
                curvedVel = max(0.15, min(1.0, velValue))
            case .exponential:
                let clamped = max(0.0, min(1.0, velValue))
                curvedVel = max(0.15, clamped * clamped)
            case .logarithmic:
                let clamped = max(0.0, min(1.0, velValue))
                curvedVel = max(0.15, sqrt(clamped))
            }
            let effectiveVel = 1.0 - cachedVelocityToVolume * (1.0 - curvedVel)
            var amplitude = sample * envelopeValue * effectiveVel
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
            if perVoiceFilter {
                if v.filterControlTick & 3 == 0 {
                    var c = voiceFilterBaseCutoff
                    var envAmt = filterEnvAmt
                    if velToEnvAmt != 0 {
                        envAmt *= max(0.0, 1.0 + (v.velocity - 1.0) * velToEnvAmt)
                    }
                    if envAmt != 0 {
                        c *= pow(2, envAmt * filterEnvVal * 4)
                    }
                    if filterKeyTrk != 0 {
                        c *= pow(2, Float(v.midiNote - 60) / 12 * filterKeyTrk)
                    }
                    if velToCutoff > 0 {
                        c *= pow(2, (v.velocity - 1.0) * velToCutoff * 3.0)
                    }
                    if cachedAnalogDrift > 0 {
                        c *= v.driftCutoffMul
                    }
                    c = max(20, min(voiceFilterMaxCutoff, c))
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
                var c = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                if perVoiceFilter {
                    c = max(20, min(voiceFilterMaxCutoff, c))
                }
                let combed = comb.process(amplitude, cutoff: c, resonance: voiceFilterResonance, sampleRate: Float(sampleRate))
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
                    var c = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                    if perVoiceFilter {
                        var envAmt = filterEnvAmt
                        if velToEnvAmt != 0 {
                            envAmt *= max(0.0, 1.0 + (v.velocity - 1.0) * velToEnvAmt)
                        }
                        if envAmt != 0 {
                            c *= pow(2, envAmt * filterEnvVal * 4)
                        }
                        if filterKeyTrk != 0 {
                            c *= pow(2, Float(v.midiNote - 60) / 12 * filterKeyTrk)
                        }
                        if velToCutoff > 0 {
                            c *= pow(2, (v.velocity - 1.0) * velToCutoff * 3.0)
                        }
                        if cachedAnalogDrift > 0 {
                            c *= v.driftCutoffMul
                        }
                        c = max(20, min(voiceFilterMaxCutoff, c))
                    }
                    amplitude = v.ladder.process(
                        fed,
                        cutoff: c,
                        resonance: voiceFilterResonance,
                        drive: cachedFilterDrive,
                        sampleRate: Float(sampleRate)
                    )
                } else if cachedFilterDrive != 0 {
                    let driven = AudioMath.fastTanh(fed * (1 + cachedFilterDrive * 8))
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
                var c = perVoiceFilter ? voiceFilterBaseCutoff : cutoff
                if perVoiceFilter {
                    var envAmt = filterEnvAmt
                    if velToEnvAmt != 0 {
                        envAmt *= max(0.0, 1.0 + (v.velocity - 1.0) * velToEnvAmt)
                    }
                    if envAmt != 0 {
                        c *= pow(2, envAmt * filterEnvVal * 4)
                    }
                    if filterKeyTrk != 0 {
                        c *= pow(2, Float(v.midiNote - 60) / 12 * filterKeyTrk)
                    }
                    if velToCutoff > 0 {
                        c *= pow(2, (v.velocity - 1.0) * velToCutoff * 3.0)
                    }
                    if cachedAnalogDrift > 0 {
                        c *= v.driftCutoffMul
                    }
                    c = max(20, min(voiceFilterMaxCutoff, c))
                }
                amplitude = v.ladder.process(
                    amplitude,
                    cutoff: c,
                    resonance: voiceFilterResonance,
                    drive: cachedFilterDrive,
                    sampleRate: Float(sampleRate)
                )
            } else if cachedFilterDrive != 0 {
                let driven = AudioMath.fastTanh(amplitude * (1 + cachedFilterDrive * 8))
                amplitude = v.filter.process(driven, coeffs: voiceCoeffs)
            } else {
                amplitude = v.filter.process(amplitude, coeffs: voiceCoeffs)
            }
            if !amplitude.isFinite { amplitude = 0 }
            if cachedFilter2Routing != .off {
                let dual = voiceDualPtr[i].takeUnretainedValue()
                dual.routing = cachedFilter2Routing
                dual.type2 = cachedFilter2Type
                dual.cutoff2 = cachedFilter2Cutoff
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
        }

        if !mixedSampleL.isFinite { mixedSampleL = 0 }
        if !mixedSampleR.isFinite { mixedSampleR = 0 }

        let headroom: Float = 0.65
        var outL = mixedSampleL * smoothedMasterVolume * headroom
        var outR = mixedSampleR * smoothedMasterVolume * headroom
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

        let sendSourceL = cachedSendPostInsert ? outL : preInsertL
        let sendSourceR = cachedSendPostInsert ? outR : preInsertR

        if cachedSendA > 0 {
            if sendReverb.isClearing { sendReverb.cancelIncrementalClear() }
            sendFadeA += (cachedSendA - sendFadeA) * 0.1
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
                // R9-2: Smoothly fade out previous tail instead of hard cutting,
                // and incrementally clear the buffer without blocking render
                if !sendReverb.isClearing { sendReverb.startIncrementalClear() }
                sendFadeA = max(0, sendFadeA - (1.0 / 8.0))
                let wet = sendReverb.process(
                    inputL: 0,
                    inputR: 0,
                    room: cachedReverbRoom,
                    damp: cachedReverbDamping
                )
                outL += wet.0 * sendFadeA
                outR += wet.1 * sendFadeA
                sendReverb.clearIncremental(count: (sendReverb.totalCount / 8) + 1)
            } else if sendReverb.isClearing {
                sendReverb.clearIncremental(count: (sendReverb.totalCount / 8) + 1)
            }
        }

        if cachedSendB > 0 {
            if sendDelay.isClearing { sendDelay.cancelIncrementalClear() }
            sendFadeB += (cachedSendB - sendFadeB) * 0.1
            lastSendB = cachedSendB
            sendDelay.delayTime = cachedSendDelayTime
            sendDelay.feedback = cachedSendDelayFeedback
            let wet = sendDelay.process(inputL: sendSourceL, inputR: sendSourceR, mix: 1)
            outL += wet.0 * sendFadeB
            outR += wet.1 * sendFadeB
        } else {
            lastSendB = 0
            if sendFadeB > 0 {
                // R9-2: Smoothly fade out previous tail instead of hard cutting,
                // and incrementally clear the buffer without blocking render
                if !sendDelay.isClearing { sendDelay.startIncrementalClear() }
                sendFadeB = max(0, sendFadeB - (1.0 / 8.0))
                sendDelay.delayTime = cachedSendDelayTime
                sendDelay.feedback = cachedSendDelayFeedback
                let wet = sendDelay.process(inputL: 0, inputR: 0, mix: 1)
                outL += wet.0 * sendFadeB
                outR += wet.1 * sendFadeB
                sendDelay.clearIncremental(count: (sendDelay.totalCount / 8) + 1)
            } else if sendDelay.isClearing {
                sendDelay.clearIncremental(count: (sendDelay.totalCount / 8) + 1)
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

    /// ~5 ms one-pole toward the bend target. Idle bend stays exactly 1 and does no work.
    /// exp() only when portamento time or sample rate changes (same expression, bit-identical).
    @inline(__always) func portamentoGlideRate() -> Double {
        if cachedPortamento != glideRateForPortamento || sampleRate != glideRateSampleRate {
            glideRateForPortamento = cachedPortamento
            glideRateSampleRate = sampleRate
            glideRateCached = 1.0 - exp(-5.0 / (Double(cachedPortamento) * sampleRate))
        }
        return glideRateCached
    }

    /// 5 ms one-pole coefficient for bend/aftertouch; exp() only when the
    /// sample rate changes (same expression, so the value is bit-identical).
    @inline(__always) public func midiSmoothingCoeff() -> Float {
        if sampleRate != midiSmoothCoeffSampleRate {
            midiSmoothCoeffSampleRate = sampleRate
            midiSmoothCoeff = Float(1 - exp(-1.0 / (0.005 * sampleRate)))
        }
        return midiSmoothCoeff
    }

    public func advancePitchBend() -> Double {
        let target = pitchBendTarget
        if target == 0 && pitchBendSmoothed == 0 {
            return 1
        }
        let coeff = midiSmoothingCoeff()
        pitchBendSmoothed += (target - pitchBendSmoothed) * coeff
        if abs(target - pitchBendSmoothed) < 0.00002 {
            pitchBendSmoothed = target
        }
        if pitchBendSmoothed == 0 {
            cachedPitchBendMultiplier = 1
            cachedPitchBendMultiplierSmoothed = 0
            cachedPitchBendMultiplierRange = cachedPitchBendRange
            return 1
        }
        // Same bits as calling exp2 every sample. A held wheel repeats the input.
        if pitchBendSmoothed == cachedPitchBendMultiplierSmoothed
            && cachedPitchBendRange == cachedPitchBendMultiplierRange {
            return cachedPitchBendMultiplier
        }
        cachedPitchBendMultiplierSmoothed = pitchBendSmoothed
        cachedPitchBendMultiplierRange = cachedPitchBendRange
        cachedPitchBendMultiplier = exp2(Double(pitchBendSmoothed) * Double(cachedPitchBendRange) / 12)
        return cachedPitchBendMultiplier
    }

    /// ~5 ms one-pole toward aftertouch target. Idle aftertouch stays 0 and skips work.
    public func advanceAftertouch() -> Float {
        let target = aftertouchTarget
        if target == 0 && aftertouchSmoothed == 0 {
            return 0
        }
        let coeff = midiSmoothingCoeff()
        aftertouchSmoothed += (target - aftertouchSmoothed) * coeff
        if abs(target - aftertouchSmoothed) < 0.00002 {
            aftertouchSmoothed = target
        }
        return aftertouchSmoothed
    }

    public func pullPresetSnapshotRT() {
        if let snap = rtPresetBuffer.pullNewSnapshot() {
            applyPresetDSP(snap)
        }
    }

    public func processCommandQueue() {
        pullPresetSnapshotRT()
        commandQueue.drain(limit: 128) { [self] command in
            handleCommand(command)
        }
        midiQueue.drain(limit: 128) { [self] command in
            handleCommand(command)
        }
        if midiResetRequested.exchange(false, ordering: .acquiringAndReleasing) {
            // Whatever is still queued came from before the reset; drop it.
            midiQueue.discardPendingRT()
            applyMIDIResetRT()
        }
        // After the whole batch, so releasing a chord (held ends at 0) still rings.
        // A new chord in the same batch is already held, and only its oldest tails go.
        trimAbandonedTails()
    }

    public func handleCommand(_ command: AudioCommand) {
            switch command {
            case .resetPatchState:
                resetPatchStateRT()
            case .allNotesOff:
                releaseAllHeldNotesRT()
            case .keyDown(let midiNote, let velocity):
                if cachedArpMode != .off {
                    handleCommand(.arpKeyDown(midiNote: midiNote))
                } else {
                    handleNoteOn(midiNote: midiNote, velocity: velocity)
                }
            case .keyUp(let midiNote):
                // Follow where the key went, so an arp toggle mid-hold cannot strand it.
                if heldKeysForArp.contains(midiNote) {
                    handleCommand(.arpKeyUp(midiNote: midiNote))
                } else {
                    handleNoteOff(midiNote: midiNote)
                }
            case .noteOn(let midiNote, let velocity):
                handleNoteOn(midiNote: midiNote, velocity: velocity)
            case .noteOff(let midiNote):
                handleNoteOff(midiNote: midiNote)
            case .mpeKeyDown(let midiNote, let velocity, let channel):
                handleNoteOn(midiNote: midiNote, velocity: velocity, channel: channel)
            case .mpeKeyUp(let midiNote, let channel):
                handleNoteOff(midiNote: midiNote, channel: channel)
            case .mpePitchBend(let channel, let value):
                let ch = Int(channel & 15)
                mpeChannelStates[ch].pitchBend = value
                let mul = exp2(Double(value) * Double(cachedMpePitchBendRange) / 12.0)
                mpeChannelStates[ch].pitchBendMultiplier = mul
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiChannel == channel {
                        voices[i].mpePitchBend = value
                        voices[i].mpePitchBendMultiplier = mul
                    }
                }
            case .mpePressure(let channel, let value):
                let ch = Int(channel & 15)
                mpeChannelStates[ch].pressure = value
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiChannel == channel {
                        voices[i].mpePressure = value
                    }
                }
            case .mpeTimbre(let channel, let value):
                let ch = Int(channel & 15)
                mpeChannelStates[ch].timbre = value
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiChannel == channel {
                        voices[i].mpeTimbre = value
                    }
                }
            case .setPitchBend(let amount):
                pitchBendTarget = amount
            case .setModWheel(let amount):
                modWheel = amount
            case .setAftertouch(let amount):
                aftertouchTarget = amount
            case .setPolyAftertouch(let midiNote, let pressure):
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiNote == midiNote {
                        voices[i].polyAftertouch = pressure
                    }
                }
                // Poly pressure is per-voice only; channel aftertouch owns aftertouchTarget.
            case .setSustain(let down):
                setSustainPedal(down: down)
            case .controlChange(let cc, let value):
                let rtIdx = (rtCCMap + Int(cc & 127)).pointee.load(ordering: .acquiring)
                if rtIdx >= 0, let target = MIDIControlTarget.from(rtIndex: rtIdx) {
                    if !target.writesAudioParameter || ccTakeoverShouldApply(cc: cc, raw: value, current: liveUnit(for: target), target: target) {
                        applySingleParameterRT(target: target, rawValue: value)
                    }
                }
            case .midiClock:
                receiveMIDIClockRT()
            case .midiStart:
                applyMIDITransportRT(resetPhase: true, running: true)
            case .midiContinue:
                applyMIDITransportRT(resetPhase: false, running: true)
            case .midiStop:
                applyMIDITransportRT(resetPhase: false, running: false)
            case .setAddressedParameter(let id, let value):
                applyAddressedParameterRT(id: id, value: value)
            case .setFXOrder(let table):
                cachedFXOrder = table
            case .clearAll:
                clearAllVoices()
                // A new patch / panic must not inherit a bent pitch or a stuck pedal.
                pitchBendTarget = 0
                pitchBendSmoothed = 0
                cachedPitchBendMultiplier = 1
                cachedPitchBendMultiplierSmoothed = 0
                cachedPitchBendMultiplierRange = 0
                aftertouchTarget = 0
                aftertouchSmoothed = 0
                cachedMacro1 = 0
                cachedMacro2 = 0
                cachedMacro3 = 0
                cachedMacro4 = 0
                for i in 0..<16 {
                    mpeChannelStates[i] = MPEChannelState()
                }
                sustainPedalDown = false
                sustainedLo = 0
                sustainedHi = 0
                heldKeysForArp.removeAll()
                latchedKeysForArp.removeAll()
                playedKeysForArp.removeAll(keepingCapacity: true)
                arp.reset()
                arpGateSamplesLeft = 0
                arpStepIndex = 0
                seqMirror.heldNote = -1
                seqMirror.gateSamplesLeft = 0
                filterL.reset()
                filterR.reset()
                lfo.reset()
            case .arpKeyDown(let midiNote):
                if cachedArpLatch && heldKeysForArp.isEmpty {
                    latchedKeysForArp.removeAll()
                    playedKeysForArp.removeAll(keepingCapacity: true)
                }
                heldKeysForArp.insert(midiNote)
                if !playedKeysForArp.contains(midiNote) {
                    playedKeysForArp.append(midiNote)
                }
                arp.mode = cachedArpMode
                arp.octaves = cachedArpOctaves
                arp.latch = cachedArpLatch
                if cachedArpLatch {
                    latchedKeysForArp.insert(midiNote)
                    arp.setHeldKeys(latchedKeysForArp, playedOrder: playedKeysForArp)
                } else {
                    arp.setHeldKeys(heldKeysForArp, playedOrder: playedKeysForArp)
                }
            case .arpKeyUp(let midiNote):
                heldKeysForArp.remove(midiNote)
                arp.mode = cachedArpMode
                arp.octaves = cachedArpOctaves
                arp.latch = cachedArpLatch
                if !cachedArpLatch {
                    playedKeysForArp.removeAll { $0 == midiNote }
                    arp.setHeldKeys(heldKeysForArp, playedOrder: playedKeysForArp)
                } else {
                    arp.setHeldKeys(latchedKeysForArp, playedOrder: playedKeysForArp)
                }
            }
    }

    /// Sample-accurate 16th-note clock. Swing delays user-facing even steps
    /// (2, 4, 6… — odd indices) by `swing * step * 0.5` and shortens them so
    /// the bar length stays constant. No allocation.
    public func advanceSequencerOneSample() {
        let generationChanged = sequencerTransport.pullIfChanged(into: &seqMirror)
        if usesHostTransport || cachedSyncSource == .midiClock {
            seqMirror.bpm = cachedBPM
        }
        if generationChanged {
            releaseSequencerNote()
            seqMirror.stepIndex = 0
            seqMirror.phase = 0
            seqMirror.armed = seqMirror.playing
            seqMirror.stepSkipped = false
            seqMirror.ratchetIndex = 0
            sequencerTransport.setDisplayStep(0)
        }

        guard seqMirror.playing else { return }

        if seqMirror.length < 1 { seqMirror.length = 1 }
        if seqMirror.stepIndex >= seqMirror.length { seqMirror.stepIndex = 0 }

        if seqMirror.armed {
            seqMirror.armed = false
            triggerSequencerStep()
        } else {
            let step = seqMirror.steps[seqMirror.stepIndex]
            let stepDuration = sequencerStepDuration(stepIndex: seqMirror.stepIndex)
            let ratchet = max(1, Int(step.ratchet))
            let subDuration = stepDuration / Double(ratchet)

            if !seqMirror.stepSkipped && ratchet > 1 {
                let currentSubIndex = min(ratchet - 1, Int(seqMirror.phase / max(1.0, subDuration)))
                if currentSubIndex > seqMirror.ratchetIndex {
                    seqMirror.ratchetIndex = currentSubIndex
                    triggerRatchetSubStep(step: step, subDuration: subDuration)
                }
            }

            if seqMirror.gateSamplesLeft > 0 {
                seqMirror.gateSamplesLeft -= 1
                if seqMirror.gateSamplesLeft == 0 {
                    let nextIndex = (seqMirror.stepIndex + 1) % seqMirror.length
                    let nextStep = seqMirror.steps[nextIndex]
                    if !nextStep.tie || !nextStep.isActive || ratchet > 1 {
                        releaseSequencerNote()
                    }
                }
            }
        }

        let length = sequencerStepDuration(stepIndex: seqMirror.stepIndex)
        seqMirror.phase += 1
        if seqMirror.phase >= length {
            seqMirror.phase -= length
            seqMirror.stepIndex = (seqMirror.stepIndex + 1) % seqMirror.length
            seqMirror.ratchetIndex = 0
            sequencerTransport.setDisplayStep(seqMirror.stepIndex)
            triggerSequencerStep()
        }
    }

    public func sequencerStepDuration(stepIndex: Int) -> Double {
        let bpm = Double(max(20, seqMirror.bpm))
        let samplesPerStep = sampleRate * 60.0 / bpm / 4.0
        let swing = Double(min(1, max(0, seqMirror.swing)))
        let offset = swing * samplesPerStep * 0.5
        if stepIndex % 2 == 0 {
            return samplesPerStep + offset
        }
        return max(1, samplesPerStep - offset)
    }

    public func triggerSequencerStep() {
        let index = seqMirror.stepIndex
        guard index >= 0 && index < SequencerTransport.stepCount else { return }

        let step = seqMirror.steps[index]
        guard step.isActive else {
            seqMirror.stepSkipped = true
            releaseSequencerNote()
            return
        }

        if step.probability < 1.0 {
            seqMirror.prngState ^= seqMirror.prngState << 13
            seqMirror.prngState ^= seqMirror.prngState >> 17
            seqMirror.prngState ^= seqMirror.prngState << 5
            let roll = Float(seqMirror.prngState & 0xFFFF) / 65535.0
            if roll > step.probability {
                seqMirror.stepSkipped = true
                releaseSequencerNote()
                return
            }
        }
        seqMirror.stepSkipped = false

        let raw = seqMirror.rootNote + Int(step.noteOffset) + Int(step.octave) * 12
        let midi = max(0, min(127, raw))

        if step.tie && seqMirror.heldNote >= 0 {
            // Slide / Tie: Retain existing voice, glide target frequency to new pitch
            let newFreq = AudioMath.midiToFrequency(midi)
            for i in 0..<AudioEngine.maxVoices {
                if voices[i].isActive && voices[i].midiNote == seqMirror.heldNote {
                    voices[i].midiNote = midi
                    voices[i].targetFrequency = newFreq
                }
            }
            seqMirror.heldNote = midi
        } else {
            releaseSequencerNote()
            createVoice(midiNote: midi, velocity: step.velocity)
            seqMirror.heldNote = midi
        }

        let stepDuration = sequencerStepDuration(stepIndex: index)
        let ratchet = max(1, Int(step.ratchet))
        let subDuration = stepDuration / Double(ratchet)
        let effectiveGate = Double(step.gate)
        seqMirror.gateSamplesLeft = max(1, Int((subDuration * effectiveGate).rounded(.down)))
    }

    public func triggerRatchetSubStep(step: SequencerStepRT, subDuration: Double) {
        let raw = seqMirror.rootNote + Int(step.noteOffset) + Int(step.octave) * 12
        let midi = max(0, min(127, raw))
        releaseSequencerNote()
        createVoice(midiNote: midi, velocity: step.velocity)
        seqMirror.heldNote = midi
        let effectiveGate = Double(step.gate)
        seqMirror.gateSamplesLeft = max(1, Int((subDuration * effectiveGate).rounded(.down)))
    }

    public func releaseSequencerNote() {
        guard seqMirror.heldNote >= 0 else { return }
        releaseHeldNote(seqMirror.heldNote)
        seqMirror.heldNote = -1
        seqMirror.gateSamplesLeft = 0
    }

    @inline(__always)
    public func currentArpStepDuration() -> Double {
        let base = samplesPerTick
        if cachedArpSwing > 0.001 {
            let offset = Double(cachedArpSwing) * base * 0.5
            if arpStepIndex % 2 == 0 {
                return base + offset
            } else {
                return max(1.0, base - offset)
            }
        }
        return base
    }

    public func handleArpTick(stepDuration: Double) {
        if let oldNote = arp.currentNote {
            releaseHeldNote(oldNote)
        }

        guard let newNote = arp.advanceTick(randomSource: &noiseSeed) else {
            arp.currentNote = nil
            arpGateSamplesLeft = 0
            trimAbandonedTails()
            return
        }
        createVoice(midiNote: newNote, velocity: 0.8)
        let gateFrac = Double(max(0.1, min(1.0, cachedArpGateLength)))
        arpGateSamplesLeft = max(1, Int((stepDuration * gateFrac).rounded(.down)))
        trimAbandonedTails()
    }

    public func applySingleParameterRT(target: MIDIControlTarget, rawValue: UInt8) {
        let norm = Float(rawValue) / 127.0
        switch target {
        case .cutoff:
            cachedFilterCutoff = 20.0 * pow(1000.0, norm)
        case .resonance:
            ccResonanceRT = norm * 0.95
            ccResonanceBaseRT = filterL.resonance
        case .amp:
            cachedMasterVolume = norm
        case .pan:
            ccPanTarget = (norm - 0.5) * 2.0
        case .pitch1:
            ccDetune1Target = (norm - 0.5) * 100.0
        case .pitch2:
            ccDetune2Target = (norm - 0.5) * 100.0
        case .finePitch:
            ccDetune1Target = (norm - 0.5) * 100.0
            ccDetune2Target = (norm - 0.5) * 100.0
        case .pwm1:
            ccPwm1Target = 0.1 + norm * 0.8
        case .pwm2:
            ccPwm2Target = 0.1 + norm * 0.8
        case .wtMorph1:
            ccWtMorph1Target = norm
        case .wtMorph2:
            ccWtMorph2Target = norm
        case .lfoRate:
            ccLfoRateTarget = 0.05 + norm * 19.95
        case .lfoDepth:
            ccLfoDepthTarget = norm
        case .mix, .osc2Volume:
            ccMixTarget = norm
        case .attack:
            ccAttackTarget = 0.001 + norm * 1.999
        case .decay:
            ccDecayTarget = 0.001 + norm * 1.999
        case .sustain:
            ccSustainTarget = norm
        case .release:
            ccReleaseTarget = 0.001 + norm * 2.999
        case .filterAttack:
            ccFilterAttackTarget = 0.001 + norm * 1.999
        case .filterDecay:
            ccFilterDecayTarget = 0.001 + norm * 1.999
        case .filterSustain:
            ccFilterSustainTarget = norm
        case .filterRelease:
            ccFilterReleaseTarget = 0.001 + norm * 2.999
        case .filterEnvelopeAmount:
            cachedFilterEnvAmount = (norm - 0.5) * 2.0
        case .reverbMix:
            cachedReverbMix = max(0, min(1, norm))
            parameterReverbMix = cachedReverbMix
        case .reverbRoomSize:
            cachedReverbRoom = max(0, min(1, norm))
            parameterReverbRoom = cachedReverbRoom
        case .reverbShimmer:
            cachedReverbShimmer = norm
        case .delayMix:
            pingPongDelay.mix = norm
        case .delayTime:
            pingPongDelay.delayTime = 0.01 + norm * 0.99
        case .delayFeedback:
            pingPongDelay.feedback = norm * 0.9
        case .chorusMix:
            dspChorus.mix = norm
        case .chorusRate:
            dspChorus.rate = 0.1 + norm * 4.9
        case .chorusDepth:
            dspChorus.depth = norm
        case .distortionMix:
            distortion.mix = norm
        case .distortionDrive:
            distortion.drive = norm
        case .phaserMix:
            phaser.mix = norm
        case .phaserRate:
            phaser.rate = 0.05 + norm * 4.95
        case .phaserDepth:
            phaser.depth = norm
        case .osc1Volume:
            oscillator1.volume = norm
        case .subOscVolume:
            cachedSubOscVolume = norm
        case .fmAmount:
            cachedFmAmount = norm
        case .ringModAmount:
            cachedRingModAmount = norm
        case .unisonDetune:
            cachedUnisonDetune = norm * 50.0
        case .unisonSpread:
            cachedUnisonSpread = norm
        case .analogDrift:
            cachedAnalogDrift = norm
        case .portamento:
            cachedPortamento = norm
        case .macro1:
            cachedMacro1 = (norm - 0.5) * 2.0
        case .macro2:
            cachedMacro2 = (norm - 0.5) * 2.0
        case .macro3:
            cachedMacro3 = (norm - 0.5) * 2.0
        case .macro4:
            cachedMacro4 = (norm - 0.5) * 2.0
        case .macro5:
            cachedMacro5 = (norm - 0.5) * 2.0
        case .macro6:
            cachedMacro6 = (norm - 0.5) * 2.0
        case .macro7:
            cachedMacro7 = (norm - 0.5) * 2.0
        case .macro8:
            cachedMacro8 = (norm - 0.5) * 2.0
        }
    }
}
