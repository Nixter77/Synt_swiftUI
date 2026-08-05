//
//  FactoryPresets.swift
//  Synt_swiftUI
//
//  Complete factory preset library (2026 redesign).
//  Design rules for clean sound:
//  - masterVolume typically 0.45…0.65
//  - unison ≤ 5, detune moderate
//  - filter resonance ≤ 0.75 unless character requires a bit more
//  - advanced FX opt-in with mild drive/feedback/mix
//

import Foundation

extension SynthPreset {
    /// Full factory library grouped by category — replaces the old lightweight set.
    static let factoryPresets: [SynthPreset] = bassPresets
        + leadPresets
        + padPresets
        + keysPresets
        + pluckPresets
        + stringsPresets
        + fxPresets

    // MARK: - BASS (6)

    private static let bassPresets: [SynthPreset] = [
        SynthPreset(
            name: "Clean Sub",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.75, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.25, osc2Octave: -1, osc2Detune: 2,
            attack: 0.008, decay: 0.12, sustain: 0.92, release: 0.180,
            filterCutoff: 320, filterResonance: 0.12,
            reverbMix: 0.05, reverbRoomSize: 0.3,
            masterVolume: 0.55,
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 5, eqLowFreq: 70, eqMidGain: -1, eqMidFreq: 800, eqHighGain: -2, eqHighFreq: 6000
        ),
        SynthPreset(
            name: "Velvet Acid",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.72, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.35, osc2Octave: -1, osc2Detune: 8, osc2PulseWidth: 0.35,
            attack: 0.005, decay: 0.22, sustain: 0.4, release: 0.120,
            filterCutoff: 720, filterResonance: 0.48, filterEnvelopeAmount: 0.55,
            lfoEnabled: true, lfoRate: 0.35, lfoDepth: 0.35, lfoTarget: .filter,
            reverbMix: 0.08,
            masterVolume: 0.52, portamento: 0.04,
            modMatrix: [PresetAuthoring.mod(.env1, .cutoff, 0.45)],
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.20, distortionTone: 0.4, distortionMix: 0.12,
            eqEnabled: true, eqPreset: .midScoop,
            eqLowGain: 3, eqLowFreq: 90, eqMidGain: -3, eqMidFreq: 900, eqHighGain: 0, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Round Reese",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: -1, osc1Detune: -6,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Octave: -1, osc2Detune: 7,
            attack: 0.020, decay: 0.25, sustain: 0.8, release: 0.250,
            filterCutoff: 900, filterResonance: 0.35,
            reverbMix: 0.12, reverbRoomSize: 0.4,
            chorusRate: 0.8, chorusDepth: 0.35, chorusMix: 0.18,
            masterVolume: 0.50,
            unisonVoices: 2, unisonDetune: 10, unisonSpread: 0.45,
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 4, eqLowFreq: 85, eqMidGain: -2, eqMidFreq: 1200, eqHighGain: -1, eqHighFreq: 8000
        ),
        SynthPreset(
            name: "Wavetable Growl",
            category: .bass,
            osc1Waveform: .wavetable, osc1Volume: 0.70, osc1Octave: -1, osc1WavetableMorph: 0.55,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.3, osc2Octave: -2, osc2PulseWidth: 0.3,
            attack: 0.010, decay: 0.2, sustain: 0.7, release: 0.200,
            filterCutoff: 1100, filterResonance: 0.45, filterEnvelopeAmount: 0.3,
            lfoEnabled: true, lfoRate: 4.5, lfoDepth: 0.25, lfoTarget: .filter,
            reverbMix: 0.1,
            masterVolume: 0.50,
            modMatrix: [PresetAuthoring.mod(.lfo1, .cutoff, 0.3)],
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.20, distortionTone: 0.45, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Muted Funk",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.75, osc1Octave: -1, osc1PulseWidth: 0.28,
            osc2Enabled: false,
            attack: 0.005, decay: 0.16, sustain: 0.45, release: 0.100,
            filterCutoff: 1400, filterResonance: 0.40,
            reverbMix: 0.04,
            masterVolume: 0.55,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.35)],
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: 2, eqLowFreq: 100, eqMidGain: 3, eqMidFreq: 900, eqHighGain: -2, eqHighFreq: 6000
        ),
        SynthPreset(
            name: "Soft 808",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.75, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.2, osc2Octave: -1, osc2Detune: 3,
            attack: 0.005, decay: 0.45, sustain: 0.15, release: 0.350,
            filterCutoff: 280, filterResonance: 0.10,
            reverbMix: 0.06, reverbRoomSize: 0.25,
            masterVolume: 0.55,
            eqEnabled: true, eqPreset: .bassBoost,
            eqLowGain: 5, eqLowFreq: 55, eqMidGain: -4, eqMidFreq: 500, eqHighGain: -6, eqHighFreq: 4000
        ),
    ]

    // MARK: - LEAD (6)

    private static let leadPresets: [SynthPreset] = [
        SynthPreset(
            name: "Silk Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.4, osc2Octave: 0, osc2Detune: 6,
            attack: 0.020, decay: 0.18, sustain: 0.7, release: 0.220,
            filterCutoff: 3200, filterResonance: 0.28,
            lfoEnabled: true, lfoRate: 5.2, lfoDepth: 0.12, lfoTarget: .pitch,
            reverbMix: 0.22, reverbRoomSize: 0.5,
            chorusRate: 1.2, chorusDepth: 0.3, chorusMix: 0.15,
            masterVolume: 0.52,
            unisonVoices: 2, unisonDetune: 8, unisonSpread: 0.35
        ),
        SynthPreset(
            name: "Crystal Lead",
            category: .lead,
            osc1Waveform: .wavetable, osc1Volume: 0.62, osc1Octave: 1, osc1WavetableMorph: 0.2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.35, osc2Octave: 1, osc2Detune: 4,
            attack: 0.005, decay: 0.25, sustain: 0.55, release: 0.300,
            filterCutoff: 4500, filterResonance: 0.25,
            reverbMix: 0.28, reverbRoomSize: 0.55,
            delayTime: 0.28, delayFeedback: 0.28, delayMix: 0.12,
            masterVolume: 0.50,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 2, eqMidFreq: 2200, eqHighGain: 3, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Warm Mono",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.3, osc2Octave: 0, osc2Detune: 5, osc2PulseWidth: 0.4,
            attack: 0.010, decay: 0.2, sustain: 0.75, release: 0.180,
            filterCutoff: 2200, filterResonance: 0.40, filterEnvelopeAmount: 0.25,
            reverbMix: 0.15,
            masterVolume: 0.52, portamento: 0.08,
            modMatrix: [PresetAuthoring.mod(.velocity, .cutoff, 0.25)],
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.20, distortionTone: 0.4, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Arp Cascade",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.60, osc1Octave: 0, osc1PulseWidth: 0.35,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.35, osc2Octave: 1, osc2Detune: 3,
            attack: 0.005, decay: 0.12, sustain: 0.35, release: 0.100,
            filterCutoff: 3800, filterResonance: 0.35,
            lfoEnabled: true, lfoRate: 0.2, lfoDepth: 0.2, lfoTarget: .filter,
            reverbMix: 0.2, reverbRoomSize: 0.45,
            delayTime: 0.22, delayFeedback: 0.3, delayMix: 0.14,
            masterVolume: 0.50,
            arpMode: .up, bpm: 128,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.35, phaserDepth: 0.4,
            phaserFeedback: 0.18, phaserMix: 0.28
        ),
        SynthPreset(
            name: "Supersaw Soft",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.55, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 9,
            attack: 0.030, decay: 0.2, sustain: 0.75, release: 0.280,
            filterCutoff: 2800, filterResonance: 0.22,
            reverbMix: 0.25, reverbRoomSize: 0.55,
            chorusRate: 0.9, chorusDepth: 0.4, chorusMix: 0.22,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 10, unisonSpread: 0.65,
            eqEnabled: true, eqPreset: .midScoop,
            eqLowGain: 0, eqLowFreq: 120, eqMidGain: -2, eqMidFreq: 800, eqHighGain: 2, eqHighFreq: 9000
        ),
        SynthPreset(
            name: "PWM Whisper",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.68, osc1Octave: 0, osc1PulseWidth: 0.22,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.28, osc2Octave: 0, osc2Detune: 4, osc2PulseWidth: 0.55,
            attack: 0.015, decay: 0.15, sustain: 0.65, release: 0.200,
            filterCutoff: 2600, filterResonance: 0.30,
            lfoEnabled: true, lfoRate: 0.4, lfoDepth: 0.35, lfoWaveform: .triangle, lfoTarget: .filter,
            reverbMix: 0.18,
            masterVolume: 0.52,
            modMatrix: [PresetAuthoring.mod(.lfo1, .pwm1, 0.4)]
        ),
    ]

    // MARK: - PAD (6)

    private static let padPresets: [SynthPreset] = [
        SynthPreset(
            name: "Cloud Bed",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.55, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 4,
            attack: 0.900, decay: 0.6, sustain: 0.85, release: 1.400,
            filterCutoff: 1800, filterResonance: 0.18,
            reverbMix: 0.4, reverbRoomSize: 0.75,
            chorusRate: 0.5, chorusDepth: 0.45, chorusMix: 0.28,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 10, unisonSpread: 0.7,
            eqEnabled: true, eqPreset: .dark,
            eqLowGain: 2, eqLowFreq: 120, eqMidGain: 0, eqMidFreq: 800, eqHighGain: -4, eqHighFreq: 5000
        ),
        SynthPreset(
            name: "Glass Horizon",
            category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 0, osc1WavetableMorph: 0.15,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.4, osc2Octave: 1, osc2Detune: 5, osc2WavetableMorph: 0.7,
            attack: 1.200, decay: 0.8, sustain: 0.8, release: 1.800,
            filterCutoff: 2400, filterResonance: 0.20,
            lfoEnabled: true, lfoRate: 0.12, lfoDepth: 0.2, lfoTarget: .filter,
            reverbMix: 0.45, reverbRoomSize: 0.8,
            delayTime: 0.4, delayFeedback: 0.25, delayMix: 0.1,
            masterVolume: 0.46,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.12, phaserDepth: 0.35,
            phaserFeedback: 0.15, phaserCenterFrequency: 600, phaserMix: 0.25
        ),
        SynthPreset(
            name: "Analog Drift",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.50, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 8,
            attack: 0.700, decay: 0.5, sustain: 0.9, release: 1.100,
            filterCutoff: 1400, filterResonance: 0.30,
            lfoEnabled: true, lfoRate: 0.08, lfoDepth: 0.15, lfoTarget: .pitch,
            reverbMix: 0.35, reverbRoomSize: 0.65,
            chorusRate: 0.35, chorusDepth: 0.5, chorusMix: 0.3,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 11, unisonSpread: 0.6,
            modMatrix: [PresetAuthoring.mod(.lfo1, .pan, 0.25)]
        ),
        SynthPreset(
            name: "Noir Pad",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.55, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.25, osc2Octave: 0, osc2PulseWidth: 0.45,
            attack: 1.000, decay: 0.7, sustain: 0.75, release: 1.500,
            filterCutoff: 900, filterResonance: 0.35,
            reverbMix: 0.42, reverbRoomSize: 0.7,
            masterVolume: 0.47,
            eqEnabled: true, eqPreset: .dark,
            eqLowGain: 3, eqLowFreq: 100, eqMidGain: -1, eqMidFreq: 700, eqHighGain: -6, eqHighFreq: 4000,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.08, phaserDepth: 0.45,
            phaserFeedback: 0.18, phaserMix: 0.32
        ),
        SynthPreset(
            name: "Air Choir",
            category: .pad,
            osc1Waveform: .sine, osc1Volume: 0.50, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.45, osc2Octave: 1, osc2Detune: 3,
            attack: 0.800, decay: 0.4, sustain: 0.85, release: 1.600,
            filterCutoff: 3000, filterResonance: 0.15,
            reverbMix: 0.48, reverbRoomSize: 0.85,
            chorusRate: 0.6, chorusDepth: 0.35, chorusMix: 0.2,
            masterVolume: 0.46,
            unisonVoices: 2, unisonDetune: 7, unisonSpread: 0.8,
            eqEnabled: true, eqPreset: .vocal,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 3, eqMidFreq: 1600, eqHighGain: 2, eqHighFreq: 7000
        ),
        SynthPreset(
            name: "Slow Motion",
            category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.52, osc1Octave: -1, osc1WavetableMorph: 0.4,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.3, osc2Octave: 0, osc2Detune: 5,
            attack: 1.500, decay: 1.0, sustain: 0.9, release: 2.200,
            filterCutoff: 1200, filterResonance: 0.22,
            lfoEnabled: true, lfoRate: 0.05, lfoDepth: 0.25, lfoTarget: .filter,
            reverbMix: 0.5, reverbRoomSize: 0.9,
            delayTime: 0.55, delayFeedback: 0.3, delayMix: 0.12,
            masterVolume: 0.45
        ),
    ]

    // MARK: - KEYS (5)

    private static let keysPresets: [SynthPreset] = [
        SynthPreset(
            name: "Soft EP",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.35, osc2Octave: 1, osc2Detune: 2,
            attack: 0.005, decay: 0.55, sustain: 0.35, release: 0.450,
            filterCutoff: 2800, filterResonance: 0.20,
            reverbMix: 0.22, reverbRoomSize: 0.45,
            chorusRate: 1.0, chorusDepth: 0.25, chorusMix: 0.12,
            masterVolume: 0.55,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.4)],
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: -1, eqLowFreq: 120, eqMidGain: 3, eqMidFreq: 2000, eqHighGain: 1, eqHighFreq: 8000
        ),
        SynthPreset(
            name: "Organ Soft",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.55, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.4, osc2Octave: 1, osc2Detune: 1,
            attack: 0.020, decay: 0.1, sustain: 0.9, release: 0.150,
            filterCutoff: 4000, filterResonance: 0.12,
            reverbMix: 0.18, reverbRoomSize: 0.4,
            chorusRate: 0.7, chorusDepth: 0.3, chorusMix: 0.2,
            masterVolume: 0.52,
            // third harmonic via detuned octave blend already
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: 0, eqLowFreq: 100, eqMidGain: 1, eqMidFreq: 1200, eqHighGain: 3, eqHighFreq: 5000
        ),
        SynthPreset(
            name: "Clav Tick",
            category: .keys,
            osc1Waveform: .square, osc1Volume: 0.65, osc1Octave: 0, osc1PulseWidth: 0.2,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.25, osc2Octave: 0, osc2Detune: 4,
            attack: 0.005, decay: 0.18, sustain: 0.2, release: 0.120,
            filterCutoff: 2200, filterResonance: 0.45, filterEnvelopeAmount: 0.4,
            reverbMix: 0.1,
            masterVolume: 0.53,
            modMatrix: [PresetAuthoring.mod(.velocity, .cutoff, 0.35)],
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.20, distortionTone: 0.55, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Bell Keys",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.60, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.35, osc2Octave: 2, osc2Detune: 8,
            attack: 0.005, decay: 0.7, sustain: 0.15, release: 0.800,
            filterCutoff: 5000, filterResonance: 0.15,
            reverbMix: 0.35, reverbRoomSize: 0.6,
            delayTime: 0.3, delayFeedback: 0.25, delayMix: 0.1,
            masterVolume: 0.50,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -4, eqLowFreq: 200, eqMidGain: 2, eqMidFreq: 2500, eqHighGain: 3, eqHighFreq: 8000
        ),
        SynthPreset(
            name: "Rhodes Warm",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.3, osc2Octave: 1, osc2Detune: 3,
            attack: 0.008, decay: 0.65, sustain: 0.4, release: 0.500,
            filterCutoff: 2400, filterResonance: 0.22,
            reverbMix: 0.25, reverbRoomSize: 0.5,
            chorusRate: 0.8, chorusDepth: 0.35, chorusMix: 0.18,
            masterVolume: 0.54,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.18, distortionTone: 0.42, distortionMix: 0.12,
            eqEnabled: true, eqPreset: .midPresence,
            eqLowGain: 1, eqLowFreq: 110, eqMidGain: 2, eqMidFreq: 1800, eqHighGain: -1, eqHighFreq: 7000
        ),
    ]

    // MARK: - PLUCK (5)

    private static let pluckPresets: [SynthPreset] = [
        SynthPreset(
            name: "Nylon Pluck",
            category: .pluck,
            osc1Waveform: .triangle, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.25, osc2Octave: 1, osc2Detune: 2,
            attack: 0.005, decay: 0.35, sustain: 0.1, release: 0.250,
            filterCutoff: 3500, filterResonance: 0.25, filterEnvelopeAmount: 0.35,
            reverbMix: 0.2, reverbRoomSize: 0.4,
            masterVolume: 0.55,
            modMatrix: [PresetAuthoring.mod(.velocity, .amp, 0.45)]
        ),
        SynthPreset(
            name: "Steel Spark",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.60, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.3, osc2Octave: 1, osc2PulseWidth: 0.3,
            attack: 0.005, decay: 0.28, sustain: 0.08, release: 0.200,
            filterCutoff: 4200, filterResonance: 0.35, filterEnvelopeAmount: 0.5,
            reverbMix: 0.18,
            delayTime: 0.2, delayFeedback: 0.22, delayMix: 0.1,
            masterVolume: 0.52,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -2, eqLowFreq: 150, eqMidGain: 1, eqMidFreq: 2500, eqHighGain: 3, eqHighFreq: 9000
        ),
        SynthPreset(
            name: "Kalimba Soft",
            category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.3, osc2Octave: 2, osc2Detune: 6,
            attack: 0.005, decay: 0.5, sustain: 0.05, release: 0.400,
            filterCutoff: 5000, filterResonance: 0.15,
            reverbMix: 0.3, reverbRoomSize: 0.55,
            masterVolume: 0.52
        ),
        SynthPreset(
            name: "WT Pluck",
            category: .pluck,
            osc1Waveform: .wavetable, osc1Volume: 0.62, osc1Octave: 0, osc1WavetableMorph: 0.35,
            osc2Enabled: false,
            attack: 0.005, decay: 0.32, sustain: 0.12, release: 0.220,
            filterCutoff: 3800, filterResonance: 0.30, filterEnvelopeAmount: 0.4,
            reverbMix: 0.22,
            masterVolume: 0.53,
            modMatrix: [
                PresetAuthoring.mod(.env1, .cutoff, 0.4),
                PresetAuthoring.mod(.velocity, .amp, 0.3)
            ]
        ),
        SynthPreset(
            name: "Muted Guitar",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.55, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.4, osc2Octave: 0, osc2Detune: 3,
            attack: 0.005, decay: 0.2, sustain: 0.15, release: 0.150,
            filterCutoff: 1600, filterResonance: 0.40,
            reverbMix: 0.12,
            masterVolume: 0.54,
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.15, distortionTone: 0.35, distortionMix: 0.10,
            eqEnabled: true, eqPreset: .midScoop,
            eqLowGain: 1, eqLowFreq: 120, eqMidGain: -3, eqMidFreq: 900, eqHighGain: 1, eqHighFreq: 6000
        ),
    ]

    // MARK: - STRINGS (5)

    private static let stringsPresets: [SynthPreset] = [
        SynthPreset(
            name: "Section Soft",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.50, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 7,
            attack: 0.350, decay: 0.4, sustain: 0.85, release: 0.700,
            filterCutoff: 2000, filterResonance: 0.20,
            reverbMix: 0.32, reverbRoomSize: 0.6,
            chorusRate: 0.45, chorusDepth: 0.4, chorusMix: 0.25,
            masterVolume: 0.50,
            unisonVoices: 2, unisonDetune: 10, unisonSpread: 0.7
        ),
        SynthPreset(
            name: "Cello Warm",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.60, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.35, osc2Octave: -1, osc2Detune: 4,
            attack: 0.200, decay: 0.3, sustain: 0.8, release: 0.500,
            filterCutoff: 1400, filterResonance: 0.28,
            reverbMix: 0.28, reverbRoomSize: 0.55,
            masterVolume: 0.52,
            eqEnabled: true, eqPreset: .dark,
            eqLowGain: 3, eqLowFreq: 100, eqMidGain: 1, eqMidFreq: 600, eqHighGain: -3, eqHighFreq: 5000
        ),
        SynthPreset(
            name: "High Ensemble",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.48, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.4, osc2Octave: 1, osc2Detune: 6,
            attack: 0.400, decay: 0.35, sustain: 0.85, release: 0.800,
            filterCutoff: 3200, filterResonance: 0.18,
            reverbMix: 0.38, reverbRoomSize: 0.7,
            chorusRate: 0.55, chorusDepth: 0.35, chorusMix: 0.22,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 9, unisonSpread: 0.75
        ),
        SynthPreset(
            name: "Tremolo Strings",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.55, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.4, osc2Octave: 0, osc2Detune: 5,
            attack: 0.150, decay: 0.25, sustain: 0.8, release: 0.450,
            filterCutoff: 2400, filterResonance: 0.22,
            lfoEnabled: true, lfoRate: 6.5, lfoDepth: 0.35, lfoWaveform: .triangle, lfoTarget: .amplitude,
            reverbMix: 0.3, reverbRoomSize: 0.55,
            masterVolume: 0.50,
            modMatrix: [PresetAuthoring.mod(.lfo1, .amp, 0.3)]
        ),
        SynthPreset(
            name: "WT Orchestra",
            category: .strings,
            osc1Waveform: .wavetable, osc1Volume: 0.52, osc1Octave: 0, osc1WavetableMorph: 0.25,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.4, osc2Octave: 0, osc2Detune: 6, osc2WavetableMorph: 0.6,
            attack: 0.450, decay: 0.4, sustain: 0.85, release: 0.900,
            filterCutoff: 2200, filterResonance: 0.20,
            reverbMix: 0.4, reverbRoomSize: 0.75,
            chorusRate: 0.4, chorusDepth: 0.4, chorusMix: 0.2,
            masterVolume: 0.48,
            unisonVoices: 2, unisonDetune: 10, unisonSpread: 0.65,
            phaserEnabled: true, phaserMode: .phaser2, phaserRate: 0.15, phaserDepth: 0.3,
            phaserFeedback: 0.12, phaserMix: 0.18
        ),
    ]

    // MARK: - FX (5)

    private static let fxPresets: [SynthPreset] = [
        SynthPreset(
            name: "Shimmer Rise",
            category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.50, osc1Octave: 1, osc1WavetableMorph: 0.8,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.35, osc2Octave: 2, osc2Detune: 10,
            attack: 0.600, decay: 0.8, sustain: 0.7, release: 1.200,
            filterType: .highPass, filterCutoff: 800, filterResonance: 0.35,
            lfoEnabled: true, lfoRate: 0.15, lfoDepth: 0.4, lfoTarget: .filter,
            reverbMix: 0.55, reverbRoomSize: 0.9,
            delayTime: 0.35, delayFeedback: 0.35, delayMix: 0.18,
            masterVolume: 0.45,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.2, phaserDepth: 0.5,
            phaserFeedback: 0.18, phaserCenterFrequency: 1200, phaserMix: 0.35
        ),
        SynthPreset(
            name: "Noise Sweep",
            category: .fx,
            osc1Waveform: .noise, osc1Volume: 0.55, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.25, osc2Octave: 0,
            attack: 0.050, decay: 0.4, sustain: 0.5, release: 0.600,
            filterType: .bandPass, filterCutoff: 1500, filterResonance: 0.48,
            lfoEnabled: true, lfoRate: 0.25, lfoDepth: 0.6, lfoTarget: .filter,
            reverbMix: 0.35, reverbRoomSize: 0.7,
            masterVolume: 0.48,
            eqEnabled: true, eqPreset: .telephone,
            eqLowGain: -10, eqLowFreq: 300, eqMidGain: 5, eqMidFreq: 1200, eqHighGain: -8, eqHighFreq: 3500
        ),
        SynthPreset(
            name: "Glitch Arp",
            category: .fx,
            osc1Waveform: .square, osc1Volume: 0.55, osc1Octave: 1, osc1PulseWidth: 0.15,
            osc2Enabled: true, osc2Waveform: .noise, osc2Volume: 0.15, osc2Octave: 0,
            attack: 0.005, decay: 0.08, sustain: 0.2, release: 0.080,
            filterCutoff: 4500, filterResonance: 0.45,
            reverbMix: 0.15,
            delayTime: 0.12, delayFeedback: 0.4, delayMix: 0.2,
            masterVolume: 0.50,
            arpMode: .random, bpm: 140,
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.20, distortionTone: 0.6, distortionMix: 0.12
        ),
        SynthPreset(
            name: "Deep Drone",
            category: .fx,
            osc1Waveform: .sawtooth, osc1Volume: 0.45, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: -1, osc2Detune: 3,
            attack: 1.200, decay: 1.0, sustain: 0.95, release: 2.000,
            filterCutoff: 600, filterResonance: 0.40,
            lfoEnabled: true, lfoRate: 0.04, lfoDepth: 0.3, lfoTarget: .filter,
            reverbMix: 0.45, reverbRoomSize: 0.85,
            masterVolume: 0.46,
            unisonVoices: 2, unisonDetune: 6, unisonSpread: 0.5,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.05, phaserDepth: 0.4,
            phaserFeedback: 0.18, phaserCenterFrequency: 400, phaserMix: 0.3
        ),
        SynthPreset(
            name: "Space Pluck FX",
            category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.55, osc1Octave: 1, osc1WavetableMorph: 0.5,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.3, osc2Octave: 2, osc2Detune: 12,
            attack: 0.005, decay: 0.4, sustain: 0.1, release: 0.900,
            filterCutoff: 3600, filterResonance: 0.30,
            reverbMix: 0.5, reverbRoomSize: 0.85,
            delayTime: 0.45, delayFeedback: 0.4, delayMix: 0.22,
            masterVolume: 0.48,
            arpMode: .upDown, bpm: 100,
            eqEnabled: true, eqPreset: .bright,
            eqLowGain: -3, eqLowFreq: 200, eqMidGain: 2, eqMidFreq: 2000, eqHighGain: 3, eqHighFreq: 8000
        ),
    ]
}
