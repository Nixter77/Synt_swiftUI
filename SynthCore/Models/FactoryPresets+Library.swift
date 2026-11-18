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
        p.osc1Volume = 0.56
        p.osc1Octave = -1
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Octave = -1
        p.osc2PulseWidth = 0.32
        p.osc2Detune = 5
        p.subOscVolume = 0.16
        p.subOscWaveform = .square
        p.envelopeModel = .analog
        p.attack = 0.004
        p.decay = 0.2
        p.sustain = 0.35
        p.release = 0.1
        p.filterType = .ladder
        p.filterCutoff = 480
        p.filterResonance = 0.42
        p.filterDrive = 0.20
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.38
        p.filterAttack = 0.003
        p.filterEnvHold = 0.008
        p.filterDecay = 0.15
        p.filterSustain = 0.1
        p.filterRelease = 0.1
        p.velocityToEnvAmount = 0.35
        p.reverbMix = 0.06
        p.reverbRoomSize = 0.30
        p.busGlueEnabled = true
        p.masterVolume = 0.59
        p.voiceMode = .legato
        p.portamento = 0.035
        p.glideLegatoOnly = true
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.22
        p.distortionTone = 0.48
        p.distortionMix = 0.16
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [
            A.mod(.env2, .pwm2, 0.26, curveShape: -0.35)
        ]
    },
        A.make("Hollow Pulse Bass", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.54
        p.osc1Octave = -1
        p.osc1PulseWidth = 0.28
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Octave = -1
        p.osc2Detune = 6
        p.subOscVolume = 0.16
        p.subOscWaveform = .triangle
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmAmount = 0.14
        p.envelopeModel = .analog
        p.attack = 0.006
        p.decay = 0.22
        p.sustain = 0.58
        p.release = 0.15
        p.filterType = .ladder
        p.filterCutoff = 620
        p.filterResonance = 0.26
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.004
        p.filterDecay = 0.16
        p.filterSustain = 0.20
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.32
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.025
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.15
        p.distortionTone = 0.44
        p.distortionMix = 0.13
        p.stereoEnabled = true
        p.stereoMonoBassHz = 115
        p.lfoEnabled = true
        p.lfoRate = 0.30
        p.lfoTarget = .none
        p.modMatrix = [
            A.mod(.lfo1, .pwm1, 0.30),
            A.mod(.env2, .fm, 0.18),
            A.mod(.velocity, .amp, 0.18)
        ]
    },
        A.make("Fat Unison Bass", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.osc1Detune = -6
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.34
        p.osc2Octave = -1
        p.osc2Detune = 7
        p.subOscVolume = 0.18
        p.subOscWaveform = .triangle
        p.envelopeModel = .analog
        p.attack = 0.010
        p.decay = 0.24
        p.sustain = 0.70
        p.release = 0.20
        p.filterCutoff = 760
        p.filterResonance = 0.24
        p.filterDrive = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.005
        p.filterEnvHold = 0.006
        p.filterDecay = 0.18
        p.filterSustain = 0.25
        p.filterRelease = 0.15
        p.velocityToCutoff = 0.22
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.chorusMix = 0.12
        p.masterVolume = 0.58
        p.voiceMode = .legato
        p.portamento = 0.04
        p.unisonVoices = 2
        p.unisonDetune = 8
        p.unisonSpread = 0.34
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.16
        p.distortionTone = 0.45
        p.distortionMix = 0.14
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoMonoBassHz = 115
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 0.22
        p.lfoStereoPhase = 90
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.32)]
    },
        A.make("Finger Pluck Bass", .bass) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.58
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Octave = -2
        p.osc2PulseWidth = 0.36
        p.osc2Detune = 4
        p.subOscVolume = 0.20
        p.subOscWaveform = .triangle
        p.envelopeModel = .analog
        p.attack = 0.003
        p.decay = 0.18
        p.sustain = 0.26
        p.release = 0.12
        p.filterCutoff = 780
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.32
        p.filterAttack = 0.002
        p.filterEnvHold = 0.012
        p.filterDecay = 0.12
        p.filterSustain = 0.10
        p.filterRelease = 0.10
        p.velocityToCutoff = 0.30
        p.velocityToEnvAmount = 0.32
        p.reverbMix = 0.06
        p.reverbRoomSize = 0.28
        p.busGlueEnabled = true
        p.masterVolume = 0.60
        p.voiceMode = .mono
        p.portamento = 0.02
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.16
        p.distortionTone = 0.44
        p.distortionMix = 0.14
        p.transientEnabled = true
        p.transientAttack = 0.32
        p.transientSustain = -0.14
        p.transientMix = 0.60
        p.character = .warm
        p.modMatrix = [
            A.mod(.env2, .pitch1, 0.20, curveShape: -0.60),
            A.mod(.env2, .pwm2, 0.24),
            A.mod(.velocity, .amp, 0.22)
        ]
    },
        A.make("Wavefold Bass", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.54
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.24
        p.osc2Octave = -1
        p.osc2Detune = 6
        p.osc2PulseWidth = 0.35
        p.subOscVolume = 0.16
        p.subOscWaveform = .square
        p.oscSyncEnabled = true
        p.envelopeModel = .analog
        p.attack = 0.005
        p.decay = 0.20
        p.sustain = 0.55
        p.release = 0.14
        p.filterCutoff = 720
        p.filterResonance = 0.28
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.28
        p.filterAttack = 0.003
        p.filterDecay = 0.16
        p.filterSustain = 0.18
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.25
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.32
        p.busGlueEnabled = true
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.03
        p.distortionEnabled = true
        p.distortionType = .wavefolder
        p.distortionDrive = 0.20
        p.distortionTone = 0.48
        p.distortionMix = 0.15
        p.fxOrder = A.orderDirtLast
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [
            A.mod(.env2, .pitch2, 0.24, curveShape: -0.40)
        ]
    },
        A.make("Dub Wobble", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Octave = -1
        p.osc1Detune = -4
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.26
        p.osc2Octave = -1
        p.osc2Detune = 5
        p.osc2PulseWidth = 0.38
        p.subOscVolume = 0.22
        p.subOscWaveform = .sine
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmAmount = 0.14
        p.envelopeModel = .analog
        p.attack = 0.008
        p.decay = 0.28
        p.sustain = 0.68
        p.release = 0.18
        p.filterType = .ladder
        p.filterCutoff = 540
        p.filterResonance = 0.34
        p.filterDrive = 0.16
        p.lfoEnabled = true
        p.lfoRate = 0.38
        p.lfoTempoSync = true
        p.lfoSyncDivision = .eighth
        p.lfoTarget = .none
        p.reverbMix = 0.09
        p.reverbRoomSize = 0.36
        p.delayMix = 0.10
        p.delayTime = 0.36
        p.delayFeedback = 0.18
        p.delayPingPong = true
        p.masterVolume = 0.59
        p.voiceMode = .legato
        p.portamento = 0.05
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.18
        p.distortionTone = 0.44
        p.distortionMix = 0.14
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.character = .warm
        p.modMatrix = [
            A.mod(.lfo1, .cutoff, 0.38),
            A.mod(.modWheel, .lfoRate, 0.35),
            A.mod(.lfo1, .pwm2, 0.24, via: .modWheel)
        ]
    },
    ]

    private static let libLead: [SynthPreset] = [
        A.make("Chip Square Lead", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.54
        p.osc1PulseWidth = 0.25
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2PulseWidth = 0.40
        p.osc2Detune = 5
        p.subOscVolume = 0.08
        p.attack = 0.004
        p.decay = 0.14
        p.sustain = 0.60
        p.release = 0.12
        p.filterCutoff = 2200
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.003
        p.filterDecay = 0.10
        p.filterSustain = 0.28
        p.filterRelease = 0.10
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayPingPong = true
        p.delayFeedback = 0.18
        p.masterVolume = 0.54
        p.voiceMode = .mono
        p.portamento = 0.02
        p.distortionEnabled = true
        p.distortionType = .bitcrusher
        p.distortionDrive = 0.14
        p.distortionMix = 0.12
        p.modMatrix = [A.mod(.env2, .pwm1, 0.26)]
    },
        A.make("Glide Saw Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Detune = -5
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 7
        p.subOscVolume = 0.12
        p.noiseColor = .pink
        p.attack = 0.008
        p.decay = 0.22
        p.sustain = 0.72
        p.release = 0.18
        p.filterCutoff = 1750
        p.filterResonance = 0.26
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.005
        p.filterDecay = 0.18
        p.filterSustain = 0.32
        p.filterRelease = 0.16
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.40
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighthD
        p.delayPingPong = true
        p.delayFeedback = 0.20
        p.masterVolume = 0.56
        p.voiceMode = .legato
        p.portamento = 0.075
        p.glideLegatoOnly = true
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.15
        p.distortionTone = 0.46
        p.distortionMix = 0.13
        p.analogDrift = 0.10
        p.lfoEnabled = true
        p.lfoRate = 0.26
        p.lfoTarget = .none
        p.lfo2Enabled = true
        p.lfo2Rate = 5.1
        p.lfo2Depth = 0.10
        p.lfo2Target = .pitch
        p.modMatrix = [
            A.mod(.lfo1, .cutoff, 0.30),
            A.mod(.env2, .noiseLevel, 0.16, curveShape: -0.45)
        ]
    },
        A.make("Breathy Flute", .lead) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.56
        p.osc2Enabled = true
        p.osc2Waveform = .noise
        p.osc2Volume = 0.12
        p.noiseColor = .pink
        p.fmAmount = 0.08
        p.attack = 0.055
        p.decay = 0.22
        p.sustain = 0.76
        p.release = 0.24
        p.filterCutoff = 2100
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.18
        p.filterAttack = 0.015
        p.filterDecay = 0.08
        p.filterSustain = 0.15
        p.filterRelease = 0.20
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.46
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.18
        p.delayPingPong = true
        p.masterVolume = 0.56
        p.voiceMode = .legato
        p.portamento = 0.035
        p.glideLegatoOnly = true
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 4.8
        p.lfoDepth = 0.10
        p.lfoTarget = .pitch
        p.modMatrix = [
            A.mod(.env2, .noiseLevel, 0.18, curveShape: -0.45),
            A.mod(.lfo1, .finePitch, 0.16, via: .aftertouch),
            A.mod(.env1, .cutoff, 0.18),
            A.mod(.velocity, .amp, 0.22)
        ]
    },
        A.make("Overdrive Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Detune = -4
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.24
        p.osc2PulseWidth = 0.34
        p.osc2Detune = 6
        p.subOscVolume = 0.10
        p.oscSyncEnabled = true
        p.attack = 0.006
        p.decay = 0.18
        p.sustain = 0.66
        p.release = 0.16
        p.filterType = .ladder
        p.filterCutoff = 1620
        p.filterResonance = 0.28
        p.filterDrive = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.004
        p.filterDecay = 0.14
        p.filterSustain = 0.32
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.28
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayPingPong = true
        p.delayFeedback = 0.18
        p.masterVolume = 0.56
        p.voiceMode = .mono
        p.portamento = 0.04
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.24
        p.distortionTone = 0.48
        p.distortionMix = 0.18
        p.fxOrder = A.orderDirtLast
        p.modMatrix = [
            A.mod(.env2, .pwm2, 0.24),
            A.mod(.env2, .pitch2, 0.22, curveShape: -0.35)
        ]
    },
        A.make("Whistle Lead", .lead) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.56
        p.osc1WavetableMorph = 0.34
        p.osc1WavetableIndex = 4
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2Detune = 4
        p.noiseColor = .pink
        p.attack = 0.016
        p.decay = 0.18
        p.sustain = 0.74
        p.release = 0.22
        p.filterCutoff = 2600
        p.filterResonance = 0.20
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.18
        p.filterAttack = 0.010
        p.filterDecay = 0.10
        p.filterSustain = 0.20
        p.filterRelease = 0.18
        p.velocityToCutoff = 0.22
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.44
        p.delayMix = 0.12
        p.delayTime = 0.28
        p.delayFeedback = 0.18
        p.delayPingPong = true
        p.masterVolume = 0.55
        p.voiceMode = .legato
        p.portamento = 0.06
        p.lfoEnabled = true
        p.lfoRate = 5.0
        p.lfoDepth = 0.10
        p.lfoTarget = .pitch
        p.lfo2Enabled = true
        p.lfo2Rate = 0.24
        p.lfo2Target = .none
        p.modMatrix = [
            A.mod(.lfo2, .wtMorph1, 0.34),
            A.mod(.env2, .noiseLevel, 0.16, curveShape: -0.45)
        ]
    },
        A.make("Nasal Band Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.64
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.28
        p.osc2PulseWidth = 0.34
        p.osc2Detune = 5
        p.subOscVolume = 0.12
        p.attack = 0.008
        p.decay = 0.18
        p.sustain = 0.72
        p.release = 0.18
        p.filterType = .bandPass
        p.filterCutoff = 1350
        p.filterResonance = 0.44
        p.filterDrive = 0.20
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.005
        p.filterDecay = 0.18
        p.filterSustain = 0.45
        p.filterRelease = 0.16
        p.filter2Routing = .parallel
        p.filter2Type = .formant
        p.filterVowel = 1.8
        p.filter2Balance = 0.30
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayPingPong = true
        p.delayFeedback = 0.18
        p.masterVolume = 0.56
        p.voiceMode = .mono
        p.portamento = 0.035
        p.distortionEnabled = true
        p.distortionType = .softClip
        p.distortionDrive = 0.18
        p.distortionMix = 0.14
        p.lfoEnabled = true
        p.lfoRate = 0.30
        p.lfoTarget = .none
        p.modMatrix = [
            A.mod(.lfo1, .cutoff, 0.34),
            A.mod(.lfo1, .vowel, 0.22),
            A.mod(.env2, .pwm2, 0.22)
        ]
    },
    ]

    private static let libPad: [SynthPreset] = [
        A.make("Soft Saw Pad", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.26
        p.osc2Detune = 6
        p.attack = 0.52
        p.ampDelay = 0.015
        p.decay = 0.45
        p.sustain = 0.84
        p.release = 1.25
        p.filterCutoff = 1150
        p.filterResonance = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.030
        p.filterAttack = 0.40
        p.filterDecay = 0.50
        p.filterSustain = 0.50
        p.filterRelease = 1.00
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.16
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 100
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 4.0
        p.analogDrift = 0.14
        p.lfoEnabled = true
        p.lfoRate = 0.14
        p.lfoStereoPhase = 120
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.32), A.mod(.lfo1, .pan, 0.22)]
    },
        A.make("Sine Glass Pad", .pad) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.44
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 3
        p.fmFine = 0.01
        p.fmAmount = 0.14
        p.attack = 0.54
        p.decay = 0.48
        p.sustain = 0.86
        p.release = 1.30
        p.filterCutoff = 2250
        p.filterResonance = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterAttack = 0.42
        p.filterDecay = 0.55
        p.filterSustain = 0.55
        p.filterRelease = 1.10
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.50
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 120
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoHaasMs = 3.8
        p.character = .bright
        p.lfoEnabled = true
        p.lfoRate = 0.16
        p.lfoStereoPhase = 140
        p.lfoTarget = .none
        p.mseg = A.loopingMSEG(rate: 0.16, [
            (0.0, 0.0, 0.0), (0.36, 0.75, -0.25), (0.70, -0.15, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [
            A.mod(.mseg, .cutoff, 0.34),
            A.mod(.lfo1, .pan, 0.22),
            A.mod(.env2, .fm, 0.16)
        ]
    },
        A.make("Dark Choir", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.30
        p.osc2Detune = 5
        p.attack = 0.50
        p.decay = 0.45
        p.sustain = 0.82
        p.release = 1.25
        p.filterType = .formant
        p.filterCutoff = 1350
        p.filterResonance = 0.10
        p.filterVowel = 0.40
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoStereoPhase = 135
        p.lfoTarget = .none
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 95
        p.masterVolume = 0.35
        p.character = .warm
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 1600
        p.filter2Resonance = 0.12
        p.filter2Balance = 0.62
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 4.0
        p.analogDrift = 0.14
        p.mseg = A.loopingMSEG(rate: 0.12, [
            (0.0, 0.0, 0.0), (0.38, 0.72, -0.25), (0.74, -0.25, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [A.mod(.mseg, .vowel, 0.36), A.mod(.lfo1, .pan, 0.22)]
    },
        A.make("Pulse Sweep Pad", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.38
        p.osc1WavetableMorph = 0.36
        p.osc1WavetableIndex = 3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.40
        p.osc2Detune = 5
        p.attack = 0.52
        p.decay = 0.45
        p.sustain = 0.80
        p.release = 1.20
        p.filterCutoff = 1450
        p.filterResonance = 0.16
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.18
        p.filterAttack = 0.40
        p.filterDecay = 0.50
        p.filterSustain = 0.48
        p.filterRelease = 1.00
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoStereoPhase = 150
        p.lfoTarget = .none
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 110
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 3.5
        p.modMatrix = [
            A.mod(.lfo1, .wtMorph1, 0.36),
            A.mod(.lfo1, .pwm2, 0.26),
            A.mod(.lfo1, .cutoff, 0.24)
        ]
    },
        A.make("Night Swell", .pad) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.42
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.24
        p.osc2Detune = 4
        p.subOscVolume = 0.08
        p.attack = 0.58
        p.ampDelay = 0.025
        p.decay = 0.50
        p.sustain = 0.82
        p.release = 1.35
        p.filterType = .ladder
        p.filterCutoff = 1050
        p.filterResonance = 0.14
        p.filterDrive = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.045
        p.filterAttack = 0.45
        p.filterDecay = 0.55
        p.filterSustain = 0.48
        p.filterRelease = 1.10
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.50
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 100
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.26
        p.stereoHaasMs = 4.2
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoStereoPhase = 120
        p.lfoTarget = .none
        p.character = .warm
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.34), A.mod(.lfo1, .pan, 0.22)]
    },
    ]

    private static let libKeys: [SynthPreset] = [
        A.make("Toy Piano", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.16
        p.osc2Octave = 2
        p.osc2Detune = 4
        p.fmRatioEnabled = true
        p.fmCoarse = 7
        p.fmFine = 0.02
        p.fmAmount = 0.18
        p.attack = 0.002
        p.decay = 0.32
        p.sustain = 0.06
        p.release = 0.22
        p.filterCutoff = 3400
        p.filterResonance = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.001
        p.filterDecay = 0.16
        p.filterSustain = 0.06
        p.filterRelease = 0.16
        p.velocityToCutoff = 0.26
        p.velocityToEnvAmount = 0.24
        p.transientEnabled = true
        p.transientAttack = 0.22
        p.transientSustain = -0.08
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.36
        p.chorusMix = 0.15
        p.masterVolume = 0.45
        p.character = .bright
        p.modMatrix = [
            A.mod(.velocity, .fm, 0.28, curveShape: -0.20),
            A.mod(.env2, .fm, 0.18),
            A.mod(.velocity, .amp, 0.26)
        ]
    },
        A.make("Digital EP", .keys) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.48
        p.osc1WavetableMorph = 0.24
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.20
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmFine = 0.015
        p.fmAmount = 0.18
        p.attack = 0.004
        p.decay = 0.44
        p.sustain = 0.34
        p.release = 0.35
        p.filterCutoff = 2150
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.002
        p.filterDecay = 0.22
        p.filterSustain = 0.18
        p.filterRelease = 0.24
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.24
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.40
        p.chorusMix = 0.16
        p.busGlueEnabled = true
        p.masterVolume = 0.45
        p.lfoEnabled = true
        p.lfoRate = 3.4
        p.lfoStereoPhase = 135
        p.lfoTarget = .none
        p.modMatrix = [
            A.mod(.velocity, .fm, 0.26, curveShape: -0.25),
            A.mod(.env1, .wtMorph1, 0.24),
            A.mod(.lfo1, .pan, 0.32),
            A.mod(.velocity, .amp, 0.24)
        ]
    },
        A.make("Rotary Organ", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.36
        p.osc1PulseWidth = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.24
        p.osc2Octave = 1
        p.osc2Detune = 2
        p.subOscVolume = 0.16
        p.subOscWaveform = .sine
        p.attack = 0.015
        p.decay = 0.10
        p.sustain = 0.75
        p.release = 0.16
        p.filterCutoff = 2250
        p.filterResonance = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.12
        p.filterAttack = 0.004
        p.filterDecay = 0.08
        p.filterSustain = 0.50
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.18
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.chorusMix = 0.15
        p.masterVolume = 0.45
        p.rotaryEnabled = true
        p.rotaryMix = 0.78
        p.rotaryDrive = 0.16
        p.rotaryFast = true
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.12
        p.distortionMix = 0.10
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 5.4
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .amp, 0.30), A.mod(.velocity, .amp, 0.18)]
    },
        A.make("Bright Harpsi", .keys) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.40
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.18
        p.osc2PulseWidth = 0.28
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 4
        p.fmAmount = 0.16
        p.noiseColor = .pink
        p.attack = 0.002
        p.decay = 0.22
        p.sustain = 0.10
        p.release = 0.15
        p.filterCutoff = 3500
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.001
        p.filterDecay = 0.14
        p.filterSustain = 0.08
        p.filterRelease = 0.10
        p.velocityToCutoff = 0.26
        p.velocityToEnvAmount = 0.24
        p.transientEnabled = true
        p.transientAttack = 0.26
        p.transientSustain = -0.10
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.chorusMix = 0.15
        p.busGlueEnabled = true
        p.masterVolume = 0.45
        p.character = .bright
        p.modMatrix = [
            A.mod(.env2, .noiseLevel, 0.15, curveShape: -0.45),
            A.mod(.env2, .pwm2, 0.22),
            A.mod(.velocity, .amp, 0.24)
        ]
    },
        A.make("Mellow Vibes", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.50
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.20
        p.osc2Octave = 1
        p.osc2Detune = 6
        p.fmRatioEnabled = true
        p.fmCoarse = 4
        p.fmFine = 0.015
        p.fmAmount = 0.18
        p.attack = 0.008
        p.decay = 0.56
        p.sustain = 0.20
        p.release = 0.45
        p.filterCutoff = 2600
        p.filterResonance = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.004
        p.filterDecay = 0.28
        p.filterSustain = 0.15
        p.filterRelease = 0.30
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.42
        p.chorusMix = 0.15
        p.masterVolume = 0.45
        p.macro3 = 0.35
        p.lfoEnabled = true
        p.lfoRate = 4.2
        p.lfoStereoPhase = 180
        p.lfoTarget = .none
        p.character = .warm
        p.modMatrix = [
            A.mod(.macro3, .pan, 0.25),
            A.mod(.lfo1, .amp, 0.30),
            A.mod(.velocity, .fm, 0.22),
            A.mod(.velocity, .amp, 0.24)
        ]
    },
    ]

    private static let libPluck: [SynthPreset] = [
        A.make("Koto Pluck", .pluck) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.14
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.noiseColor = .pink
        p.attack = 0.002
        p.decay = 0.22
        p.sustain = 0.08
        p.release = 0.16
        p.filterCutoff = 2000
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.34
        p.filterAttack = 0.001
        p.filterEnvHold = 0.006
        p.filterDecay = 0.12
        p.filterSustain = 0.06
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.30
        p.velocityToEnvAmount = 0.28
        p.transientEnabled = true
        p.transientAttack = 0.18
        p.transientSustain = -0.12
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.45
        p.modMatrix = [
            A.mod(.env2, .noiseLevel, 0.20, curveShape: -0.45, via: .velocity),
            A.mod(.velocity, .osc2Level, 0.22),
            A.mod(.velocity, .amp, 0.26)
        ]
    },
        A.make("Marimba", .pluck) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.18
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 4
        p.fmFine = 0.01
        p.fmAmount = 0.20
        p.attack = 0.002
        p.decay = 0.28
        p.sustain = 0.05
        p.release = 0.22
        p.filterType = .ladder
        p.filterCutoff = 2900
        p.filterResonance = 0.10
        p.filterDrive = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.001
        p.filterDecay = 0.14
        p.filterSustain = 0.05
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.26
        p.transientEnabled = true
        p.transientAttack = 0.24
        p.transientSustain = -0.10
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.38
        p.masterVolume = 0.45
        p.character = .warm
        p.modMatrix = [
            A.mod(.velocity, .fm, 0.28, curveShape: -0.20),
            A.mod(.env2, .fm, 0.18),
            A.mod(.velocity, .amp, 0.26)
        ]
    },
        A.make("Harp Glimmer", .pluck) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.46
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.20
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.noiseColor = .pink
        p.attack = 0.003
        p.decay = 0.45
        p.sustain = 0.10
        p.release = 0.40
        p.filterCutoff = 2800
        p.filterResonance = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.002
        p.filterEnvHold = 0.005
        p.filterDecay = 0.22
        p.filterSustain = 0.08
        p.filterRelease = 0.24
        p.velocityToCutoff = 0.26
        p.velocityToEnvAmount = 0.24
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.46
        p.delayMix = 0.13
        p.delayTempoSync = true
        p.delaySyncDivision = .eighthD
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.45
        p.lfoEnabled = true
        p.lfoRate = 0.28
        p.lfoTarget = .none
        p.character = .bright
        p.modMatrix = [
            A.mod(.env2, .noiseLevel, 0.16, curveShape: -0.45),
            A.mod(.lfo1, .pan, 0.26),
            A.mod(.velocity, .amp, 0.24)
        ]
    },
        A.make("Muted Synth Pluck", .pluck) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.46
        p.osc1PulseWidth = 0.35
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.16
        p.osc2Detune = 4
        p.attack = 0.002
        p.decay = 0.15
        p.sustain = 0.10
        p.release = 0.10
        p.filterType = .ladder
        p.filterCutoff = 1380
        p.filterResonance = 0.22
        p.filterDrive = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.34
        p.filterAttack = 0.001
        p.filterEnvHold = 0.006
        p.filterDecay = 0.10
        p.filterSustain = 0.06
        p.filterRelease = 0.08
        p.velocityToCutoff = 0.30
        p.velocityToEnvAmount = 0.30
        p.transientEnabled = true
        p.transientAttack = 0.28
        p.transientSustain = -0.14
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.34
        p.masterVolume = 0.45
        p.character = .warm
        p.modMatrix = [
            A.mod(.env2, .pwm1, 0.24),
            A.mod(.velocity, .amp, 0.28)
        ]
    },
        A.make("Echo Pluck", .pluck) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.44
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.noiseColor = .pink
        p.attack = 0.003
        p.decay = 0.22
        p.sustain = 0.10
        p.release = 0.28
        p.filterCutoff = 2000
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.30
        p.filterAttack = 0.002
        p.filterDecay = 0.14
        p.filterSustain = 0.08
        p.filterRelease = 0.16
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.28
        p.transientEnabled = true
        p.transientAttack = 0.24
        p.transientSustain = -0.10
        p.delayMix = 0.14
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.18
        p.delayPingPong = true
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.masterVolume = 0.45
        p.modMatrix = [
            A.mod(.env2, .noiseLevel, 0.15, curveShape: -0.45),
            A.mod(.velocity, .osc2Level, 0.26, curveShape: -0.25),
            A.mod(.velocity, .amp, 0.26)
        ]
    },
    ]

    private static let libStrings: [SynthPreset] = [
        A.make("Slow Violas", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 5
        p.attack = 0.36
        p.ampDelay = 0.020
        p.decay = 0.34
        p.sustain = 0.85
        p.release = 0.75
        p.filterType = .ladder
        p.filterCutoff = 1220
        p.filterResonance = 0.12
        p.filterDrive = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.045
        p.filterAttack = 0.28
        p.filterDecay = 0.38
        p.filterSustain = 0.55
        p.filterRelease = 0.65
        p.velocityToCutoff = 0.18
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.46
        p.chorusMix = 0.16
        p.chorusMode = .ensemble
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 105
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 4.0
        p.analogDrift = 0.14
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 4.6
        p.lfoDepth = 0.06
        p.lfoStereoPhase = 120
        p.lfoTarget = .pitch
        p.mseg = A.loopingMSEG(rate: 0.13, [
            (0.0, 0.0, 0.0), (0.36, 0.72, -0.25), (0.72, -0.15, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [
            A.mod(.mseg, .cutoff, 0.32),
            A.mod(.modWheel, .lfoDepth, 0.30)
        ]
    },
        A.make("Pizzicato", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Detune = 3
        p.noiseColor = .pink
        p.attack = 0.002
        p.decay = 0.16
        p.sustain = 0.05
        p.release = 0.12
        p.filterType = .ladder
        p.filterCutoff = 1750
        p.filterResonance = 0.14
        p.filterDrive = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.30
        p.filterAttack = 0.001
        p.filterEnvHold = 0.005
        p.filterDecay = 0.10
        p.filterSustain = 0.05
        p.filterRelease = 0.09
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.28
        p.transientEnabled = true
        p.transientAttack = 0.26
        p.transientSustain = -0.12
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.40
        p.chorusMix = 0.14
        p.masterVolume = 0.38
        p.character = .warm
        p.lfo2Enabled = true
        p.lfo2Rate = 0.14
        p.lfo2Target = .none
        p.modMatrix = [
            A.mod(.env2, .noiseLevel, 0.16, curveShape: -0.45),
            A.mod(.lfo2, .cutoff, 0.32),
            A.mod(.velocity, .amp, 0.26)
        ]
    },
        A.make("Solo Cello", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.48
        p.osc1Octave = -1
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.18
        p.osc2Octave = -1
        p.osc2Detune = 3
        p.attack = 0.18
        p.ampDelay = 0.015
        p.decay = 0.28
        p.sustain = 0.78
        p.release = 0.65
        p.filterType = .ladder
        p.filterCutoff = 840
        p.filterResonance = 0.16
        p.filterDrive = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterEnvDelay = 0.030
        p.filterAttack = 0.14
        p.filterDecay = 0.28
        p.filterSustain = 0.46
        p.filterRelease = 0.38
        p.velocityToCutoff = 0.22
        p.reverbMix = 0.17
        p.reverbRoomSize = 0.42
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 95
        p.masterVolume = 0.35
        p.analogDrift = 0.14
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 4.8
        p.lfoDepth = 0.06
        p.lfoTarget = .pitch
        p.mseg = A.loopingMSEG(rate: 0.17, [
            (0.0, 0.0, 0.0), (0.40, 0.72, -0.25), (0.75, 0.1, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [
            A.mod(.mseg, .cutoff, 0.32),
            A.mod(.env1, .cutoff, 0.18),
            A.mod(.modWheel, .lfoDepth, 0.32)
        ]
    },
        A.make("String Machine", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.36
        p.osc1Detune = -4
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.30
        p.osc2Detune = 7
        p.attack = 0.26
        p.decay = 0.32
        p.sustain = 0.86
        p.release = 0.65
        p.filterCutoff = 1650
        p.filterResonance = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterAttack = 0.20
        p.filterDecay = 0.34
        p.filterSustain = 0.55
        p.filterRelease = 0.55
        p.velocityToCutoff = 0.18
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.46
        p.chorusMix = 0.16
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 115
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoHaasMs = 4.2
        p.analogDrift = 0.16
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 0.22
        p.lfoStereoPhase = 150
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.34), A.mod(.lfo1, .pan, 0.24)]
    },
    ]

    private static let libBrass: [SynthPreset] = [
        A.make("Brass Stab", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.50
        p.osc1Detune = -4
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.24
        p.osc2Detune = 5
        p.osc2PulseWidth = 0.38
        p.attack = 0.010
        p.ampHold = 0.025
        p.decay = 0.18
        p.sustain = 0.36
        p.release = 0.15
        p.filterType = .ladder
        p.filterCutoff = 1350
        p.filterResonance = 0.24
        p.filterDrive = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.32
        p.filterEnvDelay = 0.010
        p.filterAttack = 0.006
        p.filterEnvHold = 0.028
        p.filterDecay = 0.16
        p.filterSustain = 0.18
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.30
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.busGlueEnabled = true
        p.masterVolume = 0.45
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.15
        p.distortionTone = 0.46
        p.distortionMix = 0.13
        p.analogDrift = 0.10
        p.character = .warm
        p.modMatrix = [
            A.mod(.env2, .pwm2, 0.24),
            A.mod(.env2, .drive, 0.20)
        ]
    },
        A.make("Soft Horns", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 5
        p.attack = 0.055
        p.ampHold = 0.032
        p.decay = 0.26
        p.sustain = 0.76
        p.release = 0.30
        p.filterCutoff = 1120
        p.filterResonance = 0.20
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterEnvDelay = 0.020
        p.filterAttack = 0.035
        p.filterEnvHold = 0.035
        p.filterDecay = 0.22
        p.filterSustain = 0.40
        p.filterRelease = 0.24
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.46
        p.chorusMix = 0.14
        p.masterVolume = 0.43
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.12
        p.distortionTone = 0.42
        p.distortionMix = 0.12
        p.analogDrift = 0.12
        p.character = .warm
        p.macro2 = 0.3
        p.lfoEnabled = true
        p.lfoRate = 0.18
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.macro2, .cutoff, 0.24), A.mod(.lfo1, .pan, 0.30)]
    },
        A.make("Trumpet Lead", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.54
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2PulseWidth = 0.38
        p.osc2Detune = 4
        p.attack = 0.016
        p.ampHold = 0.022
        p.decay = 0.18
        p.sustain = 0.72
        p.release = 0.18
        p.filterCutoff = 1680
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.28
        p.filterEnvDelay = 0.012
        p.filterAttack = 0.012
        p.filterEnvHold = 0.024
        p.filterDecay = 0.14
        p.filterSustain = 0.48
        p.filterRelease = 0.16
        p.velocityToCutoff = 0.28
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.40
        p.delayMix = 0.10
        p.delayTime = 0.26
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.busGlueEnabled = true
        p.masterVolume = 0.52
        p.voiceMode = .legato
        p.portamento = 0.035
        p.glideLegatoOnly = true
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.16
        p.distortionTone = 0.50
        p.distortionMix = 0.14
        p.lfoEnabled = true
        p.lfoRate = 5.0
        p.lfoDepth = 0.08
        p.lfoTarget = .pitch
        p.modMatrix = [
            A.mod(.env2, .pwm2, 0.22),
            A.mod(.env2, .finePitch, 0.20, curveShape: -0.50)
        ]
    },
        A.make("Synth Brass Pad", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.44
        p.osc1Detune = -5
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 7
        p.attack = 0.085
        p.ampHold = 0.035
        p.decay = 0.28
        p.sustain = 0.80
        p.release = 0.38
        p.filterType = .ladder
        p.filterCutoff = 1280
        p.filterResonance = 0.20
        p.filterDrive = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterEnvDelay = 0.028
        p.filterAttack = 0.045
        p.filterEnvHold = 0.040
        p.filterDecay = 0.24
        p.filterSustain = 0.45
        p.filterRelease = 0.30
        p.velocityToCutoff = 0.22
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.14
        p.masterVolume = 0.40
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.14
        p.distortionTone = 0.44
        p.distortionMix = 0.12
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.analogDrift = 0.14
        p.character = .warm
        p.lfoEnabled = true
        p.lfoRate = 0.16
        p.lfoStereoPhase = 120
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.30)]
    },
        A.make("Low Tuba", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.54
        p.osc1Octave = -1
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.28
        p.osc2Octave = -1
        p.osc2Detune = 4
        p.subOscVolume = 0.18
        p.subOscWaveform = .triangle
        p.attack = 0.032
        p.ampHold = 0.028
        p.decay = 0.22
        p.sustain = 0.78
        p.release = 0.24
        p.filterCutoff = 540
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterEnvDelay = 0.015
        p.filterAttack = 0.018
        p.filterEnvHold = 0.030
        p.filterDecay = 0.18
        p.filterSustain = 0.35
        p.filterRelease = 0.20
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.busGlueEnabled = true
        p.masterVolume = 0.54
        p.voiceMode = .mono
        p.portamento = 0.04
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.15
        p.distortionTone = 0.40
        p.distortionMix = 0.14
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.character = .warm
        p.analogDrift = 0.10
        p.lfoEnabled = true
        p.lfoRate = 0.25
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.30), A.mod(.env1, .finePitch, 0.18)]
    },
    ]

    private static let libArp: [SynthPreset] = [
        A.make("Up Arp Pluck", .arp) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.44
        p.osc1PulseWidth = 0.34
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.attack = 0.003
        p.decay = 0.15
        p.sustain = 0.18
        p.release = 0.10
        p.filterCutoff = 2150
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.30
        p.filterAttack = 0.001
        p.filterDecay = 0.10
        p.filterSustain = 0.10
        p.filterRelease = 0.08
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.36
        p.delayMix = 0.14
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayPingPong = true
        p.delayFeedback = 0.16
        p.masterVolume = 0.42
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.arpGateLength = 0.50
        p.arpSwing = 0.14
        p.tranceGateEnabled = true
        p.tranceGatePattern = 0xEEAE
        p.tranceGateDepth = 0.45
        p.tranceGateSmooth = 0.18
        p.tranceGateDivision = .sixteenth
        p.sequencerData = A.proSequence()
        p.modMatrix = [
            A.mod(.env2, .pwm1, 0.24),
            A.mod(.velocity, .amp, 0.22)
        ]
    },
        A.make("Down Arp Bells", .arp) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.46
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.20
        p.osc2Octave = 1
        p.osc2Detune = 4
        p.fmRatioEnabled = true
        p.fmCoarse = 3
        p.fmFine = 0.02
        p.fmAmount = 0.20
        p.attack = 0.003
        p.decay = 0.30
        p.sustain = 0.10
        p.release = 0.24
        p.filterCutoff = 3400
        p.filterResonance = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.002
        p.filterDecay = 0.18
        p.filterSustain = 0.10
        p.filterRelease = 0.18
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.42
        p.delayMix = 0.13
        p.delayTempoSync = true
        p.delaySyncDivision = .eighthD
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.42
        p.arpMode = .down
        p.arpRate = .eighth
        p.arpOctaves = 2
        p.arpGateLength = 0.46
        p.arpSwing = 0.10
        p.sequencerData = A.proSequencePattern(
            notes: [12, 7, 4, 0, 12, 9, 5, 0],
            ratchets: [4: 2, 12: 2],
            ties: [2, 10],
            probabilities: [14: 0.75],
            octaves: [0: 1]
        )
        p.character = .bright
        p.modMatrix = [
            A.mod(.velocity, .fm, 0.26, curveShape: -0.20),
            A.mod(.env2, .fm, 0.18),
            A.mod(.velocity, .amp, 0.24)
        ]
    },
        A.make("Random Sparkle", .arp) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.44
        p.osc1Octave = 1
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Octave = 2
        p.osc2Detune = 5
        p.fmAmount = 0.08
        p.attack = 0.003
        p.decay = 0.18
        p.sustain = 0.10
        p.release = 0.16
        p.filterCutoff = 3900
        p.filterResonance = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.001
        p.filterDecay = 0.12
        p.filterSustain = 0.08
        p.filterRelease = 0.12
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.42
        p.delayMix = 0.14
        p.delayTempoSync = true
        p.delaySyncDivision = .sixteenthD
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.42
        p.arpMode = .random
        p.arpRate = .sixteenth
        p.arpOctaves = 2
        p.arpGateLength = 0.44
        p.arpSwing = 0.16
        p.sequencerData = A.proSequencePattern(
            notes: [0, 7, 12, 14, 19, 12, 7, 2],
            ratchets: [3: 2, 11: 3],
            ties: [6],
            probabilities: [5: 0.70, 9: 0.80, 13: 0.75],
            octaves: [8: 1]
        )
        p.lfoEnabled = true
        p.lfoRate = 0.35
        p.lfoTarget = .none
        p.modMatrix = [
            A.mod(.lfo1, .pan, 0.30),
            A.mod(.velocity, .amp, 0.22)
        ]
    },
        A.make("UpDown Bass Arp", .arp) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc1Octave = -1
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.18
        p.osc2Octave = -1
        p.osc2PulseWidth = 0.36
        p.osc2Detune = 4
        p.subOscVolume = 0.14
        p.subOscWaveform = .square
        p.attack = 0.003
        p.decay = 0.16
        p.sustain = 0.36
        p.release = 0.11
        p.filterType = .ladder
        p.filterCutoff = 880
        p.filterResonance = 0.24
        p.filterDrive = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.30
        p.filterAttack = 0.002
        p.filterDecay = 0.11
        p.filterSustain = 0.14
        p.filterRelease = 0.09
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.05
        p.reverbRoomSize = 0.30
        p.delayMix = 0.13
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.15
        p.delayPingPong = true
        p.masterVolume = 0.44
        p.arpMode = .upDown
        p.arpRate = .eighth
        p.arpGateLength = 0.52
        p.arpSwing = 0.12
        p.tranceGateEnabled = true
        p.tranceGatePattern = 0xAAEE
        p.tranceGateDepth = 0.52
        p.tranceGateSmooth = 0.12
        p.tranceGateDivision = .sixteenth
        p.sequencerData = A.proSequencePattern(
            notes: [0, 0, 7, 0, 10, 0, 12, 7],
            ratchets: [6: 2, 14: 2],
            ties: [3, 11],
            probabilities: [15: 0.80]
        )
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [
            A.mod(.env2, .pwm2, 0.24),
            A.mod(.velocity, .amp, 0.20)
        ]
    },
    ]

    private static let libFX: [SynthPreset] = [
        A.make("Laser Zap", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.44
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.32
        p.osc2Detune = 5
        p.osc2FixedFrequency = true
        p.osc2FrequencyHz = 440
        p.attack = 0.002
        p.decay = 0.14
        p.sustain = 0.10
        p.release = 0.15
        p.filterCutoff = 2400
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.34
        p.filterAttack = 0.001
        p.filterDecay = 0.10
        p.filterSustain = 0.08
        p.filterRelease = 0.10
        p.reverbMix = 0.31
        p.reverbRoomSize = 0.36
        p.delayMix = 0.12
        p.delayTime = 0.16
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.42
        p.frequencyShifterEnabled = true
        p.frequencyShifterShiftHz = 18
        p.frequencyShifterMix = 0.28
        p.frequencyShifterFeedback = 0.08
        p.lfoEnabled = true
        p.lfoRate = 0.45
        p.lfoTarget = .none
        p.modMatrix = [
            A.mod(.env1, .pitch1, 0.18),
            A.mod(.sampleAndHold, .pitch2, 0.22),
            A.mod(.lfo1, .pan, 0.24)
        ]
    },
        A.make("Wind Gust", .fx) { p in
        p.osc1Waveform = .noise
        p.osc1Volume = 0.56
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 4
        p.attack = 0.14
        p.decay = 0.45
        p.sustain = 0.62
        p.release = 0.55
        p.filterType = .bandPass
        p.filterCutoff = 820
        p.filterResonance = 0.30
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.12
        p.filterDecay = 0.45
        p.filterSustain = 0.45
        p.filterRelease = 0.50
        p.reverbMix = 0.32
        p.reverbRoomSize = 0.50
        p.chorusMix = 0.14
        p.masterVolume = 0.48
        p.noiseColor = .brown
        p.perlinRate = 0.85
        p.stereoEnabled = true
        p.stereoWidth = 1.26
        p.stereoHaasMs = 4.0
        p.lfoEnabled = true
        p.lfoRate = 0.16
        p.lfoTarget = .none
        p.mseg2 = A.loopingMSEG(rate: 0.18, [
            (0.0, -0.3, 0.0), (0.35, 0.65, -0.25), (0.72, -0.1, 0.2), (1.0, -0.3, 0.15)
        ], continuous: true)
        p.modMatrix = [
            A.mod(.mseg2, .cutoff, 0.34),
            A.mod(.smoothRandom, .pan, 0.26),
            A.mod(.lfo1, .pan, 0.24)
        ]
    },
    ]
}
