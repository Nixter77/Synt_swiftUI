//
//  FactoryPresets+Library.swift
//  Synt_swiftUI
//
//  2026-10-18: 42 patches appended after the showcase so the library is 100.
//  Legacy + showcase patches are untouched (their golden hashes stay).
//  Same authoring limits as FactoryPresets.swift; LibraryPresetTests checks
//  every patch for NaN, clipping and loudness at 1 / 3 notes (and its arp).
//

import Foundation

public extension SynthPreset {
    private typealias M = PresetAuthoring

    static let libraryPresets: [SynthPreset] =
        libBass + libLead + libPad + libKeys + libPluck + libStrings + libBrass + libArp + libFX
        + stage8Presets

    // MARK: - Bass (6)

    private static let libBass: [SynthPreset] = [
        SynthPreset(
            name: "Acid Squelch",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.68, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.003, decay: 0.20, sustain: 0.35, release: 0.090,
            filterCutoff: 520, filterResonance: 0.62,
            reverbMix: 0.03, reverbRoomSize: 0.25,
            masterVolume: 0.40, portamento: 0.06,
            modMatrix: [M.mod(.env1, .cutoff, 0.40), M.mod(.velocity, .resonance, 0.15)],
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.18, distortionTone: 0.45, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Hollow Pulse Bass",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.66, osc1Octave: -1, osc1PulseWidth: 0.18,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.30, osc2Octave: -1, osc2Detune: 0,
            attack: 0.004, decay: 0.30, sustain: 0.55, release: 0.120,
            filterCutoff: 1400, filterResonance: 0.18,
            reverbMix: 0.03, reverbRoomSize: 0.25,
            masterVolume: 0.50
        ),
        SynthPreset(
            name: "Fat Unison Bass",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.58, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.42, osc2Octave: -2, osc2Detune: 3,
            attack: 0.006, decay: 0.25, sustain: 0.80, release: 0.160,
            filterCutoff: 640, filterResonance: 0.24,
            reverbMix: 0.03, reverbRoomSize: 0.25,
            masterVolume: 0.46,
            unisonVoices: 2, unisonDetune: 10, unisonSpread: 0.35,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.16, distortionTone: 0.40, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Finger Pluck Bass",
            category: .bass,
            osc1Waveform: .triangle, osc1Volume: 0.70, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.22, osc2Octave: -1, osc2Detune: 2,
            attack: 0.002, decay: 0.38, sustain: 0.0, release: 0.120,
            filterCutoff: 700, filterResonance: 0.15,
            reverbMix: 0.04, reverbRoomSize: 0.28,
            masterVolume: 0.54,
            modMatrix: [M.mod(.env1, .cutoff, 0.30), M.mod(.velocity, .amp, 0.30)]
        ),
        SynthPreset(
            name: "Wavefold Bass",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.25, osc2Octave: -2, osc2Detune: 0,
            attack: 0.004, decay: 0.30, sustain: 0.70, release: 0.140,
            filterCutoff: 1800, filterResonance: 0.12,
            reverbMix: 0.03, reverbRoomSize: 0.25,
            masterVolume: 0.48,
            distortionEnabled: true, distortionType: .wavefolder, distortionDrive: 0.30, distortionTone: 0.45, distortionMix: 0.30
        ),
        SynthPreset(
            name: "Dub Wobble",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.62, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.36, osc2Octave: -2, osc2Detune: 0,
            attack: 0.006, decay: 0.20, sustain: 0.85, release: 0.180,
            filterCutoff: 480, filterResonance: 0.42,
            lfoEnabled: true, lfoRate: 2.0, lfoDepth: 0.30, lfoWaveform: .triangle, lfoTarget: .filter,
            reverbMix: 0.05, reverbRoomSize: 0.30,
            masterVolume: 0.48
        ),
    ]

    // MARK: - Lead (6)

