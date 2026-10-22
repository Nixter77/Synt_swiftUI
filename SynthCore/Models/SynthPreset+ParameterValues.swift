//
//  SynthPreset+ParameterValues.swift
//  SynthCore
//
//  The plugin view reads and writes knob fields on a preset copy.
//  DSP still goes through the parameter tree.
//

import Foundation

extension SynthPreset {
    public func parameterValue(for address: SynthParameterAddress) -> Float {
        switch address {
        case .osc1Volume: return osc1Volume
        case .osc1Octave: return Float(osc1Octave)
        case .osc1Detune: return osc1Detune
        case .osc1PulseWidth: return osc1PulseWidth
        case .osc1WavetableMorph: return osc1WavetableMorph
        case .osc1Waveform: return waveformIndex(osc1Waveform)
        case .osc1WavetableIndex: return Float(osc1WavetableIndex)
        case .osc2Volume: return osc2Volume
        case .osc2Octave: return Float(osc2Octave)
        case .osc2Detune: return osc2Detune
        case .osc2PulseWidth: return osc2PulseWidth
        case .osc2WavetableMorph: return osc2WavetableMorph
        case .osc2Waveform: return waveformIndex(osc2Waveform)
        case .osc2Enabled: return osc2Enabled ? 1 : 0
        case .subOscVolume: return subOscVolume
        case .fmAmount: return fmAmount
        case .ringModAmount: return ringModAmount
        case .noiseColor: return noiseIndex(noiseColor)
        case .osc2WavetableIndex: return Float(osc2WavetableIndex)
        case .attack: return attack
        case .decay: return decay
        case .sustain: return sustain
        case .release: return release
        case .filterAttack: return filterAttack
        case .filterDecay: return filterDecay
        case .filterSustain: return filterSustain
        case .filterRelease: return filterRelease
        case .filterCutoff: return filterCutoff
        case .filterResonance: return filterResonance
        case .filterType: return filterIndex(filterType)
        case .filterDrive: return filterDrive
        case .filterEnvelopeAmount: return filterEnvelopeAmount
        case .velocityToCutoff: return velocityToCutoff
        case .filterKeyTracking: return filterKeyTracking
        case .lfoEnabled: return lfoEnabled ? 1 : 0
        case .lfoRate: return lfoRate
        case .lfoDepth: return lfoDepth
        case .lfoWaveform: return waveformIndex(lfoWaveform)
        case .lfoTarget: return targetIndex(lfoTarget)
        case .lfo2Enabled: return lfo2Enabled ? 1 : 0
        case .lfo2Rate: return lfo2Rate
        case .lfo2Depth: return lfo2Depth
        case .lfo2Waveform: return waveformIndex(lfo2Waveform)
        case .lfo2Target: return targetIndex(lfo2Target)
        case .reverbMix: return reverbMix
        case .reverbRoomSize: return reverbRoomSize
        case .reverbShimmer: return reverbShimmer
        case .chorusRate: return chorusRate
        case .chorusDepth: return chorusDepth
        case .chorusMix: return chorusMix
        case .delayTime: return delayTime
        case .delayFeedback: return delayFeedback
        case .delayMix: return delayMix
        case .distortionEnabled: return distortionEnabled ? 1 : 0
        case .distortionDrive: return distortionDrive
        case .distortionTone: return distortionTone
        case .distortionMix: return distortionMix
        case .phaserEnabled: return phaserEnabled ? 1 : 0
        case .phaserRate: return phaserRate
        case .phaserDepth: return phaserDepth
        case .phaserMix: return phaserMix
        case .phaserFeedback: return phaserFeedback
        case .phaserCenterFrequency: return phaserCenterFrequency
        case .phaserSpread: return phaserStereoSpread
        case .eqEnabled: return eqEnabled ? 1 : 0
        case .eqLowGain: return eqLowGain
        case .eqMidGain: return eqMidGain
        case .eqHighGain: return eqHighGain
        case .eqLowFreq: return eqLowFreq
        case .eqMidFreq: return eqMidFreq
        case .eqHighFreq: return eqHighFreq
        case .unisonDetune: return unisonDetune
        case .unisonSpread: return unisonSpread
        case .analogDrift: return analogDrift
        case .portamento: return portamento
        case .macro1: return macro1
        case .macro2: return macro2
        case .macro3: return macro3
        case .macro4: return macro4
        case .macro5: return macro5
        case .macro6: return macro6
        case .macro7: return macro7
        case .macro8: return macro8
        case .pan: return pan
        case .lfoMode: return lfoModeIndex(lfoMode)
        case .lfoStartPhase: return lfoStartPhase
        case .lfo2Mode: return lfoModeIndex(lfo2Mode)
        case .lfo2StartPhase: return lfo2StartPhase
        case .arpLatch: return arpLatch ? 1 : 0
        case .velocityCurve: return velocityCurveIndex(velocityCurve)
        case .velocityToVolume: return velocityToVolume
        case .modEnvAttack: return modEnvAttack
        case .modEnvDecay: return modEnvDecay
        case .modEnvSustain: return modEnvSustain
        case .modEnvRelease: return modEnvRelease
        case .glideMode: return glideModeIndex(glideMode)
        case .glideLegatoOnly: return glideLegatoOnly ? 1 : 0
        case .monoPriority: return monoPriorityIndex(monoPriority)
        case .filter2Cutoff: return filter2Cutoff
        case .filter2Resonance: return filter2Resonance
        case .filter2Type: return filterIndex(filter2Type)
        case .filter2Balance: return filter2Balance
        case .filter2Routing: return filter2RoutingIndex(filter2Routing)
        case .envFollowerAttack: return envFollowerAttack
        case .envFollowerRelease: return envFollowerRelease
        case .sendA: return sendA
        case .sendB: return sendB
        case .sendPostInsert: return sendPostInsert ? 1 : 0
        case .rotaryEnabled: return rotaryEnabled ? 1 : 0
        case .rotaryFast: return rotaryFast ? 1 : 0
        case .rotaryHornSlow: return rotaryHornSlow
        case .rotaryHornFast: return rotaryHornFast
        case .rotaryDrumSlow: return rotaryDrumSlow
        case .rotaryDrumFast: return rotaryDrumFast
        case .rotaryDrive: return rotaryDrive
        case .rotaryMix: return rotaryMix
        case .rotaryAccel: return rotaryAccel
        }
    }

