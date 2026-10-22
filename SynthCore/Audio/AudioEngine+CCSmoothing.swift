//
//  AudioEngine+CCSmoothing.swift
//  Synt_swiftUI
//
//  ~8 ms one-pole on the zipper CCs, and soft takeover after a patch change.
//  The audio thread only reads and writes fields that already exist.
//

import Foundation
import Synchronization

public extension MIDIControlTarget {
    /// Reverb mix and room size are Apple AU parameters. The audio thread does not own them.
    public var writesAudioParameter: Bool {
        switch self {
        case .reverbMix, .reverbRoomSize: return false
        default: return true
        }
    }

    /// Inverse of `MIDICCLearnStore.applyValue`, as a 0...1 position.
    public func normalizedUnit(_ unit: Float) -> Float {
        switch self {
        case .cutoff:
            return log(max(unit, 1e-4) / 20) / log(1000)
        case .resonance:
            return unit / 0.95
        case .amp, .wtMorph1, .wtMorph2, .lfoDepth, .mix, .sustain, .filterSustain,
             .reverbMix, .reverbRoomSize, .reverbShimmer, .delayMix, .chorusMix, .chorusDepth,
             .distortionMix, .distortionDrive, .phaserMix, .phaserDepth,
             .osc1Volume, .osc2Volume, .subOscVolume, .fmAmount, .ringModAmount,
             .unisonSpread, .analogDrift, .portamento:
            return unit
        case .pan:
            return unit / 2 + 0.5
        case .pitch1, .pitch2, .finePitch:
            return unit / 100 + 0.5
        case .pwm1, .pwm2:
            return (unit - 0.1) / 0.8
        case .lfoRate:
            return (unit - 0.05) / 19.95
        case .attack, .decay, .filterAttack, .filterDecay:
            return (unit - 0.001) / 1.999
        case .release, .filterRelease:
            return (unit - 0.001) / 2.999
        case .filterEnvelopeAmount, .macro1, .macro2, .macro3, .macro4, .macro5, .macro6, .macro7, .macro8:
            return unit / 2 + 0.5
        case .delayTime:
            return (unit - 0.01) / 0.99
        case .delayFeedback:
            return unit / 0.9
        case .chorusRate:
            return (unit - 0.1) / 4.9
        case .phaserRate:
            return (unit - 0.05) / 4.95
        case .unisonDetune:
            return unit / 50
        }
    }

    public func rawMIDI(matching unit: Float) -> Int {
        let norm = normalizedUnit(unit)
        guard norm.isFinite else { return 0 }
        let clamped = min(1, max(0, norm))
        return Int((Double(clamped) * 127).rounded())
    }

    public func unit(in preset: SynthPreset, pan: Float) -> Float {
        switch self {
        case .cutoff: return preset.filterCutoff
        case .resonance: return preset.filterResonance
        case .amp: return preset.masterVolume
        case .pan: return pan
        case .pitch1: return preset.osc1Detune
        case .pitch2: return preset.osc2Detune
        case .finePitch: return preset.osc1Detune
        case .pwm1: return preset.osc1PulseWidth
        case .pwm2: return preset.osc2PulseWidth
        case .wtMorph1: return preset.osc1WavetableMorph
        case .wtMorph2: return preset.osc2WavetableMorph
        case .lfoRate: return preset.lfoRate
        case .lfoDepth: return preset.lfoDepth
        case .mix, .osc2Volume: return preset.osc2Volume
        case .attack: return preset.attack
        case .decay: return preset.decay
        case .sustain: return preset.sustain
        case .release: return preset.release
        case .filterAttack: return preset.filterAttack
        case .filterDecay: return preset.filterDecay
        case .filterSustain: return preset.filterSustain
        case .filterRelease: return preset.filterRelease
        case .filterEnvelopeAmount: return preset.filterEnvelopeAmount
        case .reverbMix: return preset.reverbMix
        case .reverbRoomSize: return preset.reverbRoomSize
        case .reverbShimmer: return preset.reverbShimmer
        case .delayMix: return preset.delayMix
        case .delayTime: return preset.delayTime
        case .delayFeedback: return preset.delayFeedback
        case .chorusMix: return preset.chorusMix
        case .chorusRate: return preset.chorusRate
        case .chorusDepth: return preset.chorusDepth
        case .distortionMix: return preset.distortionMix
        case .distortionDrive: return preset.distortionDrive
        case .phaserMix: return preset.phaserMix
        case .phaserRate: return preset.phaserRate
        case .phaserDepth: return preset.phaserDepth
        case .osc1Volume: return preset.osc1Volume
        case .subOscVolume: return preset.subOscVolume
        case .fmAmount: return preset.fmAmount
        case .ringModAmount: return preset.ringModAmount
        case .unisonDetune: return preset.unisonDetune
        case .unisonSpread: return preset.unisonSpread
        case .analogDrift: return preset.analogDrift
        case .portamento: return preset.portamento
        case .macro1: return preset.macro1
        case .macro2: return preset.macro2
        case .macro3: return preset.macro3
        case .macro4: return preset.macro4
        case .macro5: return preset.macro5
        case .macro6: return preset.macro6
        case .macro7: return preset.macro7
        case .macro8: return preset.macro8
        }
    }
}