    private static let libLead: [SynthPreset] = [
        SynthPreset(
            name: "Chip Square Lead",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.56, osc1Octave: 0, osc1PulseWidth: 0.25,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.18, osc2Octave: 1, osc2Detune: 0, osc2PulseWidth: 0.5,
            attack: 0.002, decay: 0.10, sustain: 0.80, release: 0.080,
            filterCutoff: 6500, filterResonance: 0.08,
            lfoEnabled: true, lfoRate: 6.0, lfoDepth: 0.04, lfoTarget: .pitch,
            reverbMix: 0.08, reverbRoomSize: 0.30,
            masterVolume: 0.42,
            distortionEnabled: true, distortionType: .bitcrusher, distortionDrive: 0.15, distortionTone: 0.55, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Glide Saw Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.58, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 8,
            attack: 0.010, decay: 0.20, sustain: 0.75, release: 0.200,
            filterCutoff: 3200, filterResonance: 0.28,
            reverbMix: 0.10, reverbRoomSize: 0.38,
            delayTime: 0.375, delayFeedback: 0.20, delayMix: 0.08,
            masterVolume: 0.46, portamento: 0.12
        ),
        SynthPreset(
            name: "Breathy Flute",
            category: .lead,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .noise, osc2Volume: 0.06, osc2Octave: 0, osc2Detune: 0,
            attack: 0.070, decay: 0.20, sustain: 0.85, release: 0.180,
            filterCutoff: 3000, filterResonance: 0.10,
            lfoEnabled: true, lfoRate: 4.8, lfoDepth: 0.03, lfoTarget: .pitch,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            masterVolume: 0.56,
            modMatrix: [M.mod(.velocity, .amp, 0.25)]
        ),
        SynthPreset(
            name: "Overdrive Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.60, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.24, osc2Octave: -1, osc2Detune: 4, osc2PulseWidth: 0.45,
            attack: 0.008, decay: 0.25, sustain: 0.80, release: 0.200,
            filterCutoff: 2400, filterResonance: 0.32,
            reverbMix: 0.10, reverbRoomSize: 0.38,
            masterVolume: 0.42,
            unisonVoices: 2, unisonDetune: 5, unisonSpread: 0.30,
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.34, distortionTone: 0.45, distortionMix: 0.28
        ),
        SynthPreset(
            name: "Whistle Lead",
            category: .lead,
            osc1Waveform: .triangle, osc1Volume: 0.62, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.30, osc2Octave: 1, osc2Detune: 3,
            attack: 0.025, decay: 0.15, sustain: 0.85, release: 0.150,
            filterCutoff: 5000, filterResonance: 0.08,
            lfoEnabled: true, lfoRate: 5.5, lfoDepth: 0.05, lfoTarget: .pitch,
            reverbMix: 0.16, reverbRoomSize: 0.42,
            masterVolume: 0.50, portamento: 0.04
        ),
        SynthPreset(
            name: "Nasal Band Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.30, osc2Octave: 0, osc2Detune: 5, osc2PulseWidth: 0.35,
            attack: 0.012, decay: 0.20, sustain: 0.78, release: 0.180,
            filterType: .bandPass, filterCutoff: 1400, filterResonance: 0.40,
            reverbMix: 0.12, reverbRoomSize: 0.40,
            masterVolume: 0.56,
            modMatrix: [M.mod(.velocity, .cutoff, 0.15)],
            eqEnabled: true, eqPreset: .vocal,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 3, eqMidFreq: 1500, eqHighGain: 0, eqHighFreq: 8000
        ),
    ]

    // MARK: - Pad (5) — chords: no unison, quieter master

