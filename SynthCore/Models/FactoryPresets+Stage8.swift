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
        p.subOscVolume = 0.16
        p.subOscWaveform = .triangle
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmAmount = 0.16
        p.envelopeModel = .analog
        p.attack = 0.005
        p.decay = 0.22
        p.sustain = 0.58
        p.release = 0.18
        p.filterType = .ladder
        p.filterCutoff = 700
        p.filterResonance = 0.18
        p.filterDrive = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.003
        p.filterEnvHold = 0.008
        p.filterDecay = 0.16
        p.filterSustain = 0.24
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.04
        p.reverbRoomSize = 0.28
        p.busGlueEnabled = true
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.03
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.lfoEnabled = true
        p.lfoRate = 0.35
        p.lfoTarget = .none
        p.modMatrix = [
            A.mod(.lfo1, .cutoff, 0.32),
            A.mod(.env1, .cutoff, 0.18)
        ]
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
        p.osc1Volume = 0.72
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.32
        p.osc2PulseWidth = 0.38
        p.osc2Detune = 4
        p.subOscVolume = 0.16
        p.attack = 0.008
        p.decay = 0.22
        p.sustain = 0.86
        p.release = 0.22
        p.filterType = .formant
        p.filterCutoff = 2600
        p.filterResonance = 0.14
        p.filterDrive = 0.18
        p.filterVowel = 1.4
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 2400
        p.filter2Resonance = 0.14
        p.filter2Balance = 0.15
        p.lfoEnabled = true
        p.lfoRate = 0.32
        p.lfoTarget = .none
        p.lfo2Enabled = true
        p.lfo2Rate = 5.1
        p.lfo2Depth = 0.10
        p.lfo2Target = .pitch
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.14
        p.delayPingPong = true
        p.sendA = 0.14
        p.sendB = 0.12
        p.masterVolume = 0.60
        p.portamento = 0.035
        p.character = .bright
        p.modMatrix = [
            A.mod(.lfo1, .vowel, 0.34),
            A.mod(.env2, .pwm2, 0.22),
            A.mod(.velocity, .amp, 0.22)
        ]
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
        p.osc2FixedFrequency = true
        p.osc2FrequencyHz = 528
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
        p.reverbMix = 0.31
        p.reverbRoomSize = 0.36
        p.chorusMix = 0.14
        p.frequencyShifterEnabled = true
        p.frequencyShifterShiftHz = 6
        p.frequencyShifterMix = 0.18
        p.masterVolume = 0.38
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 3.5
        var m = A.shape(rate: 0.70, -0.55, 0.85, -0.55)
        m.loopStartIndex = 0
        m.loopEndIndex = 2
        p.mseg = m
        p.mseg2 = A.loopingMSEG(rate: 0.28, [
            (0.0, 0.0, 0.0), (0.35, 0.7, -0.2), (0.72, -0.35, 0.2), (1.0, 0.0, 0.15)
        ])
        p.modMatrix = [
            A.mod(.mseg, .cutoff, 0.34),
            A.mod(.mseg, .pan, 0.22),
            A.mod(.mseg2, .pitch2, 0.16)
        ]
    }
    }
}
