//
//  SynthPreset.swift
//  Synt_swiftUI
//
//  Preset model + categories. Factory library lives in FactoryPresets.swift.
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
    /// Wavetable morph 0…1 (only meaningful when waveform == .wavetable)
    var osc1WavetableMorph: Float = 0.0

    // Oscillator 2
    var osc2Enabled: Bool = true
    var osc2Waveform: WaveformType = .square
    var osc2Volume: Float = 0.5
    var osc2Octave: Int = 0
    var osc2Detune: Float = 5.0
    var osc2PulseWidth: Float = 0.5
    var osc2WavetableMorph: Float = 0.0

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

    // Mix FX
    var reverbMix: Float = 0.2
    var reverbRoomSize: Float = 0.5
    var chorusRate: Float = 1.5
    var chorusDepth: Float = 0.5
    var chorusMix: Float = 0.0
    var delayTime: Float = 0.3
    var delayFeedback: Float = 0.4
    var delayMix: Float = 0.0

    // Master
    var masterVolume: Float = 0.55
    var portamento: Float = 0.0

    // Unison
    var unisonVoices: Int = 1
    var unisonDetune: Float = 0.0
    var unisonSpread: Float = 0.0

    // Matrix
    var modMatrix: [ModMatrixEntry] = []

    // Arpeggiator / Sequencer
    var arpMode: ArpeggiatorMode = .off
    var arpRate: TimeDivision = .sixteenth
    var bpm: Float = 120.0
    var sequencerData: [SequencerStep] = Array(repeating: SequencerStep(), count: 16)

    // MARK: - Advanced FX (Stage 4) — default OFF / neutral for clean Init

    var distortionEnabled: Bool = false
    var distortionType: DistortionType = .softClip
    var distortionDrive: Float = 0.35
    var distortionTone: Float = 0.5
    var distortionMix: Float = 0.25

    var eqEnabled: Bool = false
    var eqPreset: EQPreset = .flat
    var eqLowGain: Float = 0
    var eqLowFreq: Float = 100
    var eqMidGain: Float = 0
    var eqMidFreq: Float = 1000
    var eqMidQ: Float = 1.0
    var eqHighGain: Float = 0
    var eqHighFreq: Float = 8000

    var phaserEnabled: Bool = false
    var phaserMode: PhaserMode = .phaser4
    var phaserRate: Float = 0.4
    var phaserDepth: Float = 0.55
    var phaserFeedback: Float = 0.25
    var phaserCenterFrequency: Float = 800
    var phaserStereoSpread: Float = 0.5
    var phaserMix: Float = 0.4

    /// Safe neutral starting point (clean headroom).
    static let defaultPreset = SynthPreset(name: "Init", category: .lead)

    // MARK: - Codable (new fields optional for older user JSON)

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case osc1Waveform, osc1Volume, osc1Octave, osc1Detune, osc1PulseWidth, osc1WavetableMorph
        case osc2Enabled, osc2Waveform, osc2Volume, osc2Octave, osc2Detune, osc2PulseWidth, osc2WavetableMorph
        case attack, decay, sustain, release
        case filterType, filterCutoff, filterResonance, filterEnvelopeAmount
        case lfoEnabled, lfoRate, lfoDepth, lfoWaveform, lfoTarget
        case reverbMix, reverbRoomSize, chorusRate, chorusDepth, chorusMix
        case delayTime, delayFeedback, delayMix
        case masterVolume, portamento
        case unisonVoices, unisonDetune, unisonSpread
        case modMatrix
        case arpMode, arpRate, bpm, sequencerData
        case distortionEnabled, distortionType, distortionDrive, distortionTone, distortionMix
        case eqEnabled, eqPreset, eqLowGain, eqLowFreq, eqMidGain, eqMidFreq, eqMidQ, eqHighGain, eqHighFreq
        case phaserEnabled, phaserMode, phaserRate, phaserDepth, phaserFeedback
        case phaserCenterFrequency, phaserStereoSpread, phaserMix
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: PresetCategory = .lead,
        osc1Waveform: WaveformType = .sawtooth,
        osc1Volume: Float = 0.7,
        osc1Octave: Int = 0,
        osc1Detune: Float = 0.0,
        osc1PulseWidth: Float = 0.5,
        osc1WavetableMorph: Float = 0.0,
        osc2Enabled: Bool = true,
        osc2Waveform: WaveformType = .square,
        osc2Volume: Float = 0.5,
        osc2Octave: Int = 0,
        osc2Detune: Float = 5.0,
        osc2PulseWidth: Float = 0.5,
        osc2WavetableMorph: Float = 0.0,
        attack: Float = 0.01,
        decay: Float = 0.1,
        sustain: Float = 0.7,
        release: Float = 0.3,
        filterType: FilterType = .lowPass,
        filterCutoff: Float = 5000.0,
        filterResonance: Float = 0.5,
        filterEnvelopeAmount: Float = 0.0,
        lfoEnabled: Bool = false,
        lfoRate: Float = 5.0,
        lfoDepth: Float = 0.5,
        lfoWaveform: WaveformType = .sine,
        lfoTarget: LFOTarget = .pitch,
        reverbMix: Float = 0.2,
        reverbRoomSize: Float = 0.5,
        chorusRate: Float = 1.5,
        chorusDepth: Float = 0.5,
        chorusMix: Float = 0.0,
        delayTime: Float = 0.3,
        delayFeedback: Float = 0.4,
        delayMix: Float = 0.0,
        masterVolume: Float = 0.55,
        portamento: Float = 0.0,
        unisonVoices: Int = 1,
        unisonDetune: Float = 0.0,
        unisonSpread: Float = 0.0,
        modMatrix: [ModMatrixEntry] = [],
        arpMode: ArpeggiatorMode = .off,
        arpRate: TimeDivision = .sixteenth,
        bpm: Float = 120.0,
        sequencerData: [SequencerStep] = Array(repeating: SequencerStep(), count: 16),
        distortionEnabled: Bool = false,
        distortionType: DistortionType = .softClip,
        distortionDrive: Float = 0.35,
        distortionTone: Float = 0.5,
        distortionMix: Float = 0.25,
        eqEnabled: Bool = false,
        eqPreset: EQPreset = .flat,
        eqLowGain: Float = 0,
        eqLowFreq: Float = 100,
        eqMidGain: Float = 0,
        eqMidFreq: Float = 1000,
        eqMidQ: Float = 1.0,
        eqHighGain: Float = 0,
        eqHighFreq: Float = 8000,
        phaserEnabled: Bool = false,
        phaserMode: PhaserMode = .phaser4,
        phaserRate: Float = 0.4,
        phaserDepth: Float = 0.55,
        phaserFeedback: Float = 0.25,
        phaserCenterFrequency: Float = 800,
        phaserStereoSpread: Float = 0.5,
        phaserMix: Float = 0.4
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.osc1Waveform = osc1Waveform
        self.osc1Volume = osc1Volume
        self.osc1Octave = osc1Octave
        self.osc1Detune = osc1Detune
        self.osc1PulseWidth = osc1PulseWidth
        self.osc1WavetableMorph = osc1WavetableMorph
        self.osc2Enabled = osc2Enabled
        self.osc2Waveform = osc2Waveform
        self.osc2Volume = osc2Volume
        self.osc2Octave = osc2Octave
        self.osc2Detune = osc2Detune
        self.osc2PulseWidth = osc2PulseWidth
        self.osc2WavetableMorph = osc2WavetableMorph
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.filterType = filterType
        self.filterCutoff = filterCutoff
        self.filterResonance = filterResonance
        self.filterEnvelopeAmount = filterEnvelopeAmount
        self.lfoEnabled = lfoEnabled
        self.lfoRate = lfoRate
        self.lfoDepth = lfoDepth
        self.lfoWaveform = lfoWaveform
        self.lfoTarget = lfoTarget
        self.reverbMix = reverbMix
        self.reverbRoomSize = reverbRoomSize
        self.chorusRate = chorusRate
        self.chorusDepth = chorusDepth
        self.chorusMix = chorusMix
        self.delayTime = delayTime
        self.delayFeedback = delayFeedback
        self.delayMix = delayMix
        self.masterVolume = masterVolume
        self.portamento = portamento
        self.unisonVoices = unisonVoices
        self.unisonDetune = unisonDetune
        self.unisonSpread = unisonSpread
        self.modMatrix = modMatrix
        self.arpMode = arpMode
        self.arpRate = arpRate
        self.bpm = bpm
        self.sequencerData = sequencerData
        self.distortionEnabled = distortionEnabled
        self.distortionType = distortionType
        self.distortionDrive = distortionDrive
        self.distortionTone = distortionTone
        self.distortionMix = distortionMix
        self.eqEnabled = eqEnabled
        self.eqPreset = eqPreset
        self.eqLowGain = eqLowGain
        self.eqLowFreq = eqLowFreq
        self.eqMidGain = eqMidGain
        self.eqMidFreq = eqMidFreq
        self.eqMidQ = eqMidQ
        self.eqHighGain = eqHighGain
        self.eqHighFreq = eqHighFreq
        self.phaserEnabled = phaserEnabled
        self.phaserMode = phaserMode
        self.phaserRate = phaserRate
        self.phaserDepth = phaserDepth
        self.phaserFeedback = phaserFeedback
        self.phaserCenterFrequency = phaserCenterFrequency
        self.phaserStereoSpread = phaserStereoSpread
        self.phaserMix = phaserMix
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        category = try c.decodeIfPresent(PresetCategory.self, forKey: .category) ?? .lead
        osc1Waveform = try c.decodeIfPresent(WaveformType.self, forKey: .osc1Waveform) ?? .sawtooth
        osc1Volume = try c.decodeIfPresent(Float.self, forKey: .osc1Volume) ?? 0.7
        osc1Octave = try c.decodeIfPresent(Int.self, forKey: .osc1Octave) ?? 0
        osc1Detune = try c.decodeIfPresent(Float.self, forKey: .osc1Detune) ?? 0
        osc1PulseWidth = try c.decodeIfPresent(Float.self, forKey: .osc1PulseWidth) ?? 0.5
        osc1WavetableMorph = try c.decodeIfPresent(Float.self, forKey: .osc1WavetableMorph) ?? 0
        osc2Enabled = try c.decodeIfPresent(Bool.self, forKey: .osc2Enabled) ?? true
        osc2Waveform = try c.decodeIfPresent(WaveformType.self, forKey: .osc2Waveform) ?? .square
        osc2Volume = try c.decodeIfPresent(Float.self, forKey: .osc2Volume) ?? 0.5
        osc2Octave = try c.decodeIfPresent(Int.self, forKey: .osc2Octave) ?? 0
        osc2Detune = try c.decodeIfPresent(Float.self, forKey: .osc2Detune) ?? 5
        osc2PulseWidth = try c.decodeIfPresent(Float.self, forKey: .osc2PulseWidth) ?? 0.5
        osc2WavetableMorph = try c.decodeIfPresent(Float.self, forKey: .osc2WavetableMorph) ?? 0
        attack = try c.decodeIfPresent(Float.self, forKey: .attack) ?? 0.01
        decay = try c.decodeIfPresent(Float.self, forKey: .decay) ?? 0.1
        sustain = try c.decodeIfPresent(Float.self, forKey: .sustain) ?? 0.7
        release = try c.decodeIfPresent(Float.self, forKey: .release) ?? 0.3
        filterType = try c.decodeIfPresent(FilterType.self, forKey: .filterType) ?? .lowPass
        filterCutoff = try c.decodeIfPresent(Float.self, forKey: .filterCutoff) ?? 5000
        filterResonance = try c.decodeIfPresent(Float.self, forKey: .filterResonance) ?? 0.5
        filterEnvelopeAmount = try c.decodeIfPresent(Float.self, forKey: .filterEnvelopeAmount) ?? 0
        lfoEnabled = try c.decodeIfPresent(Bool.self, forKey: .lfoEnabled) ?? false
        lfoRate = try c.decodeIfPresent(Float.self, forKey: .lfoRate) ?? 5
        lfoDepth = try c.decodeIfPresent(Float.self, forKey: .lfoDepth) ?? 0.5
        lfoWaveform = try c.decodeIfPresent(WaveformType.self, forKey: .lfoWaveform) ?? .sine
        lfoTarget = try c.decodeIfPresent(LFOTarget.self, forKey: .lfoTarget) ?? .pitch
        reverbMix = try c.decodeIfPresent(Float.self, forKey: .reverbMix) ?? 0.2
        reverbRoomSize = try c.decodeIfPresent(Float.self, forKey: .reverbRoomSize) ?? 0.5
        chorusRate = try c.decodeIfPresent(Float.self, forKey: .chorusRate) ?? 1.5
        chorusDepth = try c.decodeIfPresent(Float.self, forKey: .chorusDepth) ?? 0.5
        chorusMix = try c.decodeIfPresent(Float.self, forKey: .chorusMix) ?? 0
        delayTime = try c.decodeIfPresent(Float.self, forKey: .delayTime) ?? 0.3
        delayFeedback = try c.decodeIfPresent(Float.self, forKey: .delayFeedback) ?? 0.4
        delayMix = try c.decodeIfPresent(Float.self, forKey: .delayMix) ?? 0
        masterVolume = try c.decodeIfPresent(Float.self, forKey: .masterVolume) ?? 0.55
        portamento = try c.decodeIfPresent(Float.self, forKey: .portamento) ?? 0
        unisonVoices = try c.decodeIfPresent(Int.self, forKey: .unisonVoices) ?? 1
        unisonDetune = try c.decodeIfPresent(Float.self, forKey: .unisonDetune) ?? 0
        unisonSpread = try c.decodeIfPresent(Float.self, forKey: .unisonSpread) ?? 0
        modMatrix = try c.decodeIfPresent([ModMatrixEntry].self, forKey: .modMatrix) ?? []
        arpMode = try c.decodeIfPresent(ArpeggiatorMode.self, forKey: .arpMode) ?? .off
        arpRate = try c.decodeIfPresent(TimeDivision.self, forKey: .arpRate) ?? .sixteenth
        bpm = try c.decodeIfPresent(Float.self, forKey: .bpm) ?? 120
        sequencerData = try c.decodeIfPresent([SequencerStep].self, forKey: .sequencerData)
            ?? Array(repeating: SequencerStep(), count: 16)
        distortionEnabled = try c.decodeIfPresent(Bool.self, forKey: .distortionEnabled) ?? false
        distortionType = try c.decodeIfPresent(DistortionType.self, forKey: .distortionType) ?? .softClip
        distortionDrive = try c.decodeIfPresent(Float.self, forKey: .distortionDrive) ?? 0.35
        distortionTone = try c.decodeIfPresent(Float.self, forKey: .distortionTone) ?? 0.5
        distortionMix = try c.decodeIfPresent(Float.self, forKey: .distortionMix) ?? 0.25
        eqEnabled = try c.decodeIfPresent(Bool.self, forKey: .eqEnabled) ?? false
        eqPreset = try c.decodeIfPresent(EQPreset.self, forKey: .eqPreset) ?? .flat
        eqLowGain = try c.decodeIfPresent(Float.self, forKey: .eqLowGain) ?? 0
        eqLowFreq = try c.decodeIfPresent(Float.self, forKey: .eqLowFreq) ?? 100
        eqMidGain = try c.decodeIfPresent(Float.self, forKey: .eqMidGain) ?? 0
        eqMidFreq = try c.decodeIfPresent(Float.self, forKey: .eqMidFreq) ?? 1000
        eqMidQ = try c.decodeIfPresent(Float.self, forKey: .eqMidQ) ?? 1
        eqHighGain = try c.decodeIfPresent(Float.self, forKey: .eqHighGain) ?? 0
        eqHighFreq = try c.decodeIfPresent(Float.self, forKey: .eqHighFreq) ?? 8000
        phaserEnabled = try c.decodeIfPresent(Bool.self, forKey: .phaserEnabled) ?? false
        phaserMode = try c.decodeIfPresent(PhaserMode.self, forKey: .phaserMode) ?? .phaser4
        phaserRate = try c.decodeIfPresent(Float.self, forKey: .phaserRate) ?? 0.4
        phaserDepth = try c.decodeIfPresent(Float.self, forKey: .phaserDepth) ?? 0.55
        phaserFeedback = try c.decodeIfPresent(Float.self, forKey: .phaserFeedback) ?? 0.25
        phaserCenterFrequency = try c.decodeIfPresent(Float.self, forKey: .phaserCenterFrequency) ?? 800
        phaserStereoSpread = try c.decodeIfPresent(Float.self, forKey: .phaserStereoSpread) ?? 0.5
        phaserMix = try c.decodeIfPresent(Float.self, forKey: .phaserMix) ?? 0.4
    }

    /// Apply EQ factory curve into numeric fields (and enable EQ).
    mutating func applyEQCurve(_ preset: EQPreset) {
        eqPreset = preset
        let s = preset.settings
        eqLowGain = s.lowGain
        eqLowFreq = s.lowFreq
        eqMidGain = s.midGain
        eqMidFreq = s.midFreq
        eqMidQ = s.midQ
        eqHighGain = s.highGain
        eqHighFreq = s.highFreq
    }
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

struct ModMatrixEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var source: ModSource
    var destination: ModDestination
    var amount: Float
}

enum ModSource: String, CaseIterable, Codable {
    case lfo1 = "LFO 1"
    case env1 = "Env 1 (Amp)"
    case velocity = "Velocity"
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

// MARK: - Factory authoring helpers

enum PresetAuthoring {
    /// Destinations the live render actually applies (pitch1/2, amp, pan).
    /// Cutoff / PWM / mix entries are stored and silent — do not author them.
    static let liveDestinations: Set<ModDestination> = [.pitch1, .pitch2, .amp, .pan]

    static func mod(_ source: ModSource, _ dest: ModDestination, _ amount: Float) -> ModMatrixEntry {
        ModMatrixEntry(source: source, destination: dest, amount: amount)
    }
}
