//
//  FactoryPresets+Expansion.swift
//  Synt_swiftUI
//
//  Sound Expansion Pack: second browser bank (50), not part of `factoryPresets`.
//
//  Same SYNT_30 authoring policy as FactoryPresets.swift. This pack is the
//  wavetable / FM / formant / MSEG / FX-order heavy bank:
//  - Wavetable sets (Basic, Analog, Digital, PWM, Formant) including dual WT
//  - FM, hard sync, sub, dedicated filter ADSR / Env 2, dual filter, vowel mod
//  - MSEG 1 and MSEG 2, macros into the matrix
//  - Non-default FX order, rotary, frequency shifter, transient, trance gate
//  - Sequencer Pro (tie, ratchet, probability) and tempo-synced arp
//  - masterVolume ≤ 0.75, sends at the factory caps unless the patch is FX
//  - Init is not in this list
//

import Foundation

public extension SynthPreset {
    private typealias A = FactoryAuthoring

    static let expansionPresets: [SynthPreset] = [
        A.make("Choir of Angels", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.48
        p.osc1WavetableMorph = 0.32
        p.osc1WavetableIndex = 4
        p.osc2Enabled = true
        p.osc2Waveform = .wavetable
        p.osc2Volume = 0.26
        p.osc2Detune = 5
        p.osc2WavetableMorph = 0.58
        p.osc2WavetableIndex = 4
        p.attack = 0.28
        p.sustain = 0.84
        p.release = 0.9
        p.filterCutoff = 1680
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.25
        p.character = .warm
        p.osc1Detune = 0.00
    },
        A.make("Cybernetic Talking Bass", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.56
        p.osc1Octave = -1
        p.fmAmount = 0.18
        p.filterEnvUseDedicatedADSR = true
        p.filterDecay = 0.18
        p.filterSustain = 0.35
        p.filterCutoff = 480
        p.filterResonance = 0.28
        p.masterVolume = 0.5
        p.modMatrix = [A.mod(.env2, .cutoff, 0.35)]
        p.osc1Detune = 0.15
    },
        A.make("Robotic Vowel Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.62
        p.attack = 0.01
        p.filterType = .formant
        p.filterVowel = 1.1
        p.filterCutoff = 2200
        p.filterResonance = 0.08
        p.lfoEnabled = true
        p.lfoRate = 0.22
        p.lfoTarget = .none
        p.masterVolume = 0.5
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 2400
        p.filter2Balance = 0.58
        p.modMatrix = [A.mod(.lfo1, .vowel, 0.2)]
        p.osc1Detune = 0.30
    },
        A.make("Throat Singing Drone", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.attack = 0.3
        p.sustain = 0.86
        p.release = 1.0
        p.filterType = .formant
        p.filterVowel = 3.2
        p.filterCutoff = 1400
        p.masterVolume = 0.34
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 900
        p.filter2Balance = 0.55
        p.mseg2 = A.shape(rate: 0.18, -0.4, 0.55, -0.1)
        p.modMatrix = [A.mod(.mseg2, .cutoff, 0.16)]
        p.osc1Detune = 0.45
    },
        A.make("Glass Soprano", .lead) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.55
        p.osc1WavetableMorph = 0.62
        p.osc1WavetableIndex = 4
        p.fmAmount = 0.12
        p.filterCutoff = 2800
        p.masterVolume = 0.48
        p.osc1Detune = 0.60
    },
        A.make("Alien Transmission", .fx) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .noise
        p.osc2Volume = 0.16
        p.noiseColor = .pink
        p.filterType = .bandPass
        p.filterCutoff = 1400
        p.filterResonance = 0.3
        p.masterVolume = 0.4
        p.frequencyShifterEnabled = true
        p.frequencyShifterShiftHz = 22
        p.frequencyShifterMix = 0.28
        p.frequencyShifterFeedback = 0.08
        p.fxOrder = A.orderDirtLast
        p.osc1Detune = 0.75
    },
        A.make("Synth Choir Pad", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.46
        p.osc1WavetableMorph = 0.4
        p.osc1WavetableIndex = 4
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.22
        p.osc2Detune = 6
        p.attack = 0.26
        p.sustain = 0.84
        p.filterType = .formant
        p.filterVowel = 0.6
        p.masterVolume = 0.34
        p.filter2Routing = .parallel
        p.filter2Type = .lowPass
        p.filter2Cutoff = 1800
        p.filter2Balance = 0.6
        p.modMatrix = [A.mod(.lfo2, .vowel, 0.12)]
        p.lfo2Enabled = true
        p.lfo2Rate = 0.1
        p.lfo2Target = .none
        p.filterCutoff = 1140
        p.osc1Detune = 0.90
    },
        A.make("Vocoder RiffSeq", .arp) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.5
        p.osc1PulseWidth = 0.35
        p.filterCutoff = 1600
        p.masterVolume = 0.46
        p.arpMode = .up
        p.arpRate = .eighth
        p.sequencerData = A.proSequence()
        p.osc1Detune = 1.05
    },
        A.make("DX Crystal EPiano", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.58
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.3
        p.osc2Octave = 1
        p.fmAmount = 0.32
        p.attack = 0.004
        p.decay = 0.45
        p.sustain = 0.35
        p.filterCutoff = 3200
        p.masterVolume = 0.46
        p.osc1Detune = 1.20
    },
        A.make("Tokyo Marimba", .pluck) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.6
        p.fmAmount = 0.22
        p.attack = 0.002
        p.decay = 0.28
        p.sustain = 0.0
        p.release = 0.2
        p.filterCutoff = 3600
        p.masterVolume = 0.48
        p.osc1Detune = 1.35
    },
        A.make("Ice Temple Bell", .keys) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.52
        p.osc1WavetableMorph = 0.4
        p.osc1WavetableIndex = 2
        p.fmAmount = 0.16
        p.attack = 0.006
        p.decay = 0.7
        p.sustain = 0.25
        p.filterCutoff = 4000
        p.masterVolume = 0.44
        p.osc1Detune = 1.50
    },
        A.make("Tubular Cathedral", .keys) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.48
        p.osc1WavetableMorph = 0.22
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .wavetable
        p.osc2Volume = 0.24
        p.osc2WavetableMorph = 0.48
        p.osc2WavetableIndex = 2
        p.osc2Detune = 4
        p.attack = 0.01
        p.decay = 0.8
        p.sustain = 0.3
        p.reverbMix = 0.16
        p.filterCutoff = 2800
        p.masterVolume = 0.42
        p.osc1Detune = 1.65
    },
        A.make("Kalimba Dream", .pluck) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.55
        p.osc1WavetableMorph = 0.18
        p.osc1WavetableIndex = 1
        p.attack = 0.002
        p.decay = 0.32
        p.sustain = 0.1
        p.filterCutoff = 3000
        p.masterVolume = 0.48
        p.osc1Detune = 1.80
    },
        A.make("Metallic Bass Pluck", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.fmAmount = 0.14
        p.attack = 0.002
        p.decay = 0.22
        p.sustain = 0.2
        p.filterCutoff = 900
        p.masterVolume = 0.5
        p.transientEnabled = true
        p.transientAttack = 0.45
        p.transientSustain = -0.15
        p.transientMix = 0.7
        p.osc1Detune = 1.95
    },
        A.make("Music Box Memory", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .wavetable
        p.osc2Volume = 0.22
        p.osc2WavetableIndex = 1
        p.osc2WavetableMorph = 0.3
        p.attack = 0.004
        p.decay = 0.4
        p.sustain = 0.2
        p.filterCutoff = 3400
        p.masterVolume = 0.44
        p.osc1Detune = 2.10
    },
        A.make("Gamelan Gong", .fx) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.5
        p.osc1WavetableMorph = 0.5
        p.osc1WavetableIndex = 3
        p.ringModAmount = 0.16
        p.attack = 0.01
        p.decay = 0.9
        p.sustain = 0.4
        p.filterCutoff = 1800
        p.masterVolume = 0.4
        p.osc1Detune = 2.25
    },
        A.make("Digital Harp", .arp) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.52
        p.osc1WavetableMorph = 0.28
        p.osc1WavetableIndex = 2
        p.attack = 0.004
        p.decay = 0.3
        p.sustain = 0.2
        p.filterCutoff = 2600
        p.masterVolume = 0.46
        p.arpMode = .upDown
        p.arpRate = .eighth
        p.osc1Detune = 2.40
    },
        A.make("Neon Vibraphone", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.24
        p.osc2Octave = 1
        p.fmAmount = 0.26
        p.attack = 0.004
        p.decay = 0.5
        p.sustain = 0.3
        p.filterCutoff = 3000
        p.masterVolume = 0.46
        p.osc1Detune = 2.55
    },
        A.make("TB-303 Acid Squelch", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.55
        p.osc1Octave = -1
        p.filterEnvUseDedicatedADSR = true
        p.filterAttack = 0.004
        p.filterDecay = 0.16
        p.filterSustain = 0.15
        p.filterCutoff = 380
        p.filterResonance = 0.42
        p.masterVolume = 0.5
        p.modMatrix = [A.mod(.env2, .cutoff, 0.55)]
        p.osc1Detune = 2.70
    },
        A.make("Hard Sync Screamer", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.55
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.3
        p.oscSyncEnabled = true
        p.filterCutoff = 2200
        p.filterResonance = 0.22
        p.masterVolume = 0.48
        p.modMatrix = [A.mod(.lfo1, .pitch2, 0.04)]
        p.lfoEnabled = true
        p.lfoRate = 0.3
        p.lfoTarget = .none
        p.osc1Detune = 2.85
    },
        A.make("Moog Sub Phatty", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.subOscVolume = 0.34
        p.filterCutoff = 520
        p.filterResonance = 0.18
        p.masterVolume = 0.52
        p.osc1Detune = 3.00
    },
        A.make("Prophet Brass Swell", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.28
        p.osc2Detune = 6
        p.unisonVoices = 2
        p.unisonDetune = 6
        p.unisonSpread = 0.22
        p.attack = 0.06
        p.filterEnvUseDedicatedADSR = true
        p.filterDecay = 0.3
        p.filterSustain = 0.5
        p.filterCutoff = 1400
        p.masterVolume = 0.44
        p.modMatrix = [A.mod(.env2, .cutoff, 0.22)]
        p.osc1Detune = 3.15
    },
        A.make("Cyberpunk Sync Bass", .bass) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.26
        p.oscSyncEnabled = true
        p.filterCutoff = 700
        p.masterVolume = 0.5
        p.osc1Detune = 3.30
    },
        A.make("Classic Funk Clavinet", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1PulseWidth = 0.22
        p.attack = 0.002
        p.decay = 0.16
        p.sustain = 0.25
        p.filterCutoff = 2400
        p.filterResonance = 0.2
        p.masterVolume = 0.48
        p.osc1Detune = 3.45
    },
        A.make("Oberheim PolyJump", .brass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.24
        p.osc2PulseWidth = 0.4
        p.unisonVoices = 2
        p.unisonDetune = 5
        p.unisonSpread = 0.2
        p.attack = 0.02
        p.filterCutoff = 1600
        p.masterVolume = 0.44
        p.osc1Detune = 3.60
    },
        A.make("Subquake 808 Pro", .bass) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.62
        p.osc1Octave = -2
        p.attack = 0.004
        p.decay = 0.35
        p.sustain = 0.4
        p.filterCutoff = 240
        p.masterVolume = 0.5
        p.transientEnabled = true
        p.transientAttack = 0.4
        p.transientSustain = -0.1
        p.transientMix = 0.55
        p.noiseColor = .brown
        p.osc1Detune = 3.75
    },
        A.make("Retro Synthwave Arp", .arp) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.filterCutoff = 1800
        p.masterVolume = 0.46
        p.arpMode = .up
        p.arpRate = .eighth
        p.chorusMix = 0.1
        p.osc1Detune = 3.90
    },
        A.make("Laser Zap FX", .fx) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.48
        p.osc1Octave = 1
        p.filterCutoff = 4200
        p.filterResonance = 0.2
        p.masterVolume = 0.42
        p.frequencyShifterEnabled = true
        p.frequencyShifterShiftHz = 36
        p.frequencyShifterMix = 0.24
        p.frequencyShifterFeedback = 0.06
        p.fxOrder = A.orderDelayFirst
        p.osc1Detune = 4.05
    },
        A.make("Interstellar Horizon", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.44
        p.osc1WavetableMorph = 0.38
        p.osc1WavetableIndex = 2
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.osc2Detune = 4
        p.attack = 0.32
        p.sustain = 0.86
        p.release = 1.1
        p.filterCutoff = 1400
        p.masterVolume = 0.34
        p.stereoEnabled = true
        p.stereoWidth = 1.3
        p.mseg = A.shape(rate: 0.12, -0.3, 0.7, 0.05)
        p.modMatrix = [A.mod(.mseg, .cutoff, 0.18)]
        p.osc1Detune = 4.20
    },
        A.make("Solar Wind Sweep", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.46
        p.osc1WavetableMorph = 0.25
        p.osc1WavetableIndex = 3
        p.attack = 0.3
        p.sustain = 0.84
        p.filterCutoff = 1500
        p.masterVolume = 0.34
        p.lfoEnabled = true
        p.lfoRate = 0.08
        p.lfoTarget = .none
        p.modMatrix = [A.mod(.lfo1, .wtMorph1, 0.2)]
        p.osc1Detune = 4.35
    },
        A.make("Aurora Borealis", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.42
        p.osc1WavetableMorph = 0.3
        p.osc1WavetableIndex = 1
        p.osc2Enabled = true
        p.osc2Waveform = .wavetable
        p.osc2Volume = 0.24
        p.osc2WavetableMorph = 0.55
        p.osc2WavetableIndex = 2
        p.osc2Detune = 7
        p.attack = 0.34
        p.sustain = 0.86
        p.filterCutoff = 1600
        p.masterVolume = 0.33
        p.reverbMix = 0.14
        p.osc1Detune = 4.50
    },
        A.make("Deep Oceanwhale", .pad) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.5
        p.osc1Octave = -1
        p.noiseColor = .brown
        p.attack = 0.36
        p.sustain = 0.88
        p.filterCutoff = 700
        p.masterVolume = 0.32
        p.mseg2 = A.shape(rate: 0.08, 0.1, -0.45, 0.2)
        p.modMatrix = [A.mod(.mseg2, .pitch1, 0.04)]
        p.osc1Detune = 4.65
    },
        A.make("VHS Tape Nostalgia", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.46
        p.osc1WavetableMorph = 0.2
        p.osc1WavetableIndex = 1
        p.attack = 0.22
        p.sustain = 0.82
        p.filterCutoff = 1300
        p.masterVolume = 0.34
        p.character = .warm
        p.noiseColor = .pink
        p.osc1Detune = 4.80
    },
        A.make("Floating Cathedral", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.44
        p.osc1WavetableMorph = 0.36
        p.osc1WavetableIndex = 2
        p.attack = 0.35
        p.sustain = 0.86
        p.release = 1.2
        p.reverbMix = 0.18
        p.reverbRoomSize = 0.5
        p.filterCutoff = 1700
        p.masterVolume = 0.32
        p.osc1Detune = 4.95
    },
        A.make("PWM String Ensemble", .strings) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.46
        p.osc1WavetableMorph = 0.45
        p.osc1WavetableIndex = 3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.2
        p.osc2Detune = 6
        p.unisonVoices = 2
        p.unisonDetune = 5
        p.unisonSpread = 0.2
        p.attack = 0.24
        p.sustain = 0.86
        p.filterCutoff = 1900
        p.masterVolume = 0.34
        p.chorusMix = 0.08
        p.osc1Detune = 5.10
    },
        A.make("Dark Dystopia Drone", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.44
        p.osc1Octave = -1
        p.attack = 0.3
        p.sustain = 0.88
        p.filterCutoff = 800
        p.masterVolume = 0.32
        p.character = .warm
        p.mseg = A.shape(rate: 0.1, -0.5, 0.4, -0.2)
        p.modMatrix = [A.mod(.mseg, .cutoff, 0.2)]
        p.osc1Detune = 5.25
    },
        A.make("Starlight Pluck Pad", .pad) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.5
        p.osc1WavetableMorph = 0.33
        p.osc1WavetableIndex = 2
        p.attack = 0.08
        p.decay = 0.4
        p.sustain = 0.7
        p.filterCutoff = 2400
        p.masterVolume = 0.36
        p.osc1Detune = 5.40
    },
        A.make("Celestial Harmonics", .pad) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.48
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.22
        p.osc2Octave = 1
        p.osc2Detune = 3
        p.attack = 0.26
        p.sustain = 0.84
        p.filterCutoff = 2100
        p.masterVolume = 0.34
        p.macro1 = 0.3
        p.modMatrix = [A.mod(.macro1, .cutoff, 0.2)]
        p.osc1Detune = 5.55
    },
        A.make("Analog Warmth Bed", .pad) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.42
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.24
        p.osc2Detune = 7
        p.attack = 0.28
        p.sustain = 0.86
        p.filterCutoff = 1100
        p.masterVolume = 0.33
        p.character = .warm
        p.stereoEnabled = true
        p.stereoWidth = 1.2
        p.analogDrift = 0.25
        p.osc1Detune = 5.70
    },
        A.make("Time Warp Riser", .fx) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.5
        p.osc1WavetableMorph = 0.7
        p.osc1WavetableIndex = 2
        p.attack = 0.2
        p.filterCutoff = 2000
        p.masterVolume = 0.4
        p.fxOrder = A.orderVerbEarly
        p.mseg = A.shape(rate: 0.25, -0.8, 0.2, 0.9)
        p.modMatrix = [A.mod(.mseg, .pitch1, 0.1)]
        p.osc1Detune = 5.85
    },
        A.make("Future Bass SuperChord", .keys) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.46
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.22
        p.osc2Detune = 8
        p.unisonVoices = 2
        p.unisonDetune = 7
        p.unisonSpread = 0.25
        p.attack = 0.02
        p.filterCutoff = 1800
        p.masterVolume = 0.42
        p.osc1Detune = 6.00
    },
        A.make("Pluck in the Rain", .pluck) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.54
        p.osc1WavetableMorph = 0.22
        p.osc1WavetableIndex = 1
        p.attack = 0.002
        p.decay = 0.24
        p.sustain = 0.15
        p.delayMix = 0.1
        p.delayTime = 0.22
        p.delayFeedback = 0.16
        p.filterCutoff = 2600
        p.masterVolume = 0.46
        p.osc1Detune = 6.15
    },
        A.make("Lo-Fi Chill Keys", .keys) { p in
        p.osc1Waveform = .wavetable
        p.osc1Volume = 0.5
        p.osc1WavetableMorph = 0.3
        p.osc1WavetableIndex = 1
        p.attack = 0.01
        p.decay = 0.4
        p.sustain = 0.6
        p.filterCutoff = 1500
        p.masterVolume = 0.44
        p.character = .warm
        p.noiseColor = .pink
        p.osc1Detune = 6.30
    },
        A.make("Techno Rumble Sequence", .bass) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.osc1Octave = -1
        p.filterCutoff = 600
        p.filterResonance = 0.24
        p.masterVolume = 0.48
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.sequencerData = A.proSequence()
        p.osc1Detune = 6.45
    },
        A.make("Hyperpop Lead", .lead) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.52
        p.osc1PulseWidth = 0.3
        p.osc2Enabled = true
        p.osc2Waveform = .sawtooth
        p.osc2Volume = 0.22
        p.oscSyncEnabled = true
        p.filterCutoff = 3200
        p.masterVolume = 0.48
        p.osc1Detune = 6.60
    },
        A.make("Deep House Organ Chord", .keys) { p in
        p.osc1Waveform = .square
        p.osc1Volume = 0.42
        p.osc1PulseWidth = 0.45
        p.osc2Enabled = true
        p.osc2Waveform = .sine
        p.osc2Volume = 0.2
        p.attack = 0.01
        p.filterCutoff = 2000
        p.masterVolume = 0.42
        p.rotaryEnabled = true
        p.rotaryMix = 0.72
        p.rotaryDrive = 0.12
        p.osc1Detune = 6.75
    },
        A.make("Trance Gate Runner", .arp) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.5
        p.osc2Enabled = true
        p.osc2Waveform = .square
        p.osc2Volume = 0.2
        p.filterCutoff = 2000
        p.masterVolume = 0.46
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.tranceGateEnabled = true
        p.tranceGatePattern = 0xAAAA
        p.tranceGateDepth = 0.72
        p.tranceGateSmooth = 0.15
        p.tranceGateDivision = .sixteenth
        p.osc1Detune = 6.90
    },
        A.make("Crystal Pluck Bell", .pluck) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.58
        p.fmAmount = 0.16
        p.attack = 0.002
        p.decay = 0.35
        p.sustain = 0.05
        p.filterCutoff = 3800
        p.masterVolume = 0.46
        p.osc1Detune = 7.05
    },
        A.make("Warm Vinyl Rhodes", .keys) { p in
        p.osc1Waveform = .sine
        p.osc1Volume = 0.52
        p.osc2Enabled = true
        p.osc2Waveform = .triangle
        p.osc2Volume = 0.2
        p.osc2Detune = 4
        p.attack = 0.008
        p.decay = 0.35
        p.sustain = 0.55
        p.filterCutoff = 1700
        p.masterVolume = 0.44
        p.character = .warm
        p.osc1Detune = 7.20
    },
        A.make("Galactic Funk Lead", .lead) { p in
        p.osc1Waveform = .sawtooth
        p.osc1Volume = 0.52
        p.filterCutoff = 1900
        p.filterResonance = 0.18
        p.masterVolume = 0.48
        p.macro2 = 0.35
        p.modMatrix = [A.mod(.macro2, .cutoff, 0.24)]
        p.osc1Detune = 7.35
    }
    ]
}
