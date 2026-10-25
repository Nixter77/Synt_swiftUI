//
//  FactoryPresets+Showcase.swift
//  Synt_swiftUI
//
//  Showcase library (2026-10-13): patches that use the newer engine features —
//  every matrix destination, raw LFO rows (lfoRowsFollowDepth = false,
//  incl. "Matrix only" LFO), Voices/unison, phaser modes and per-effect settings.
//  Appended after the legacy library; legacy patches are untouched.
//  Same authoring limits as FactoryPresets.swift (tests enforce them).
//

import Foundation

public extension SynthPreset {
    private typealias M = PresetAuthoring

    static let showcasePresets: [SynthPreset] = [
        // MARK: Bass
        SynthPreset(
            name: "Rubber Wobble",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.66, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.26, osc2Octave: -2, osc2PulseWidth: 0.40,
            attack: 0.006, decay: 0.2, sustain: 0.8, release: 0.160,
            filterCutoff: 700, filterResonance: 0.34,
            lfoEnabled: true, lfoRate: 2.0, lfoDepth: 0.0, lfoWaveform: .triangle, lfoTarget: .none,
            reverbMix: 0.04,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 6, unisonSpread: 0.30,
            modMatrix: [M.mod(.lfo1, .cutoff, 0.30), M.mod(.velocity, .lfoRate, 0.25)],
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.14, distortionTone: 0.40, distortionMix: 0.10
        ),
        SynthPreset(
            name: "PWM Sub Pulse",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.68, osc1Octave: -1, osc1PulseWidth: 0.45,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.30, osc2Octave: -2,
            attack: 0.005, decay: 0.25, sustain: 0.75, release: 0.150,
            filterCutoff: 900, filterResonance: 0.20,
            lfoEnabled: true, lfoRate: 0.6, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.04,
            masterVolume: 0.50,
            modMatrix: [M.mod(.lfo1, .pwm1, 0.35)],
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 3, eqLowFreq: 70, eqMidGain: -1, eqMidFreq: 800, eqHighGain: -2, eqHighFreq: 5000
        ),
        SynthPreset(
            name: "Snap Resonator",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.68, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.004, decay: 0.18, sustain: 0.40, release: 0.110,
            filterCutoff: 850, filterResonance: 0.30,
            reverbMix: 0.04,
            masterVolume: 0.50, portamento: 0.03,
            modMatrix: [M.mod(.env1, .cutoff, 0.25), M.mod(.velocity, .resonance, 0.25)]
        ),
        // MARK: Lead
        SynthPreset(
            name: "Vox Morph Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.58, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 4,
            attack: 0.015, decay: 0.2, sustain: 0.72, release: 0.220,
            filterCutoff: 2200, filterResonance: 0.26,
            lfoEnabled: true, lfoRate: 0.9, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 6, unisonSpread: 0.35,
            modMatrix: [M.mod(.lfo1, .mix, 0.40), M.mod(.lfo1, .cutoff, 0.12)]
        ),
        SynthPreset(
            name: "Delayed Vibrato",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.24, osc2Octave: 0, osc2Detune: 3, osc2PulseWidth: 0.42,
            attack: 0.030, decay: 0.3, sustain: 0.75, release: 0.250,
            filterCutoff: 2600, filterResonance: 0.22,
            lfoEnabled: true, lfoRate: 5.4, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            delayTime: 0.30, delayFeedback: 0.18, delayMix: 0.07,
            masterVolume: 0.48, portamento: 0.05,
            modMatrix: [M.mod(.lfo1, .pitch1, 0.012), M.mod(.lfo1, .pitch2, 0.012), M.mod(.lfo1, .pwm2, 0.15), M.mod(.env1, .cutoff, 0.10)]
        ),
        SynthPreset(
            name: "Fifth Sync Lead",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.56, osc1Octave: 0, osc1PulseWidth: 0.38,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.32, osc2Octave: 0, osc2Detune: 2,
            attack: 0.008, decay: 0.22, sustain: 0.65, release: 0.180,
            filterCutoff: 2400, filterResonance: 0.28,
            reverbMix: 0.12,
            masterVolume: 0.46,
            unisonVoices: 2, unisonDetune: 5, unisonSpread: 0.25,
            modMatrix: [M.mod(.velocity, .pitch2, 0.05), M.mod(.velocity, .cutoff, 0.15)],
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.12, distortionTone: 0.42, distortionMix: 0.08
        ),
        // MARK: Pad
        SynthPreset(
            name: "Phase Cathedral",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.46, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.40, osc2Octave: 1, osc2Detune: 5,
            attack: 0.700, decay: 0.8, sustain: 0.85, release: 1.400,
            filterCutoff: 1800, filterResonance: 0.16,
            lfoEnabled: true, lfoRate: 0.08, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            masterVolume: 0.40,
            modMatrix: [M.mod(.lfo1, .cutoff, 0.10)],
            phaserEnabled: true, phaserMode: .phaser8, phaserRate: 0.10, phaserDepth: 0.60,
            phaserFeedback: 0.30, phaserCenterFrequency: 650, phaserStereoSpread: 0.70, phaserMix: 0.35
        ),
        SynthPreset(
            name: "Breathing Glass",
            category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 0, osc1WavetableMorph: 0.20,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.34, osc2Octave: 1, osc2Detune: 4,
            attack: 0.900, decay: 1.0, sustain: 0.85, release: 1.600,
            filterCutoff: 2400, filterResonance: 0.14,
            lfoEnabled: true, lfoRate: 0.18, lfoDepth: 0.0, lfoWaveform: .triangle, lfoTarget: .none,
            reverbMix: 0.20, reverbRoomSize: 0.52,
            chorusRate: 0.35, chorusDepth: 0.30, chorusMix: 0.10,
            masterVolume: 0.40,
            modMatrix: [M.mod(.lfo1, .amp, 0.18), M.mod(.lfo1, .pan, 0.30)]
        ),
        SynthPreset(
            name: "Tidal Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.44, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.38, osc2Octave: 0, osc2Detune: 7,
            attack: 0.600, decay: 0.8, sustain: 0.8, release: 1.200,
            filterCutoff: 1400, filterResonance: 0.22,
            lfoEnabled: true, lfoRate: 0.12, lfoDepth: 0.15, lfoTarget: .filter,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            masterVolume: 0.40,
            modMatrix: [M.mod(.lfo1, .lfoRate, 0.30), M.mod(.lfo1, .resonance, 0.15)],
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.15, phaserDepth: 0.45,
            phaserFeedback: 0.20, phaserCenterFrequency: 800, phaserStereoSpread: 0.50, phaserMix: 0.28
        ),
        // MARK: Keys
        SynthPreset(
            name: "Phaser Rhodes",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 1, osc2Detune: 2,
            attack: 0.004, decay: 0.9, sustain: 0.35, release: 0.450,
            filterCutoff: 2600, filterResonance: 0.14,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            masterVolume: 0.48,
            modMatrix: [M.mod(.velocity, .cutoff, 0.20), M.mod(.velocity, .amp, 0.30)],
            phaserEnabled: true, phaserMode: .phaser2, phaserRate: 0.45, phaserDepth: 0.40,
            phaserFeedback: 0.12, phaserCenterFrequency: 1000, phaserStereoSpread: 0.60, phaserMix: 0.30
        ),
        SynthPreset(
            name: "Wurli Tremolo",
            category: .keys,
            osc1Waveform: .triangle, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.14, osc2Octave: 0, osc2PulseWidth: 0.30,
            attack: 0.004, decay: 0.7, sustain: 0.40, release: 0.350,
            filterCutoff: 2000, filterResonance: 0.18,
            lfoEnabled: true, lfoRate: 4.8, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.12, reverbRoomSize: 0.36,
            masterVolume: 0.50,
            modMatrix: [M.mod(.lfo1, .amp, 0.20), M.mod(.lfo1, .pan, 0.15)],
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.10, distortionTone: 0.38, distortionMix: 0.08
        ),
        SynthPreset(
            name: "Velvet Clav",
            category: .keys,
            osc1Waveform: .square, osc1Volume: 0.56, osc1Octave: 0, osc1PulseWidth: 0.25,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.20, osc2Octave: 1,
            attack: 0.003, decay: 0.30, sustain: 0.20, release: 0.120,
            filterCutoff: 2200, filterResonance: 0.30,
            reverbMix: 0.08,
            masterVolume: 0.50,
            modMatrix: [M.mod(.velocity, .pwm1, 0.40), M.mod(.env1, .resonance, 0.15)],
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: -1, eqLowFreq: 120, eqMidGain: 2, eqMidFreq: 1600, eqHighGain: 0, eqHighFreq: 6000
        ),
        // MARK: Pluck
        SynthPreset(
            name: "Pan Ping Pluck",
            category: .pluck,
            osc1Waveform: .triangle, osc1Volume: 0.64, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.24, osc2Octave: 1, osc2Detune: 3,
            attack: 0.004, decay: 0.32, sustain: 0.08, release: 0.280,
            filterCutoff: 3000, filterResonance: 0.20,
            lfoEnabled: true, lfoRate: 1.5, lfoDepth: 0.0, lfoWaveform: .square, lfoTarget: .none,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            delayTime: 0.25, delayFeedback: 0.18, delayMix: 0.07,
            masterVolume: 0.50,
            modMatrix: [M.mod(.lfo1, .pan, 0.45)]
        ),
        SynthPreset(
            name: "Flange Harp",
            category: .pluck,
            osc1Waveform: .wavetable, osc1Volume: 0.58, osc1Octave: 0, osc1WavetableMorph: 0.26,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.22, osc2Octave: 1, osc2Detune: 4,
            attack: 0.004, decay: 0.45, sustain: 0.06, release: 0.400,
            filterCutoff: 3200, filterResonance: 0.18,
            reverbMix: 0.16, reverbRoomSize: 0.44,
            masterVolume: 0.48,
            modMatrix: [M.mod(.velocity, .cutoff, 0.15)],
            phaserEnabled: true, phaserMode: .flanger, phaserRate: 0.20, phaserDepth: 0.35,
            phaserFeedback: 0.30, phaserCenterFrequency: 900, phaserStereoSpread: 0.40, phaserMix: 0.25
        ),
        SynthPreset(
            name: "Bit Pluck Arp",
            category: .pluck,
            osc1Waveform: .square, osc1Volume: 0.56, osc1Octave: 0, osc1PulseWidth: 0.30,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.22, osc2Octave: 1,
            attack: 0.003, decay: 0.14, sustain: 0.10, release: 0.100,
            filterCutoff: 2800, filterResonance: 0.26,
            reverbMix: 0.10,
            delayTime: 0.19, delayFeedback: 0.18, delayMix: 0.07,
            masterVolume: 0.46,
            modMatrix: [M.mod(.velocity, .pwm1, 0.30), M.mod(.velocity, .mix, -0.20)],
            arpMode: .upDown, bpm: 118,
            distortionEnabled: true, distortionType: .bitcrusher, distortionDrive: 0.12, distortionTone: 0.50, distortionMix: 0.08
        ),
        // MARK: Strings
        SynthPreset(
            name: "Chamber Swell",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.48, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 6,
            attack: 0.500, decay: 0.5, sustain: 0.85, release: 0.800,
            filterCutoff: 1500, filterResonance: 0.16,
            lfoEnabled: true, lfoRate: 5.2, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            chorusRate: 0.40, chorusDepth: 0.26, chorusMix: 0.10,
            masterVolume: 0.44,
            modMatrix: [M.mod(.env1, .cutoff, 0.15), M.mod(.lfo1, .pitch1, 0.006)]
        ),
        SynthPreset(
            name: "Phased Violins",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.46, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.34, osc2Octave: 1, osc2Detune: 5,
            attack: 0.350, decay: 0.4, sustain: 0.85, release: 0.700,
            filterCutoff: 2200, filterResonance: 0.14,
            reverbMix: 0.18, reverbRoomSize: 0.48,
            masterVolume: 0.42,
            modMatrix: [M.mod(.velocity, .amp, 0.25)],
            phaserEnabled: true, phaserMode: .phaser6, phaserRate: 0.22, phaserDepth: 0.45,
            phaserFeedback: 0.18, phaserCenterFrequency: 1100, phaserStereoSpread: 0.60, phaserMix: 0.28
        ),
        // MARK: FX
        SynthPreset(
            name: "Siren Drift",
            category: .fx,
            osc1Waveform: .triangle, osc1Volume: 0.52, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.30, osc2Octave: 1, osc2Detune: 4,
            attack: 0.200, decay: 0.5, sustain: 0.8, release: 0.800,
            filterCutoff: 2400, filterResonance: 0.20,
            lfoEnabled: true, lfoRate: 0.5, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.18, reverbRoomSize: 0.50,
            delayTime: 0.33, delayFeedback: 0.18, delayMix: 0.07,
            masterVolume: 0.42,
            modMatrix: [M.mod(.lfo1, .pitch1, 0.08), M.mod(.lfo1, .pitch2, -0.08), M.mod(.lfo1, .lfoRate, 0.25)]
        ),
        SynthPreset(
            name: "Jet Flanger",
            category: .fx,
            osc1Waveform: .noise, osc1Volume: 0.40, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.26, osc2Octave: -1,
            attack: 0.300, decay: 0.6, sustain: 0.7, release: 1.000,
            filterCutoff: 2000, filterResonance: 0.24,
            lfoEnabled: true, lfoRate: 0.12, lfoDepth: 0.15, lfoTarget: .filter,
            reverbMix: 0.16, reverbRoomSize: 0.46,
            masterVolume: 0.40,
            modMatrix: [M.mod(.lfo1, .cutoff, 0.20), M.mod(.velocity, .lfoDepth, 0.30)],
            phaserEnabled: true, phaserMode: .flanger, phaserRate: 0.10, phaserDepth: 0.55,
            phaserFeedback: 0.40, phaserCenterFrequency: 1200, phaserStereoSpread: 0.70, phaserMix: 0.35
        ),
        SynthPreset(
            name: "Random Bloom",
            category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 1, osc1WavetableMorph: 0.18,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 0, osc2Detune: 6,
            attack: 0.010, decay: 0.35, sustain: 0.2, release: 0.500,
            filterCutoff: 2600, filterResonance: 0.26,
            lfoEnabled: true, lfoRate: 3.0, lfoDepth: 0.0, lfoWaveform: .noise, lfoTarget: .none,
            reverbMix: 0.18, reverbRoomSize: 0.50,
            delayTime: 0.24, delayFeedback: 0.18, delayMix: 0.07,
            masterVolume: 0.42,
            unisonVoices: 2, unisonDetune: 7, unisonSpread: 0.45,
            modMatrix: [M.mod(.lfo1, .cutoff, 0.20), M.mod(.lfo1, .pan, 0.35)],
            arpMode: .random, bpm: 110
        ),
    ]
}
