//
//  FactoryPresets+Library.swift
//  Synt_swiftUI
//
//  Library appended after the showcase. Stage 8 demos stay the suffix.
//  SYNT_30 bodies: filter 2, formant, MSEG, Env 2, rotary, and macros
//  live here as well as in the legacy bank. Same caps as FactoryPresets.swift.
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    static let libraryPresets: [SynthPreset] =
        libBass + libLead + libPad + libKeys + libPluck + libStrings + libBrass + libArp + libFX
        + stage8Presets

    private static let libBass: [SynthPreset] = [
        A.make("Acid Squelch", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.55
        p.osc1Octave = -1
        p.attack = 0.004
        p.decay = 0.2
        p.sustain = 0.35
        p.release = 0.1
        p.filterCutoff = 480
        p.filterResonance = 0.45
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.3
        p.filterAttack = 0.003
        p.filterDecay = 0.16
        p.filterSustain = 0.1
        p.filterRelease = 0.1
        p.reverbMix = 0.03
        p.masterVolume = 0.48
        p.modMatrix = [A.mod(.env2, .pitch1, 0.04)]
    },
        A.make("Hollow Pulse Bass", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.osc1PulseWidth = 0.3
        p.attack = 0.008
        p.decay = 0.24
        p.sustain = 0.6
        p.release = 0.16
        p.filterCutoff = 620
        p.filterResonance = 0.2
        p.reverbMix = 0.04
        p.masterVolume = 0.46
        p.filter2Routing = .serial
        p.filter2Type = .bandPass
        p.filter2Cutoff = 1100
        p.filter2Resonance = 0.3
        p.filter2Balance = 0.55
    },
        A.make("Fat Unison Bass", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc1Octave = -1
        p.osc1Detune = -5
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.36
        p.osc2Detune = 6
        p.attack = 0.015
        p.decay = 0.25
        p.sustain = 0.7
        p.release = 0.22
        p.filterCutoff = 800
        p.filterResonance = 0.18
        p.reverbMix = 0.05
        p.masterVolume = 0.44
        p.unisonVoices = 2
        p.unisonDetune = 8
        p.unisonSpread = 0.3
    },
        A.make("Finger Pluck Bass", .bass) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.55
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.3
        p.osc2Octave = -2
        p.attack = 0.003
        p.decay = 0.18
        p.sustain = 0.25
        p.release = 0.12
        p.filterCutoff = 900
        p.filterResonance = 0.12
        p.reverbMix = 0.04
        p.masterVolume = 0.48
    },
        A.make("Wavefold Bass", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.2
        p.oscSyncEnabled = true
        p.attack = 0.006
        p.decay = 0.2
        p.sustain = 0.55
        p.release = 0.14
        p.filterCutoff = 740
        p.filterResonance = 0.24
        p.reverbMix = 0.04
        p.masterVolume = 0.46
        p.distortionEnabled = true
        p.distortionType = .wavefolder
        p.distortionDrive = 0.16
        p.distortionMix = 0.08
    },
        A.make("Dub Wobble", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.osc2Octave = -1
        p.attack = 0.01
        p.decay = 0.3
        p.sustain = 0.65
        p.release = 0.2
        p.filterCutoff = 540
        p.filterResonance = 0.3
        p.lfoEnabled = true
        p.lfoRate = 0.4
        p.lfoTarget = .none
        p.reverbMix = 0.08
        p.delayMix = 0.06
        p.delayTime = 0.36
        p.delayFeedback = 0.18
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.28)]
    },
    ]

    private static let libLead: [SynthPreset] = [
        A.make("Chip Square Lead", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1PulseWidth = 0.25
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.18
        p.osc2Octave = 1
        p.osc2PulseWidth = 0.4
        p.attack = 0.004
        p.decay = 0.14
        p.sustain = 0.6
        p.release = 0.12
        p.filterCutoff = 2400
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterDecay = 0.1
        p.filterSustain = 0.3
        p.reverbMix = 0.06
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.env2, .pwm1, 0.18)]
    },
        A.make("Glide Saw Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.2
        p.osc2Detune = 4
        p.attack = 0.01
        p.decay = 0.2
        p.sustain = 0.7
        p.release = 0.18
        p.filterCutoff = 1900
        p.filterResonance = 0.18
        p.reverbMix = 0.08
        p.masterVolume = 0.46
        p.portamento = 0.08
    },
        A.make("Breathy Flute", .lead) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.22
        p.osc2Detune = 2
        p.fmAmount = 0.1
        p.attack = 0.08
        p.decay = 0.2
        p.sustain = 0.75
        p.release = 0.25
        p.filterCutoff = 2800
        p.filterResonance = 0.08
        p.reverbMix = 0.1
        p.masterVolume = 0.46
        p.noiseColor = .pink
        p.modMatrix = [A.mod(.lfo1, .pitch1, 0.01)]
        p.lfoEnabled = true
        p.lfoRate = 4.8
        p.lfoTarget = .none
    },
        A.make("Overdrive Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.18
        p.osc2PulseWidth = 0.35
        p.attack = 0.008
        p.decay = 0.18
        p.sustain = 0.65
        p.release = 0.16
        p.filterCutoff = 1600
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.2
        p.filterAttack = 0.005
        p.filterDecay = 0.14
        p.filterSustain = 0.35
        p.reverbMix = 0.06
        p.masterVolume = 0.46
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.16
        p.distortionMix = 0.1
        p.modMatrix = [A.mod(.env2, .pwm2, 0.16)]
    },
        A.make("Whistle Lead", .lead) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.48
        p.osc1WavetableMorph = 0.42
        p.osc1WavetableIndex = 4
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Octave = 1
        p.attack = 0.02
        p.decay = 0.15
        p.sustain = 0.7
        p.release = 0.2
        p.filterCutoff = 3600
        p.filterResonance = 0.06
        p.reverbMix = 0.08
        p.masterVolume = 0.46
    },
        A.make("Nasal Band Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.92
        p.attack = 0.01
        p.decay = 0.18
        p.sustain = 0.7
        p.release = 0.18
        p.filterType = .formant
        p.filterCutoff = 2400
        p.filterResonance = 0.08
        p.filterVowel = 1.0
        p.filterEnvUseDedicatedADSR = true
        p.filterDecay = 0.2
        p.filterSustain = 0.55
        p.reverbMix = 0.08
        p.masterVolume = 0.62
        p.modMatrix = [A.mod(.env2, .pitch1, 0.04)]
    },
    ]

    private static let libPad: [SynthPreset] = [
        A.make("Soft Saw Pad", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.4
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 6
        p.attack = 0.3
        p.decay = 0.35
        p.sustain = 0.84
        p.release = 0.8
        p.filterCutoff = 1100
        p.filterResonance = 0.1
        p.reverbMix = 0.14
        p.chorusMix = 0.1
        p.masterVolume = 0.34
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 2800
        p.filter2Resonance = 0.1
        p.filter2Balance = 0.4
    },
        A.make("Sine Glass Pad", .pad) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.46
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.28
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.attack = 0.28
        p.decay = 0.3
        p.sustain = 0.86
        p.release = 0.9
        p.filterCutoff = 2000
        p.filterResonance = 0.06
        p.reverbMix = 0.16
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.25
    },
        A.make("Dark Choir", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.32
        p.osc2Detune = 5
        p.attack = 0.16
        p.decay = 0.35
        p.sustain = 0.82
        p.release = 0.9
        p.filterType = .formant
        p.filterCutoff = 1800
        p.filterResonance = 0.08
        p.filterVowel = 0.4
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoTarget = .none
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.48
        p.masterVolume = 0.36
        p.character = .warm
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 1600
        p.filter2Resonance = 0.1
        p.filter2Balance = 0.62
        p.modMatrix = [A.mod(.lfo1, .vowel, 0.16)]
    },
        A.make("Pulse Sweep Pad", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.4
        p.osc1WavetableMorph = 0.42
        p.osc1WavetableIndex = 3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.4
        p.attack = 0.26
        p.decay = 0.35
        p.sustain = 0.8
        p.release = 0.75
        p.filterCutoff = 1400
        p.filterResonance = 0.14
        p.lfoEnabled = true
        p.lfoRate = 0.1
        p.lfoTarget = .none
        p.reverbMix = 0.14
        p.masterVolume = 0.34
        p.modMatrix = [A.mod(.lfo1, .wtMorph1, 0.2)]
    },
        A.make("Night Swell", .pad) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.44
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.24
        p.osc2Detune = 4
        p.attack = 0.35
        p.decay = 0.4
        p.sustain = 0.82
        p.release = 1.0
        p.filterCutoff = 1000
        p.filterResonance = 0.1
        p.reverbMix = 0.16
        p.masterVolume = 0.32
        p.mseg = A.shape(rate: 0.12, 0.1, 0.9, 0.2)
        p.modMatrix = [A.mod(.mseg, .cutoff, 0.25)]
    },
    ]

    private static let libKeys: [SynthPreset] = [
        A.make("Toy Piano", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.16
        p.osc2Octave = 2
        p.attack = 0.002
        p.decay = 0.3
        p.sustain = 0.05
        p.release = 0.2
        p.filterCutoff = 3400
        p.filterResonance = 0.06
        p.reverbMix = 0.1
        p.masterVolume = 0.46
    },
        A.make("Digital EP", .keys) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.52
        p.osc1WavetableMorph = 0.24
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.attack = 0.005
        p.decay = 0.4
        p.sustain = 0.35
        p.release = 0.35
        p.filterCutoff = 2100
        p.filterResonance = 0.12
        p.reverbMix = 0.1
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.env1, .wtMorph1, 0.15)]
    },
        A.make("Rotary Organ", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.38
        p.osc1PulseWidth = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Octave = 1
        p.attack = 0.015
        p.decay = 0.08
        p.sustain = 0.9
        p.release = 0.16
        p.filterCutoff = 2200
        p.filterResonance = 0.06
        p.reverbMix = 0.08
        p.masterVolume = 0.48
        p.rotaryEnabled = true
        p.rotaryMix = 0.72
        p.rotaryDrive = 0.12
        p.rotaryFast = true
    },
        A.make("Bright Harpsi", .keys) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.2
        p.osc2PulseWidth = 0.3
        p.attack = 0.002
        p.decay = 0.2
        p.sustain = 0.1
        p.release = 0.12
        p.filterCutoff = 3600
        p.filterResonance = 0.1
        p.reverbMix = 0.08
        p.masterVolume = 0.46
    },
        A.make("Mellow Vibes", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2Detune = 6
        p.attack = 0.01
        p.decay = 0.55
        p.sustain = 0.2
        p.release = 0.45
        p.filterCutoff = 2600
        p.filterResonance = 0.08
        p.reverbMix = 0.12
        p.masterVolume = 0.46
        p.macro3 = 0.35
        p.modMatrix = [A.mod(.macro3, .pan, 0.25)]
    },
    ]

    private static let libPluck: [SynthPreset] = [
        A.make("Koto Pluck", .pluck) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.18
        p.attack = 0.002
        p.decay = 0.2
        p.sustain = 0.08
        p.release = 0.16
        p.filterCutoff = 2200
        p.filterResonance = 0.16
        p.reverbMix = 0.08
        p.masterVolume = 0.46
    },
        A.make("Marimba", .pluck) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.osc2Octave = 1
        p.attack = 0.003
        p.decay = 0.28
        p.sustain = 0.05
        p.release = 0.22
        p.filterCutoff = 3000
        p.filterResonance = 0.08
        p.reverbMix = 0.1
        p.masterVolume = 0.46
    },
        A.make("Harp Glimmer", .pluck) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.attack = 0.004
        p.decay = 0.45
        p.sustain = 0.1
        p.release = 0.4
        p.filterCutoff = 2800
        p.filterResonance = 0.06
        p.reverbMix = 0.14
        p.delayMix = 0.05
        p.delayFeedback = 0.14
        p.masterVolume = 0.44
    },
        A.make("Muted Synth Pluck", .pluck) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1PulseWidth = 0.35
        p.attack = 0.003
        p.decay = 0.14
        p.sustain = 0.12
        p.release = 0.1
        p.filterCutoff = 1500
        p.filterResonance = 0.2
        p.reverbMix = 0.06
        p.masterVolume = 0.46
    },
        A.make("Echo Pluck", .pluck) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.attack = 0.004
        p.decay = 0.22
        p.sustain = 0.1
        p.release = 0.3
        p.filterCutoff = 2000
        p.filterResonance = 0.12
        p.delayMix = 0.08
        p.delayTime = 0.28
        p.delayFeedback = 0.18
        p.reverbMix = 0.08
        p.masterVolume = 0.46
    },
    ]

    private static let libStrings: [SynthPreset] = [
        A.make("Slow Violas", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.4
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 5
        p.attack = 0.34
        p.decay = 0.3
        p.sustain = 0.85
        p.release = 0.7
        p.filterCutoff = 1200
        p.filterResonance = 0.1
        p.reverbMix = 0.14
        p.chorusMix = 0.1
        p.masterVolume = 0.32
    },
        A.make("Pizzicato", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.attack = 0.002
        p.decay = 0.16
        p.sustain = 0.05
        p.release = 0.12
        p.filterCutoff = 1800
        p.filterResonance = 0.12
        p.reverbMix = 0.1
        p.masterVolume = 0.4
    },
        A.make("Solo Cello", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.18
        p.osc2Octave = -1
        p.attack = 0.06
        p.decay = 0.25
        p.sustain = 0.75
        p.release = 0.35
        p.filterCutoff = 780
        p.filterResonance = 0.14
        p.reverbMix = 0.12
        p.masterVolume = 0.36
        p.character = .warm
    },
        A.make("String Machine", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Detune = -4
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.32
        p.osc2Detune = 7
        p.attack = 0.18
        p.decay = 0.25
        p.sustain = 0.86
        p.release = 0.55
        p.filterCutoff = 1600
        p.filterResonance = 0.08
        p.reverbMix = 0.12
        p.chorusMix = 0.12
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.25
    },
    ]

    private static let libBrass: [SynthPreset] = [
        A.make("Brass Stab", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Detune = 3
        p.attack = 0.01
        p.decay = 0.16
        p.sustain = 0.35
        p.release = 0.14
        p.filterCutoff = 1400
        p.filterResonance = 0.2
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.28
        p.filterAttack = 0.008
        p.filterDecay = 0.18
        p.filterSustain = 0.2
        p.reverbMix = 0.06
        p.masterVolume = 0.48
        p.modMatrix = [A.mod(.env2, .pwm2, 0.16)]
    },
        A.make("Soft Horns", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 4
        p.attack = 0.08
        p.decay = 0.25
        p.sustain = 0.75
        p.release = 0.3
        p.filterCutoff = 1100
        p.filterResonance = 0.12
        p.reverbMix = 0.1
        p.masterVolume = 0.44
        p.macro2 = 0.3
        p.modMatrix = [A.mod(.macro2, .cutoff, 0.22)]
    },
        A.make("Trumpet Lead", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.4
        p.attack = 0.02
        p.decay = 0.18
        p.sustain = 0.7
        p.release = 0.18
        p.filterCutoff = 1800
        p.filterResonance = 0.16
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.015
        p.filterDecay = 0.12
        p.filterSustain = 0.55
        p.reverbMix = 0.08
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.env2, .pwm2, 0.14)]
    },
        A.make("Synth Brass Pad", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.3
        p.osc2Detune = 6
        p.attack = 0.12
        p.decay = 0.25
        p.sustain = 0.8
        p.release = 0.4
        p.filterCutoff = 1300
        p.filterResonance = 0.14
        p.reverbMix = 0.12
        p.chorusMix = 0.08
        p.masterVolume = 0.4
    },
        A.make("Low Tuba", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.28
        p.osc2Octave = -1
        p.attack = 0.04
        p.decay = 0.2
        p.sustain = 0.8
        p.release = 0.25
        p.filterCutoff = 520
        p.filterResonance = 0.12
        p.reverbMix = 0.08
        p.masterVolume = 0.46
        p.character = .warm
    },
    ]

    private static let libArp: [SynthPreset] = [
        A.make("Up Arp Pluck", .arp) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1PulseWidth = 0.35
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.attack = 0.003
        p.decay = 0.14
        p.sustain = 0.2
        p.release = 0.1
        p.filterCutoff = 2200
        p.filterResonance = 0.14
        p.reverbMix = 0.06
        p.masterVolume = 0.44
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.sequencerData = A.proSequence()
        p.modMatrix = [A.mod(.velocity, .cutoff, 0.12)]
    },
        A.make("Down Arp Bells", .arp) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.attack = 0.004
        p.decay = 0.3
        p.sustain = 0.1
        p.release = 0.25
        p.filterCutoff = 3400
        p.filterResonance = 0.06
        p.reverbMix = 0.12
        p.masterVolume = 0.44
        p.arpMode = .down
        p.arpRate = .eighth
    },
        A.make("Random Sparkle", .arp) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.48
        p.osc1Octave = 1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Octave = 2
        p.attack = 0.003
        p.decay = 0.18
        p.sustain = 0.1
        p.release = 0.16
        p.filterCutoff = 4000
        p.filterResonance = 0.08
        p.reverbMix = 0.1
        p.masterVolume = 0.44
        p.arpMode = .random
        p.arpRate = .sixteenth
    },
        A.make("UpDown Bass Arp", .arp) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.18
        p.osc2Octave = -1
        p.attack = 0.004
        p.decay = 0.16
        p.sustain = 0.4
        p.release = 0.12
        p.filterCutoff = 900
        p.filterResonance = 0.22
        p.reverbMix = 0.04
        p.masterVolume = 0.46
        p.arpMode = .upDown
        p.arpRate = .eighth
    },
    ]

    private static let libFX: [SynthPreset] = [
        A.make("Laser Zap", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.attack = 0.002
        p.decay = 0.12
        p.sustain = 0.1
        p.release = 0.15
        p.filterCutoff = 2400
        p.filterResonance = 0.2
        p.reverbMix = 0.08
        p.masterVolume = 0.42
        p.frequencyShifterEnabled = true
        p.frequencyShifterShiftHz = 18
        p.frequencyShifterMix = 0.28
        p.frequencyShifterFeedback = 0.08
        p.modMatrix = [A.mod(.env1, .pitch1, 0.15)]
    },
        A.make("Wind Gust", .fx) { p in
        p.osc1Waveform = .noise
        p.osc1Volume = 0.4
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.14
        p.attack = 0.2
        p.decay = 0.4
        p.sustain = 0.6
        p.release = 0.7
        p.filterType = .bandPass
        p.filterCutoff = 800
        p.filterResonance = 0.28
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.5
        p.masterVolume = 0.36
        p.noiseColor = .brown
        p.mseg2 = A.shape(rate: 0.18, -0.3, 0.6, 0.05)
        p.modMatrix = [A.mod(.mseg2, .cutoff, 0.3)]
    },
    ]
}
