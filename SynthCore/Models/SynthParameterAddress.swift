//
//  SynthParameterAddress.swift
//  SynthCore
//
//  Addresses are permanent. Append new cases. Never renumber or reuse a raw value.
//

import Foundation

public enum SynthParameterAddress: UInt64, CaseIterable, Sendable {
    case osc1Volume = 1
    case osc1Octave = 2
    case osc1Detune = 3
    case osc1PulseWidth = 4
    case osc1WavetableMorph = 5
    case osc1Waveform = 6
    case osc1WavetableIndex = 7
    case osc2Volume = 8
    case osc2Octave = 9
    case osc2Detune = 10
    case osc2PulseWidth = 11
    case osc2WavetableMorph = 12
    case osc2Waveform = 13
    case osc2Enabled = 14
    case subOscVolume = 15
    case fmAmount = 16
    case ringModAmount = 17
    case noiseColor = 18
    /// Appended. 19 was never published; do not renumber the cases above.
    case osc2WavetableIndex = 19

    case attack = 20
    case decay = 21
    case sustain = 22
    case release = 23
    case filterAttack = 24
    case filterDecay = 25
    case filterSustain = 26
    case filterRelease = 27

    case filterCutoff = 30
    case filterResonance = 31
    case filterType = 32
    case filterDrive = 33
    case filterEnvelopeAmount = 34
    case velocityToCutoff = 35
    case filterKeyTracking = 36

    case lfoEnabled = 40
    case lfoRate = 41
    case lfoDepth = 42
    case lfoWaveform = 43
    case lfoTarget = 44
    case lfo2Enabled = 45
    case lfo2Rate = 46
    case lfo2Depth = 47
    case lfo2Waveform = 48
    case lfo2Target = 49

    case reverbMix = 60
    case reverbRoomSize = 61
    case reverbShimmer = 62
    case chorusRate = 63
    case chorusDepth = 64
    case chorusMix = 65
    case delayTime = 66
    case delayFeedback = 67
    case delayMix = 68
    case distortionEnabled = 69
    case distortionDrive = 70
    case distortionTone = 71
    case distortionMix = 72
    case phaserEnabled = 73
    case phaserRate = 74
    case phaserDepth = 75
    case phaserMix = 76
    case phaserFeedback = 77
    case phaserCenterFrequency = 78
    case phaserSpread = 79
    case eqEnabled = 84
    case eqLowGain = 85
    case eqMidGain = 86
    case eqHighGain = 87
    case eqLowFreq = 88
    case eqMidFreq = 89
    case eqHighFreq = 90

    case unisonDetune = 100
    case unisonSpread = 101
    case analogDrift = 102
    case portamento = 103

    case macro1 = 110
    case macro2 = 111
    case macro3 = 112
    case macro4 = 113

    case pan = 120
    case lfoMode = 121
    case lfoStartPhase = 122
    case lfo2Mode = 123
    case lfo2StartPhase = 124
    case arpLatch = 125
    case velocityCurve = 126
    case velocityToVolume = 127
    case modEnvAttack = 128
    case modEnvDecay = 129
    case modEnvSustain = 130
    case modEnvRelease = 131
    case glideMode = 132
    case glideLegatoOnly = 133
    case monoPriority = 134

    /// Filter 2 group. Appended after monoPriority.
    case filter2Cutoff = 135
    case filter2Resonance = 136
    case filter2Type = 137
    case filter2Balance = 138
    case filter2Routing = 139
    case envFollowerAttack = 140
    case envFollowerRelease = 141
    /// Parallel send into the reverb bus. 0 leaves the insert chain bit-exact.
    case sendA = 142
    /// Parallel send into the delay bus.
    case sendB = 143
    /// Leslie rotor. Off leaves the insert chain bit-exact. Not an FX slot.
    case rotaryEnabled = 144
    /// 0 is slow, 1 is fast. The host automates this switch.
    case rotaryFast = 145
    case rotaryHornSlow = 146
    case rotaryHornFast = 147
    case rotaryDrumSlow = 148
    case rotaryDrumFast = 149
    case rotaryDrive = 150
    case rotaryMix = 151
    case rotaryAccel = 152
    /// Pre/post-insert switch for FX send buses (0 = Pre, 1 = Post).
    case sendPostInsert = 153
    case macro5 = 154
    case macro6 = 155
    case macro7 = 156
    case macro8 = 157
    case transientEnabled = 158
    case transientAttack = 159
    case transientSustain = 160
    case transientOutput = 161
    case transientMix = 162
    case mpeEnabled = 163
    case mpePitchBendRange = 164
    case mpeZone = 165
    case mpeMemberChannelCount = 166

