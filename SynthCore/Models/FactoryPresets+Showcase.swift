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
        p.osc1Volume = 0.58
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Octave = -2
        p.osc2PulseWidth = 0.4
        p.attack = 0.006
        p.decay = 0.2
        p.sustain = 0.78
        p.release = 0.16
        p.filterCutoff = 700
        p.filterResonance = 0.28
        p.lfoEnabled = true
        p.lfoRate = 2.0
        p.lfoDepth = 0
        p.lfoTarget = .none
        p.reverbMix = 0.04
        p.masterVolume = 0.48
        p.unisonVoices = 2
        p.unisonDetune = 6
        p.unisonSpread = 0.3
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.3), A.mod(.velocity, .lfoRate, 0.25)]
        p.distortionEnabled = true
        p.distortionType = .tubeSaturation
        p.distortionDrive = 0.12
        p.distortionMix = 0.08
    },
        A.make("PWM Sub Pulse", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.6
        p.osc1Octave = -1
        p.osc1PulseWidth = 0.45
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Octave = -2
        p.attack = 0.005
        p.decay = 0.24
        p.sustain = 0.74
        p.release = 0.16
        p.filterCutoff = 900
        p.filterResonance = 0.16
        p.lfoEnabled = true
        p.lfoRate = 0.55
        p.lfoTarget = .none
        p.reverbMix = 0.04
        p.masterVolume = 0.5
        p.modMatrix = [A.mod(.lfo1, .pwm1, 0.32)]
        p.eqEnabled = true
        p.eqLowGain = 3
        p.eqMidGain = -1
        p.eqHighGain = -2
    },
        A.make("Snap Resonator", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.58
        p.osc1Octave = -1
        p.attack = 0.004
        p.decay = 0.18
        p.sustain = 0.42
        p.release = 0.12
        p.filterCutoff = 840
        p.filterResonance = 0.26
        p.reverbMix = 0.04
        p.masterVolume = 0.5
        p.portamento = 0.03
        p.modMatrix = [A.mod(.env1, .cutoff, 0.22), A.mod(.velocity, .resonance, 0.22)]
    },
        A.make("Vox Morph Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.34
        p.osc2Detune = 4
        p.attack = 0.015
        p.decay = 0.2
        p.sustain = 0.7
        p.release = 0.22
        p.filterCutoff = 2000
        p.filterResonance = 0.2
        p.lfoEnabled = true
        p.lfoRate = 0.85
        p.lfoTarget = .none
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.4
        p.masterVolume = 0.46
        p.unisonVoices = 2
        p.unisonDetune = 6
        p.unisonSpread = 0.3
        p.modMatrix = [A.mod(.lfo1, .mix, 0.35), A.mod(.lfo1, .cutoff, 0.1)]
    },
        A.make("Delayed Vibrato", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Detune = 3
        p.osc2PulseWidth = 0.42
        p.attack = 0.03
        p.decay = 0.28
        p.sustain = 0.72
        p.release = 0.26
        p.filterCutoff = 2300
        p.filterResonance = 0.16
        p.lfoEnabled = true
        p.lfoRate = 5.2
        p.lfoTarget = .none
        p.reverbMix = 0.12
        p.reverbRoomSize = 0.4
        p.delayMix = 0.07
        p.delayTime = 0.3
        p.delayFeedback = 0.16
        p.masterVolume = 0.46
        p.portamento = 0.04
        p.modMatrix = [A.mod(.lfo1, .pitch1, 0.012), A.mod(.lfo1, .pitch2, 0.012), A.mod(.lfo1, .pwm2, 0.14), A.mod(.env1, .cutoff, 0.1)]
    },
        A.make("Fifth Sync Lead", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.5
        p.osc1PulseWidth = 0.38
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 2
        p.oscSyncEnabled = true
        p.attack = 0.008
        p.decay = 0.22
        p.sustain = 0.64
        p.release = 0.18
        p.filterCutoff = 2200
        p.filterResonance = 0.22
        p.reverbMix = 0.1
        p.masterVolume = 0.46
        p.unisonVoices = 2
        p.unisonDetune = 5
        p.unisonSpread = 0.22
        p.modMatrix = [A.mod(.velocity, .pitch2, 0.04), A.mod(.velocity, .cutoff, 0.14)]
        p.distortionEnabled = true
        p.distortionType = .tapeSaturation
        p.distortionDrive = 0.1
        p.distortionMix = 0.07
    },
        A.make("Phase Cathedral", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.4
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.28
        p.osc2Detune = 5
        p.attack = 0.3
        p.decay = 0.4
        p.sustain = 0.84
        p.release = 0.9
        p.filterCutoff = 1400
        p.filterResonance = 0.12
        p.lfoEnabled = true
        p.lfoRate = 0.12
        p.lfoTarget = .none
        p.reverbMix = 0.16
        p.reverbRoomSize = 0.5
        p.masterVolume = 0.34
        p.phaserEnabled = true
        p.phaserMode = .phaser8
        p.phaserMix = 0.2
        p.phaserRate = 0.12
        p.modMatrix = [A.mod(.lfo1, .pan, 0.35)]
    },
        A.make("Breathing Glass", .pad) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.44
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.26
        p.osc2Detune = 4
        p.attack = 0.28
        p.decay = 0.35
        p.sustain = 0.8
        p.release = 0.85
        p.filterCutoff = 1600
        p.filterResonance = 0.1
        p.lfo2Enabled = true
        p.lfo2Rate = 0.1
        p.lfo2Target = .none
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.46
        p.masterVolume = 0.34
        p.filter2Routing = .parallel
        p.filter2Type = .highPass
        p.filter2Cutoff = 420
        p.filter2Resonance = 0.12
        p.filter2Balance = 0.35
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.modMatrix = [A.mod(.lfo2, .amp, 0.16)]
    },
        A.make("Tidal Pad", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.42
        p.osc1WavetableMorph = 0.32
        p.osc1WavetableIndex = 3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.18
        p.osc2Detune = 6
        p.attack = 0.32
        p.decay = 0.4
        p.sustain = 0.82
        p.release = 0.9
        p.filterCutoff = 1300
        p.filterResonance = 0.12
        p.reverbMix = 0.14
        p.reverbRoomSize = 0.48
        p.chorusMix = 0.08
        p.masterVolume = 0.34
        p.modMatrix = [A.mod(.modWheel, .lfoDepth, 0.3)]
    },
        A.make("Phaser Rhodes", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.22
        p.osc2Detune = 3
        p.attack = 0.006
        p.decay = 0.4
        p.sustain = 0.4
        p.release = 0.35
        p.filterCutoff = 1900
        p.filterResonance = 0.12
        p.reverbMix = 0.1
        p.masterVolume = 0.46
        p.phaserEnabled = true
        p.phaserMode = .phaser4
        p.phaserMix = 0.22
        p.phaserRate = 0.3
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.12)]
        p.lfoEnabled = true
        p.lfoRate = 0.4
        p.lfoTarget = .none
    },
        A.make("Wurli Tremolo", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.osc2PulseWidth = 0.4
        p.attack = 0.005
        p.decay = 0.32
        p.sustain = 0.45
        p.release = 0.28
        p.filterCutoff = 1700
        p.filterResonance = 0.14
        p.lfoEnabled = true
        p.lfoRate = 4.2
        p.lfoTarget = .none
        p.reverbMix = 0.08
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.lfo1, .amp, 0.2)]
    },
        A.make("Velvet Clav", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1PulseWidth = 0.3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.14
        p.attack = 0.002
        p.decay = 0.14
        p.sustain = 0.2
        p.release = 0.1
        p.filterCutoff = 2600
        p.filterResonance = 0.2
        p.reverbMix = 0.06
        p.masterVolume = 0.48
        p.modMatrix = [A.mod(.velocity, .cutoff, 0.18)]
    },
        A.make("Pan Ping Pluck", .pluck) { p in
        p.osc1Waveform = .triangle
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.osc2Octave = 1
        p.attack = 0.003
        p.decay = 0.24
        p.sustain = 0.12
        p.release = 0.2
        p.filterCutoff = 2400
        p.filterResonance = 0.1
        p.lfoEnabled = true
        p.lfoRate = 0.5
        p.lfoTarget = .none
        p.delayMix = 0.06
        p.delayTime = 0.22
        p.delayFeedback = 0.14
        p.reverbMix = 0.08
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.lfo1, .pan, 0.4)]
    },
        A.make("Flange Harp", .pluck) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.5
        p.osc1WavetableMorph = 0.26
        p.osc1WavetableIndex = 1
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.18
        p.osc2Octave = 1
        p.attack = 0.004
        p.decay = 0.4
        p.sustain = 0.1
        p.release = 0.35
        p.filterCutoff = 3000
        p.filterResonance = 0.08
        p.reverbMix = 0.12
        p.masterVolume = 0.46
        p.modMatrix = [A.mod(.env1, .pitch1, 0.02)]
    },
        A.make("Bit Pluck Arp", .pluck) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1Octave = 1
        p.osc1PulseWidth = 0.25
        p.attack = 0.003
        p.decay = 0.12
        p.sustain = 0.2
        p.release = 0.1
        p.filterCutoff = 2600
        p.filterResonance = 0.16
        p.reverbMix = 0.06
        p.masterVolume = 0.46
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.modMatrix = [A.mod(.velocity, .amp, 0.15)]
    },
        A.make("Chamber Swell", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.38
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 6
        p.attack = 0.3
        p.decay = 0.35
        p.sustain = 0.82
        p.release = 0.7
        p.filterCutoff = 1500
        p.filterResonance = 0.1
        p.reverbMix = 0.14
        p.chorusMix = 0.1
        p.masterVolume = 0.32
        p.mseg = A.shape(rate: 0.2, -0.2, 0.8, 0.1)
        p.modMatrix = [A.mod(.mseg, .cutoff, 0.2)]
    },
        A.make("Phased Violins", .strings) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.4
        p.osc1Octave = 1
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.24
        p.osc2Detune = 5
        p.attack = 0.22
        p.decay = 0.3
        p.sustain = 0.8
        p.release = 0.55
        p.filterCutoff = 2000
        p.filterResonance = 0.1
        p.lfoEnabled = true
        p.lfoRate = 0.2
        p.lfoTarget = .none
        p.reverbMix = 0.14
        p.masterVolume = 0.32
        p.phaserEnabled = true
        p.phaserMode = .phaser6
        p.phaserMix = 0.18
        p.phaserRate = 0.15
        p.modMatrix = [A.mod(.lfo1, .cutoff, 0.12)]
    },
        A.make("Siren Drift", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.16
        p.attack = 0.05
        p.decay = 0.3
        p.sustain = 0.7
        p.release = 0.4
        p.filterCutoff = 1800
        p.filterResonance = 0.2
        p.reverbMix = 0.12
        p.masterVolume = 0.4
        p.mseg = A.shape(rate: 0.35, -0.6, 0.9, -0.2)
        p.modMatrix = [A.mod(.mseg, .pitch1, 0.06)]
    },
        A.make("Jet Flanger", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.44
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.2
        p.osc2Detune = 4
        p.attack = 0.02
        p.decay = 0.25
        p.sustain = 0.6
        p.release = 0.3
        p.filterCutoff = 1600
        p.filterResonance = 0.16
        p.reverbMix = 0.1
        p.masterVolume = 0.42
        p.phaserEnabled = true
        p.phaserMode = .flanger
        p.phaserMix = 0.26
        p.phaserRate = 0.18
        p.fxOrder = A.orderDelayFirst
        p.lfoEnabled = true
        p.lfoRate = 0.3
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .pitch2, 0.02)]
    },
        A.make("Random Bloom", .fx) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.44
        p.osc1Octave = 1
        p.osc1WavetableMorph = 0.2
        p.osc1WavetableIndex = 2
        p.attack = 0.08
        p.decay = 0.4
        p.sustain = 0.55
        p.release = 0.6
        p.filterCutoff = 2200
        p.filterResonance = 0.12
        p.reverbMix = 0.16
        p.masterVolume = 0.4
        p.lfo2Enabled = true
        p.lfo2Rate = 0.25
        p.lfo2Target = .none
        p.macro1 = 0.4
        p.modMatrix = [A.mod(.lfo2, .pan, 0.3), A.mod(.macro1, .cutoff, 0.2)]
    },
    ]
}
