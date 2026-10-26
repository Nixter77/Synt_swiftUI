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
        p.osc1Volume = 0.55
        p.osc1Octave = -1
        p.attack = 0.006
        p.decay = 0.22
        p.sustain = 0.6
        p.release = 0.18
        p.filterCutoff = 680
        p.filterResonance = 0.16
        p.reverbMix = 0.04
        p.reverbRoomSize = 0.28
        p.masterVolume = 0.42
        p.modMatrix = [A.mod(.env1, .cutoff, 0.12)]
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
        p.osc1Volume = 0.95
        p.attack = 0.008
        p.decay = 0.2
        p.sustain = 0.85
        p.release = 0.22
        p.filterType = .formant
        p.filterCutoff = 2600
        p.filterResonance = 0.06
        p.lfoEnabled = true
        p.lfoRate = 0.3
        p.lfoTarget = .none
        p.reverbMix = 0.06
        p.reverbRoomSize = 0.32
        p.masterVolume = 0.64
        p.modMatrix = [A.mod(.lfo1, .vowel, 0.18)]
        p.filterVowel = 1.4
    }
    }

    private static var msegDrift: SynthPreset {
        A.make("MSEG Drift", .fx) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.55
        p.attack = 0.02
        p.decay = 0.35
        p.sustain = 0.72
        p.release = 0.35
        p.filterCutoff = 2400
        p.filterResonance = 0.08
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.32
        p.masterVolume = 0.38
        p.modMatrix = [A.mod(.mseg, .pitch1, 0.08)]
        p.mseg = A.shape(rate: 0.7, -0.55, 0.85, -0.15)
    }
    }
}