    public mutating func setParameterValue(_ raw: Float, for address: SynthParameterAddress) {
        let value = address.clamped(raw)
        switch address {
        case .osc1Volume: osc1Volume = value
        case .osc1Octave: osc1Octave = Int(value.rounded())
        case .osc1Detune: osc1Detune = value
        case .osc1PulseWidth: osc1PulseWidth = value
        case .osc1WavetableMorph: osc1WavetableMorph = value
        case .osc1Waveform: osc1Waveform = waveform(value)
        case .osc1WavetableIndex: osc1WavetableIndex = Int(value.rounded())
        case .osc2Volume: osc2Volume = value
        case .osc2Octave: osc2Octave = Int(value.rounded())
        case .osc2Detune: osc2Detune = value
        case .osc2PulseWidth: osc2PulseWidth = value
        case .osc2WavetableMorph: osc2WavetableMorph = value
        case .osc2Waveform: osc2Waveform = waveform(value)
        case .osc2Enabled: osc2Enabled = value >= 0.5
        case .subOscVolume: subOscVolume = value
        case .fmAmount: fmAmount = value
        case .ringModAmount: ringModAmount = value
        case .noiseColor: noiseColor = noise(value)
        case .osc2WavetableIndex: osc2WavetableIndex = Int(value.rounded())
        case .attack: attack = value
        case .decay: decay = value
        case .sustain: sustain = value
        case .release: release = value
        case .filterAttack: filterAttack = value
        case .filterDecay: filterDecay = value
        case .filterSustain: filterSustain = value
        case .filterRelease: filterRelease = value
        case .filterCutoff: filterCutoff = value
        case .filterResonance: filterResonance = value
        case .filterType: filterType = filterKind(value)
        case .filterDrive: filterDrive = value
        case .filterEnvelopeAmount: filterEnvelopeAmount = value
        case .velocityToCutoff: velocityToCutoff = value
        case .filterKeyTracking: filterKeyTracking = value
        case .lfoEnabled: lfoEnabled = value >= 0.5
        case .lfoRate: lfoRate = value
        case .lfoDepth: lfoDepth = value
        case .lfoWaveform: lfoWaveform = waveform(value)
        case .lfoTarget: lfoTarget = lfoDestination(value)
        case .lfo2Enabled: lfo2Enabled = value >= 0.5
        case .lfo2Rate: lfo2Rate = value
        case .lfo2Depth: lfo2Depth = value
        case .lfo2Waveform: lfo2Waveform = waveform(value)
        case .lfo2Target: lfo2Target = lfoDestination(value)
        case .reverbMix: reverbMix = value
        case .reverbRoomSize: reverbRoomSize = value
        case .reverbShimmer: reverbShimmer = value
        case .chorusRate: chorusRate = value
        case .chorusDepth: chorusDepth = value
        case .chorusMix: chorusMix = value
        case .delayTime: delayTime = value
        case .delayFeedback: delayFeedback = value
        case .delayMix: delayMix = value
        case .distortionEnabled: distortionEnabled = value >= 0.5
        case .distortionDrive: distortionDrive = value
        case .distortionTone: distortionTone = value
        case .distortionMix: distortionMix = value
        case .phaserEnabled: phaserEnabled = value >= 0.5
        case .phaserRate: phaserRate = value
        case .phaserDepth: phaserDepth = value
        case .phaserMix: phaserMix = value
        case .phaserFeedback: phaserFeedback = value
        case .phaserCenterFrequency: phaserCenterFrequency = value
        case .phaserSpread: phaserStereoSpread = value
        case .eqEnabled: eqEnabled = value >= 0.5
        case .eqLowGain: eqLowGain = value
        case .eqMidGain: eqMidGain = value
        case .eqHighGain: eqHighGain = value
        case .eqLowFreq: eqLowFreq = value
        case .eqMidFreq: eqMidFreq = value
        case .eqHighFreq: eqHighFreq = value
        case .unisonDetune: unisonDetune = value
        case .unisonSpread: unisonSpread = value
        case .analogDrift: analogDrift = value
        case .portamento: portamento = value
        case .macro1: macro1 = value
        case .macro2: macro2 = value
        case .macro3: macro3 = value
        case .macro4: macro4 = value
        case .macro5: macro5 = value
        case .macro6: macro6 = value
        case .macro7: macro7 = value
        case .macro8: macro8 = value
        case .pan: pan = value
        case .lfoMode: lfoMode = SynthCore.lfoModeFromFloat(value)
        case .lfoStartPhase: lfoStartPhase = value
        case .lfo2Mode: lfo2Mode = SynthCore.lfoModeFromFloat(value)
        case .lfo2StartPhase: lfo2StartPhase = value
        case .arpLatch: arpLatch = value >= 0.5
        case .velocityCurve: velocityCurve = SynthCore.velocityCurveFromFloat(value)
        case .velocityToVolume: velocityToVolume = value
        case .modEnvAttack: modEnvAttack = value
        case .modEnvDecay: modEnvDecay = value
        case .modEnvSustain: modEnvSustain = value
        case .modEnvRelease: modEnvRelease = value
        case .glideMode: glideMode = SynthCore.glideModeFromFloat(value)
        case .glideLegatoOnly: glideLegatoOnly = value >= 0.5
        case .monoPriority: monoPriority = SynthCore.monoPriorityFromFloat(value)
        case .filter2Cutoff: filter2Cutoff = value
        case .filter2Resonance: filter2Resonance = value
        case .filter2Type: filter2Type = filterKind(value)
        case .filter2Balance: filter2Balance = value
        case .filter2Routing: filter2Routing = filter2RoutingValue(value)
        case .envFollowerAttack: envFollowerAttack = value
        case .envFollowerRelease: envFollowerRelease = value
        case .sendA: sendA = value
        case .sendB: sendB = value
        case .sendPostInsert: sendPostInsert = value >= 0.5
        case .rotaryEnabled: rotaryEnabled = value >= 0.5
        case .rotaryFast: rotaryFast = value >= 0.5
        case .rotaryHornSlow: rotaryHornSlow = value
        case .rotaryHornFast: rotaryHornFast = value
        case .rotaryDrumSlow: rotaryDrumSlow = value
        case .rotaryDrumFast: rotaryDrumFast = value
        case .rotaryDrive: rotaryDrive = value
        case .rotaryMix: rotaryMix = value
        case .rotaryAccel: rotaryAccel = value
        }
    }