    public var identifier: String {
        switch self {
        case .osc1Volume: return "osc1Volume"
        case .osc1Octave: return "osc1Octave"
        case .osc1Detune: return "osc1Detune"
        case .osc1PulseWidth: return "osc1PulseWidth"
        case .osc1WavetableMorph: return "osc1WavetableMorph"
        case .osc1Waveform: return "osc1Waveform"
        case .osc1WavetableIndex: return "osc1WavetableIndex"
        case .osc2Volume: return "osc2Volume"
        case .osc2Octave: return "osc2Octave"
        case .osc2Detune: return "osc2Detune"
        case .osc2PulseWidth: return "osc2PulseWidth"
        case .osc2WavetableMorph: return "osc2WavetableMorph"
        case .osc2Waveform: return "osc2Waveform"
        case .osc2Enabled: return "osc2Enabled"
        case .subOscVolume: return "subOscVolume"
        case .fmAmount: return "fmAmount"
        case .ringModAmount: return "ringModAmount"
        case .noiseColor: return "noiseColor"
        case .osc2WavetableIndex: return "osc2WavetableIndex"
        case .attack: return "attack"
        case .decay: return "decay"
        case .sustain: return "sustain"
        case .release: return "release"
        case .filterAttack: return "filterAttack"
        case .filterDecay: return "filterDecay"
        case .filterSustain: return "filterSustain"
        case .filterRelease: return "filterRelease"
        case .filterCutoff: return "filterCutoff"
        case .filterResonance: return "filterResonance"
        case .filterType: return "filterType"
        case .filterDrive: return "filterDrive"
        case .filterEnvelopeAmount: return "filterEnvelopeAmount"
        case .velocityToCutoff: return "velocityToCutoff"
        case .filterKeyTracking: return "filterKeyTracking"
        case .lfoEnabled: return "lfoEnabled"
        case .lfoRate: return "lfoRate"
        case .lfoDepth: return "lfoDepth"
        case .lfoWaveform: return "lfoWaveform"
        case .lfoTarget: return "lfoTarget"
        case .lfo2Enabled: return "lfo2Enabled"
        case .lfo2Rate: return "lfo2Rate"
        case .lfo2Depth: return "lfo2Depth"
        case .lfo2Waveform: return "lfo2Waveform"
        case .lfo2Target: return "lfo2Target"
        case .reverbMix: return "reverbMix"
        case .reverbRoomSize: return "reverbRoomSize"
        case .reverbShimmer: return "reverbShimmer"
        case .chorusRate: return "chorusRate"
        case .chorusDepth: return "chorusDepth"
        case .chorusMix: return "chorusMix"
        case .delayTime: return "delayTime"
        case .delayFeedback: return "delayFeedback"
        case .delayMix: return "delayMix"
        case .distortionEnabled: return "distortionEnabled"
        case .distortionDrive: return "distortionDrive"
        case .distortionTone: return "distortionTone"
        case .distortionMix: return "distortionMix"
        case .phaserEnabled: return "phaserEnabled"
        case .phaserRate: return "phaserRate"
        case .phaserDepth: return "phaserDepth"
        case .phaserMix: return "phaserMix"
        case .phaserFeedback: return "phaserFeedback"
        case .phaserCenterFrequency: return "phaserCenterFrequency"
        case .phaserSpread: return "phaserSpread"
        case .eqEnabled: return "eqEnabled"
        case .eqLowGain: return "eqLowGain"
        case .eqMidGain: return "eqMidGain"
        case .eqHighGain: return "eqHighGain"
        case .eqLowFreq: return "eqLowFreq"
        case .eqMidFreq: return "eqMidFreq"
        case .eqHighFreq: return "eqHighFreq"
        case .unisonDetune: return "unisonDetune"
        case .unisonSpread: return "unisonSpread"
        case .analogDrift: return "analogDrift"
        case .portamento: return "portamento"
        case .macro1: return "macro1"
        case .macro2: return "macro2"
        case .macro3: return "macro3"
        case .macro4: return "macro4"
        case .pan: return "pan"
        case .lfoMode: return "lfoMode"
        case .lfoStartPhase: return "lfoStartPhase"
        case .lfo2Mode: return "lfo2Mode"
        case .lfo2StartPhase: return "lfo2StartPhase"
        case .arpLatch: return "arpLatch"
        case .velocityCurve: return "velocityCurve"
        case .velocityToVolume: return "velocityToVolume"
        case .modEnvAttack: return "modEnvAttack"
        case .modEnvDecay: return "modEnvDecay"
        case .modEnvSustain: return "modEnvSustain"
        case .modEnvRelease: return "modEnvRelease"
        case .glideMode: return "glideMode"
        case .glideLegatoOnly: return "glideLegatoOnly"
        case .monoPriority: return "monoPriority"
        case .filter2Cutoff: return "filter2Cutoff"
        case .filter2Resonance: return "filter2Resonance"
        case .filter2Type: return "filter2Type"
        case .filter2Balance: return "filter2Balance"
        case .filter2Routing: return "filter2Routing"
        case .envFollowerAttack: return "envFollowerAttack"
        case .envFollowerRelease: return "envFollowerRelease"
        case .sendA: return "sendA"
        case .sendB: return "sendB"
        case .rotaryEnabled: return "rotaryEnabled"
        case .rotaryFast: return "rotaryFast"
        case .rotaryHornSlow: return "rotaryHornSlow"
        case .rotaryHornFast: return "rotaryHornFast"
        case .rotaryDrumSlow: return "rotaryDrumSlow"
        case .rotaryDrumFast: return "rotaryDrumFast"
        case .rotaryDrive: return "rotaryDrive"
        case .rotaryMix: return "rotaryMix"
        case .rotaryAccel: return "rotaryAccel"
        case .sendPostInsert: return "sendPostInsert"
        case .macro5: return "macro5"
        case .macro6: return "macro6"
        case .macro7: return "macro7"
        case .macro8: return "macro8"
        case .transientEnabled: return "transientEnabled"
        case .transientAttack: return "transientAttack"
        case .transientSustain: return "transientSustain"
        case .transientOutput: return "transientOutput"
        case .transientMix: return "transientMix"
        case .mpeEnabled: return "mpeEnabled"
        case .mpePitchBendRange: return "mpePitchBendRange"
        case .mpeZone: return "mpeZone"
        case .mpeMemberChannelCount: return "mpeMemberChannelCount"
        }
    }

