//
//  AudioEngine+ModulationRT.swift
//  Synt_swiftUI
//
//  Real-time modulation matrix, filter cutoff, trance gate, and MIDI/expression
//  controller helpers extracted from AudioEngine+Render.swift.
//

import Foundation
import Synchronization

public extension AudioEngine {
    /// Samples matrix rows that move envelope times. Called only when the preset has one.
    func latchEnvTime(
        _ voice: inout ActiveNote,
        slots: UnsafePointer<RTModSlot>,
        count: Int,
        lfo: Float,
        lfo2: Float,
        aftertouch: Float,
        smoothRandom: Float,
        mseg: Float,
        mseg2: Float
    ) {
        if voice.envelopePhase != voice.latchedAmpPhase {
            voice.latchedAmpPhase = voice.envelopePhase
            if let dest = Self.envTimeDestination(phase: voice.envelopePhase, filter: false) {
                let mul = envTimeMultiplier(
                    dest, voice: voice, slots: slots, count: count,
                    lfo: lfo, lfo2: lfo2, aftertouch: aftertouch,
                    smoothRandom: smoothRandom, mseg: mseg, mseg2: mseg2
                )
                switch voice.envelopePhase {
                case .attack, .delay, .hold: voice.ampAttackMul = mul
                case .decay: voice.ampDecayMul = mul
                case .release: voice.ampReleaseMul = mul
                case .sustain, .finished: break
                }
            }
        }
        if voice.filterEnvelopePhase != voice.latchedFilterPhase {
            voice.latchedFilterPhase = voice.filterEnvelopePhase
            if let dest = Self.envTimeDestination(phase: voice.filterEnvelopePhase, filter: true) {
                let mul = envTimeMultiplier(
                    dest, voice: voice, slots: slots, count: count,
                    lfo: lfo, lfo2: lfo2, aftertouch: aftertouch,
                    smoothRandom: smoothRandom, mseg: mseg, mseg2: mseg2
                )
                switch voice.filterEnvelopePhase {
                case .attack, .delay, .hold: voice.filterAttackMul = mul
                case .decay: voice.filterDecayMul = mul
                case .release: voice.filterReleaseMul = mul
                case .sustain, .finished: break
                }
            }
        }
    }

    static func envTimeDestination(phase: EnvelopePhase, filter: Bool) -> ModDestination? {
        switch phase {
        case .attack, .delay, .hold: return filter ? .filterAttack : .ampAttack
        case .decay: return filter ? .filterDecay : .ampDecay
        case .release: return filter ? .filterRelease : .ampRelease
        case .sustain, .finished: return nil
        }
    }

    func envTimeMultiplier(
        _ destination: ModDestination,
        voice: ActiveNote,
        slots: UnsafePointer<RTModSlot>,
        count: Int,
        lfo: Float,
        lfo2: Float,
        aftertouch: Float,
        smoothRandom: Float,
        mseg: Float,
        mseg2: Float
    ) -> Float {
        var sum: Float = 0
        let key = Float(voice.midiNote - 60) / 12
        for slot in 0..<count {
            let entry = slots[slot]
            if entry.destination != destination { continue }
            sum += rowAmount(
                entry,
                slot: slot,
                lfo: lfo,
                lfo2: lfo2,
                env: voice.envelopeValue,
                velocity: voice.velocity,
                modWheel: modWheel,
                keyTrack: key,
                env2: voice.filterEnvelopeValue,
                aftertouch: max(aftertouch, shapeAftertouch(voice.polyAftertouch)),
                modEnv: voice.modEnvelopeValue,
                pitchBend: pitchBendSmoothed,
                random: voice.randomValue,
                sampleAndHold: self.lfo.lastRandomValue,
                smoothRandom: smoothRandom,
                mseg: mseg,
                mseg2: mseg2,
                mpePitchBend: voice.smoothedMpePitchBend,
                mpePressure: voice.smoothedMpePressure,
                mpeTimbre: voice.smoothedMpeTimbre,
                releaseVelocity: voice.releaseVelocity
            )
        }
        if sum == 0 { return 1 }
        return exp2(max(-2, min(2, sum)))
    }

