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
        aftertouch: Float = 0
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
        }
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

        // Single writer: preset (main) and CC1 (MIDI) only feed the inputs.
        lfo.depth = cachedLfoDepth + (1 - cachedLfoDepth) * modWheel
        let pitchBendMultiplier = advancePitchBend()
        let currentAftertouch = advanceAftertouch()
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let (modSlots, modCount) = rtModMatrix.snapshot()

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
                    aftertouch: currentAftertouch
                )
                let modVal = src * entry.amount
                switch entry.destination {
                case .lfoRate: rateMod += modVal
                case .lfoDepth: depthMod += modVal
                case .pitch1, .pitch2, .cutoff, .resonance, .amp, .pan, .pwm1, .pwm2, .mix, .wtMorph1, .wtMorph2:
                    break
                }
            }
        }
        if depthMod != 0 {
            lfo.depth = max(0, min(1, lfo.depth + depthMod))
        }
        // Raw bipolar LFO; the direct target gets raw × Depth (same product as before).
        let lfoRaw: Float
        if lfoEnabled || matrixWantsLFO {
            if rateMod != 0 {
                let scaled = lfo.rate * pow(2, 2 * rateMod)
                let clamped = max(0.01, min(40, scaled))
                lfoRaw = lfo.nextRawValue(sampleRate: sampleRate, rateOverride: clamped)
            } else {
                lfoRaw = lfo.nextRawValue(sampleRate: sampleRate)
            }
        } else {
            lfoRaw = 0
        }
        let lfoValue = lfoRaw * lfo.depth
        // Matrix rows: Amount is the depth. Older patches keep rows × Depth.
        let matrixLFO = cachedLfoRowsFollowDepth ? lfoValue : lfoRaw
        lastMatrixLFO = matrixLFO

        // LFO 2
        lfo2.depth = cachedLfo2Depth
        let lfo2Enabled = lfo2.enabled
        let lfo2Target = lfo2.target
        let lfo2Raw: Float
        if lfo2Enabled || matrixWantsLFO2 {
            lfo2Raw = lfo2.nextRawValue(sampleRate: sampleRate)
        } else {
            lfo2Raw = 0
        }
        let lfo2Value = lfo2Raw * lfo2.depth
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
                    aftertouch: currentAftertouch
                )
                let modVal = src * entry.amount
                switch entry.destination {
                case .cutoff: cutoffMod += modVal
                case .resonance: resonanceMod += modVal
                case .wtMorph1: wtMorphMod1 += modVal
                case .wtMorph2: wtMorphMod2 += modVal
                case .pitch1, .pitch2, .amp, .pan, .pwm1, .pwm2, .lfoRate, .lfoDepth, .mix:
                    break
                }
            }
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

        // Phase 3: Sub-Osc, FM, and Hard Sync cached settings
        let fmAmount = cachedFmAmount
        let oscSync = cachedOscSyncEnabled
        let subVol = cachedSubOscVolume
        let subOctave = cachedSubOscOctave
        let subWave = cachedSubOscWaveform

        // Same for every voice: one exp() per sample, not one per voice.
        let glides = cachedPortamento > 0.001
        let glideRate = glides ? portamentoGlideRate() : 0

        // Fixed pool scan — work on a local copy to satisfy exclusivity + keep RT simple.
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            var v = voices[i]

            if glides {
                v.currentFrequency += (v.targetFrequency - v.currentFrequency) * glideRate
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

            var pitchMod1: Float = 0
            var pitchMod2: Float = 0
            var ampMod: Float = 0
            var panMod: Float = 0
            var pwmMod1: Float = 0
            var pwmMod2: Float = 0
            var mixMod: Float = 0

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
                        aftertouch: max(currentAftertouch, v.polyAftertouch)
                    )
                    let modVal = sourceVal * entry.amount
                    switch entry.destination {
                    case .pitch1: pitchMod1 += modVal
                    case .pitch2: pitchMod2 += modVal
                    case .amp: ampMod += modVal
                    case .pan: panMod += modVal
                    case .pwm1: pwmMod1 += modVal
                    case .pwm2: pwmMod2 += modVal
                    case .mix: mixMod += modVal
                    case .cutoff, .resonance, .lfoRate, .lfoDepth, .wtMorph1, .wtMorph2:
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

            osc1Freq = max(20.0, min(sampleRate * 0.45, osc1Freq))
            osc2Freq = max(20.0, min(sampleRate * 0.45, osc2Freq))

            let phaseInc1 = AudioMath.twoPi * osc1Freq / sampleRate
            let phaseInc2 = AudioMath.twoPi * osc2Freq / sampleRate

            let s2: Float
            if cachedOsc2Enabled || fmAmount > 0 || cachedRingModAmount > 0 {
                s2 = oscillator2.generateSample(
                    phase: v.phase2,
                    phaseIncrement: phaseInc2,
                    noiseValue: noiseValue,
                    pulseWidthOverride: pwmMod2 == 0 ? nil : max(0.05, min(0.95, oscillator2.pulseWidth + pwmModulationSpan * pwmMod2))
                )
            } else {
                s2 = 0
            }

            var osc1Phase = v.phase
            if fmAmount > 0 {
                osc1Phase += Double(s2 * fmAmount * Float.pi)
                osc1Phase = osc1Phase.truncatingRemainder(dividingBy: AudioMath.twoPi)
                if osc1Phase < 0 { osc1Phase += AudioMath.twoPi }
            }

            let s1 = oscillator1.generateSample(
                phase: osc1Phase,
                phaseIncrement: phaseInc1,
                noiseValue: noiseValue,
                pulseWidthOverride: pwmMod1 == 0 ? nil : max(0.05, min(0.95, oscillator1.pulseWidth + pwmModulationSpan * pwmMod1))
            )
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

            var amplitude = sample * envelopeValue * max(0.15, min(1.0, velValue))
            amplitude *= max(0.0, 1.0 + ampMod)
            amplitude *= AudioMath.voiceGain * v.unisonScale
            if lfoEnabled && lfoTarget == .amplitude {
                amplitude = lfo.modulateAmplitude(amplitude, lfoValue: lfoValue)
            }
            if lfo2Enabled && lfo2Target == .amplitude {
                amplitude = lfo2.modulateAmplitude(amplitude, lfoValue: lfo2Value)
            }
            if !amplitude.isFinite { amplitude = 0 }
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
            if voiceFilterType == .ladder {
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

            var pan = v.pan + panMod
            if ccPanRT != 0 { pan += ccPanRT }
            if lfoEnabled && lfoTarget == .pan { pan += lfoValue }
            if lfo2Enabled && lfo2Target == .pan { pan += lfo2Value }
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

        // EQ before the rider. A boost after it walked straight into the ceiling
        // and rasped; the rider now holds that extra level with one linear gain.
        if parametricEQL.enabled {
            if !parametricEQR.enabled { parametricEQR.enabled = true }
            fxL = parametricEQL.process(fxL)
            fxR = parametricEQR.process(fxR)
        }

        (fxL, fxR) = cleanBus.process(
            left: fxL,
            right: fxR,
            sampleRate: Float(sampleRate)
        )

        if distortion.enabled {
            (fxL, fxR) = distortion.processStereo(inputL: fxL, inputR: fxR)
        }
        if !phaser.bypass {
            let p = phaser.process(inputL: fxL, inputR: fxR)
            fxL = p.left
            fxR = p.right
        }

        var (outL, outR) = dspChorus.process(inputL: fxL, inputR: fxR)

        if cachedDelayPingPong {
            (outL, outR) = pingPongDelay.process(inputL: outL, inputR: outR)
        }

        if cachedReverbShimmer > 0 {
            let (shimL, shimR) = shimmer.process(inputL: outL, inputR: outR)
            outL += shimL * cachedReverbShimmer
            outR += shimR * cachedReverbShimmer
        }

        if lfoEnabled && lfoTarget == .pan {
            let panVal = max(-1, min(1, lfoValue))
            let a = (panVal + 1) * Float.pi / 4
            outL *= cos(a)
            outR *= sin(a)
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
                meteringState.writeScopeBuffer(scopeBuffer)
            }
        }

        if !outL.isFinite { outL = 0 }
        if !outR.isFinite { outR = 0 }
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

    public func processCommandQueue() {
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
                sustainPedalDown = false
                sustainedLo = 0
                sustainedHi = 0
                heldKeysForArp.removeAll()
                arp.reset()
                arpGateSamplesLeft = 0
                arpStepIndex = 0
                seqMirror.heldNote = -1
                seqMirror.gateSamplesLeft = 0
                filterL.reset()
                filterR.reset()
                lfo.reset()
            case .arpKeyDown(let midiNote):
                heldKeysForArp.insert(midiNote)
                arp.mode = cachedArpMode
                arp.octaves = cachedArpOctaves
                arp.setHeldKeys(heldKeysForArp)
            case .arpKeyUp(let midiNote):
                heldKeysForArp.remove(midiNote)
                arp.mode = cachedArpMode
                arp.octaves = cachedArpOctaves
                arp.setHeldKeys(heldKeysForArp)
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
        case .pwm1:
            ccPwm1Target = 0.1 + norm * 0.8
        case .pwm2:
            ccPwm2Target = 0.1 + norm * 0.8
        case .wtMorph1:
            oscillator1.wavetableMorph = norm
        case .wtMorph2:
            oscillator2.wavetableMorph = norm
        case .lfoRate:
            ccLfoRateTarget = 0.05 + norm * 19.95
        case .lfoDepth:
            cachedLfoDepth = norm
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
            let a = 0.001 + norm * 1.999
            filterEnvelope.attack = a
            cachedFilterAttack = a
        case .filterDecay:
            let d = 0.001 + norm * 1.999
            filterEnvelope.decay = d
            cachedFilterDecay = d
        case .filterSustain:
            filterEnvelope.sustain = norm
            cachedFilterSustain = norm
        case .filterRelease:
            let rel = 0.001 + norm * 2.999
            filterEnvelope.release = rel
            cachedFilterRelease = rel
        case .filterEnvelopeAmount:
            cachedFilterEnvAmount = (norm - 0.5) * 2.0
        case .reverbMix, .reverbRoomSize:
            break
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
        }
    }
}
