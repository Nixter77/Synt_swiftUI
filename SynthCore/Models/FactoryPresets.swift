//
//  FactoryPresets.swift
//  Synt_swiftUI
//
//  Factory library authored for the current engine (SYNT_30).
//
//  Live paths to showcase, not to avoid:
//  - Dual filter (serial / parallel), formant + vowel / vowel mod
//  - Amp env, dedicated filter ADSR / Env 2, MSEG 1 and MSEG 2
//  - Wavetable morph and index, dual wavetable, FM, hard sync, sub, ring, noise color
//  - Macros 1–8 into the matrix, raw LFO rows, arp and sequencer Pro
//  - FX order, rotary, frequency shifter, transient, trance gate, stereo bus, character
//  - MPE pressure / timbre on the dedicated MPE bank
//
//  Soft caps (FactoryPresetCoverageTests):
//  - masterVolume ≤ 0.75; poly pads and strings quieter than mono bass/lead
//  - reverbMix ≤ 0.35, delayMix ≤ 0.22, chorusMix ≤ 0.22
//    unless the patch is an explicit FX / ambient showcase
//  - unison ≤ 4; prefer 1–2 on dense pads
//  - every non-Init factory and expansion patch renders finite and non-silent for ≥ 1 s
//  - matrix rows use destinations the render path actually applies
//  - Init (`defaultPreset`) is not in this list and must stay bit-identical
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    /// Legacy categories, then showcase, then the 2026-10-18 library (stage 8 last).
    static let factoryPresets: [SynthPreset] =
        bassPresets + leadPresets + padPresets + keysPresets + pluckPresets + stringsPresets + fxPresets
        + showcasePresets
        + libraryPresets

    // MARK: - Bass

    private static let bassPresets: [SynthPreset] = [
        A.make("Clean Sub", .bass) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.62
        p.osc1Octave = -2
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Octave = -1
        p.osc2Detune = 5
        p.subOscVolume = 0.28
        p.subOscOctave = -1
        p.attack = 0.006
        p.decay = 0.18
        p.sustain = 0.84
        p.release = 0.16
        p.filterCutoff = 420
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.003
        p.filterDecay = 0.14
        p.filterSustain = 0.15
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.32
        p.masterVolume = 0.62
        p.voiceMode = .mono
        p.portamento = 0.025
        p.character = .warm
        p.analogDrift = 0.08
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.14
        p.distortionTone = 0.42
        p.distortionMix = 0.14
        p.eqEnabled = true
        p.eqLowGain = 4
        p.eqMidGain = -1
        p.eqHighGain = -3
        p.stereoEnabled = true
        p.stereoMonoBassHz = 110
        p.modMatrix = [A.mod(.env1, .cutoff, 0.18), A.mod(.velocity, .amp, 0.20)]
    },
        A.make("Velvet Acid", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.58
        p.osc1Octave = -1
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.26
        p.osc2Octave = -1
        p.osc2Detune = 6
        p.osc2PulseWidth = 0.34
        p.subOscVolume = 0.14
        p.attack = 0.005
        p.decay = 0.20
        p.sustain = 0.42
        p.release = 0.13
        p.filterType = .ladder
        p.filterCutoff = 620
        p.filterResonance = 0.38
        p.filterDrive = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.36
        p.filterAttack = 0.003
        p.filterDecay = 0.16
        p.filterSustain = 0.14
        p.filterRelease = 0.11
        p.velocityToEnvAmount = 0.34
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.masterVolume = 0.61
        p.portamento = 0.045
        p.glideLegatoOnly = true
        p.voiceMode = .legato
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.20
        p.distortionTone = 0.46
        p.distortionMix = 0.16
        p.fxOrder = A.orderDirtLast
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.character = .warm
        p.modMatrix = [A.mod(.env2, .pwm2, 0.28), A.mod(.velocity, .resonance, 0.20)]
    },
        A.make("Round Reese", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Octave = -1
        p.osc1Detune = -7
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.34
        p.osc2Octave = -1
        p.osc2Detune = 8
        p.subOscVolume = 0.18
        p.attack = 0.014
        p.decay = 0.28
        p.sustain = 0.76
        p.release = 0.22
        p.filterCutoff = 680
        p.filterResonance = 0.26
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.008
        p.filterDecay = 0.22
        p.filterSustain = 0.30
        p.filterRelease = 0.18
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.36
        p.chorusMix = 0.12
        p.masterVolume = 0.59
        p.voiceMode = .legato
        p.portamento = 0.055
        p.unisonVoices = 2
        p.unisonDetune = 8
        p.unisonSpread = 0.36
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.18
        p.distortionTone = 0.44
        p.distortionMix = 0.15
        p.filter2Routing = .serial
        p.filter2Type = .bandPass
        p.filter2Cutoff = 1380
        p.filter2Resonance = 0.26
        p.filter2Balance = 0.56
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoMonoBassHz = 115
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 0.28
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.24), A.mod(.modWheel, .lfoRate, 0.30)]
    },
        A.make("Wavetable Growl", .bass) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.58
        p.osc1Octave = -1
        p.osc1WavetableMorph = 0.36
        p.osc1WavetableIndex = 1
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.24
        p.osc2Octave = -1
        p.osc2Detune = 6
        p.subOscVolume = 0.16
        p.attack = 0.008
        p.decay = 0.26
        p.sustain = 0.68
        p.release = 0.18
        p.filterCutoff = 580
        p.filterResonance = 0.32
        p.filterDrive = 0.15
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.28
        p.filterAttack = 0.004
        p.filterDecay = 0.18
        p.filterSustain = 0.22
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.28
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.masterVolume = 0.60
        p.voiceMode = .mono
        p.portamento = 0.03
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.20
        p.distortionTone = 0.48
        p.distortionMix = 0.16
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.macro1 = 0.35
        p.lfoEnabled = true
        p.lfoRate = 0.32
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.macro1, .cutoff, 0.38), A.mod(.lfo1, .wtMorph1, 0.22), A.mod(.env2, .fm, 0.16)]
    },
        A.make("Muted Funk", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.58
        p.osc1Octave = -1
        p.osc1PulseWidth = 0.32
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.22
        p.osc2Octave = -1
        p.osc2Detune = 5
        p.subOscVolume = 0.15
        p.attack = 0.003
        p.decay = 0.15
        p.sustain = 0.36
        p.release = 0.10
        p.filterCutoff = 840
        p.filterResonance = 0.28
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.36
        p.filterAttack = 0.002
        p.filterDecay = 0.11
        p.filterSustain = 0.14
        p.filterRelease = 0.09
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.38
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.30
        p.masterVolume = 0.60
        p.voiceMode = .mono
        p.portamento = 0.02
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.16
        p.distortionTone = 0.52
        p.distortionMix = 0.14
        p.transientEnabled = true
        p.transientAttack = 0.35
        p.transientSustain = -0.18
        p.transientMix = 0.65
        p.stereoEnabled = true
        p.stereoMonoBassHz = 115
        p.modMatrix = [A.mod(.env2, .pwm1, 0.26), A.mod(.velocity, .cutoff, 0.24)]
    },
        A.make("Soft 808", .bass) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.64
        p.osc1Octave = -2
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.20
        p.osc2Octave = -1
        p.osc2Detune = 4
        p.subOscVolume = 0.24
        p.subOscOctave = -1
        p.attack = 0.003
        p.decay = 0.38
        p.sustain = 0.26
        p.release = 0.24
        p.filterCutoff = 440
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.002
        p.filterDecay = 0.09
        p.filterSustain = 0.0
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.06
        p.reverbRoomSize = 0.28
        p.masterVolume = 0.64
        p.voiceMode = .mono
        p.portamento = 0.04
        p.glideLegatoOnly = true
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.18
        p.distortionTone = 0.38
        p.distortionMix = 0.15
        p.transientEnabled = true
        p.transientAttack = 0.45
        p.transientSustain = -0.15
        p.transientMix = 0.7
        p.stereoEnabled = true
        p.stereoMonoBassHz = 130
        p.character = .warm
        p.modMatrix = [A.mod(.env2, .pitch1, 0.16), A.mod(.velocity, .cutoff, 0.20)]
    },
    ]

    // MARK: - Lead

    private static let leadPresets: [SynthPreset] = [
        A.make("Silk Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Detune = -4
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.28
        p.osc2Detune = 6
        p.subOscVolume = 0.10
        p.attack = 0.014
        p.decay = 0.24
        p.sustain = 0.72
        p.release = 0.24
        p.filterCutoff = 2100
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.006
        p.filterDecay = 0.20
        p.filterSustain = 0.35
        p.filterRelease = 0.20
        p.velocityToCutoff = 0.24
        p.lfoEnabled = true
        p.lfoRate = 5.1
        p.lfoDepth = 0.06
        p.lfoTarget = .pitch
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.42
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayPingPong = true
        p.delayFeedback = 0.20
        p.masterVolume = 0.54
        p.unisonVoices = 2
        p.unisonDetune = 6
        p.unisonSpread = 0.34
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.14
        p.distortionTone = 0.46
        p.distortionMix = 0.12
        p.analogDrift = 0.10
        p.character = .warm
        p.modMatrix = [A.mod(.env1, .cutoff, 0.20), A.mod(.modWheel, .lfoDepth, 0.35)]
    },
        A.make("Crystal Lead", .lead) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.54
        p.osc1WavetableMorph = 0.24
        p.osc1WavetableIndex = 1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.24
        p.osc2Octave = 1
        p.osc2Detune = 5
        p.fmAmount = 0.08
        p.attack = 0.006
        p.decay = 0.24
        p.sustain = 0.56
        p.release = 0.28
        p.filterCutoff = 2300
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.004
        p.filterDecay = 0.18
        p.filterSustain = 0.28
        p.filterRelease = 0.22
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.42
        p.delayMix = 0.12
        p.delayTime = 0.26
        p.delayFeedback = 0.18
        p.analogDrift = 0.08
        p.masterVolume = 0.48
        p.eqEnabled = true
        p.eqLowGain = -2
        p.eqMidGain = 1
        p.eqHighGain = 1.5
        p.lfoEnabled = true
        p.lfoRate = 0.28
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .wtMorph1, 0.20), A.mod(.velocity, .cutoff, 0.22)]
    },
        A.make("Warm Mono", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.26
        p.osc2Detune = 5
        p.osc2PulseWidth = 0.38
        p.subOscVolume = 0.12
        p.attack = 0.008
        p.decay = 0.22
        p.sustain = 0.72
        p.release = 0.18
        p.filterType = .ladder
        p.filterCutoff = 1540
        p.filterResonance = 0.28
        p.filterDrive = 0.16
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.004
        p.filterDecay = 0.18
        p.filterSustain = 0.32
        p.filterRelease = 0.16
        p.velocityToCutoff = 0.25
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.38
        p.delayMix = 0.11
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayPingPong = true
        p.delayFeedback = 0.18
        p.masterVolume = 0.60
        p.portamento = 0.065
        p.voiceMode = .mono
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.16
        p.distortionTone = 0.44
        p.distortionMix = 0.14
        p.analogDrift = 0.12
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 0.32
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .pwm2, 0.24), A.mod(.velocity, .cutoff, 0.22)]
    },
        A.make("Arp Cascade", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.54
        p.osc1PulseWidth = 0.34
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.24
        p.osc2Octave = 1
        p.osc2Detune = 6
        p.subOscVolume = 0.10
        p.attack = 0.005
        p.decay = 0.16
        p.sustain = 0.38
        p.release = 0.14
        p.filterCutoff = 1880
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.30
        p.filterAttack = 0.003
        p.filterDecay = 0.14
        p.filterSustain = 0.20
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.28
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.delayMix = 0.14
        p.delayTempoSync = true
        p.delaySyncDivision = .eighthD
        p.delayPingPong = true
        p.delayFeedback = 0.20
        p.masterVolume = 0.54
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.arpGateLength = 0.56
        p.arpOctaves = 2
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.14
        p.distortionMix = 0.12
        p.lfoEnabled = true
        p.lfoRate = 0.24
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .pwm1, 0.22), A.mod(.velocity, .cutoff, 0.24)]
    },
        A.make("Supersaw Soft", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Detune = -6
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.34
        p.osc2Detune = 8
        p.subOscVolume = 0.10
        p.attack = 0.016
        p.decay = 0.24
        p.sustain = 0.72
        p.release = 0.26
        p.filterCutoff = 1920
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.006
        p.filterDecay = 0.20
        p.filterSustain = 0.35
        p.filterRelease = 0.20
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.46
        p.chorusMix = 0.14
        p.masterVolume = 0.53
        p.unisonVoices = 2
        p.unisonDetune = 8
        p.unisonSpread = 0.40
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.14
        p.distortionTone = 0.52
        p.distortionMix = 0.12
        p.stereoEnabled = true
        p.stereoWidth = 1.26
        p.lfoEnabled = true
        p.lfoRate = 0.22
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.20), A.mod(.velocity, .cutoff, 0.22)]
    },
        A.make("PWM Whisper", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.54
        p.osc1PulseWidth = 0.38
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.26
        p.osc2Detune = 5
        p.subOscVolume = 0.10
        p.attack = 0.018
        p.decay = 0.28
        p.sustain = 0.68
        p.release = 0.28
        p.filterCutoff = 1580
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.008
        p.filterDecay = 0.22
        p.filterSustain = 0.34
        p.filterRelease = 0.22
        p.velocityToCutoff = 0.24
        p.lfoEnabled = true
        p.lfoRate = 0.32
        p.lfoTarget = .none
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.45
        p.chorusMix = 0.14
        p.masterVolume = 0.53
        p.unisonVoices = 2
        p.unisonDetune = 5
        p.unisonSpread = 0.30
        p.fxOrder = A.orderVerbEarly
        p.analogDrift = 0.10
        p.character = .warm
        p.modMatrix = [A.mod(.lfo1, .pwm1, 0.30), A.mod(.env2, .pitch2, 0.03)]
    },
    ]

    // MARK: - Pad

    private static let padPresets: [SynthPreset] = [
        A.make("Cloud Bed", .pad) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.32
        p.osc2Detune = 4
        p.attack = 0.35
        p.decay = 0.4
        p.sustain = 0.85
        p.release = 0.9
        p.filterCutoff = 1500
        p.filterResonance = 0.1
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.12
        p.masterVolume = 0.36
        p.macro2 = 0.3
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoWidth = 1.25
        p.modMatrix = [A.mod(.macro2, .amp, 0.2)]
    },
        A.make("Glass Horizon", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.46
        p.osc1WavetableMorph = 0.18
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.28
        p.osc2Detune = 4
        p.attack = 0.4
        p.decay = 0.5
        p.sustain = 0.8
        p.release = 1.1
        p.filterCutoff = 1800
        p.filterResonance = 0.12
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoDepth = 0.1
        p.lfoTarget = .filter
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.48
        p.masterVolume = 0.36
        p.phaserEnabled = false
        p.phaserMode = .phaser2
        p.phaserMix = 0.12
        p.phaserRate = 0.1
    },
        A.make("Analog Drift", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.32
        p.osc2Detune = 6
        p.attack = 0.32
        p.decay = 0.4
        p.sustain = 0.88
        p.release = 0.9
        p.filterCutoff = 1200
        p.filterResonance = 0.16
        p.lfoEnabled = true
        p.lfoRate = 0.08
        p.lfoDepth = 0.1
        p.lfoTarget = .pitch
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.5
        p.chorusMix = 0.1
        p.masterVolume = 0.36
        p.analogDrift = 0.35
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.character = .warm
        p.lfoRowsFollowDepth = true
        p.modMatrix = [A.mod(.lfo1, .pan, 0.22)]
    },
        A.make("Noir Pad", .pad) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.48
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.46
        p.attack = 0.4
        p.decay = 0.45
        p.sustain = 0.75
        p.release = 1.0
        p.filterCutoff = 880
        p.filterResonance = 0.18
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.48
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoWidth = 1.3
        p.character = .warm
        p.noiseColor = .pink
    },
        A.make("Air Choir", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.7
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.4
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.attack = 0.18
        p.decay = 0.35
        p.sustain = 0.82
        p.release = 0.9
        p.filterType = .formant
        p.filterCutoff = 2200
        p.filterResonance = 0.08
        p.filterVowel = 0.2
        p.lfoEnabled = true
        p.lfoRate = 0.18
        p.lfoTarget = .none
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.5
        p.chorusMix = 0.1
        p.masterVolume = 0.34
        p.modMatrix = [A.mod(.lfo1, .vowel, 0.22)]
    },
        A.make("Slow Motion", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.44
        p.osc1Octave = -1
        p.osc1WavetableMorph = 0.3
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Detune = 5
        p.attack = 0.42
        p.decay = 0.5
        p.sustain = 0.86
        p.release = 1.2
        p.filterCutoff = 1180
        p.filterResonance = 0.12
        p.lfoEnabled = true
        p.lfoRate = 0.06
        p.lfoTarget = .filter
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.5
        p.delayMix = 0.06
        p.delayTime = 0.4
        p.delayFeedback = 0.16
        p.masterVolume = 0.34
    },
    ]

    // MARK: - Keys

    private static let keysPresets: [SynthPreset] = [
        A.make("Soft EP", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.6
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.26
        p.osc2Octave = 1
        p.osc2Detune = 2
        p.attack = 0.005
        p.decay = 0.5
        p.sustain = 0.35
        p.release = 0.42
        p.filterCutoff = 2200
        p.filterResonance = 0.12
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.4
        p.masterVolume = 0.46
    },
        A.make("Organ Soft", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.4
        p.osc1PulseWidth = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.28
        p.osc2Octave = 1
        p.attack = 0.02
        p.decay = 0.1
        p.sustain = 0.9
        p.release = 0.18
        p.filterCutoff = 2400
        p.filterResonance = 0.08
        p.reverbMix = 0.1
        p.reverbRoomSize = 0.38
        p.masterVolume = 0.48
        p.rotaryEnabled = true
        p.rotaryMix = 0.72
        p.rotaryDrive = 0.12
        p.modMatrix = [A.mod(.lfo2, .amp, 0.08)]
        p.lfo2Enabled = true
        p.lfo2Rate = 0.7
        p.lfo2Target = .none
    },
        A.make("Clav Tick", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.55
        p.osc1PulseWidth = 0.28
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.16
        p.attack = 0.002
        p.decay = 0.12
        p.sustain = 0.15
        p.release = 0.08
        p.filterCutoff = 2800
        p.filterResonance = 0.22
        p.reverbMix = 0.06
        p.masterVolume = 0.48
    },
        A.make("Bell Keys", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.3
        p.osc2Octave = 1
        p.osc2Detune = 2
        p.fmAmount = 0.14
        p.attack = 0.004
        p.decay = 0.7
        p.sustain = 0.15
        p.release = 0.55
        p.filterCutoff = 4200
        p.filterResonance = 0.08
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.42
        p.masterVolume = 0.46
    },
        A.make("Rhodes Warm", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.58
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.22
        p.osc2Detune = 3
        p.attack = 0.006
        p.decay = 0.45
        p.sustain = 0.4
        p.release = 0.4
        p.filterCutoff = 1800
        p.filterResonance = 0.14
        p.reverbMix = 0.12
        p.chorusMix = 0.08
        p.masterVolume = 0.46
        p.character = .warm
    },
    ]

    // MARK: - Pluck

    private static let pluckPresets: [SynthPreset] = [
        A.make("Nylon Pluck", .pluck) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.attack = 0.004
        p.decay = 0.28
        p.sustain = 0.15
        p.release = 0.22
        p.filterCutoff = 1600
        p.filterResonance = 0.12
        p.reverbMix = 0.1
        p.masterVolume = 0.48
    },
        A.make("Steel Spark", .pluck) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1PulseWidth = 0.3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.2
        p.osc2Octave = 1
        p.attack = 0.002
        p.decay = 0.22
        p.sustain = 0.1
        p.release = 0.18
        p.filterCutoff = 3200
        p.filterResonance = 0.14
        p.delayMix = 0.05
        p.delayTime = 0.18
        p.delayFeedback = 0.14
        p.reverbMix = 0.08
        p.masterVolume = 0.48
    },
        A.make("Kalimba Soft", .pluck) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.58
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.osc2Octave = 1
        p.osc2Detune = 4
        p.attack = 0.003
        p.decay = 0.35
        p.sustain = 0.08
        p.release = 0.3
        p.filterCutoff = 2600
        p.filterResonance = 0.1
        p.reverbMix = 0.12
        p.masterVolume = 0.46
    },
        A.make("WT Pluck", .pluck) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.55
        p.osc1WavetableMorph = 0.28
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.18
        p.attack = 0.004
        p.decay = 0.26
        p.sustain = 0.12
        p.release = 0.24
        p.filterCutoff = 2400
        p.filterResonance = 0.16
        p.reverbMix = 0.1
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.env1, .wtMorph1, 0.2)]
    },
        A.make("Muted Guitar", .pluck) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.5
        p.osc1PulseWidth = 0.38
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.16
        p.osc2Detune = -5
        p.attack = 0.003
        p.decay = 0.18
        p.sustain = 0.2
        p.release = 0.12
        p.filterCutoff = 1400
        p.filterResonance = 0.18
        p.reverbMix = 0.08
        p.masterVolume = 0.48
        p.noiseColor = .pink
    },
    ]

    // MARK: - Strings

    private static let stringsPresets: [SynthPreset] = [
        A.make("Section Soft", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.4
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.32
        p.osc2Detune = 5
        p.attack = 0.28
        p.decay = 0.35
        p.sustain = 0.85
        p.release = 0.7
        p.filterCutoff = 1400
        p.filterResonance = 0.1
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.12
        p.masterVolume = 0.34
        p.macro1 = 0.28
        p.modMatrix = [A.mod(.macro1, .cutoff, 0.25)]
    },
        A.make("Cello Warm", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.22
        p.osc2Octave = -1
        p.osc2Detune = 4
        p.attack = 0.12
        p.decay = 0.3
        p.sustain = 0.8
        p.release = 0.45
        p.filterCutoff = 900
        p.filterResonance = 0.14
        p.reverbMix = 0.12
        p.masterVolume = 0.36
        p.character = .warm
    },
        A.make("High Ensemble", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Octave = 1
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.28
        p.osc2Octave = 1
        p.osc2Detune = 6
        p.attack = 0.22
        p.decay = 0.3
        p.sustain = 0.82
        p.release = 0.6
        p.filterCutoff = 2200
        p.filterResonance = 0.08
        p.reverbMix = 0.14
        p.chorusMix = 0.1
        p.masterVolume = 0.32
    },
        A.make("Tremolo Strings", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 7
        p.attack = 0.18
        p.decay = 0.25
        p.sustain = 0.8
        p.release = 0.5
        p.filterCutoff = 1600
        p.filterResonance = 0.1
        p.lfoEnabled = true
        p.lfoRate = 4.5
        p.lfoDepth = 0.5
        p.lfoTarget = .none
        p.reverbMix = 0.12
        p.chorusMix = 0.08
        p.masterVolume = 0.34
        p.lfoRowsFollowDepth = true
        p.modMatrix = [A.mod(.lfo1, .amp, 0.18)]
    },
        A.make("WT Orchestra", .strings) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.4
        p.osc1WavetableMorph = 0.4
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.22
        p.osc2Detune = 4
        p.attack = 0.26
        p.decay = 0.35
        p.sustain = 0.84
        p.release = 0.7
        p.filterCutoff = 1700
        p.filterResonance = 0.1
        p.reverbMix = 0.14
        p.chorusMix = 0.1
        p.masterVolume = 0.32
    },
    ]

    // MARK: - FX

    private static let fxPresets: [SynthPreset] = [
        A.make("Shimmer Rise", .fx) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.46
        p.osc1Octave = 1
        p.osc1WavetableMorph = 0.25
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.2
        p.attack = 0.2
        p.decay = 0.4
        p.sustain = 0.7
        p.release = 0.8
        p.filterCutoff = 2000
        p.filterResonance = 0.12
        p.reverbMix = 0.2
        p.reverbRoomSize = 0.5
        p.chorusMix = 0.12
        p.masterVolume = 0.4
        p.fxOrder = A.orderDelayFirst
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.15)]
        p.lfoEnabled = true
        p.lfoRate = 0.15
        p.lfoTarget = .none
    },
        A.make("Noise Sweep", .fx) { p in
        p.osc1Waveform = .noise
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.16
        p.attack = 0.08
        p.decay = 0.4
        p.sustain = 0.55
        p.release = 0.5
        p.filterType = .bandPass
        p.filterCutoff = 1400
        p.filterResonance = 0.32
        p.lfoEnabled = true
        p.lfoRate = 0.22
        p.lfoTarget = .filter
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.48
        p.masterVolume = 0.38
        p.noiseColor = .pink
        p.fxOrder = A.orderDirtLast
    },
        A.make("Glitch Arp", .fx) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1Octave = 1
        p.osc1PulseWidth = 0.2
        p.osc2Enabled = true
        p.osc2Waveform = .noise
        p.osc2Volume = 0.08
        p.attack = 0.004
        p.decay = 0.1
        p.sustain = 0.25
        p.release = 0.08
        p.filterCutoff = 2800
        p.filterResonance = 0.24
        p.reverbMix = 0.08
        p.delayMix = 0.06
        p.delayTime = 0.14
        p.delayFeedback = 0.16
        p.masterVolume = 0.46
        p.arpMode = .random
        p.distortionEnabled = true
        p.distortionDrive = 0.14
        p.distortionMix = 0.1
    },
        A.make("Deep Drone", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.4
        p.osc1Octave = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.34
        p.osc2Octave = -1
        p.osc2Detune = 3
        p.attack = 0.4
        p.decay = 0.5
        p.sustain = 0.9
        p.release = 1.2
        p.filterCutoff = 520
        p.filterResonance = 0.2
        p.lfoEnabled = true
        p.lfoRate = 0.05
        p.lfoTarget = .filter
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.5
        p.masterVolume = 0.36
        p.mseg2 = A.shape(rate: 0.15, -0.4, 0.7, -0.1)
        p.modMatrix = [A.mod(.mseg2, .pitch2, 0.04)]
    },
        A.make("Space Pluck FX", .fx) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.48
        p.osc1WavetableMorph = 0.34
        p.osc1WavetableIndex = 3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.2
        p.osc2Octave = 1
        p.osc2Detune = 8
        p.attack = 0.005
        p.decay = 0.35
        p.sustain = 0.15
        p.release = 0.55
        p.filterCutoff = 2600
        p.filterResonance = 0.18
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.48
        p.delayMix = 0.06
        p.delayTime = 0.32
        p.delayFeedback = 0.16
        p.masterVolume = 0.44
        p.arpMode = .upDown
        p.fxOrder = A.orderVerbEarly
        p.eqEnabled = true
        p.eqLowGain = -2
        p.eqMidGain = 1
        p.eqHighGain = 1
    },
    ]
}
