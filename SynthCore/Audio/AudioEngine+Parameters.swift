//
//  AudioEngine+Parameters.swift
//  SynthCore
//
//  Host automation on the audio thread writes DSP fields directly.
//  commandQueue stays single-producer: only the main thread pushes it.
//

import Foundation

extension AudioEngine {
    /// Audio thread. Unknown addresses do nothing. Does not touch `preset`.
    func applyAddressedParameterRT(id: UInt64, value: Float) {
        guard let address = SynthParameterAddress(rawValue: id) else { return }
        let v = address.clamped(value)
        switch address {
        case .osc1Volume: oscillator1.volume = v
        case .osc1Octave: oscillator1.octave = Int(v.rounded())
        case .osc1Detune:
            oscillator1.detune = v
            ccDetune1Target = v
        case .osc1PulseWidth:
            oscillator1.pulseWidth = v
            ccPwm1Target = v
        case .osc1WavetableMorph:
            oscillator1.wavetableMorph = v
            ccWtMorph1Target = v
        case .osc1Waveform: oscillator1.waveform = Self.waveform(v)
        case .osc1WavetableIndex, .osc2WavetableIndex: break
        case .osc2Volume:
            oscillator2.volume = v
            ccMixTarget = v
        case .osc2Octave: oscillator2.octave = Int(v.rounded())
        case .osc2Detune:
            oscillator2.detune = v
            ccDetune2Target = v
        case .osc2PulseWidth:
            oscillator2.pulseWidth = v
            ccPwm2Target = v
        case .osc2WavetableMorph:
            oscillator2.wavetableMorph = v
            ccWtMorph2Target = v
        case .osc2Waveform: oscillator2.waveform = Self.waveform(v)
        case .osc2Enabled: cachedOsc2Enabled = v >= 0.5
        case .subOscVolume: cachedSubOscVolume = v
        case .fmAmount: cachedFmAmount = v
        case .ringModAmount: cachedRingModAmount = v
        case .noiseColor: cachedNoiseColor = Self.noiseColor(v)
        case .attack:
            envelope.attack = v
            ccAttackTarget = v
        case .decay:
            envelope.decay = v
            ccDecayTarget = v
        case .sustain:
            envelope.sustain = v
            ccSustainTarget = v
        case .release:
            envelope.release = v
            ccReleaseTarget = v
        case .filterAttack:
            filterEnvelope.attack = v
            cachedFilterAttack = v
            ccFilterAttackTarget = v
        case .filterDecay:
            filterEnvelope.decay = v
            cachedFilterDecay = v
            ccFilterDecayTarget = v
        case .filterSustain:
            filterEnvelope.sustain = v
            cachedFilterSustain = v
            ccFilterSustainTarget = v
        case .filterRelease:
            filterEnvelope.release = v
            cachedFilterRelease = v
            ccFilterReleaseTarget = v
        case .filterCutoff: cachedFilterCutoff = v
        case .filterResonance:
            ccResonanceRT = -1
            filterL.resonance = v
            filterR.resonance = v
        case .filterType:
            let kind = Self.filterType(v)
            filterL.type = kind
            filterR.type = kind
        case .filterDrive: cachedFilterDrive = v
        case .filterEnvelopeAmount: cachedFilterEnvAmount = v
        case .velocityToCutoff: cachedVelocityToCutoff = v
        case .filterKeyTracking: cachedFilterKeyTracking = v
        case .lfoEnabled: lfo.enabled = v >= 0.5
        case .lfoRate:
            lfo.rate = v
            ccLfoRateTarget = v
        case .lfoDepth:
            cachedLfoDepth = v
            ccLfoDepthTarget = v
        case .lfoWaveform: lfo.waveform = Self.waveform(v)
        case .lfoTarget: lfo.target = Self.lfoTarget(v)
        case .lfo2Enabled: lfo2.enabled = v >= 0.5
        case .lfo2Rate: lfo2.rate = v
        case .lfo2Depth: cachedLfo2Depth = v
        case .lfo2Waveform: lfo2.waveform = Self.waveform(v)
        case .lfo2Target: lfo2.target = Self.lfoTarget(v)
        case .reverbMix, .reverbRoomSize: break
        case .reverbShimmer: cachedReverbShimmer = v
        case .chorusRate: dspChorus.rate = v
        case .chorusDepth: dspChorus.depth = v
        case .chorusMix: dspChorus.mix = v
        case .delayTime:
            parameterDelayTime = v
            pingPongDelay.delayTime = v
        case .delayFeedback:
            parameterDelayFeedback = v
            pingPongDelay.feedback = v
        case .delayMix:
            parameterDelayMix = v
            pingPongDelay.mix = v
        case .distortionEnabled: distortion.enabled = v >= 0.5
        case .distortionDrive: distortion.drive = v
        case .distortionTone: distortion.tone = v
        case .distortionMix: distortion.mix = v
        case .phaserEnabled: phaser.bypass = v < 0.5
        case .phaserRate: phaser.rate = v
        case .phaserDepth: phaser.depth = v
        case .phaserMix: phaser.mix = v
        case .phaserFeedback: phaser.feedback = v
        case .phaserCenterFrequency: phaser.centerFrequency = v
        case .phaserSpread: phaser.stereoSpread = v
        case .eqEnabled:
            parametricEQL.enabled = v >= 0.5
            parametricEQR.enabled = v >= 0.5
        case .eqLowGain:
            parametricEQL.lowGain = v
            parametricEQR.lowGain = v
        case .eqMidGain:
            parametricEQL.midGain = v
            parametricEQR.midGain = v
        case .eqHighGain:
            parametricEQL.highGain = v
            parametricEQR.highGain = v
        case .eqLowFreq:
            parametricEQL.lowFreq = v
            parametricEQR.lowFreq = v
        case .eqMidFreq:
            parametricEQL.midFreq = v
            parametricEQR.midFreq = v
        case .eqHighFreq:
            parametricEQL.highFreq = v
            parametricEQR.highFreq = v
        case .unisonDetune: cachedUnisonDetune = v
        case .unisonSpread: cachedUnisonSpread = v
        case .analogDrift: cachedAnalogDrift = v
        case .portamento: cachedPortamento = v
        case .macro1: cachedMacro1 = v
        case .macro2: cachedMacro2 = v
        case .macro3: cachedMacro3 = v
        case .macro4: cachedMacro4 = v
        case .pan:
            ccPanRT = v
            ccPanTarget = v
        case .lfoMode: lfo.mode = Self.lfoMode(v)
        case .lfoStartPhase: lfo.startPhaseDegrees = v
        case .lfo2Mode: lfo2.mode = Self.lfoMode(v)
        case .lfo2StartPhase: lfo2.startPhaseDegrees = v
        case .arpLatch:
            cachedArpLatch = v >= 0.5
            arp.latch = cachedArpLatch
        case .velocityCurve: cachedVelocityCurve = SynthCore.velocityCurveFromFloat(v)
        case .velocityToVolume: cachedVelocityToVolume = v
        case .modEnvAttack: modEnvelope.attack = v
        case .modEnvDecay: modEnvelope.decay = v
        case .modEnvSustain: modEnvelope.sustain = v
        case .modEnvRelease: modEnvelope.release = v
        case .glideMode: cachedGlideMode = SynthCore.glideModeFromFloat(v)
        case .glideLegatoOnly: cachedGlideLegatoOnly = v >= 0.5
        case .monoPriority: cachedMonoPriority = SynthCore.monoPriorityFromFloat(v)
        }
    }