    private static let libPad: [SynthPreset] = [
        SynthPreset(
            name: "Soft Saw Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.46, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 7,
            attack: 0.800, decay: 0.6, sustain: 0.85, release: 1.400,
            filterCutoff: 1600, filterResonance: 0.14,
            reverbMix: 0.22, reverbRoomSize: 0.52,
            chorusRate: 0.6, chorusDepth: 0.30, chorusMix: 0.12,
            masterVolume: 0.38
        ),
        SynthPreset(
            name: "Sine Glass Pad",
            category: .pad,
            osc1Waveform: .sine, osc1Volume: 0.56, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 1, osc2Detune: 4,
            attack: 1.200, decay: 0.8, sustain: 0.80, release: 1.600,
            filterCutoff: 4200, filterResonance: 0.08,
            lfoEnabled: true, lfoRate: 0.25, lfoDepth: 0.12, lfoTarget: .amplitude,
            reverbMix: 0.22, reverbRoomSize: 0.54,
            masterVolume: 0.44
        ),
        SynthPreset(
            name: "Dark Choir",
            category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 0, osc1WavetableMorph: 0.22,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.30, osc2Octave: -1, osc2Detune: 3,
            attack: 0.600, decay: 0.5, sustain: 0.85, release: 1.200,
            filterCutoff: 950, filterResonance: 0.12,
            reverbMix: 0.22, reverbRoomSize: 0.52,
            masterVolume: 0.44,
            eqEnabled: true, eqPreset: .vocal,
            eqLowGain: -1, eqLowFreq: 150, eqMidGain: 3, eqMidFreq: 900, eqHighGain: -2, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Pulse Sweep Pad",
            category: .pad,
            osc1Waveform: .square, osc1Volume: 0.46, osc1Octave: 0, osc1PulseWidth: 0.40,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.28, osc2Octave: 0, osc2Detune: 6,
            attack: 0.700, decay: 0.6, sustain: 0.85, release: 1.300,
            filterCutoff: 2000, filterResonance: 0.14,
            lfoEnabled: true, lfoRate: 0.35, lfoDepth: 0.0, lfoTarget: .none,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            masterVolume: 0.38,
            modMatrix: [M.mod(.lfo1, .pwm1, 0.30), M.mod(.lfo1, .cutoff, 0.15)]
        ),
        SynthPreset(
            name: "Night Swell",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.44, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.36, osc2Octave: -1, osc2Detune: 0,
            attack: 1.500, decay: 1.0, sustain: 0.90, release: 1.800,
            filterCutoff: 1100, filterResonance: 0.20,
            lfoEnabled: true, lfoRate: 0.12, lfoDepth: 0.30, lfoTarget: .filter,
            reverbMix: 0.24, reverbRoomSize: 0.55,
            masterVolume: 0.40
        ),
    ]

    // MARK: - Keys (5)

    private static let libKeys: [SynthPreset] = [
        SynthPreset(
            name: "Toy Piano",
            category: .keys,
            osc1Waveform: .triangle, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.18, osc2Octave: 2, osc2Detune: 6,
            attack: 0.002, decay: 0.55, sustain: 0.0, release: 0.300,
            filterCutoff: 6000, filterResonance: 0.08,
            reverbMix: 0.12, reverbRoomSize: 0.35,
            masterVolume: 0.50,
            modMatrix: [M.mod(.velocity, .amp, 0.35)]
        ),
        SynthPreset(
            name: "Digital EP",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.26, osc2Octave: 1, osc2Detune: 4,
            attack: 0.003, decay: 1.20, sustain: 0.25, release: 0.500,
            filterCutoff: 5000, filterResonance: 0.08,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            chorusRate: 0.8, chorusDepth: 0.30, chorusMix: 0.10,
            masterVolume: 0.48,
            modMatrix: [M.mod(.velocity, .amp, 0.40), M.mod(.velocity, .mix, 0.20)]
        ),
        SynthPreset(
            name: "Rotary Organ",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.56, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.40, osc2Octave: 1, osc2Detune: 0,
            attack: 0.004, decay: 0.10, sustain: 0.90, release: 0.080,
            filterCutoff: 4500, filterResonance: 0.06,
            lfoEnabled: true, lfoRate: 6.2, lfoDepth: 0.35, lfoTarget: .pan,
            reverbMix: 0.12, reverbRoomSize: 0.38,
            masterVolume: 0.42
        ),
        SynthPreset(
            name: "Bright Harpsi",
            category: .keys,
            osc1Waveform: .sawtooth, osc1Volume: 0.52, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.22, osc2Octave: 1, osc2Detune: 2, osc2PulseWidth: 0.20,
            attack: 0.001, decay: 0.60, sustain: 0.0, release: 0.250,
            filterCutoff: 4800, filterResonance: 0.10,
            reverbMix: 0.12, reverbRoomSize: 0.36,
            masterVolume: 0.44,
            eqEnabled: true, eqPreset: .bassCut,
            eqLowGain: -4, eqLowFreq: 180, eqMidGain: 0, eqMidFreq: 1000, eqHighGain: 1, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Mellow Vibes",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.66, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.16, osc2Octave: 2, osc2Detune: 0,
            attack: 0.002, decay: 1.50, sustain: 0.0, release: 0.800,
            filterCutoff: 5000, filterResonance: 0.06,
            lfoEnabled: true, lfoRate: 5.0, lfoDepth: 0.22, lfoTarget: .amplitude,
            reverbMix: 0.16, reverbRoomSize: 0.42,
            masterVolume: 0.50,
            modMatrix: [M.mod(.velocity, .amp, 0.30)]
        ),
    ]