    public var displayName: String {
        switch self {
        case .osc1Volume: return "Osc 1 Volume"
        case .osc1Octave: return "Osc 1 Octave"
        case .osc1Detune: return "Osc 1 Detune"
        case .osc1PulseWidth: return "Osc 1 Pulse Width"
        case .osc1WavetableMorph: return "Osc 1 Morph"
        case .osc1Waveform: return "Osc 1 Waveform"
        case .osc1WavetableIndex: return "Osc 1 Wavetable"
        case .osc2Volume: return "Osc 2 Volume"
        case .osc2Octave: return "Osc 2 Octave"
        case .osc2Detune: return "Osc 2 Detune"
        case .osc2PulseWidth: return "Osc 2 Pulse Width"
        case .osc2WavetableMorph: return "Osc 2 Morph"
        case .osc2Waveform: return "Osc 2 Waveform"
        case .osc2Enabled: return "Osc 2"
        case .subOscVolume: return "Sub"
        case .fmAmount: return "FM"
        case .ringModAmount: return "Ring"
        case .noiseColor: return "Noise Color"
        case .osc2WavetableIndex: return "Osc 2 Wavetable"
        case .attack: return "Attack"
        case .decay: return "Decay"
        case .sustain: return "Sustain"
        case .release: return "Release"
        case .filterAttack: return "Filter Attack"
        case .filterDecay: return "Filter Decay"
        case .filterSustain: return "Filter Sustain"
        case .filterRelease: return "Filter Release"
        case .filterCutoff: return "Cutoff"
        case .filterResonance: return "Resonance"
        case .filterType: return "Filter Type"
        case .filterDrive: return "Drive"
        case .filterEnvelopeAmount: return "Filter Env"
        case .velocityToCutoff: return "Velocity to Cutoff"
        case .filterKeyTracking: return "Key Track"
        case .lfoEnabled: return "LFO"
        case .lfoRate: return "LFO Rate"
        case .lfoDepth: return "LFO Depth"
        case .lfoWaveform: return "LFO Waveform"
        case .lfoTarget: return "LFO Target"
        case .lfo2Enabled: return "LFO 2"
        case .lfo2Rate: return "LFO 2 Rate"
        case .lfo2Depth: return "LFO 2 Depth"
        case .lfo2Waveform: return "LFO 2 Waveform"
        case .lfo2Target: return "LFO 2 Target"
        case .reverbMix: return "Reverb Mix"
        case .reverbRoomSize: return "Reverb Room"
        case .reverbShimmer: return "Reverb Shimmer"
        case .chorusRate: return "Chorus Rate"
        case .chorusDepth: return "Chorus Depth"
        case .chorusMix: return "Chorus Mix"
        case .delayTime: return "Delay Time"
        case .delayFeedback: return "Delay Feedback"
        case .delayMix: return "Delay Mix"
        case .distortionEnabled: return "Distortion"
        case .distortionDrive: return "Distortion Drive"
        case .distortionTone: return "Distortion Tone"
        case .distortionMix: return "Distortion Mix"
        case .phaserEnabled: return "Phaser"
        case .phaserRate: return "Phaser Rate"
        case .phaserDepth: return "Phaser Depth"
        case .phaserMix: return "Phaser Mix"
        case .phaserFeedback: return "Phaser Feedback"
        case .phaserCenterFrequency: return "Phaser Center"
        case .phaserSpread: return "Phaser Spread"
        case .eqEnabled: return "EQ"
        case .eqLowGain: return "EQ Low"
        case .eqMidGain: return "EQ Mid"
        case .eqHighGain: return "EQ High"
        case .eqLowFreq: return "EQ Low Freq"
        case .eqMidFreq: return "EQ Mid Freq"
        case .eqHighFreq: return "EQ High Freq"
        case .unisonDetune: return "Unison Detune"
        case .unisonSpread: return "Unison Spread"
        case .analogDrift: return "Drift"
        case .portamento: return "Glide"
        case .macro1: return "Macro 1"
        case .macro2: return "Macro 2"
        case .macro3: return "Macro 3"
        case .macro4: return "Macro 4"
        case .pan: return "Pan"
        case .lfoMode: return "LFO Mode"
        case .lfoStartPhase: return "LFO Phase"
        case .lfo2Mode: return "LFO 2 Mode"
        case .lfo2StartPhase: return "LFO 2 Phase"
        case .arpLatch: return "Arp Latch"
        case .velocityCurve: return "Velocity Curve"
        case .velocityToVolume: return "Velocity To Vol"
        case .modEnvAttack: return "Mod Env Attack"
        case .modEnvDecay: return "Mod Env Decay"
        case .modEnvSustain: return "Mod Env Sustain"
        case .modEnvRelease: return "Mod Env Release"
        case .glideMode: return "Glide Mode"
        case .glideLegatoOnly: return "Glide Legato Only"
        case .monoPriority: return "Mono Priority"
        case .filter2Cutoff: return "Filter 2 Cutoff"
        case .filter2Resonance: return "Filter 2 Resonance"
        case .filter2Type: return "Filter 2 Type"
        case .filter2Balance: return "Filter 2 Balance"
        case .filter2Routing: return "Filter 2 Routing"
        case .envFollowerAttack: return "Env Follower Attack"
        case .envFollowerRelease: return "Env Follower Release"
        case .sendA: return "Send A"
        case .sendB: return "Send B"
        case .rotaryEnabled: return "Rotary"
        case .rotaryFast: return "Rotary Speed"
        case .rotaryHornSlow: return "Horn Slow"
        case .rotaryHornFast: return "Horn Fast"
        case .rotaryDrumSlow: return "Drum Slow"
        case .rotaryDrumFast: return "Drum Fast"
        case .rotaryDrive: return "Rotary Drive"
        case .rotaryMix: return "Rotary Mix"
        case .rotaryAccel: return "Rotary Accel"
        case .sendPostInsert: return "Send Post-Insert"
        case .macro5: return "Macro 5"
        case .macro6: return "Macro 6"
        case .macro7: return "Macro 7"
        case .macro8: return "Macro 8"
        case .transientEnabled: return "Transient Shaper"
        case .transientAttack: return "Transient Attack"
        case .transientSustain: return "Transient Sustain"
        case .transientOutput: return "Transient Output"
        case .transientMix: return "Transient Mix"
        case .mpeEnabled: return "MPE Enabled"
        case .mpePitchBendRange: return "MPE Bend Range"
        case .mpeZone: return "MPE Zone"
        case .mpeMemberChannelCount: return "MPE Member Channels"
        }
    }