public extension AudioEngine {
    /// ~8 ms. Cached per sample rate. 44.1 kHz goldens never take the glide branch.
    @inline(__always)
    public func ccSmoothingCoeff() -> Float {
        if sampleRate != ccSmoothCoeffSampleRate {
            ccSmoothCoeffSampleRate = sampleRate
            ccSmoothCoeff = Float(1 - exp(-1.0 / (0.008 * sampleRate)))
        }
        return ccSmoothCoeff
    }

    /// One sample of the zipper glide. An idle parameter is left untouched.
    @inline(__always)
    public func glideToward(_ value: inout Float, target: Float, coeff: Float) {
        let delta = target - value
        if abs(delta) < 1e-6 {
            if value != target { value = target }
            return
        }
        value += delta * coeff
    }

    public func advanceCCSmoothers() {
        let coeff = ccSmoothingCoeff()
        glideToward(&ccPanRT, target: ccPanTarget, coeff: coeff)
        glideToward(&oscillator1.pulseWidth, target: ccPwm1Target, coeff: coeff)
        glideToward(&oscillator2.pulseWidth, target: ccPwm2Target, coeff: coeff)
        glideToward(&oscillator1.detune, target: ccDetune1Target, coeff: coeff)
        glideToward(&oscillator2.detune, target: ccDetune2Target, coeff: coeff)
        glideToward(&oscillator2.volume, target: ccMixTarget, coeff: coeff)
        glideToward(&lfo.rate, target: ccLfoRateTarget, coeff: coeff)
        glideToward(&envelope.attack, target: ccAttackTarget, coeff: coeff)
        glideToward(&envelope.decay, target: ccDecayTarget, coeff: coeff)
        glideToward(&envelope.sustain, target: ccSustainTarget, coeff: coeff)
        glideToward(&envelope.release, target: ccReleaseTarget, coeff: coeff)
        glideToward(&filterEnvelope.attack, target: ccFilterAttackTarget, coeff: coeff)
        cachedFilterAttack = filterEnvelope.attack
        glideToward(&filterEnvelope.decay, target: ccFilterDecayTarget, coeff: coeff)
        cachedFilterDecay = filterEnvelope.decay
        glideToward(&filterEnvelope.sustain, target: ccFilterSustainTarget, coeff: coeff)
        cachedFilterSustain = filterEnvelope.sustain
        glideToward(&filterEnvelope.release, target: ccFilterReleaseTarget, coeff: coeff)
        cachedFilterRelease = filterEnvelope.release
        glideToward(&oscillator1.wavetableMorph, target: ccWtMorph1Target, coeff: coeff)
        glideToward(&oscillator2.wavetableMorph, target: ccWtMorph2Target, coeff: coeff)
        glideToward(&cachedLfoDepth, target: ccLfoDepthTarget, coeff: coeff)
    }

    /// Copy the values `applyPreset` just wrote, so the next sample does not glide.
    public func snapCCTargetsFromLive() {
        ccPanTarget = ccPanRT
        ccPwm1Target = oscillator1.pulseWidth
        ccPwm2Target = oscillator2.pulseWidth
        ccDetune1Target = oscillator1.detune
        ccDetune2Target = oscillator2.detune
        ccMixTarget = oscillator2.volume
        ccLfoRateTarget = lfo.rate
        ccAttackTarget = envelope.attack
        ccDecayTarget = envelope.decay
        ccSustainTarget = envelope.sustain
        ccReleaseTarget = envelope.release
        ccFilterAttackTarget = filterEnvelope.attack
        ccFilterDecayTarget = filterEnvelope.decay
        ccFilterSustainTarget = filterEnvelope.sustain
        ccFilterReleaseTarget = filterEnvelope.release
        ccWtMorph1Target = oscillator1.wavetableMorph
        ccWtMorph2Target = oscillator2.wavetableMorph
        ccLfoDepthTarget = cachedLfoDepth
    }