    /// Live value for the parameter tree. Reads DSP fields, not the preset struct.
    func addressedParameterValue(_ address: SynthParameterAddress) -> Float {
        switch address {
        case .osc1Volume: return oscillator1.volume
        case .osc1Octave: return Float(oscillator1.octave)
        case .osc1Detune: return oscillator1.detune
        case .osc1PulseWidth: return oscillator1.pulseWidth
        case .osc1WavetableMorph: return oscillator1.wavetableMorph
        case .osc1Waveform: return Self.index(of: oscillator1.waveform)
        case .osc1WavetableIndex: return Float(loadedWTIndex1)
        case .osc2WavetableIndex: return Float(loadedWTIndex2)
        case .osc2Volume: return oscillator2.volume
        case .osc2Octave: return Float(oscillator2.octave)
        case .osc2Detune: return oscillator2.detune
        case .osc2PulseWidth: return oscillator2.pulseWidth
        case .osc2WavetableMorph: return oscillator2.wavetableMorph
        case .osc2Waveform: return Self.index(of: oscillator2.waveform)
        case .osc2Enabled: return cachedOsc2Enabled ? 1 : 0
        case .subOscVolume: return cachedSubOscVolume
        case .fmAmount: return cachedFmAmount
        case .ringModAmount: return cachedRingModAmount
        case .noiseColor: return Self.index(of: cachedNoiseColor)
        case .attack: return envelope.attack
        case .decay: return envelope.decay
        case .sustain: return envelope.sustain
        case .release: return envelope.release
        case .filterAttack: return cachedFilterAttack
        case .filterDecay: return cachedFilterDecay
        case .filterSustain: return cachedFilterSustain
        case .filterRelease: return cachedFilterRelease
        case .filterCutoff: return cachedFilterCutoff
        case .filterResonance: return filterL.resonance
        case .filterType: return Self.index(of: filterL.type)
        case .filterDrive: return cachedFilterDrive
        case .filterEnvelopeAmount: return cachedFilterEnvAmount
        case .velocityToCutoff: return cachedVelocityToCutoff
        case .filterKeyTracking: return cachedFilterKeyTracking
        case .lfoEnabled: return lfo.enabled ? 1 : 0
        case .lfoRate: return lfo.rate
        case .lfoDepth: return cachedLfoDepth
        case .lfoWaveform: return Self.index(of: lfo.waveform)
        case .lfoTarget: return Self.index(of: lfo.target)
        case .lfo2Enabled: return lfo2.enabled ? 1 : 0
        case .lfo2Rate: return lfo2.rate
        case .lfo2Depth: return cachedLfo2Depth
        case .lfo2Waveform: return Self.index(of: lfo2.waveform)
        case .lfo2Target: return Self.index(of: lfo2.target)
        case .reverbMix: return parameterReverbMix
        case .reverbRoomSize: return parameterReverbRoom
        case .reverbShimmer: return cachedReverbShimmer
        case .chorusRate: return dspChorus.rate
        case .chorusDepth: return dspChorus.depth
        case .chorusMix: return dspChorus.mix
        case .delayTime: return parameterDelayTime
        case .delayFeedback: return parameterDelayFeedback
        case .delayMix: return parameterDelayMix
        case .distortionEnabled: return distortion.enabled ? 1 : 0
        case .distortionDrive: return distortion.drive
        case .distortionTone: return distortion.tone
        case .distortionMix: return distortion.mix
        case .phaserEnabled: return phaser.bypass ? 0 : 1
        case .phaserRate: return phaser.rate
        case .phaserDepth: return phaser.depth
        case .phaserMix: return phaser.mix
        case .phaserFeedback: return phaser.feedback
        case .phaserCenterFrequency: return phaser.centerFrequency
        case .phaserSpread: return phaser.stereoSpread
        case .eqEnabled: return parametricEQL.enabled ? 1 : 0
        case .eqLowGain: return parametricEQL.lowGain
        case .eqMidGain: return parametricEQL.midGain
        case .eqHighGain: return parametricEQL.highGain
        case .eqLowFreq: return parametricEQL.lowFreq
        case .eqMidFreq: return parametricEQL.midFreq
        case .eqHighFreq: return parametricEQL.highFreq
        case .unisonDetune: return cachedUnisonDetune
        case .unisonSpread: return cachedUnisonSpread
        case .analogDrift: return cachedAnalogDrift
        case .portamento: return cachedPortamento
        case .macro1: return cachedMacro1
        case .macro2: return cachedMacro2
        case .macro3: return cachedMacro3
        case .macro4: return cachedMacro4
        case .pan: return ccPanRT
        case .lfoMode: return Self.index(of: lfo.mode)
        case .lfoStartPhase: return lfo.startPhaseDegrees
        case .lfo2Mode: return Self.index(of: lfo2.mode)
        case .lfo2StartPhase: return lfo2.startPhaseDegrees
        case .arpLatch: return arp.latch ? 1 : 0
        case .velocityCurve:
            switch cachedVelocityCurve {
            case .linear: return 0
            case .exponential: return 1
            case .logarithmic: return 2
            }
        case .velocityToVolume: return cachedVelocityToVolume
        case .modEnvAttack: return modEnvelope.attack
        case .modEnvDecay: return modEnvelope.decay
        case .modEnvSustain: return modEnvelope.sustain
        case .modEnvRelease: return modEnvelope.release
        case .glideMode: return cachedGlideMode == .rate ? 1 : 0
        case .glideLegatoOnly: return cachedGlideLegatoOnly ? 1 : 0
        case .monoPriority:
            switch cachedMonoPriority {
            case .last: return 0
            case .low: return 1
            case .high: return 2
            }
        }
    }