    public var min: Float {
        switch self {
        case .pan: return -1
        case .osc1Detune, .osc2Detune: return -50
        case .osc1Octave, .osc2Octave: return -2
        case .osc1PulseWidth, .osc2PulseWidth: return 0.05
        case .attack, .decay, .filterAttack, .filterDecay, .modEnvAttack, .modEnvDecay, .envFollowerAttack, .envFollowerRelease: return 0.001
        case .release, .filterRelease, .modEnvRelease: return 0.001
        case .filterCutoff, .filter2Cutoff: return 20
        case .filterEnvelopeAmount, .macro1, .macro2, .macro3, .macro4, .macro5, .macro6, .macro7, .macro8, .transientAttack, .transientSustain: return -1
        case .lfoRate, .lfo2Rate: return 0.1
        case .chorusRate: return 0.1
        case .delayTime: return 0.01
        case .phaserRate: return 0.05
        case .phaserFeedback: return -0.9
        case .phaserCenterFrequency: return 200
        case .eqLowGain, .eqMidGain, .eqHighGain: return -12
        case .eqLowFreq: return 40
        case .eqMidFreq: return 200
        case .eqHighFreq: return 2000
        case .rotaryHornSlow: return 0.2
        case .rotaryHornFast, .rotaryDrumFast: return 1
        case .rotaryDrumSlow: return 0.15
        case .rotaryAccel: return 0.2
        default: return 0
        }
    }