    public func disarmCCTakeover() {
        ccCaughtLo.store(0, ordering: .releasing)
        ccCaughtHi.store(0, ordering: .releasing)
        for i in 0..<128 {
            (ccLastRaw + i).pointee.store(255, ordering: .relaxed)
        }
    }

    public func isCCCaught(_ cc: UInt8) -> Bool {
        let n = cc & 127
        if n < 64 {
            return ccCaughtLo.load(ordering: .acquiring) & (UInt64(1) << n) != 0
        }
        return ccCaughtHi.load(ordering: .acquiring) & (UInt64(1) << (n - 64)) != 0
    }

    public func setCCCaught(_ cc: UInt8) {
        let n = cc & 127
        if n < 64 {
            ccCaughtLo.bitwiseOr(UInt64(1) << n, ordering: .releasing)
        } else {
            ccCaughtHi.bitwiseOr(UInt64(1) << (n - 64), ordering: .releasing)
        }
    }

    /// True when this CC may move the parameter. After a patch change it waits
    /// until the knob is within one step of the value, or steps across it.
    public func ccTakeoverShouldApply(cc: UInt8, raw: UInt8, current: Float, target: MIDIControlTarget) -> Bool {
        if isCCCaught(cc) { return true }
        let position = target.rawMIDI(matching: current)
        let rawI = Int(raw & 127)
        let last = Int((ccLastRaw + Int(cc & 127)).pointee.load(ordering: .relaxed))
        let within = abs(rawI - position) <= 1
        let crossed = last != 255 && last != rawI && (last - position) * (rawI - position) <= 0
        (ccLastRaw + Int(cc & 127)).pointee.store(UInt8(rawI), ordering: .relaxed)
        if within || crossed {
            setCCCaught(cc)
            return true
        }
        return false
    }

    /// Value the audio thread is using right now, in the same units as the CC mapping.
    public func liveUnit(for target: MIDIControlTarget) -> Float {
        switch target {
        case .cutoff: return cachedFilterCutoff
        case .resonance: return ccResonanceRT >= 0 ? ccResonanceRT : filterL.resonance
        case .amp: return cachedMasterVolume
        case .pan: return ccPanRT
        case .pitch1: return oscillator1.detune
        case .pitch2: return oscillator2.detune
        case .finePitch: return oscillator1.detune
        case .pwm1: return oscillator1.pulseWidth
        case .pwm2: return oscillator2.pulseWidth
        case .wtMorph1: return oscillator1.wavetableMorph
        case .wtMorph2: return oscillator2.wavetableMorph
        case .lfoRate: return lfo.rate
        case .lfoDepth: return cachedLfoDepth
        case .mix, .osc2Volume: return oscillator2.volume
        case .attack: return envelope.attack
        case .decay: return envelope.decay
        case .sustain: return envelope.sustain
        case .release: return envelope.release
        case .filterAttack: return filterEnvelope.attack
        case .filterDecay: return filterEnvelope.decay
        case .filterSustain: return filterEnvelope.sustain
        case .filterRelease: return filterEnvelope.release
        case .filterEnvelopeAmount: return cachedFilterEnvAmount
        case .reverbMix: return cachedReverbMix
        case .reverbRoomSize: return cachedReverbRoom
        case .reverbShimmer: return cachedReverbShimmer
        case .delayMix: return pingPongDelay.mix
        case .delayTime: return pingPongDelay.delayTime
        case .delayFeedback: return pingPongDelay.feedback
        case .chorusMix: return dspChorus.mix
        case .chorusRate: return dspChorus.rate
        case .chorusDepth: return dspChorus.depth
        case .distortionMix: return distortion.mix
        case .distortionDrive: return distortion.drive
        case .phaserMix: return phaser.mix
        case .phaserRate: return phaser.rate
        case .phaserDepth: return phaser.depth
        case .osc1Volume: return oscillator1.volume
        case .subOscVolume: return cachedSubOscVolume
        case .fmAmount: return cachedFmAmount
        case .ringModAmount: return cachedRingModAmount
        case .unisonDetune: return cachedUnisonDetune
        case .unisonSpread: return cachedUnisonSpread
        case .analogDrift: return cachedAnalogDrift
        case .portamento: return cachedPortamento
        case .macro1: return cachedMacro1
        case .macro2: return cachedMacro2
        case .macro3: return cachedMacro3
        case .macro4: return cachedMacro4
        case .macro5: return cachedMacro5
        case .macro6: return cachedMacro6
        case .macro7: return cachedMacro7
        case .macro8: return cachedMacro8
        }
    }
}