    /// Same preset with every published knob at its minimum, so a compare ignores knob edits.
    public func withAddressedKnobsParked() -> SynthPreset {
        var copy = self
        for address in SynthParameterAddress.allCases {
            copy.setParameterValue(address.min, for: address)
        }
        return copy
    }
}

private func waveformIndex(_ waveform: WaveformType) -> Float {
    switch waveform {
    case .sine: return 0
    case .sawtooth: return 1
    case .square: return 2
    case .triangle: return 3
    case .noise: return 4
    case .wavetable: return 5
    }
}

private func waveform(_ value: Float) -> WaveformType {
    switch Int(value.rounded()) {
    case 0: return .sine
    case 2: return .square
    case 3: return .triangle
    case 4: return .noise
    case 5: return .wavetable
    default: return .sawtooth
    }
}

private func filterIndex(_ type: FilterType) -> Float {
    switch type {
    case .lowPass: return 0
    case .highPass: return 1
    case .bandPass: return 2
    case .notch: return 3
    case .ladder: return 4
    case .formant: return 5
    case .comb: return 6
    }
}

private func filterKind(_ value: Float) -> FilterType {
    switch Int(value.rounded()) {
    case 1: return .highPass
    case 2: return .bandPass
    case 3: return .notch
    case 4: return .ladder
    case 5: return .formant
    case 6: return .comb
    default: return .lowPass
    }
}