    public var max: Float {
        switch self {
        case .osc1Detune, .osc2Detune, .unisonDetune: return 50
        case .osc1Octave, .osc2Octave: return 2
        case .osc1PulseWidth, .osc2PulseWidth: return 0.95
        case .osc1Waveform, .osc2Waveform, .lfoWaveform, .lfo2Waveform, .osc1WavetableIndex, .osc2WavetableIndex: return 5
        case .noiseColor, .velocityCurve, .monoPriority, .transientOutput: return 2
        case .glideMode, .glideLegatoOnly: return 1
        case .lfoMode, .lfo2Mode: return 2
        case .lfoStartPhase, .lfo2StartPhase: return 360
        case .arpLatch: return 1
        case .filterType, .filter2Type: return 6
        case .lfoTarget, .lfo2Target: return 4
        case .filter2Routing: return 2
        case .attack, .decay, .filterAttack, .filterDecay, .modEnvAttack, .modEnvDecay, .envFollowerAttack, .envFollowerRelease: return 2
        case .release, .filterRelease, .modEnvRelease: return 3
        case .filterCutoff, .filter2Cutoff: return 20000
        case .filterEnvelopeAmount, .macro1, .macro2, .macro3, .macro4, .macro5, .macro6, .macro7, .macro8: return 1
        case .lfoRate, .lfo2Rate: return 20
        case .chorusRate: return 5
        case .delayTime: return 1
        case .delayFeedback: return 0.9
        case .phaserRate: return 5
        case .phaserFeedback: return 0.9
        case .phaserCenterFrequency: return 4000
        case .eqLowGain, .eqMidGain, .eqHighGain: return 12
        case .eqLowFreq: return 400
        case .eqMidFreq: return 5000
        case .eqHighFreq: return 16000
        case .rotaryHornSlow: return 3
        case .rotaryHornFast: return 12
        case .rotaryDrumSlow: return 2.5
        case .rotaryDrumFast: return 10
        case .rotaryAccel: return 20
        case .mpePitchBendRange: return 96
        case .mpeZone: return 1
        case .mpeMemberChannelCount: return 15
        default: return 1
        }
    }

    public func clamped(_ value: Float) -> Float {
        guard value.isFinite else { return min }
        return Swift.min(max, Swift.max(min, value))
    }
}
