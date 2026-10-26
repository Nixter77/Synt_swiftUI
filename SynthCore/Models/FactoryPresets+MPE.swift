//
//  FactoryPresets+MPE.swift
//  Two MPE demos for the current engine: pressure to cutoff, timbre to
//  wavetable morph. Refreshed with filter 2 / macros; still a small set.
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    static let mpeFactoryPresets: [SynthPreset] = [
        A.make("MPE Expressive Pad", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.3
        p.osc2Detune = 4
        p.attack = 0.08
        p.decay = 0.3
        p.sustain = 0.78
        p.release = 0.45
        p.filterCutoff = 1100
        p.filterResonance = 0.22
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.4
        p.masterVolume = 0.36
        p.modMatrix = [
                A.mod(.mpePressure, .cutoff, 0.55),
                A.mod(.macro1, .resonance, 0.2)
            ]
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 3200
        p.filter2Resonance = 0.12
        p.filter2Balance = 0.4
        p.macro1 = 0.25
        p.mpeEnabled = true
        p.mpePitchBendRange = 48
        p.mpeZone = .lower
        p.mpeMemberChannelCount = 15
    },
        A.make("MPE Wavetable Morph", .lead) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.58
        p.osc1WavetableMorph = 0.16
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.attack = 0.01
        p.decay = 0.22
        p.sustain = 0.85
        p.release = 0.22
        p.filterCutoff = 4200
        p.filterResonance = 0.12
        p.reverbMix = 0.08
        p.masterVolume = 0.5
        p.modMatrix = [A.mod(.mpeTimbre, .wtMorph1, 0.65), A.mod(.mpePressure, .cutoff, 0.2)]
        p.mpeEnabled = true
        p.mpePitchBendRange = 48
        p.mpeZone = .lower
        p.mpeMemberChannelCount = 15
    },
    ]

    static var mpePresets: [SynthPreset] { mpeFactoryPresets }
}
