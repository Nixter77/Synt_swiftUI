//
//  FactoryPresets+Showcase.swift
//  Synt_swiftUI
//
//  Showcase bank (20). Raw LFO rows (lfoRowsFollowDepth = false), one matrix
//  row on every patch, and the destinations the older showcase test still
//  expects. Newer paths (filter 2, MSEG, wavetable, sync) sit on top.
//  Same SYNT_30 caps as FactoryPresets.swift.
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    static let showcasePresets: [SynthPreset] = [
        A.make("Rubber Wobble", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.54
        p.osc1Octave = -1
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Octave = -2
        p.osc2PulseWidth = 0.40
        p.osc2Detune = 5
        p.subOscVolume = 0.16
        p.subOscWaveform = .square
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmAmount = 0.16
        p.envelopeModel = .analog
        p.attack = 0.006
        p.decay = 0.22
        p.sustain = 0.76
        p.release = 0.16
        p.filterType = .ladder
        p.filterCutoff = 700
        p.filterResonance = 0.30
        p.filterDrive = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.004
        p.filterEnvHold = 0.008
        p.filterDecay = 0.16
        p.filterSustain = 0.30
        p.filterRelease = 0.14
        p.filter2Routing = .serial
        p.filter2Type = .bandPass
        p.filter2Cutoff = 1350
        p.filter2Resonance = 0.28
        p.filter2Balance = 0.52
        p.velocityToCutoff = 0.22
        p.lfoEnabled = true
        p.lfoRate = 2.0
        p.lfoDepth = 0
        p.lfoStereoPhase = 90
        p.lfoTarget = .none
        p.reverbMix = 0.04
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.03
        p.unisonVoices = 2
        p.unisonDetune = 6
        p.unisonSpread = 0.30
        p.busGlueEnabled = true
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.34), A.mod(.velocity, .lfoRate, 0.25), A.mod(.env2, .pwm2, 0.22)]
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.14
        p.distortionMix = 0.12
    },
        A.make("PWM Sub Pulse", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.56
        p.osc1Octave = -1
        p.osc1PulseWidth = 0.44
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Octave = -2
        p.osc2Detune = 3
        p.subOscVolume = 0.18
        p.subOscWaveform = .triangle
        p.envelopeModel = .analog
        p.attack = 0.005
        p.decay = 0.24
        p.sustain = 0.74
        p.release = 0.16
        p.filterType = .ladder
        p.filterCutoff = 880
        p.filterResonance = 0.18
        p.filterDrive = 0.10
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.003
        p.filterEnvHold = 0.010
        p.filterDecay = 0.16
        p.filterSustain = 0.28
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.24
        p.lfoEnabled = true
        p.lfoRate = 0.55
        p.lfoTarget = .none
        p.reverbMix = 0.04
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.03
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [A.mod(.lfo1, .pwm1, 0.34), A.mod(.velocity, .cutoff, 0.22)]
        p.eqEnabled = true
        p.eqLowGain = 3
        p.eqMidGain = -1
        p.eqHighGain = -2
    },
        A.make("Snap Resonator", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.54
        p.osc1Octave = -1
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.18
        p.osc2Octave = -1
        p.osc2PulseWidth = 0.34
        p.osc2Detune = 4
        p.subOscVolume = 0.16
        p.subOscWaveform = .square
        p.envelopeModel = .analog
        p.attack = 0.003
        p.decay = 0.18
        p.sustain = 0.40
        p.release = 0.12
        p.filterType = .ladder
        p.filterCutoff = 820
        p.filterResonance = 0.28
        p.filterDrive = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.32
        p.filterAttack = 0.002
        p.filterEnvHold = 0.012
        p.filterDecay = 0.12
        p.filterSustain = 0.16
        p.filterRelease = 0.10
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.04
        p.masterVolume = 0.58
        p.voiceMode = .mono
        p.portamento = 0.03
        p.busGlueEnabled = true
        p.stereoEnabled = true
        p.stereoMonoBassHz = 120
        p.modMatrix = [
            A.mod(.env2, .pitch1, 0.18, curveShape: -0.60),
            A.mod(.env1, .cutoff, 0.24),
            A.mod(.velocity, .resonance, 0.24),
            A.mod(.env2, .pwm2, 0.22)
        ]
    },
        A.make("Vox Morph Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.50
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.32
        p.osc2Detune = 5
        p.attack = 0.014
        p.decay = 0.22
        p.sustain = 0.70
        p.release = 0.22
        p.filterCutoff = 2000
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.006
        p.filterDecay = 0.18
        p.filterSustain = 0.36
        p.filterRelease = 0.18
        p.filter2Routing = .parallel
        p.filter2Type = .formant
        p.filterVowel = 1.2
        p.filter2Balance = 0.34
        p.velocityToCutoff = 0.22
        p.lfoEnabled = true
        p.lfoRate = 0.85
        p.lfoTarget = .none
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.40
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.52
        p.unisonVoices = 2
        p.unisonDetune = 6
        p.unisonSpread = 0.30
        p.modMatrix = [A.mod(.lfo1, .mix, 0.36), A.mod(.lfo1, .cutoff, 0.20)]
    },
        A.make("Delayed Vibrato", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Detune = 4
        p.osc2PulseWidth = 0.42
        p.attack = 0.028
        p.decay = 0.28
        p.sustain = 0.72
        p.release = 0.26
        p.filterCutoff = 2250
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.012
        p.filterDecay = 0.22
        p.filterSustain = 0.40
        p.filterRelease = 0.22
        p.velocityToCutoff = 0.22
        p.lfoEnabled = true
        p.lfoRate = 5.2
        p.lfoDepth = 0.11
        p.lfoTarget = .pitch
        p.lfo2Enabled = true
        p.lfo2Rate = 0.42
        p.lfo2Target = .none
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.42
        p.delayMix = 0.12
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.52
        p.portamento = 0.04
        p.character = .warm
        p.modMatrix = [
            A.mod(.lfo1, .pitch1, 0.15, via: .aftertouch),
            A.mod(.lfo2, .pwm2, 0.30),
            A.mod(.env1, .cutoff, 0.22)
        ]
    },
        A.make("Fifth Sync Lead", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1PulseWidth = 0.38
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 4
        p.oscSyncEnabled = true
        p.attack = 0.008
        p.decay = 0.22
        p.sustain = 0.64
        p.release = 0.18
        p.filterCutoff = 2200
        p.filterResonance = 0.24
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.24
        p.filterAttack = 0.004
        p.filterDecay = 0.16
        p.filterSustain = 0.30
        p.filterRelease = 0.16
        p.velocityToCutoff = 0.24
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.delayMix = 0.13
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.52
        p.unisonVoices = 2
        p.unisonDetune = 5
        p.unisonSpread = 0.24
        p.modMatrix = [
            A.mod(.env2, .pitch2, 0.22, curveShape: -0.30),
            A.mod(.velocity, .cutoff, 0.22)
        ]
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.12
        p.distortionMix = 0.12
    },
        A.make("Phase Cathedral", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.26
        p.osc2Detune = 5
        p.attack = 0.52
        p.ampDelay = 0.020
        p.decay = 0.45
        p.sustain = 0.84
        p.release = 1.25
        p.filterCutoff = 1400
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.035
        p.filterAttack = 0.40
        p.filterDecay = 0.50
        p.filterSustain = 0.50
        p.filterRelease = 1.00
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoStereoPhase = 135
        p.lfoTarget = .none
        p.reverbMix = 0.22
        p.reverbRoomSize = 0.50
        p.reverbShimmer = 0.18
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 110
        p.masterVolume = 0.34
        p.phaserEnabled = true
        p.phaserMode = .phaser8
        p.phaserMix = 0.20
        p.phaserRate = 0.12
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 4.0
        p.mseg = A.loopingMSEG(rate: 0.14, [
            (0.0, 0.0, 0.0), (0.35, 0.75, -0.25), (0.72, -0.2, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [A.mod(.lfo1, .pan, 0.35), A.mod(.mseg, .cutoff, 0.34)]
    },
        A.make("Breathing Glass", .pad) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.42
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Octave = 1
        p.osc2Detune = 4
        p.attack = 0.50
        p.decay = 0.45
        p.sustain = 0.82
        p.release = 1.20
        p.filterCutoff = 2250
        p.filterResonance = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.030
        p.filterAttack = 0.38
        p.filterDecay = 0.48
        p.filterSustain = 0.52
        p.filterRelease = 0.95
        p.lfo2Enabled = true
        p.lfo2Rate = 0.12
        p.lfo2StereoPhase = 140
        p.lfo2Target = .none
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.16
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 120
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.stereoHaasMs = 3.8
        p.mseg2 = A.loopingMSEG(rate: 0.12, [
            (0.0, -0.2, 0.0), (0.40, 0.75, -0.25), (0.75, 0.15, 0.2), (1.0, -0.2, 0.15)
        ], continuous: true)
        p.modMatrix = [A.mod(.lfo2, .amp, 0.20), A.mod(.mseg2, .cutoff, 0.34)]
    },
        A.make("Tidal Pad", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.40
        p.osc1WavetableMorph = 0.32
        p.osc1WavetableIndex = 3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.18
        p.osc2Detune = 6
        p.attack = 0.54
        p.decay = 0.48
        p.sustain = 0.82
        p.release = 1.25
        p.filterCutoff = 1350
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.025
        p.filterAttack = 0.42
        p.filterDecay = 0.52
        p.filterSustain = 0.50
        p.filterRelease = 1.00
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 105
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 4.0
        p.lfoEnabled = true
        p.lfoRate = 0.14
        p.lfoDepth = 0.14
        p.lfoStereoPhase = 150
        p.lfoTarget = .filter
        p.mseg = A.loopingMSEG(rate: 0.14, [
            (0.0, 0.0, 0.0), (0.35, 0.75, -0.25), (0.70, -0.2, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [
            A.mod(.modWheel, .lfoDepth, 0.30),
            A.mod(.mseg, .cutoff, 0.34),
            A.mod(.lfo1, .pan, 0.24)
        ]
    },
        A.make("Phaser Rhodes", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 2
        p.fmFine = 0.01
        p.fmAmount = 0.18
        p.attack = 0.005
        p.decay = 0.44
        p.sustain = 0.38
        p.release = 0.36
        p.filterCutoff = 1950
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.003
        p.filterDecay = 0.22
        p.filterSustain = 0.20
        p.filterRelease = 0.22
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.04
        p.reverbRoomSize = 0.40
        p.chorusMix = 0.16
        p.sendA = 0.14
        p.masterVolume = 0.45
        p.phaserEnabled = true
        p.phaserMode = .phaser4
        p.phaserMix = 0.22
        p.phaserRate = 0.30
        p.lfoEnabled = true
        p.lfoRate = 0.40
        p.lfoTarget = .none
        p.character = .warm
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.30), A.mod(.velocity, .amp, 0.22)]
    },
        A.make("Wurli Tremolo", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.40
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 3
        p.fmAmount = 0.16
        p.attack = 0.004
        p.decay = 0.36
        p.sustain = 0.42
        p.release = 0.28
        p.filterCutoff = 1750
        p.filterResonance = 0.16
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.002
        p.filterDecay = 0.20
        p.filterSustain = 0.22
        p.filterRelease = 0.20
        p.velocityToCutoff = 0.26
        p.lfoEnabled = true
        p.lfoRate = 4.4
        p.lfoStereoPhase = 120
        p.lfoTarget = .none
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.chorusMix = 0.15
        p.busGlueEnabled = true
        p.masterVolume = 0.45
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.12
        p.distortionMix = 0.12
        p.character = .warm
        p.modMatrix = [A.mod(.lfo1, .amp, 0.32), A.mod(.velocity, .amp, 0.22), A.mod(.velocity, .cutoff, 0.20)]
    },
        A.make("Velvet Clav", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1PulseWidth = 0.30
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.16
        p.osc2Detune = 3
        p.fmRatioEnabled = true
        p.fmCoarse = 4
        p.fmAmount = 0.16
        p.attack = 0.002
        p.decay = 0.16
        p.sustain = 0.18
        p.release = 0.15
        p.filterCutoff = 2500
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.30
        p.filterAttack = 0.001
        p.filterDecay = 0.11
        p.filterSustain = 0.12
        p.filterRelease = 0.08
        p.velocityToCutoff = 0.28
        p.velocityToEnvAmount = 0.28
        p.transientEnabled = true
        p.transientAttack = 0.20
        p.transientSustain = -0.10
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.chorusMix = 0.15
        p.masterVolume = 0.45
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.12
        p.distortionMix = 0.12
        p.modMatrix = [A.mod(.velocity, .cutoff, 0.24), A.mod(.velocity, .amp, 0.22), A.mod(.env2, .pwm1, 0.24)]
    },
        A.make("Pan Ping Pluck", .pluck) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.48
        p.osc1Detune = -2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.20
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.noiseColor = .pink
        p.attack = 0.003
        p.decay = 0.24
        p.sustain = 0.10
        p.release = 0.20
        p.filterCutoff = 2400
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.28
        p.filterAttack = 0.001
        p.filterEnvHold = 0.006
        p.filterDecay = 0.14
        p.filterSustain = 0.08
        p.filterRelease = 0.14
        p.velocityToCutoff = 0.26
        p.lfoEnabled = true
        p.lfoRate = 0.50
        p.lfoStereoPhase = 180
        p.lfoTarget = .none
        p.delayMix = 0.14
        p.delayTempoSync = true
        p.delaySyncDivision = .eighth
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.reverbMix = 0.10
        p.reverbRoomSize = 0.38
        p.masterVolume = 0.45
        p.modMatrix = [A.mod(.lfo1, .pan, 0.40), A.mod(.velocity, .amp, 0.24), A.mod(.velocity, .cutoff, 0.20)]
    },
        A.make("Flange Harp", .pluck) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.48
        p.osc1WavetableMorph = 0.26
        p.osc1WavetableIndex = 1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.18
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.noiseColor = .pink
        p.attack = 0.003
        p.decay = 0.38
        p.sustain = 0.10
        p.release = 0.34
        p.filterCutoff = 2900
        p.filterResonance = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.26
        p.filterAttack = 0.002
        p.filterEnvHold = 0.005
        p.filterDecay = 0.20
        p.filterSustain = 0.08
        p.filterRelease = 0.22
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.42
        p.chorusMix = 0.12
        p.masterVolume = 0.45
        p.lfoEnabled = true
        p.lfoRate = 0.35
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .pan, 0.24), A.mod(.velocity, .amp, 0.24), A.mod(.velocity, .cutoff, 0.20)]
    },
        A.make("Bit Pluck Arp", .pluck) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.46
        p.osc1Octave = 1
        p.osc1PulseWidth = 0.25
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.16
        p.osc2Detune = 4
        p.attack = 0.002
        p.decay = 0.14
        p.sustain = 0.16
        p.release = 0.10
        p.filterCutoff = 2600
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.28
        p.filterAttack = 0.001
        p.filterDecay = 0.10
        p.filterSustain = 0.08
        p.filterRelease = 0.08
        p.velocityToCutoff = 0.26
        p.reverbMix = 0.08
        p.reverbRoomSize = 0.34
        p.delayMix = 0.13
        p.delayTempoSync = true
        p.delaySyncDivision = .sixteenthD
        p.delayFeedback = 0.14
        p.delayPingPong = true
        p.masterVolume = 0.45
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.arpGateLength = 0.52
        p.arpSwing = 0.10
        p.sequencerData = A.proSequencePattern(
            notes: [0, 4, 7, 12, 7, 4, 0, 11],
            ratchets: [7: 2, 15: 2],
            ties: [2, 10],
            probabilities: [12: 0.80]
        )
        p.modMatrix = [A.mod(.velocity, .amp, 0.20), A.mod(.env2, .pwm1, 0.24), A.mod(.velocity, .cutoff, 0.22)]
    },
        A.make("Chamber Swell", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.36
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.26
        p.osc2Detune = 6
        p.attack = 0.34
        p.ampDelay = 0.020
        p.decay = 0.38
        p.sustain = 0.82
        p.release = 0.78
        p.filterType = .ladder
        p.filterCutoff = 1500
        p.filterResonance = 0.12
        p.filterDrive = 0.08
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.040
        p.filterAttack = 0.26
        p.filterDecay = 0.38
        p.filterSustain = 0.55
        p.filterRelease = 0.65
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.15
        p.chorusMode = .ensemble
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 105
        p.masterVolume = 0.32
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.stereoHaasMs = 4.0
        p.lfoStereoPhase = 120
        p.analogDrift = 0.14
        p.character = .warm
        p.mseg = A.loopingMSEG(rate: 0.18, [
            (0.0, -0.2, 0.0), (0.38, 0.8, -0.22), (0.72, 0.1, 0.18), (1.0, -0.2, 0.15)
        ], continuous: true)
        p.modMatrix = [A.mod(.mseg, .cutoff, 0.34), A.mod(.mseg, .pan, 0.20)]
    },
        A.make("Phased Violins", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc1Octave = 1
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 5
        p.attack = 0.26
        p.ampDelay = 0.015
        p.decay = 0.34
        p.sustain = 0.80
        p.release = 0.65
        p.filterCutoff = 2000
        p.filterResonance = 0.12
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.16
        p.filterEnvDelay = 0.035
        p.filterAttack = 0.20
        p.filterDecay = 0.34
        p.filterSustain = 0.52
        p.filterRelease = 0.55
        p.lfoEnabled = true
        p.lfoRate = 0.20
        p.lfoStereoPhase = 140
        p.lfoTarget = .none
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.46
        p.chorusMix = 0.15
        p.sceneHPFEnabled = true
        p.sceneHPFFrequency = 120
        p.masterVolume = 0.32
        p.phaserEnabled = true
        p.phaserMode = .phaser6
        p.phaserMix = 0.18
        p.phaserRate = 0.15
        p.stereoEnabled = true
        p.stereoWidth = 1.22
        p.stereoHaasMs = 3.5
        p.mseg = A.loopingMSEG(rate: 0.16, [
            (0.0, 0.0, 0.0), (0.42, 0.75, -0.25), (0.78, 0.2, 0.2), (1.0, 0.0, 0.15)
        ], continuous: true)
        p.modMatrix = [A.mod(.mseg, .cutoff, 0.32), A.mod(.lfo1, .pan, 0.20)]
    },
        A.make("Siren Drift", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.40
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.38
        p.osc2Detune = 5
        p.osc2FixedFrequency = true
        p.osc2FrequencyHz = 293.66
        p.attack = 0.06
        p.decay = 0.34
        p.sustain = 0.70
        p.release = 0.45
        p.filterCutoff = 1800
        p.filterResonance = 0.22
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.22
        p.filterAttack = 0.04
        p.filterDecay = 0.30
        p.filterSustain = 0.45
        p.filterRelease = 0.38
        p.reverbMix = 0.31
        p.reverbRoomSize = 0.44
        p.delayMix = 0.12
        p.delayTime = 0.28
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.frequencyShifterEnabled = true
        p.frequencyShifterShiftHz = 12
        p.frequencyShifterMix = 0.20
        p.masterVolume = 0.40
        p.mseg = A.loopingMSEG(rate: 0.35, [
            (0.0, -0.5, 0.0), (0.45, 0.85, -0.2), (0.80, -0.2, 0.2), (1.0, -0.5, 0.15)
        ])
        p.modMatrix = [A.mod(.mseg, .pitch1, 0.18), A.mod(.mseg, .cutoff, 0.32)]
    },
        A.make("Jet Flanger", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc1Detune = -3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.20
        p.osc2Detune = 5
        p.attack = 0.03
        p.decay = 0.28
        p.sustain = 0.62
        p.release = 0.35
        p.filterCutoff = 1650
        p.filterResonance = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.02
        p.filterDecay = 0.24
        p.filterSustain = 0.42
        p.filterRelease = 0.28
        p.reverbMix = 0.30
        p.reverbRoomSize = 0.42
        p.masterVolume = 0.40
        p.phaserEnabled = true
        p.phaserMode = .flanger
        p.phaserMix = 0.26
        p.phaserRate = 0.18
        p.fxOrder = A.orderDelayFirst
        p.lfoEnabled = true
        p.lfoRate = 0.30
        p.lfoTarget = .none
        p.stereoEnabled = true
        p.stereoWidth = 1.24
        p.modMatrix = [A.mod(.lfo1, .pitch2, 0.18), A.mod(.lfo1, .cutoff, 0.30)]
    },
        A.make("Random Bloom", .fx) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.42
        p.osc1Octave = 1
        p.osc1WavetableMorph = 0.22
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.16
        p.osc2Detune = 4
        p.attack = 0.10
        p.decay = 0.42
        p.sustain = 0.56
        p.release = 0.55
        p.filterCutoff = 2200
        p.filterResonance = 0.14
        p.filterEnvUseDedicatedADSR = true
        p.filterEnvelopeAmount = 0.20
        p.filterAttack = 0.08
        p.filterDecay = 0.36
        p.filterSustain = 0.40
        p.filterRelease = 0.50
        p.reverbMix = 0.32
        p.reverbRoomSize = 0.48
        p.delayMix = 0.12
        p.delayTime = 0.30
        p.delayFeedback = 0.16
        p.delayPingPong = true
        p.masterVolume = 0.40
        p.lfo2Enabled = true
        p.lfo2Rate = 0.25
        p.lfo2Target = .none
        p.perlinRate = 1.4
        p.macro1 = 0.40
        p.stereoEnabled = true
        p.stereoWidth = 1.26
        p.modMatrix = [
            A.mod(.smoothRandom, .cutoff, 0.32),
            A.mod(.lfo2, .pan, 0.30),
            A.mod(.macro1, .cutoff, 0.22)
        ]
    },
    ]
}