    /// Main thread. Updates the preset the UI and `fullState` save, then queues the DSP write.
    /// Wavetable index loads a table, so it goes through `applyPreset` on main.
    func adoptAddressedParameterOnMain(id: UInt64, value: Float, pushToRender: Bool = true) {
        guard let address = SynthParameterAddress(rawValue: id) else { return }
        let v = address.clamped(value)
        if address == .osc1WavetableIndex || address == .osc2WavetableIndex {
            switch address {
            case .osc1WavetableIndex: preset.osc1WavetableIndex = Int(v.rounded())
            case .osc2WavetableIndex: preset.osc2WavetableIndex = Int(v.rounded())
            default: break
            }
            return
        }
        updatePresetDisplayOnly { preset in
            switch address {
            case .osc1Volume: preset.osc1Volume = v
            case .osc1Octave: preset.osc1Octave = Int(v.rounded())
            case .osc1Detune: preset.osc1Detune = v
            case .osc1PulseWidth: preset.osc1PulseWidth = v
            case .osc1WavetableMorph: preset.osc1WavetableMorph = v
            case .osc1Waveform: preset.osc1Waveform = Self.waveform(v)
            case .osc1WavetableIndex, .osc2WavetableIndex: break
            case .osc2Volume: preset.osc2Volume = v
            case .osc2Octave: preset.osc2Octave = Int(v.rounded())
            case .osc2Detune: preset.osc2Detune = v
            case .osc2PulseWidth: preset.osc2PulseWidth = v
            case .osc2WavetableMorph: preset.osc2WavetableMorph = v
            case .osc2Waveform: preset.osc2Waveform = Self.waveform(v)
            case .osc2Enabled: preset.osc2Enabled = v >= 0.5
            case .subOscVolume: preset.subOscVolume = v
            case .fmAmount: preset.fmAmount = v
            case .ringModAmount: preset.ringModAmount = v
            case .noiseColor: preset.noiseColor = Self.noiseColor(v)
            case .attack: preset.attack = v
            case .decay: preset.decay = v
            case .sustain: preset.sustain = v
            case .release: preset.release = v
            case .filterAttack: preset.filterAttack = v
            case .filterDecay: preset.filterDecay = v
            case .filterSustain: preset.filterSustain = v
            case .filterRelease: preset.filterRelease = v
            case .filterCutoff: preset.filterCutoff = v
            case .filterResonance: preset.filterResonance = v
            case .filterType: preset.filterType = Self.filterType(v)
            case .filterDrive: preset.filterDrive = v
            case .filterEnvelopeAmount: preset.filterEnvelopeAmount = v
            case .velocityToCutoff: preset.velocityToCutoff = v
            case .filterKeyTracking: preset.filterKeyTracking = v
            case .lfoEnabled: preset.lfoEnabled = v >= 0.5
            case .lfoRate: preset.lfoRate = v
            case .lfoDepth: preset.lfoDepth = v
            case .lfoWaveform: preset.lfoWaveform = Self.waveform(v)
            case .lfoTarget: preset.lfoTarget = Self.lfoTarget(v)
            case .lfo2Enabled: preset.lfo2Enabled = v >= 0.5
            case .lfo2Rate: preset.lfo2Rate = v
            case .lfo2Depth: preset.lfo2Depth = v
            case .lfo2Waveform: preset.lfo2Waveform = Self.waveform(v)
            case .lfo2Target: preset.lfo2Target = Self.lfoTarget(v)
            case .reverbMix:
                parameterReverbMix = v
                preset.reverbMix = v
                reverb.wetDryMix = AudioMath.appleFXWetPercent(v)
            case .reverbRoomSize:
                parameterReverbRoom = v
                preset.reverbRoomSize = v
                reverb.setRoomSize(v)
            case .reverbShimmer: preset.reverbShimmer = v
            case .chorusRate: preset.chorusRate = v
            case .chorusDepth: preset.chorusDepth = v
            case .chorusMix: preset.chorusMix = v
            // The DSP delay and parameterDelay* belong to the audio thread
            // (applyAddressedParameterRT). Main only drives the Apple Delay node.
            case .delayTime:
                preset.delayTime = v
                if !preset.delayPingPong && !rendersAllDelayInDSP { delay.delayTime = v }
            case .delayFeedback:
                preset.delayFeedback = v
                if !preset.delayPingPong && !rendersAllDelayInDSP { delay.feedback = v }
            case .delayMix:
                preset.delayMix = v
                if !preset.delayPingPong && !rendersAllDelayInDSP { delay.wetDryMix = AudioMath.appleFXWetPercent(v) }
            case .distortionEnabled: preset.distortionEnabled = v >= 0.5
            case .distortionDrive: preset.distortionDrive = v
            case .distortionTone: preset.distortionTone = v
            case .distortionMix: preset.distortionMix = v
            case .phaserEnabled: preset.phaserEnabled = v >= 0.5
            case .phaserRate: preset.phaserRate = v
            case .phaserDepth: preset.phaserDepth = v
            case .phaserMix: preset.phaserMix = v
            case .phaserFeedback: preset.phaserFeedback = v
            case .phaserCenterFrequency: preset.phaserCenterFrequency = v
            case .phaserSpread: preset.phaserStereoSpread = v
            case .eqEnabled: preset.eqEnabled = v >= 0.5
            case .eqLowGain: preset.eqLowGain = v
            case .eqMidGain: preset.eqMidGain = v
            case .eqHighGain: preset.eqHighGain = v
            case .eqLowFreq: preset.eqLowFreq = v
            case .eqMidFreq: preset.eqMidFreq = v
            case .eqHighFreq: preset.eqHighFreq = v
            case .unisonDetune: preset.unisonDetune = v
            case .unisonSpread: preset.unisonSpread = v
            case .analogDrift: preset.analogDrift = v
            case .portamento: preset.portamento = v
            case .macro1: preset.macro1 = v
            case .macro2: preset.macro2 = v
            case .macro3: preset.macro3 = v
            case .macro4: preset.macro4 = v
            case .pan: preset.pan = v
            case .lfoMode: preset.lfoMode = Self.lfoMode(v)
            case .lfoStartPhase: preset.lfoStartPhase = v
            case .lfo2Mode: preset.lfo2Mode = Self.lfoMode(v)
            case .lfo2StartPhase: preset.lfo2StartPhase = v
            case .arpLatch: preset.arpLatch = v >= 0.5
            case .velocityCurve: preset.velocityCurve = SynthCore.velocityCurveFromFloat(v)
            case .velocityToVolume: preset.velocityToVolume = v
            case .modEnvAttack: preset.modEnvAttack = v
            case .modEnvDecay: preset.modEnvDecay = v
            case .modEnvSustain: preset.modEnvSustain = v
            case .modEnvRelease: preset.modEnvRelease = v
            case .glideMode: preset.glideMode = SynthCore.glideModeFromFloat(v)
            case .glideLegatoOnly: preset.glideLegatoOnly = v >= 0.5
            case .monoPriority: preset.monoPriority = SynthCore.monoPriorityFromFloat(v)
            }
        }
        if pushToRender { setParameter(id: id, value: v) }
    }