    // MARK: - Pluck (5)

    private static let libPluck: [SynthPreset] = [
        SynthPreset(
            name: "Koto Pluck",
            category: .pluck,
            osc1Waveform: .square, osc1Volume: 0.56, osc1Octave: 0, osc1PulseWidth: 0.30,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.28, osc2Octave: 1, osc2Detune: 3,
            attack: 0.002, decay: 0.35, sustain: 0.0, release: 0.220,
            filterCutoff: 1600, filterResonance: 0.22,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            masterVolume: 0.48,
            modMatrix: [M.mod(.env1, .cutoff, 0.35)]
        ),
        SynthPreset(
            name: "Marimba",
            category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.72, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.14, osc2Octave: 2, osc2Detune: 0,
            attack: 0.001, decay: 0.32, sustain: 0.0, release: 0.180,
            filterCutoff: 3500, filterResonance: 0.06,
            reverbMix: 0.10, reverbRoomSize: 0.34,
            masterVolume: 0.56,
            modMatrix: [M.mod(.velocity, .amp, 0.30)]
        ),
        SynthPreset(
            name: "Harp Glimmer",
            category: .pluck,
            osc1Waveform: .triangle, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.28, osc2Octave: 1, osc2Detune: 4,
            attack: 0.002, decay: 0.90, sustain: 0.0, release: 0.700,
            filterCutoff: 4200, filterResonance: 0.08,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            masterVolume: 0.50
        ),
        SynthPreset(
            name: "Muted Synth Pluck",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.64, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.20, osc2Octave: -1, osc2Detune: 2,
            attack: 0.001, decay: 0.15, sustain: 0.0, release: 0.100,
            filterCutoff: 950, filterResonance: 0.34,
            reverbMix: 0.06, reverbRoomSize: 0.30,
            masterVolume: 0.52
        ),
        SynthPreset(
            name: "Echo Pluck",
            category: .pluck,
            osc1Waveform: .square, osc1Volume: 0.54, osc1Octave: 0, osc1PulseWidth: 0.5,
            osc2Enabled: false,
            attack: 0.001, decay: 0.25, sustain: 0.0, release: 0.150,
            filterCutoff: 2600, filterResonance: 0.18,
            reverbMix: 0.10, reverbRoomSize: 0.36,
            delayTime: 0.375, delayFeedback: 0.22, delayMix: 0.10,
            masterVolume: 0.48
        ),
    ]

    // MARK: - Strings (4)

