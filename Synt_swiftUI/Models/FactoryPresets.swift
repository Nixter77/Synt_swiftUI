//
//  FactoryPresets.swift
//  Synt_swiftUI
//
//  Factory library authored for the *live* render path, not for a future engine.
//
//  What the code actually does today:
//  - Filter: knob + LFO→filter. `filterEnvelopeAmount` and matrix→cutoff are stored, not heard.
//  - Matrix that sounds: pitch1 / pitch2 / amp / pan. PWM / cutoff / mix do nothing.
//  - Wavetable is one table (Basic Shapes): 0 sine → 0.33 tri → 0.67 saw → 1 square.
//  - Unison only while one key is held; a second key collapses to 1 partial. Useless on pads.
//  - Apple Delay/Reverb sit after our clipper. Wet chords rasp. Keep sends modest.
//  - Osc2 is mixed 50/50 with osc1 (volumes still relative). Two bright sources + octave = sand.
//  - Linear sum: 4 notes are louder than 1. Pads/strings stay quieter at the master.
//  - Phaser / deep chorus / distortion have no oversample. One extra FX, mild, or none.
//
//  Authoring limits (must match tests):
//  - reverbMix ≤ 0.24, room ≤ 0.55, delayMix ≤ 0.10, delayFeedback ≤ 0.22
//  - chorusMix ≤ 0.14; unison ≤ 2 and only bass / lead / mono FX
//  - no two wavetable oscillators; WT morph stays in 0.08…0.40 (sine–tri), not square
//  - Env Amt = 0; matrix only live destinations
//  - Init (`defaultPreset`) is not in this list and must stay untouched
//

import Foundation

extension SynthPreset {
    /// Full factory library grouped by category.
    static let factoryPresets: [SynthPreset] = bassPresets
        + leadPresets
        + padPresets
        + keysPresets
        + pluckPresets
        + stringsPresets
        + fxPresets

    // MARK: - BASS (6) — usually one note: unison / mild drive are safe