private func filter2RoutingIndex(_ routing: DualFilterRouting) -> Float {
    switch routing {
    case .serial: return 0
    case .parallel: return 1
    case .off: return 2
    }
}

private func filter2RoutingValue(_ value: Float) -> DualFilterRouting {
    switch Int(value.rounded()) {
    case 0: return .serial
    case 1: return .parallel
    default: return .off
    }
}

private func targetIndex(_ target: LFOTarget) -> Float {
    switch target {
    case .pitch: return 0
    case .filter: return 1
    case .amplitude: return 2
    case .pan: return 3
    case .none: return 4
    }
}

private func lfoDestination(_ value: Float) -> LFOTarget {
    switch Int(value.rounded()) {
    case 1: return .filter
    case 2: return .amplitude
    case 3: return .pan
    case 4: return .none
    default: return .pitch
    }
}

private func noiseIndex(_ color: NoiseColor) -> Float {
    switch color {
    case .white: return 0
    case .pink: return 1
    case .brown: return 2
    }
}

private func noise(_ value: Float) -> NoiseColor {
    switch Int(value.rounded()) {
    case 1: return .pink
    case 2: return .brown
    default: return .white
    }
}

private func lfoModeIndex(_ mode: LFOMode) -> Float {
    switch mode {
    case .free: return 0
    case .retrigger: return 1
    case .oneShot: return 2
    }
}

func lfoModeFromFloat(_ value: Float) -> LFOMode {
    switch Int(value.rounded()) {
    case 1: return .retrigger
    case 2: return .oneShot
    default: return .free
    }
}

private func velocityCurveIndex(_ curve: VelocityCurve) -> Float {
    switch curve {
    case .linear: return 0
    case .exponential: return 1
    case .logarithmic: return 2
    }
}

public func velocityCurveFromFloat(_ value: Float) -> VelocityCurve {
    switch Int(value.rounded()) {
    case 1: return .exponential
    case 2: return .logarithmic
    default: return .linear
    }
}

private func glideModeIndex(_ mode: GlideMode) -> Float {
    switch mode {
    case .time: return 0
    case .rate: return 1
    }
}

public func glideModeFromFloat(_ value: Float) -> GlideMode {
    switch Int(value.rounded()) {
    case 1: return .rate
    default: return .time
    }
}

private func monoPriorityIndex(_ priority: MonoPriority) -> Float {
    switch priority {
    case .last: return 0
    case .low: return 1
    case .high: return 2
    }
}

public func monoPriorityFromFloat(_ value: Float) -> MonoPriority {
    switch Int(value.rounded()) {
    case 1: return .low
    case 2: return .high
    default: return .last
    }
}