    private static let libStrings: [SynthPreset] = [
        SynthPreset(
            name: "Slow Violas",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.46, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 6,
            attack: 0.550, decay: 0.5, sustain: 0.85, release: 0.900,
            filterCutoff: 2200, filterResonance: 0.12,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            chorusRate: 0.5, chorusDepth: 0.28, chorusMix: 0.10,
            masterVolume: 0.40
        ),
        SynthPreset(
            name: "Pizzicato",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.56, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.30, osc2Octave: 0, osc2Detune: 4,
            attack: 0.002, decay: 0.24, sustain: 0.0, release: 0.180,
            filterCutoff: 2500, filterResonance: 0.10,
            reverbMix: 0.16, reverbRoomSize: 0.44,
            masterVolume: 0.50,
            modMatrix: [M.mod(.velocity, .amp, 0.30)]
        ),
        SynthPreset(
            name: "Solo Cello",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.58, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.34, osc2Octave: -1, osc2Detune: 4,
            attack: 0.180, decay: 0.3, sustain: 0.85, release: 0.450,
            filterCutoff: 1500, filterResonance: 0.14,
            lfoEnabled: true, lfoRate: 5.0, lfoDepth: 0.03, lfoTarget: .pitch,
            reverbMix: 0.18, reverbRoomSize: 0.46,
            masterVolume: 0.46
        ),
        SynthPreset(
            name: "String Machine",
            category: .strings,
            osc1Waveform: .square, osc1Volume: 0.44, osc1Octave: 0, osc1PulseWidth: 0.45,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.36, osc2Octave: 1, osc2Detune: 5,
            attack: 0.250, decay: 0.4, sustain: 0.85, release: 0.700,
            filterCutoff: 2800, filterResonance: 0.10,
            reverbMix: 0.16, reverbRoomSize: 0.44,
            chorusRate: 0.9, chorusDepth: 0.40, chorusMix: 0.14,
            masterVolume: 0.38
        ),
    ]

    // MARK: - Brass (5)

    private static let libBrass: [SynthPreset] = [
        SynthPreset(
            name: "Brass Stab",
            category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.54, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.42, osc2Octave: 0, osc2Detune: 5,
            attack: 0.020, decay: 0.25, sustain: 0.55, release: 0.180,
            filterCutoff: 1400, filterResonance: 0.20,
            reverbMix: 0.12, reverbRoomSize: 0.40,
            masterVolume: 0.42,
            modMatrix: [M.mod(.env1, .cutoff, 0.30), M.mod(.velocity, .cutoff, 0.15)]
        ),
        SynthPreset(
            name: "Soft Horns",
            category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.50, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.38, osc2Octave: 0, osc2Detune: 3,
            attack: 0.120, decay: 0.3, sustain: 0.80, release: 0.350,
            filterCutoff: 1150, filterResonance: 0.12,
            reverbMix: 0.18, reverbRoomSize: 0.46,
            masterVolume: 0.46,
            modMatrix: [M.mod(.velocity, .cutoff, 0.20)]
        ),
        SynthPreset(
            name: "Trumpet Lead",
            category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.58, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.24, osc2Octave: 0, osc2Detune: 2, osc2PulseWidth: 0.45,
            attack: 0.040, decay: 0.20, sustain: 0.80, release: 0.180,
            filterCutoff: 2600, filterResonance: 0.24,
            lfoEnabled: true, lfoRate: 5.5, lfoDepth: 0.03, lfoTarget: .pitch,
            reverbMix: 0.14, reverbRoomSize: 0.42,
            masterVolume: 0.44,
            modMatrix: [M.mod(.env1, .cutoff, 0.15)],
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: -1, eqLowFreq: 150, eqMidGain: 2, eqMidFreq: 1800, eqHighGain: 0, eqHighFreq: 8000
        ),
        SynthPreset(
            name: "Synth Brass Pad",
            category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.46, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 8,
            attack: 0.300, decay: 0.5, sustain: 0.80, release: 0.600,
            filterCutoff: 1800, filterResonance: 0.16,
            reverbMix: 0.18, reverbRoomSize: 0.48,
            chorusRate: 0.7, chorusDepth: 0.30, chorusMix: 0.10,
            masterVolume: 0.38
        ),
        SynthPreset(
            name: "Low Tuba",
            category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.60, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.26, osc2Octave: -2, osc2Detune: 0, osc2PulseWidth: 0.45,
            attack: 0.060, decay: 0.25, sustain: 0.80, release: 0.200,
            filterCutoff: 700, filterResonance: 0.14,
            reverbMix: 0.10, reverbRoomSize: 0.40,
            masterVolume: 0.50
        ),
    ]

