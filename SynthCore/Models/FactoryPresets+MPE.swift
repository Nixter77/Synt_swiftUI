//
//  FactoryPresets+MPE.swift
//  SynthCore
//
//  Stage 4 factory MPE presets demonstrating per-voice MPE modulation:
//  - Pressure -> filter cutoff
//  - CC74 Timbre -> wavetable position (morph)
//

import Foundation

public extension SynthPreset {
    /// Factory MPE presets demonstrating per-voice MPE modulation.
    static let mpeFactoryPresets: [SynthPreset] = [
        // 1. Pressure -> Filter Cutoff
        SynthPreset(
            name: "MPE Expressive Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.6,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.4,
            attack: 0.05, decay: 0.3, sustain: 0.8, release: 0.4,
            filterCutoff: 1200, filterResonance: 0.3,
            modMatrix: [ModMatrixEntry(source: .mpePressure, destination: .cutoff, amount: 0.6)],
            mpeEnabled: true,
            mpePitchBendRange: 48,
            mpeZone: .lower,
            mpeMemberChannelCount: 15
        ),
        // 2. CC74 Timbre -> Wavetable Morph / Position
        SynthPreset(
            name: "MPE Wavetable Morph",
            category: .lead,
            osc1Waveform: .wavetable, osc1Volume: 0.7, osc1WavetableMorph: 0.1,
            attack: 0.01, decay: 0.2, sustain: 0.9, release: 0.2,
            filterCutoff: 8000, filterResonance: 0.2,
            modMatrix: [ModMatrixEntry(source: .mpeTimbre, destination: .wtMorph1, amount: 0.7)],
            mpeEnabled: true,
            mpePitchBendRange: 48,
            mpeZone: .lower,
            mpeMemberChannelCount: 15
        )
    ]

    static var mpePresets: [SynthPreset] { mpeFactoryPresets }
}