    private static func waveform(_ value: Float) -> WaveformType {
        switch Int(value.rounded()) {
        case 0: return .sine
        case 2: return .square
        case 3: return .triangle
        case 4: return .noise
        case 5: return .wavetable
        default: return .sawtooth
        }
    }

    private static func index(of waveform: WaveformType) -> Float {
        switch waveform {
        case .sine: return 0
        case .sawtooth: return 1
        case .square: return 2
        case .triangle: return 3
        case .noise: return 4
        case .wavetable: return 5
        }
    }

    private static func filterType(_ value: Float) -> FilterType {
        switch Int(value.rounded()) {
        case 1: return .highPass
        case 2: return .bandPass
        case 3: return .notch
        case 4: return .ladder
        default: return .lowPass
        }
    }

    private static func index(of type: FilterType) -> Float {
        switch type {
        case .lowPass: return 0
        case .highPass: return 1
        case .bandPass: return 2
        case .notch: return 3
        case .ladder: return 4
        }
    }

    private static func lfoTarget(_ value: Float) -> LFOTarget {
        switch Int(value.rounded()) {
        case 1: return .filter
        case 2: return .amplitude
        case 3: return .pan
        case 4: return .none
        default: return .pitch
        }
    }

    private static func index(of target: LFOTarget) -> Float {
        switch target {
        case .pitch: return 0
        case .filter: return 1
        case .amplitude: return 2
        case .pan: return 3
        case .none: return 4
        }
    }

    private static func noiseColor(_ value: Float) -> NoiseColor {
        switch Int(value.rounded()) {
        case 1: return .pink
        case 2: return .brown
        default: return .white
        }
    }

    private static func index(of color: NoiseColor) -> Float {
        switch color {
        case .white: return 0
        case .pink: return 1
        case .brown: return 2
        }
    }

    static func lfoMode(_ value: Float) -> LFOMode {
        switch Int(value.rounded()) {
        case 1: return .retrigger
        case 2: return .oneShot
        default: return .free
        }
    }

    private static func index(of mode: LFOMode) -> Float {
        switch mode {
        case .free: return 0
        case .retrigger: return 1
        case .oneShot: return 2
        }
    }
}
