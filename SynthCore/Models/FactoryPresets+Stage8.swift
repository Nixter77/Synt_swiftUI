//
//  FactoryPresets+Stage8.swift
//  Three demos appended after the existing library. Old patches are untouched.
//

import Foundation

public extension SynthPreset {
    /// Filter 2, formant, and MSEG. Counted inside `libraryPresets` so the
    /// showcase slice stays `count - libraryCount - 20`.
    public static let stage8Presets: [SynthPreset] = [
        serialGlassBass,
        vowelAhLead,
        msegDrift
    ]

    private static var serialGlassBass: SynthPreset {
        var preset = SynthPreset(
            name: "Serial Glass Bass",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.62, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.005, decay: 0.24, sustain: 0.62, release: 0.18,
            filterCutoff: 720, filterResonance: 0.18,
            reverbMix: 0.04, reverbRoomSize: 0.28,
            masterVolume: 0.38
        )
        preset.filter2Routing = .serial
        preset.filter2Type = .bandPass
        preset.filter2Cutoff = 1600
        preset.filter2Resonance = 0.28
        preset.filter2Balance = 0.62
        return preset
    }

    private static var vowelAhLead: SynthPreset {
        var preset = SynthPreset(
            name: "Vowel Ah Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.9,
            osc2Enabled: false,
            attack: 0.008, decay: 0.2, sustain: 0.85, release: 0.22,
            filterCutoff: 4000, filterResonance: 0.1,
            reverbMix: 0.04, reverbRoomSize: 0.3,
            masterVolume: 0.75
        )
        preset.filterType = .formant
        preset.filterVowel = 1.4
        return preset
    }

    private static var msegDrift: SynthPreset {
        var preset = SynthPreset(
            name: "MSEG Drift",
            category: .fx,
            osc1Waveform: .triangle, osc1Volume: 0.64,
            osc2Enabled: false,
            attack: 0.02, decay: 0.4, sustain: 0.75, release: 0.35,
            filterCutoff: 2800, filterResonance: 0.08,
            reverbMix: 0.06, reverbRoomSize: 0.3,
            masterVolume: 0.36,
            modMatrix: [PresetAuthoring.mod(.mseg, .pitch1, 0.08)]
        )
        var shape = MSEGPreset()
        shape.points = [
            DSPMSEGPoint(time: 0, value: -0.55),
            DSPMSEGPoint(time: 0.4, value: 0.85, curve: -0.25),
            DSPMSEGPoint(time: 1, value: -0.15, curve: 0.2)
        ]
        shape.rateHz = 0.7
        shape.sustainIndex = nil
        shape.triggerMode = .retrigger
        preset.mseg = shape
        return preset
    }
}