    @inline(__always)
    func matrixSource(
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
        mseg2: Float = 0,
        mpePitchBend: Float = 0,
        mpePressure: Float = 0,
        mpeTimbre: Float = 0,
        releaseVelocity: Float = 0.5
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
        case .mpePitchBend: return mpePitchBend
        case .mpePressure: return mpePressure
        case .mpeTimbre: return mpeTimbre
        case .releaseVelocity: return releaseVelocity
        }
    }

    /// Linear rows with a flat shape multiply the raw source. Any other row reads the bank
    /// published off the audio thread. `pow` stays in `RTModMatrix.publish`.
    @inline(__always)
    func modulatedAmount(_ entry: RTModSlot, slot: Int, source: Float) -> Float {
        let shaped: Float
        if entry.curve == .linear && entry.curveShape == 0 {
            shaped = source
        } else {
            shaped = rtModMatrix.lookup(bank: entry.tableBank, slot: slot, source: source)
        }
        return shaped * entry.amount
    }

    /// `amount_eff = amount · via` when a via source is set. A nil via skips the multiply.
    @inline(__always)
    func rowAmount(
        _ entry: RTModSlot,
        slot: Int,
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
        mseg2: Float = 0,
        mpePitchBend: Float = 0,
        mpePressure: Float = 0,
        mpeTimbre: Float = 0,
        releaseVelocity: Float = 0.5
    ) -> Float {
        let source = matrixSource(
            entry.source,
            lfo: lfo,
            lfo2: lfo2,
            env: env,
            velocity: velocity,
            modWheel: modWheel,
            keyTrack: keyTrack,
            env2: env2,
            aftertouch: aftertouch,
            modEnv: modEnv,
            pitchBend: pitchBend,
            random: random,
            sampleAndHold: sampleAndHold,
            smoothRandom: smoothRandom,
            mseg: mseg,
            mseg2: mseg2,
            mpePitchBend: mpePitchBend,
            mpePressure: mpePressure,
            mpeTimbre: mpeTimbre,
            releaseVelocity: releaseVelocity
        )
        let shaped = modulatedAmount(entry, slot: slot, source: source)
        guard let via = entry.viaSource else { return shaped }
        let viaValue = matrixSource(
            via,
            lfo: lfo,
            lfo2: lfo2,
            env: env,
            velocity: velocity,
            modWheel: modWheel,
            keyTrack: keyTrack,
            env2: env2,
            aftertouch: aftertouch,
            modEnv: modEnv,
            pitchBend: pitchBend,
            random: random,
            sampleAndHold: sampleAndHold,
            smoothRandom: smoothRandom,
            mseg: mseg,
            mseg2: mseg2,
            mpePitchBend: mpePitchBend,
            mpePressure: mpePressure,
            mpeTimbre: mpeTimbre,
            releaseVelocity: releaseVelocity
        )
        return shaped * viaValue
    }

    @inline(__always)
    static func isPerVoiceCutoffSource(_ source: ModSource) -> Bool {
        switch source {
        case .env2, .modEnv, .random, .releaseVelocity: return true
        default: return false
        }
    }

    /// Shared per-voice cutoff law. Extra mods are skipped when they are zero, so the
    /// biquad and ladder paths stay the shipped product.
    @inline(__always)
    func voiceCutoffHz(
        base: Float,
        envAmt: Float,
        filterEnvMod: Float,
        filterEnvVal: Float,
        velToEnvAmt: Float,
        velocity: Float,
        keyTrk: Float,
        midiNote: Int,
        velToCutoff: Float,
        drift: Float,
        driftMul: Float,
        maxCutoff: Float,
        voiceCutoffMod: Float
    ) -> Float {
        var c = base
        var envAmt = envAmt
        if filterEnvMod != 0 { envAmt += filterEnvMod }
        if velToEnvAmt != 0 {
            envAmt *= max(0.0, 1.0 + (velocity - 1.0) * velToEnvAmt)
        }
        if envAmt != 0 {
            c *= pow(2, envAmt * filterEnvVal * 4)
        }
        if keyTrk != 0 {
            c *= pow(2, Float(midiNote - 60) / 12 * keyTrk)
        }
        if velToCutoff > 0 {
            c *= pow(2, (velocity - 1.0) * velToCutoff * 3.0)
        }
        if drift > 0 {
            c *= driftMul
        }
        if voiceCutoffMod != 0 {
            c *= pow(2, voiceCutoffMod * 4)
        }
        return max(20, min(maxCutoff, c))
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
    @inline(__always) func midiSmoothingCoeff() -> Float {
        if sampleRate != midiSmoothCoeffSampleRate {
            midiSmoothCoeffSampleRate = sampleRate
            midiSmoothCoeff = Float(1 - exp(-1.0 / (0.005 * sampleRate)))
        }
        return midiSmoothCoeff
    }

    func advancePitchBend() -> Double {
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
    /// Curve and deadzone are applied once on the smoothed value. Both zero is identity.
    func advanceAftertouch() -> Float {
        let target = aftertouchTarget
        if target == 0 && aftertouchSmoothed == 0 {
            return 0
        }
        let coeff = midiSmoothingCoeff()
        aftertouchSmoothed += (target - aftertouchSmoothed) * coeff
        if abs(target - aftertouchSmoothed) < 0.00002 {
            aftertouchSmoothed = target
        }
        return shapeAftertouch(aftertouchSmoothed)
    }

    /// Deadzone, then the same power law as the matrix curve. Identity when both are 0.
    @inline(__always)
    func shapeAftertouch(_ raw: Float) -> Float {
        let deadzone = cachedAftertouchDeadzone
        let curve = cachedAftertouchCurve
        if deadzone == 0 && curve == 0 { return raw }
        var x = raw
        if deadzone > 0 {
            if x <= deadzone { return 0 }
            let span = 1 - deadzone
            x = span > 0 ? (x - deadzone) / span : 0
        }
        if curve == 0 || x == 0 || x == 1 { return x }
        return pow(x, exp2(-3 * curve))
    }

    /// CC byte from a 0…1 controller. `rounded` so n/127 round-trips for n = 0…127.
    static func midiControllerByte(_ value: Float) -> UInt8 {
        let clamped = min(1, max(0, value))
        return UInt8((clamped * 127).rounded())
    }

    /// 5 ms one-pole on a 0…1 controller that rests at 1. Idle unity does no work.
    @inline(__always)
    func advanceUnityController(target: Float, smoothed: inout Float) -> Float {
        if target == 1 && smoothed == 1 { return 1 }
        let coeff = midiSmoothingCoeff()
        smoothed += (target - smoothed) * coeff
        if abs(target - smoothed) < 0.00002 {
            smoothed = target
        }
        return smoothed
    }

    /// GM volume: gain = (cc/127)^2, which is 40·log10. Both controllers multiply.
    func expressionGain() -> Float {
        let volume = advanceUnityController(target: channelVolumeTarget, smoothed: &channelVolumeSmoothed)
        let expression = advanceUnityController(target: expressionTarget, smoothed: &expressionSmoothed)
        if volume == 1 && expression == 1 { return 1 }
        return volume * volume * expression * expression
    }

    /// Learn wins. Otherwise the preset flag stores the 0…1 target. Flag off is a no-op.
    func applyExpressionController(cc: UInt8, value: Float, target: inout Float) {
        guard value.isFinite else { return }
        let raw = Self.midiControllerByte(value)
        if (rtCCMap + Int(cc & 127)).pointee.load(ordering: .acquiring) >= 0 {
            applyPlainCCRT(cc: cc, value: raw)
            return
        }
        if cachedRespondToExpressionCC || cachedGlobalExpressionCC {
            target = min(1, max(0, value))
        }
    }

    func resetExpressionControllersRT() {
        channelVolumeTarget = 1
        channelVolumeSmoothed = 1
        expressionTarget = 1
        expressionSmoothed = 1
    }
}
