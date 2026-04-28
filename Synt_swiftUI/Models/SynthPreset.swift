//
//  SynthPreset.swift
//  Synt_swiftUI
//

import Foundation

enum PresetCategory: String, CaseIterable, Codable {
    case bass = "Bass"
    case lead = "Lead"
    case pad = "Pad"
    case keys = "Keys"
    case pluck = "Pluck"
    case strings = "Strings"
    case fx = "FX"
}

struct SynthPreset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: PresetCategory = .lead

    // Oscillator 1
    var osc1Waveform: WaveformType = .sawtooth
    var osc1Volume: Float = 0.7
    var osc1Octave: Int = 0
    var osc1Detune: Float = 0.0
    var osc1PulseWidth: Float = 0.5

    // Oscillator 2
    var osc2Enabled: Bool = true
    var osc2Waveform: WaveformType = .square
    var osc2Volume: Float = 0.5
    var osc2Octave: Int = 0
    var osc2Detune: Float = 5.0
    var osc2PulseWidth: Float = 0.5

    // ADSR
    var attack: Float = 0.01
    var decay: Float = 0.1
    var sustain: Float = 0.7
    var release: Float = 0.3

    // Filter
    var filterType: FilterType = .lowPass
    var filterCutoff: Float = 5000.0
    var filterResonance: Float = 0.5
    var filterEnvelopeAmount: Float = 0.0

    // LFO
    var lfoEnabled: Bool = false
    var lfoRate: Float = 5.0
    var lfoDepth: Float = 0.5
    var lfoWaveform: WaveformType = .sine
    var lfoTarget: LFOTarget = .pitch

    // Effects
    var reverbMix: Float = 0.2
    var reverbRoomSize: Float = 0.5
    var chorusRate: Float = 1.5
    var chorusDepth: Float = 0.5
    var chorusMix: Float = 0.0
    var delayTime: Float = 0.3
    var delayFeedback: Float = 0.4
    var delayMix: Float = 0.0
    
    // Master
    var masterVolume: Float = 0.8
    var portamento: Float = 0.0 // Glide time in seconds
    
    // Unison
    var unisonVoices: Int = 1 // 1 = Off, up to 7
    var unisonDetune: Float = 0.0 // Cents
    var unisonSpread: Float = 0.0 // 0.0 to 1.0 (Stereo Spread)
    
    // Matrix
    var modMatrix: [ModMatrixEntry] = []
    
    // Arpeggiator / Sequencer
    var arpMode: ArpeggiatorMode = .off
    var arpRate: TimeDivision = .sixteenth
    var bpm: Float = 120.0
    var sequencerData: [SequencerStep] = Array(repeating: SequencerStep(), count: 16)

    static let defaultPreset = SynthPreset(name: "Init", category: .lead)

    // 50 lightweight factory presets.
    // CPU-saving rules: osc2Enabled=false where musically possible, LFO off by default,
    // unison voices=1, modMatrix empty, effects mix kept low/zero unless essential.
    static let factoryPresets: [SynthPreset] = [
        // ============ BASS (10) ============
        SynthPreset(
            name: "Sub Bass",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.9, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.005, decay: 0.1, sustain: 0.9, release: 0.2,
            filterCutoff: 400.0, filterResonance: 0.15
        ),
        SynthPreset(
            name: "Acid Bass",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.001, decay: 0.18, sustain: 0.35, release: 0.1,
            filterCutoff: 600.0, filterResonance: 0.85, filterEnvelopeAmount: 0.7,
            portamento: 0.05
        ),
        SynthPreset(
            name: "Funk Bass",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.8, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.001, decay: 0.2, sustain: 0.5, release: 0.15,
            filterCutoff: 1200.0, filterResonance: 0.5
        ),
        SynthPreset(
            name: "Wobble Bass",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.005, decay: 0.1, sustain: 0.85, release: 0.2,
            filterCutoff: 800.0, filterResonance: 0.7,
            lfoEnabled: true, lfoRate: 4.0, lfoDepth: 0.8, lfoTarget: .filter
        ),
        SynthPreset(
            name: "Deep House",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.01, decay: 0.2, sustain: 0.4, release: 0.2,
            filterCutoff: 500.0, filterResonance: 0.1
        ),
        SynthPreset(
            name: "Reese Bass",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.6, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.6, osc2Octave: -1, osc2Detune: 12.0,
            attack: 0.05, decay: 0.3, sustain: 0.85, release: 0.5,
            filterCutoff: 800.0, filterResonance: 0.3
        ),
        SynthPreset(
            name: "808 Bass",
            category: .bass,
            osc1Waveform: .sine, osc1Volume: 1.0, osc1Octave: -2,
            osc2Enabled: false,
            attack: 0.002, decay: 0.6, sustain: 0.0, release: 0.3,
            filterCutoff: 6000.0, filterResonance: 0.1
        ),
        SynthPreset(
            name: "Pluck Bass",
            category: .bass,
            osc1Waveform: .triangle, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.001, decay: 0.18, sustain: 0.0, release: 0.12,
            filterCutoff: 1800.0, filterResonance: 0.3, filterEnvelopeAmount: 0.4
        ),
        SynthPreset(
            name: "Rubber Bass",
            category: .bass,
            osc1Waveform: .square, osc1Volume: 0.8, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.001, decay: 0.12, sustain: 0.3, release: 0.15,
            filterCutoff: 900.0, filterResonance: 0.55, filterEnvelopeAmount: 0.5,
            portamento: 0.03
        ),
        SynthPreset(
            name: "Mono Saw Bass",
            category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.8, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.001, decay: 0.15, sustain: 0.6, release: 0.18,
            filterCutoff: 1500.0, filterResonance: 0.35
        ),

        // ============ LEAD (10) ============
        SynthPreset(
            name: "Classic Lead",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.8,
            osc2Enabled: false,
            attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.2,
            filterCutoff: 3500.0, filterResonance: 0.4,
            portamento: 0.02
        ),
        SynthPreset(
            name: "Bright Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.05, sustain: 0.9, release: 0.15,
            filterCutoff: 5000.0, filterResonance: 0.5
        ),
        SynthPreset(
            name: "Soft Lead",
            category: .lead,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.05, decay: 0.2, sustain: 0.7, release: 0.3,
            filterCutoff: 2500.0, filterResonance: 0.2,
            reverbMix: 0.2
        ),
        SynthPreset(
            name: "Trance Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.6,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.6, osc2Detune: 10.0,
            attack: 0.001, decay: 0.1, sustain: 0.7, release: 0.25,
            filterCutoff: 4000.0, filterResonance: 0.4,
            delayTime: 0.375, delayFeedback: 0.35, delayMix: 0.2
        ),
        SynthPreset(
            name: "Sync Lead",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.1,
            filterCutoff: 6000.0, filterResonance: 0.6
        ),
        SynthPreset(
            name: "80s Solo",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.03, decay: 0.2, sustain: 0.65, release: 0.3,
            filterCutoff: 3000.0, filterResonance: 0.2,
            delayTime: 0.3, delayFeedback: 0.3, delayMix: 0.25,
            portamento: 0.08
        ),
        SynthPreset(
            name: "Whistle Lead",
            category: .lead,
            osc1Waveform: .sine, osc1Volume: 0.85, osc1Octave: 1,
            osc2Enabled: false,
            attack: 0.02, decay: 0.1, sustain: 0.85, release: 0.25,
            filterCutoff: 8000.0, filterResonance: 0.1,
            reverbMix: 0.2
        ),
        SynthPreset(
            name: "Square Lead",
            category: .lead,
            osc1Waveform: .square, osc1Volume: 0.85, osc1PulseWidth: 0.35,
            osc2Enabled: false,
            attack: 0.005, decay: 0.1, sustain: 0.75, release: 0.18,
            filterCutoff: 4200.0, filterResonance: 0.3
        ),
        SynthPreset(
            name: "Retro Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.005, decay: 0.15, sustain: 0.7, release: 0.2,
            filterCutoff: 3200.0, filterResonance: 0.45,
            portamento: 0.05
        ),
        SynthPreset(
            name: "Mono Saw Lead",
            category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.002, decay: 0.08, sustain: 0.85, release: 0.15,
            filterCutoff: 4500.0, filterResonance: 0.35
        ),

        // ============ PAD (10) ============
        SynthPreset(
            name: "Warm Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.55,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Detune: 8.0,
            attack: 0.6, decay: 0.4, sustain: 0.8, release: 1.2,
            filterCutoff: 2000.0, filterResonance: 0.25,
            reverbMix: 0.4
        ),
        SynthPreset(
            name: "Dark Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 1.0, decay: 0.5, sustain: 0.7, release: 1.5,
            filterCutoff: 800.0, filterResonance: 0.4,
            reverbMix: 0.5, reverbRoomSize: 0.8
        ),
        SynthPreset(
            name: "Bright Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.4, decay: 0.3, sustain: 0.85, release: 1.0,
            filterCutoff: 6000.0, filterResonance: 0.15,
            reverbMix: 0.4
        ),
        SynthPreset(
            name: "Soft Pad",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.7, decay: 0.4, sustain: 0.8, release: 1.2,
            filterCutoff: 3000.0, filterResonance: 0.1,
            reverbMix: 0.4
        ),
        SynthPreset(
            name: "Glass Pad",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.5, decay: 1.5, sustain: 0.6, release: 1.6,
            filterCutoff: 4500.0, filterResonance: 0.1,
            reverbMix: 0.55
        ),
        SynthPreset(
            name: "Air Pad",
            category: .pad,
            osc1Waveform: .sine, osc1Volume: 0.85, osc1Octave: 1,
            osc2Enabled: false,
            attack: 1.2, decay: 0.5, sustain: 0.85, release: 1.6,
            filterCutoff: 6000.0, filterResonance: 0.05,
            reverbMix: 0.5
        ),
        SynthPreset(
            name: "Mystic Pad",
            category: .pad,
            osc1Waveform: .square, osc1Volume: 0.8, osc1PulseWidth: 0.4,
            osc2Enabled: false,
            attack: 1.0, decay: 0.6, sustain: 0.7, release: 1.8,
            filterCutoff: 1800.0, filterResonance: 0.4,
            reverbMix: 0.5
        ),
        SynthPreset(
            name: "String Pad",
            category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.55,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Detune: 10.0,
            attack: 0.7, decay: 0.3, sustain: 0.85, release: 1.0,
            filterCutoff: 3500.0, filterResonance: 0.2,
            reverbMix: 0.45
        ),
        SynthPreset(
            name: "Slow Pad",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 1.5, decay: 0.7, sustain: 0.8, release: 2.0,
            filterCutoff: 2500.0, filterResonance: 0.15,
            reverbMix: 0.5
        ),
        SynthPreset(
            name: "Drone Pad",
            category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 2.0, decay: 1.0, sustain: 1.0, release: 2.5,
            filterCutoff: 1000.0, filterResonance: 0.4,
            reverbMix: 0.6, reverbRoomSize: 0.85
        ),

        // ============ KEYS (8) ============
        SynthPreset(
            name: "Electric Piano",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.8, sustain: 0.3, release: 0.4,
            filterCutoff: 3000.0, filterResonance: 0.15,
            reverbMix: 0.2
        ),
        SynthPreset(
            name: "Organ",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.6,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.5, osc2Octave: 1,
            attack: 0.01, decay: 0.05, sustain: 0.95, release: 0.1,
            filterCutoff: 5000.0, filterResonance: 0.05,
            reverbMix: 0.25
        ),
        SynthPreset(
            name: "Clav",
            category: .keys,
            osc1Waveform: .square, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.25, sustain: 0.3, release: 0.15,
            filterCutoff: 2500.0, filterResonance: 0.6, filterEnvelopeAmount: 0.5
        ),
        SynthPreset(
            name: "Harpsichord",
            category: .keys,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.005, decay: 0.1, sustain: 0.65, release: 0.2,
            filterCutoff: 6000.0, filterResonance: 0.15
        ),
        SynthPreset(
            name: "Wurli",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.5, sustain: 0.45, release: 0.35,
            filterCutoff: 2200.0, filterResonance: 0.2,
            reverbMix: 0.2
        ),
        SynthPreset(
            name: "Bright Keys",
            category: .keys,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.4, sustain: 0.5, release: 0.3,
            filterCutoff: 5000.0, filterResonance: 0.1,
            reverbMix: 0.25
        ),
        SynthPreset(
            name: "Soft Piano",
            category: .keys,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.005, decay: 0.6, sustain: 0.35, release: 0.4,
            filterCutoff: 3500.0, filterResonance: 0.1,
            reverbMix: 0.25
        ),
        SynthPreset(
            name: "FM Bell Keys",
            category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 1.0, sustain: 0.0, release: 0.6,
            filterCutoff: 7000.0, filterResonance: 0.1,
            reverbMix: 0.4
        ),

        // ============ PLUCK (8) ============
        SynthPreset(
            name: "Pluck",
            category: .pluck,
            osc1Waveform: .triangle, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.35, sustain: 0.0, release: 0.3,
            filterCutoff: 5000.0, filterEnvelopeAmount: 0.7,
            delayTime: 0.25, delayFeedback: 0.35, delayMix: 0.2
        ),
        SynthPreset(
            name: "Bell",
            category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.85, osc1Octave: 1,
            osc2Enabled: false,
            attack: 0.001, decay: 1.4, sustain: 0.0, release: 0.9,
            filterCutoff: 8000.0, filterResonance: 0.1,
            reverbMix: 0.45
        ),
        SynthPreset(
            name: "Arp Synth",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.15, sustain: 0.4, release: 0.1,
            filterCutoff: 4000.0, filterResonance: 0.45, filterEnvelopeAmount: 0.4,
            delayTime: 0.166, delayFeedback: 0.4, delayMix: 0.25
        ),
        SynthPreset(
            name: "Koto",
            category: .pluck,
            osc1Waveform: .triangle, osc1Volume: 1.0,
            osc2Enabled: false,
            attack: 0.0, decay: 0.1, sustain: 0.0, release: 0.1,
            filterCutoff: 3000.0, filterResonance: 0.3
        ),
        SynthPreset(
            name: "Marimba",
            category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.95,
            osc2Enabled: false,
            attack: 0.001, decay: 0.3, sustain: 0.0, release: 0.2,
            filterCutoff: 4500.0, filterResonance: 0.1,
            reverbMix: 0.2
        ),
        SynthPreset(
            name: "Crystal Pluck",
            category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.85, osc1Octave: 1,
            osc2Enabled: false,
            attack: 0.0, decay: 0.5, sustain: 0.0, release: 0.4,
            filterCutoff: 7000.0, filterResonance: 0.15,
            reverbMix: 0.4
        ),
        SynthPreset(
            name: "Pulse Pluck",
            category: .pluck,
            osc1Waveform: .square, osc1Volume: 0.85, osc1PulseWidth: 0.3,
            osc2Enabled: false,
            attack: 0.001, decay: 0.2, sustain: 0.0, release: 0.15,
            filterCutoff: 3500.0, filterResonance: 0.4, filterEnvelopeAmount: 0.5,
            delayTime: 0.25, delayFeedback: 0.3, delayMix: 0.2
        ),
        SynthPreset(
            name: "Saw Stab",
            category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.001, decay: 0.18, sustain: 0.0, release: 0.12,
            filterCutoff: 3000.0, filterResonance: 0.3, filterEnvelopeAmount: 0.45
        ),

        // ============ STRINGS (4) ============
        SynthPreset(
            name: "Strings",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.55,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Detune: 10.0,
            attack: 0.6, decay: 0.3, sustain: 0.85, release: 0.9,
            filterCutoff: 3500.0, filterResonance: 0.2,
            reverbMix: 0.4
        ),
        SynthPreset(
            name: "Synth Strings",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.85, osc1Octave: 1,
            osc2Enabled: false,
            attack: 0.4, decay: 0.1, sustain: 0.9, release: 1.0,
            filterCutoff: 5000.0, filterResonance: 0.1,
            reverbMix: 0.35
        ),
        SynthPreset(
            name: "Cello",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.85, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.25, decay: 0.2, sustain: 0.85, release: 0.6,
            filterCutoff: 1800.0, filterResonance: 0.25,
            reverbMix: 0.3
        ),
        SynthPreset(
            name: "Violin",
            category: .strings,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.2, decay: 0.15, sustain: 0.85, release: 0.5,
            filterCutoff: 4500.0, filterResonance: 0.2,
            reverbMix: 0.35
        ),

        // ============ FX (4) ============
        SynthPreset(
            name: "SFX Riser",
            category: .fx,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 2.0, decay: 0.1, sustain: 0.9, release: 0.5,
            filterCutoff: 1000.0, filterResonance: 0.6,
            lfoEnabled: true, lfoRate: 0.2, lfoDepth: 0.9, lfoWaveform: .sawtooth, lfoTarget: .filter,
            reverbMix: 0.5
        ),
        SynthPreset(
            name: "Laser",
            category: .fx,
            osc1Waveform: .sawtooth, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.0, decay: 0.2, sustain: 0.0, release: 0.1,
            filterCutoff: 8000.0, filterResonance: 0.8,
            filterEnvelopeAmount: -0.8
        ),
        SynthPreset(
            name: "Noise Sweep",
            category: .fx,
            osc1Waveform: .noise, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 1.5, decay: 1.5, sustain: 0.0, release: 1.5,
            filterCutoff: 200.0, filterResonance: 0.6,
            filterEnvelopeAmount: 1.0,
            reverbMix: 0.5
        ),
        SynthPreset(
            name: "Zap",
            category: .fx,
            osc1Waveform: .square, osc1Volume: 0.85,
            osc2Enabled: false,
            attack: 0.0, decay: 0.12, sustain: 0.0, release: 0.08,
            filterCutoff: 6000.0, filterResonance: 0.5,
            filterEnvelopeAmount: -0.6,
            portamento: 0.04
        )
    ]
}

enum FilterType: String, CaseIterable, Codable {
    case lowPass = "Low Pass"
    case highPass = "High Pass"
    case bandPass = "Band Pass"
}

enum LFOTarget: String, CaseIterable, Codable {
    case pitch = "Pitch"
    case filter = "Filter"
    case amplitude = "Amplitude"
    case pan = "Pan"
}

// Modulation Matrix
struct ModMatrixEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var source: ModSource
    var destination: ModDestination
    var amount: Float // -1.0 to 1.0
}

enum ModSource: String, CaseIterable, Codable {
    case lfo1 = "LFO 1"
    case env1 = "Env 1 (Amp)"
    case velocity = "Velocity"
    // Future: LFO 2, Env 2, Wheel, KeyTrack
}

enum ModDestination: String, CaseIterable, Codable {
    case pitch1 = "Pitch OSC1"
    case pitch2 = "Pitch OSC2"
    case cutoff = "Filter Cutoff"
    case resonance = "Resonance"
    case amp = "Amplitude"
    case pan = "Pan"
    case pwm1 = "PWM OSC1"
    case pwm2 = "PWM OSC2"
    case lfoRate = "LFO Rate"
    case lfoDepth = "LFO Depth"
    case mix = "Osc Mix"
}
