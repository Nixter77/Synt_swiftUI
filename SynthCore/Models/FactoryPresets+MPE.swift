//
//  FactoryPresets+MPE.swift
//  Two MPE demos for the current engine: pressure to cutoff, timbre to
//  wavetable morph. Refreshed with filter 2 / macros; still a small set.
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    static let mpeFactoryPresets: [SynthPreset] = A.characterPass(mpeAuthored, salt: 400)

    private static let mpeAuthored: [SynthPreset] = [
        A.make("MPE Expressive Pad", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.44
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.28
        p.osc2Detune = 5
        p.attack = 0.45
        p.ampDelay = 0.020
        p.decay = 0.42
        p.sustain = 0.80
        p.release = 1.15
        p.filterType = .ladder
        p.filterCutoff = 1150
        p.filterResonance = 0.22
        p.filterDrive = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.18
        p.filterEnvDelay = 0.035
        p.filterAttack = 0.35
        p.filterDecay = 0.45
        p.filterSustain = 0.50
        p.filterRelease = 0.90
        p.reverbMix = 0.22
        p.reverbRoomSize = 0.46
        p.reverbShimmer = 0.16
        p.chorusMix = 0.16
        p.chorusMode = .ensemble
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 110
        p.sendA = 0.14
        p.masterVolume = 0.35
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoHaasMs = 4.0
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 0.16
        p.lfoStereoPhase = 120
        p.lfoTarget = .none
        p.mseg = A.loopingMSEG(rate: 0.14, [
            (0.0, 0.0, 0.0), (0.36, 0.7, -0.25), (0.72, -0.2, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [
            A.mod(.mpePressure, .cutoff, 0.55),
            A.mod(.mpeTimbre, .pwm1, 0.28),
            A.mod(.mseg, .cutoff, 0.34),
            A.mod(.lfo1, .pan, 0.24),
            A.mod(.macro1, .resonance, 0.20)
        ]
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 3200
        p.filter2Resonance = 0.12
        p.filter2Balance = 0.40
        p.macro1 = 0.25
        p.mpeEnabled = true
        p.mpePitchBendRange = 48
        p.mpeZone = .lower
        p.mpeMemberChannelCount = 15
    },
        A.make("MPE Wavetable Morph", .lead) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.56
        p.osc1WavetableMorph = 0.18
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2Detune = 4
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmFine = 0.015
        p.fmAmount = 0.16
        p.attack = 0.012
        p.decay = 0.24
        p.sustain = 0.82
        p.release = 0.24
        p.filterCutoff = 3800
        p.filterResonance = 0.16
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.008
        p.filterDecay = 0.18
        p.filterSustain = 0.42
        p.filterRelease = 0.20
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.42
        p.delayMix = 0.13
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.sendA = 0.14
        p.sendB = 0.12
        p.masterVolume = 0.52
        p.lfoEnabled = true
        p.lfoRate = 5.1
        p.lfoDepth = 0.10
        p.lfoTarget = .pitch
        p.lfo2Enabled = true
        p.lfo2Rate = 0.34
        p.lfo2Target = .none
        p.modMatrix = [
            A.mod(.mpeTimbre, .wtMorph1, 0.65),
            A.mod(.mpePressure, .cutoff, 0.28),
            A.mod(.mpePressure, .fm, 0.22),
            A.mod(.lfo2, .wtMorph1, 0.32)
        ]
        p.mpeEnabled = true
        p.mpePitchBendRange = 48
        p.mpeZone = .lower
        p.mpeMemberChannelCount = 15
    },
    ]

    static var mpePresets: [SynthPreset] { mpeFactoryPresets }
}
