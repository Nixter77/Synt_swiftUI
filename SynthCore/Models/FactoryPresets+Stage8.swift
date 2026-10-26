//
//  FactoryPresets+Stage8.swift
//  Filter 2, formant, and MSEG demos. Still the tail of `libraryPresets`,
//  and no longer the only patches that use those paths.
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    static let stage8Presets: [SynthPreset] = [
        serialGlassBass,
        vowelAhLead,
        msegDrift
    ]

    private static var serialGlassBass: SynthPreset {
        A.make("Serial Glass Bass", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.18
        p.osc2Octave = -1
        p.osc2Detune = 4
        p.subOscVolume = 0.14
        p.attack = 0.005
        p.decay = 0.22
        p.sustain = 0.58
        p.release = 0.18
        p.filterCutoff = 700
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.003
        p.filterDecay = 0.16
        p.filterSustain = 0.24
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.04
        p.reverbRoomSize = 0.28
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.03
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [A.mod(.env1, .cutoff, 0.18), A.mod(.velocity, .cutoff, 0.20)]
        p.filter2Routing = .serial
        p.filter2Type = .bandPass
        p.filter2Cutoff = 1600
        p.filter2Resonance = 0.26
        p.filter2Balance = 0.62
    }
    }

    private static var vowelAhLead: SynthPreset {
        A.make("Vowel Ah Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.94
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.38
        p.osc2PulseWidth = 0.38
        p.osc2Detune = 4
        p.subOscVolume = 0.18
        p.attack = 0.008
        p.decay = 0.22
        p.sustain = 0.86
        p.release = 0.22
        p.filterType = .formant
        p.filterCutoff = 2600
        p.filterResonance = 0.14
        p.filterDrive = 0.24
        p.filterVowel = 1.4
        p.lfoEnabled = true
        p.lfoRate = 0.30
        p.lfoTarget = .none
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.delayMix = 0.06
        p.delayTime = 0.26
        p.delayFeedback = 0.14
        p.delayPingPong = true
        p.masterVolume = 0.62
        p.portamento = 0.035
        p.character = .bright
        p.modMatrix = [A.mod(.lfo1, .vowel, 0.22), A.mod(.env2, .pwm2, 0.20), A.mod(.velocity, .amp, 0.22)]
    }
    }

    private static var msegDrift: SynthPreset {
        A.make("MSEG Drift", .fx) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.50
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.20
        p.osc2Octave = 1
        p.osc2Detune = 5
        p.attack = 0.025
        p.decay = 0.35
        p.sustain = 0.72
        p.release = 0.38
        p.filterCutoff = 2400
        p.filterResonance = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.020
        p.filterDecay = 0.30
        p.filterSustain = 0.45
        p.filterRelease = 0.32
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.36
        p.chorusMix = 0.10
        p.masterVolume = 0.38
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 3.5
        p.mseg = A.shape(rate: 0.70, -0.55, 0.85, -0.15)
        p.modMatrix = [A.mod(.mseg, .pitch1, 0.08), A.mod(.mseg, .cutoff, 0.22), A.mod(.mseg, .pan, 0.18)]
    }
    }
}