    private static let bassPresets: [SynthPreset] = [
        SynthPreset(
            name: "Clean Sub",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.75, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.22, osc2Octave: -1, osc2Detune: 2,
            attack: 0.008, decay: 0.12, sustain: 0.92, release: 0.180,
            filterCutoff: 320, filterResonance: 0.12,
            reverbMix: 0.04, reverbRoomSize: 0.28,
            masterVolume: 0.54,
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 4, eqLowFreq: 70, eqMidGain: -1, eqMidFreq: 800, eqHighGain: -3, eqHighFreq: 5000
        ),
        SynthPreset(
            name: "Velvet Acid",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.70, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.30, osc2Octave: -1, osc2Detune: 6, osc2PulseWidth: 0.35,
            attack: 0.005, decay: 0.22, sustain: 0.42, release: 0.120,
            filterCutoff: 980, filterResonance: 0.42,
            lfoEnabled: true, lfoRate: 0.32, lfoDepth: 0.28, lfoTarget: .filter,
            reverbMix: 0.06,
            masterVolume: 0.50, portamento: 0.04,
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.16, distortionTone: 0.38, distortionMix: 0.10,
            eqEnabled: true, eqPreset: .midScoop,
            eqLowGain: 2, eqLowFreq: 90, eqMidGain: -2, eqMidFreq: 900, eqHighGain: 0, eqHighFreq: 6000
        ),
        SynthPreset(
            name: "Round Reese",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.62, osc1Octave: -1, osc1Detune: -5,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.50, osc2Octave: -1, osc2Detune: 6,
            attack: 0.020, decay: 0.25, sustain: 0.8, release: 0.250,
            filterCutoff: 880, filterResonance: 0.30,
            reverbMix: 0.08, reverbRoomSize: 0.35,
            chorusRate: 0.7, chorusDepth: 0.28, chorusMix: 0.10,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 8, unisonSpread: 0.40,
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 3, eqLowFreq: 85, eqMidGain: -2, eqMidFreq: 1200, eqHighGain: -2, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Wavetable Growl",
            category: .bass,
            osc1Waveform: .wavetable, osc1Volume: 0.68, osc1Octave: -1, osc1WavetableMorph: 0.36,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.24, osc2Octave: -2, osc2PulseWidth: 0.32,
            attack: 0.010, decay: 0.2, sustain: 0.7, release: 0.200,
            filterCutoff: 1050, filterResonance: 0.38,
            lfoEnabled: true, lfoRate: 3.8, lfoDepth: 0.18, lfoTarget: .filter,
            reverbMix: 0.07,
            masterVolume: 0.48,
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.16, distortionTone: 0.42, distortionMix: 0.10
        ),
        SynthPreset(
            name: "Muted Funk",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.72, osc1Octave: -1, osc1PulseWidth: 0.28,
            osc2Enabled: false,
            attack: 0.005, decay: 0.16, sustain: 0.45, release: 0.100,
            filterCutoff: 1300, filterResonance: 0.36,
            reverbMix: 0.04,
            masterVolume: 0.54,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.35)],
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: 2, eqLowFreq: 100, eqMidGain: 2, eqMidFreq: 900, eqHighGain: -2, eqHighFreq: 5000
        ),
        SynthPreset(
            name: "Soft 808",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.75, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.18, osc2Octave: -1, osc2Detune: 2,
            attack: 0.005, decay: 0.45, sustain: 0.15, release: 0.350,
            filterCutoff: 260, filterResonance: 0.10,
            reverbMix: 0.05, reverbRoomSize: 0.25,
            masterVolume: 0.54,
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 4, eqLowFreq: 55, eqMidGain: -3, eqMidFreq: 500, eqHighGain: -6, eqHighFreq: 3500
        ),
    ]

    // MARK: - LEAD (6) — unison OK (one key). Keep the top from going sandy.

    private static let leadPresets: [SynthPreset] = [
        SynthPreset(
            name: "Silk Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.62, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.38, osc2Octave: 0, osc2Detune: 5,
            attack: 0.020, decay: 0.18, sustain: 0.7, release: 0.220,
            filterCutoff: 2800, filterResonance: 0.24,
            lfoEnabled: true, lfoRate: 5.0, lfoDepth: 0.08, lfoTarget: .pitch,
            reverbMix: 0.16, reverbRoomSize: 0.42,
            chorusRate: 1.0, chorusDepth: 0.22, chorusMix: 0.10,
            masterVolume: 0.50,
            unisonVoices: 2, unisonDetune: 7, unisonSpread: 0.30
        ),
        SynthPreset(
            name: "Crystal Lead",
            category: .lead,
            osc1Waveform: .wavetable, osc1Volume: 0.58, osc1Octave: 0, osc1WavetableMorph: 0.14,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.32, osc2Octave: 0, osc2Detune: 3,
            attack: 0.005, decay: 0.25, sustain: 0.55, release: 0.300,
            filterCutoff: 3400, filterResonance: 0.20,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            delayTime: 0.26, delayFeedback: 0.18, delayMix: 0.08,
            masterVolume: 0.46,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 1, eqMidFreq: 2200, eqHighGain: 1, eqHighFreq: 6500
        ),
        SynthPreset(
            name: "Warm Mono",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.68, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.26, osc2Octave: 0, osc2Detune: 4, osc2PulseWidth: 0.42,
            attack: 0.010, decay: 0.2, sustain: 0.75, release: 0.180,
            filterCutoff: 1900, filterResonance: 0.34,
            reverbMix: 0.12,
            masterVolume: 0.50, portamento: 0.08,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.14, distortionTone: 0.40, distortionMix: 0.10
        ),
        SynthPreset(
            name: "Arp Cascade",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.58, osc1Octave: 0, osc1PulseWidth: 0.36,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.30, osc2Octave: 1, osc2Detune: 2,
            attack: 0.005, decay: 0.12, sustain: 0.35, release: 0.100,
            filterCutoff: 3000, filterResonance: 0.28,
            lfoEnabled: true, lfoRate: 0.18, lfoDepth: 0.16, lfoTarget: .filter,
            reverbMix: 0.14, reverbRoomSize: 0.40,
            delayTime: 0.22, delayFeedback: 0.20, delayMix: 0.08,
            masterVolume: 0.48,
            arpMode: .up, bpm: 128
        ),
        SynthPreset(
            name: "Supersaw Soft",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.54, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.42, osc2Octave: 0, osc2Detune: 7,
            attack: 0.030, decay: 0.2, sustain: 0.75, release: 0.280,
            filterCutoff: 2400, filterResonance: 0.18,
            reverbMix: 0.16, reverbRoomSize: 0.45,
            chorusRate: 0.8, chorusDepth: 0.28, chorusMix: 0.12,
            masterVolume: 0.46,
            unisonVoices: 2, unisonDetune: 8, unisonSpread: 0.50,
            eqEnabled: true, eqPreset: .midScoop,
            eqLowGain: 0, eqLowFreq: 120, eqMidGain: -2, eqMidFreq: 800, eqHighGain: 1, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "PWM Whisper",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.64, osc1Octave: 0, osc1PulseWidth: 0.22,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.26, osc2Octave: 0, osc2Detune: 4, osc2PulseWidth: 0.55,
            attack: 0.015, decay: 0.15, sustain: 0.65, release: 0.200,
            filterCutoff: 2300, filterResonance: 0.26,
            lfoEnabled: true, lfoRate: 0.35, lfoDepth: 0.22, lfoWaveform: .triangle, lfoTarget: .filter,
            reverbMix: 0.14,
            masterVolume: 0.50
        ),
    ]

    // MARK: - PAD (6) — chords: no unison. One wet, modest.

    private static let padPresets: [SynthPreset] = [
        SynthPreset(
            name: "Cloud Bed",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.54, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.42, osc2Octave: 0, osc2Detune: 4,
            attack: 0.900, decay: 0.6, sustain: 0.85, release: 1.400,
            filterCutoff: 1700, filterResonance: 0.16,
            reverbMix: 0.22, reverbRoomSize: 0.52,
            chorusRate: 0.45, chorusDepth: 0.30, chorusMix: 0.12,
            masterVolume: 0.44,
            eqEnabled: true, eqPreset: .dark,
            eqLowGain: 1, eqLowFreq: 120, eqMidGain: 0, eqMidFreq: 800, eqHighGain: -3, eqHighFreq: 4500
        ),
        SynthPreset(
            name: "Glass Horizon",
            category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 0, osc1WavetableMorph: 0.16,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.36, osc2Octave: 0, osc2Detune: 4,
            attack: 1.200, decay: 0.8, sustain: 0.8, release: 1.800,
            filterCutoff: 2000, filterResonance: 0.16,
            lfoEnabled: true, lfoRate: 0.10, lfoDepth: 0.14, lfoTarget: .filter,
            reverbMix: 0.18, reverbRoomSize: 0.50,
            masterVolume: 0.42,
            phaserEnabled: true, phaserMode: .phaser2, phaserRate: 0.10, phaserDepth: 0.22,
            phaserFeedback: 0.08, phaserCenterFrequency: 700, phaserMix: 0.12
        ),
        SynthPreset(
            name: "Analog Drift",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.48, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 6,
            attack: 0.700, decay: 0.5, sustain: 0.9, release: 1.100,
            filterCutoff: 1300, filterResonance: 0.24,
            lfoEnabled: true, lfoRate: 0.07, lfoDepth: 0.10, lfoTarget: .pitch,
            reverbMix: 0.20, reverbRoomSize: 0.52,
            chorusRate: 0.32, chorusDepth: 0.32, chorusMix: 0.12,
            masterVolume: 0.44,
            modMatrix: [PresetAuthoring.mod(.lfo1, .pan, 0.22)]
        ),
        SynthPreset(
            name: "Noir Pad",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.54, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.20, osc2Octave: 0, osc2PulseWidth: 0.46,
            attack: 1.000, decay: 0.7, sustain: 0.75, release: 1.500,
            filterCutoff: 860, filterResonance: 0.28,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            masterVolume: 0.44,
            eqEnabled: true, eqPreset: .dark,
            eqLowGain: 2, eqLowFreq: 100, eqMidGain: -1, eqMidFreq: 700, eqHighGain: -5, eqHighFreq: 3800
        ),
        SynthPreset(
            name: "Air Choir",
            category: .pad,
            osc1Waveform: .sine, osc1Volume: 0.50, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.40, osc2Octave: 1, osc2Detune: 3,
            attack: 0.800, decay: 0.4, sustain: 0.85, release: 1.600,
            filterCutoff: 2400, filterResonance: 0.12,
            reverbMix: 0.20, reverbRoomSize: 0.52,
            chorusRate: 0.5, chorusDepth: 0.26, chorusMix: 0.10,
            masterVolume: 0.44,
            eqEnabled: true, eqPreset: .vocal,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 2, eqMidFreq: 1600, eqHighGain: 1, eqHighFreq: 6000
        ),
        SynthPreset(
            name: "Slow Motion",
            category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: -1, osc1WavetableMorph: 0.28,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.32, osc2Octave: 0, osc2Detune: 4,
            attack: 1.500, decay: 1.0, sustain: 0.9, release: 2.200,
            filterCutoff: 1100, filterResonance: 0.18,
            lfoEnabled: true, lfoRate: 0.05, lfoDepth: 0.16, lfoTarget: .filter,
            reverbMix: 0.20, reverbRoomSize: 0.52,
            delayTime: 0.42, delayFeedback: 0.16, delayMix: 0.06,
            masterVolume: 0.42
        ),
    ]

    // MARK: - KEYS (5) — chords: no unison

    private static let keysPresets: [SynthPreset] = [
        SynthPreset(
            name: "Soft EP",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.68, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.30, osc2Octave: 1, osc2Detune: 2,
            attack: 0.005, decay: 0.55, sustain: 0.35, release: 0.450,
            filterCutoff: 2400, filterResonance: 0.18,
            reverbMix: 0.16, reverbRoomSize: 0.40,
            chorusRate: 0.9, chorusDepth: 0.20, chorusMix: 0.10,
            masterVolume: 0.52,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.40)],
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: -1, eqLowFreq: 120, eqMidGain: 2, eqMidFreq: 2000, eqHighGain: 0, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Organ Soft",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.54, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.38, osc2Octave: 1, osc2Detune: 1,
            attack: 0.020, decay: 0.1, sustain: 0.9, release: 0.150,
            filterCutoff: 3200, filterResonance: 0.10,
            reverbMix: 0.14, reverbRoomSize: 0.36,
            chorusRate: 0.65, chorusDepth: 0.24, chorusMix: 0.12,
            masterVolume: 0.50,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: 0, eqLowFreq: 100, eqMidGain: 1, eqMidFreq: 1200, eqHighGain: 2, eqHighFreq: 4500
        ),
        SynthPreset(
            name: "Clav Tick",
            category: .keys,
            osc1Waveform: .square, osc1Volume: 0.62, osc1Octave: 0, osc1PulseWidth: 0.22,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.22, osc2Octave: 0, osc2Detune: 3,
            attack: 0.005, decay: 0.18, sustain: 0.2, release: 0.120,
            filterCutoff: 1900, filterResonance: 0.38,
            reverbMix: 0.08,
            masterVolume: 0.50,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.30)],
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.14, distortionTone: 0.50, distortionMix: 0.08
        ),
        SynthPreset(
            name: "Bell Keys",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.58, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 2, osc2Detune: 6,
            attack: 0.005, decay: 0.7, sustain: 0.15, release: 0.800,
            filterCutoff: 3800, filterResonance: 0.12,
            reverbMix: 0.20, reverbRoomSize: 0.48,
            delayTime: 0.30, delayFeedback: 0.16, delayMix: 0.06,
            masterVolume: 0.46,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -3, eqLowFreq: 200, eqMidGain: 1, eqMidFreq: 2500, eqHighGain: 1, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Rhodes Warm",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.64, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.26, osc2Octave: 1, osc2Detune: 2,
            attack: 0.008, decay: 0.65, sustain: 0.4, release: 0.500,
            filterCutoff: 2200, filterResonance: 0.20,
            reverbMix: 0.16, reverbRoomSize: 0.42,
            chorusRate: 0.7, chorusDepth: 0.26, chorusMix: 0.10,
            masterVolume: 0.50,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.12, distortionTone: 0.40, distortionMix: 0.08,
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: 1, eqLowFreq: 110, eqMidGain: 2, eqMidFreq: 1800, eqHighGain: -1, eqHighFreq: 6000
        ),
    ]

    // MARK: - PLUCK (5)

    private static let pluckPresets: [SynthPreset] = [
        SynthPreset(
            name: "Nylon Pluck",
            category: .pluck,
            osc1Waveform: .triangle, osc1Volume: 0.68, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.22, osc2Octave: 1, osc2Detune: 2,
            attack: 0.005, decay: 0.35, sustain: 0.1, release: 0.250,
            filterCutoff: 2800, filterResonance: 0.22,
            reverbMix: 0.16, reverbRoomSize: 0.38,
            masterVolume: 0.52,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.40)]
        ),
        SynthPreset(
            name: "Steel Spark",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.56, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.22, osc2Octave: 1, osc2PulseWidth: 0.32,
            attack: 0.005, decay: 0.28, sustain: 0.08, release: 0.200,
            filterCutoff: 3000, filterResonance: 0.28,
            reverbMix: 0.14,
            delayTime: 0.20, delayFeedback: 0.16, delayMix: 0.06,
            masterVolume: 0.48,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 1, eqMidFreq: 2500, eqHighGain: 1, eqHighFreq: 7500
        ),
        SynthPreset(
            name: "Kalimba Soft",
            category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.64, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.26, osc2Octave: 2, osc2Detune: 5,
            attack: 0.005, decay: 0.5, sustain: 0.05, release: 0.400,
            filterCutoff: 4200, filterResonance: 0.12,
            reverbMix: 0.20, reverbRoomSize: 0.48,
            masterVolume: 0.50
        ),
        SynthPreset(
            name: "WT Pluck",
            category: .pluck,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableMorph: 0.30,
            osc2Enabled: false,
            attack: 0.005, decay: 0.32, sustain: 0.12, release: 0.220,
            filterCutoff: 2900, filterResonance: 0.24,
            reverbMix: 0.16,
            masterVolume: 0.50,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.30)]
        ),
        SynthPreset(
            name: "Muted Guitar",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.52, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.38, osc2Octave: 0, osc2Detune: 3,
            attack: 0.005, decay: 0.2, sustain: 0.15, release: 0.150,
            filterCutoff: 1500, filterResonance: 0.34,
            reverbMix: 0.10,
            masterVolume: 0.52,
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.12, distortionTone: 0.32, distortionMix: 0.08,
            eqEnabled: true, eqPreset: .midScoop,
            eqLowGain: 1, eqLowFreq: 120, eqMidGain: -2, eqMidFreq: 900, eqHighGain: 0, eqHighFreq: 5500
        ),
    ]

    // MARK: - STRINGS (5) — chords: ensemble = two oscs + detune, not unison

    private static let stringsPresets: [SynthPreset] = [
        SynthPreset(
            name: "Section Soft",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.48, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.42, osc2Octave: 0, osc2Detune: 6,
            attack: 0.350, decay: 0.4, sustain: 0.85, release: 0.700,
            filterCutoff: 1800, filterResonance: 0.16,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            chorusRate: 0.40, chorusDepth: 0.28, chorusMix: 0.12,
            masterVolume: 0.46
        ),
        SynthPreset(
            name: "Cello Warm",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.58, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.32, osc2Octave: -1, osc2Detune: 3,
            attack: 0.200, decay: 0.3, sustain: 0.8, release: 0.500,
            filterCutoff: 1300, filterResonance: 0.24,
            reverbMix: 0.18, reverbRoomSize: 0.46,
            masterVolume: 0.50,
            eqEnabled: true, eqPreset: .dark,
            eqLowGain: 2, eqLowFreq: 100, eqMidGain: 1, eqMidFreq: 600, eqHighGain: -3, eqHighFreq: 4500
        ),
        SynthPreset(
            name: "High Ensemble",
            category: .strings,
            osc1Waveform: .triangle, osc1Volume: 0.48, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.32, osc2Octave: 1, osc2Detune: 5,
            attack: 0.400, decay: 0.35, sustain: 0.85, release: 0.800,
            filterCutoff: 2400, filterResonance: 0.14,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            chorusRate: 0.48, chorusDepth: 0.26, chorusMix: 0.10,
            masterVolume: 0.44
        ),
        SynthPreset(
            name: "Tremolo Strings",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.52, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.36, osc2Octave: 0, osc2Detune: 5,
            attack: 0.150, decay: 0.25, sustain: 0.8, release: 0.450,
            filterCutoff: 2000, filterResonance: 0.18,
            lfoEnabled: true, lfoRate: 5.8, lfoDepth: 0.20, lfoWaveform: .triangle, lfoTarget: .amplitude,
            reverbMix: 0.18, reverbRoomSize: 0.46,
            masterVolume: 0.48,
            modMatrix: [PresetAuthoring.mod(.lfo1, .amp, 0.22)]
        ),
        SynthPreset(
            name: "WT Orchestra",
            category: .strings,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 0, osc1WavetableMorph: 0.32,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.36, osc2Octave: 0, osc2Detune: 5,
            attack: 0.450, decay: 0.4, sustain: 0.85, release: 0.900,
            filterCutoff: 1700, filterResonance: 0.16,
            reverbMix: 0.20, reverbRoomSize: 0.50,
            chorusRate: 0.35, chorusDepth: 0.26, chorusMix: 0.10,
            masterVolume: 0.44
        ),
    ]

    // MARK: - FX (5) — character, still under the clipper

    private static let fxPresets: [SynthPreset] = [
        SynthPreset(
            name: "Shimmer Rise",
            category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.48, osc1Octave: 1, osc1WavetableMorph: 0.22,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.28, osc2Octave: 2, osc2Detune: 6,
            attack: 0.600, decay: 0.8, sustain: 0.7, release: 1.200,
            filterType: .highPass, filterCutoff: 900, filterResonance: 0.28,
            lfoEnabled: true, lfoRate: 0.14, lfoDepth: 0.22, lfoTarget: .filter,
            reverbMix: 0.20, reverbRoomSize: 0.52,
            delayTime: 0.34, delayFeedback: 0.16, delayMix: 0.06,
            masterVolume: 0.40
        ),
        SynthPreset(
            name: "Noise Sweep",
            category: .fx,
            osc1Waveform: .noise, osc1Volume: 0.52, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.18, osc2Octave: 0,
            attack: 0.050, decay: 0.4, sustain: 0.5, release: 0.600,
            filterType: .bandPass, filterCutoff: 1400, filterResonance: 0.40,
            lfoEnabled: true, lfoRate: 0.22, lfoDepth: 0.40, lfoTarget: .filter,
            reverbMix: 0.20, reverbRoomSize: 0.52,
            masterVolume: 0.44,
            eqEnabled: true, eqPreset: .telephone,
            eqLowGain: -8, eqLowFreq: 300, eqMidGain: 4, eqMidFreq: 1200, eqHighGain: -6, eqHighFreq: 3500
        ),
        SynthPreset(
            name: "Glitch Arp",
            category: .fx,
            osc1Waveform: .square, osc1Volume: 0.52, osc1Octave: 1, osc1PulseWidth: 0.18,
            osc2Enabled: true, osc2Waveform: .noise, osc2Volume: 0.10, osc2Octave: 0,
            attack: 0.005, decay: 0.08, sustain: 0.2, release: 0.080,
            filterCutoff: 3200, filterResonance: 0.36,
            reverbMix: 0.10,
            delayTime: 0.12, delayFeedback: 0.18, delayMix: 0.08,
            masterVolume: 0.48,
            arpMode: .random, bpm: 140,
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.14, distortionTone: 0.55, distortionMix: 0.10
        ),
        SynthPreset(
            name: "Deep Drone",
            category: .fx,
            osc1Waveform: .sawtooth, osc1Volume: 0.44, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.42, osc2Octave: -1, osc2Detune: 3,
            attack: 1.200, decay: 1.0, sustain: 0.95, release: 2.000,
            filterCutoff: 560, filterResonance: 0.30,
            lfoEnabled: true, lfoRate: 0.04, lfoDepth: 0.18, lfoTarget: .filter,
            reverbMix: 0.18, reverbRoomSize: 0.50,
            masterVolume: 0.42
        ),
        SynthPreset(
            name: "Space Pluck FX",
            category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.52, osc1Octave: 0, osc1WavetableMorph: 0.30,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.24, osc2Octave: 1, osc2Detune: 8,
            attack: 0.005, decay: 0.4, sustain: 0.1, release: 0.700,
            filterCutoff: 2800, filterResonance: 0.24,
            reverbMix: 0.18, reverbRoomSize: 0.50,
            delayTime: 0.36, delayFeedback: 0.16, delayMix: 0.06,
            masterVolume: 0.46,
            arpMode: .upDown, bpm: 100,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -2, eqLowFreq: 200, eqMidGain: 1, eqMidFreq: 2000, eqHighGain: 1, eqHighFreq: 6500
        ),
    ]
}