    // MARK: - Arp / Seq (4) — hold a chord, the arp plays it

    private static let libArp: [SynthPreset] = [
        SynthPreset(
            name: "Up Arp Pluck",
            category: .arp,
            osc1Waveform: .square, osc1Volume: 0.54, osc1Octave: 0, osc1PulseWidth: 0.35,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 1, osc2Detune: 0,
            attack: 0.001, decay: 0.16, sustain: 0.0, release: 0.100,
            filterCutoff: 2400, filterResonance: 0.22,
            reverbMix: 0.10, reverbRoomSize: 0.36,
            masterVolume: 0.48,
            arpMode: .up, arpRate: .sixteenth, bpm: 120
        ),
        SynthPreset(
            name: "Down Arp Bells",
            category: .arp,
            osc1Waveform: .sine, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.20, osc2Octave: 2, osc2Detune: 5,
            attack: 0.001, decay: 0.45, sustain: 0.0, release: 0.400,
            filterCutoff: 5000, filterResonance: 0.06,
            reverbMix: 0.18, reverbRoomSize: 0.46,
            masterVolume: 0.50,
            arpMode: .down, arpRate: .eighth, bpm: 100
        ),
        SynthPreset(
            name: "Random Sparkle",
            category: .arp,
            osc1Waveform: .triangle, osc1Volume: 0.58, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.24, osc2Octave: 1, osc2Detune: 6,
            attack: 0.001, decay: 0.20, sustain: 0.0, release: 0.150,
            filterCutoff: 5500, filterResonance: 0.08,
            reverbMix: 0.14, reverbRoomSize: 0.44,
            delayTime: 0.25, delayFeedback: 0.20, delayMix: 0.08,
            masterVolume: 0.44,
            arpMode: .random, arpRate: .sixteenth, bpm: 128
        ),
        SynthPreset(
            name: "UpDown Bass Arp",
            category: .arp,
            osc1Waveform: .sawtooth, osc1Volume: 0.64, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.24, osc2Octave: -1, osc2Detune: 3, osc2PulseWidth: 0.4,
            attack: 0.002, decay: 0.18, sustain: 0.20, release: 0.090,
            filterCutoff: 900, filterResonance: 0.30,
            reverbMix: 0.04, reverbRoomSize: 0.28,
            masterVolume: 0.48,
            modMatrix: [M.mod(.env1, .cutoff, 0.25)],
            arpMode: .upDown, arpRate: .sixteenth, bpm: 124
        ),
    ]

    // MARK: - FX (2)

    private static let libFX: [SynthPreset] = [
        SynthPreset(
            name: "Laser Zap",
            category: .fx,
            osc1Waveform: .sine, osc1Volume: 0.62, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 0, osc2Detune: 0,
            attack: 0.001, decay: 0.22, sustain: 0.0, release: 0.120,
            filterCutoff: 6000, filterResonance: 0.10,
            reverbMix: 0.12, reverbRoomSize: 0.40,
            masterVolume: 0.42,
            modMatrix: [M.mod(.env1, .pitch1, 1.5), M.mod(.env1, .pitch2, 1.2)]
        ),
        SynthPreset(
            name: "Wind Gust",
            category: .fx,
            osc1Waveform: .noise, osc1Volume: 0.46, osc1Octave: 0,
            osc2Enabled: false,
            attack: 0.900, decay: 0.8, sustain: 0.85, release: 1.500,
            filterType: .bandPass, filterCutoff: 1100, filterResonance: 0.55,
            lfoEnabled: true, lfoRate: 0.15, lfoDepth: 0.40, lfoTarget: .filter,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            masterVolume: 0.48
        ),
    ]
}
