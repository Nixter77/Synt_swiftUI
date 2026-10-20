//
//  SynthPreset.swift
//  Synt_swiftUI
//
//  Preset model + categories. Factory library lives in FactoryPresets.swift.
//

import Foundation

/// Where the arp, sequencer and tempo-synced clocks take their tempo.
enum SyncSource: String, Codable, CaseIterable, Equatable {
    case `internal`
    case midiClock
}

enum PresetCategory: String, CaseIterable, Codable {
    case bass = "Bass"
    case lead = "Lead"
    case pad = "Pad"
    case keys = "Keys"
    case pluck = "Pluck"
    case strings = "Strings"
    case brass = "Brass"
    case arp = "Arp / Seq"
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
    /// 0: Basic Shapes, 1: Analog, 2: Digital, 3: PWM, 4: Formant, 5: User
    var osc1WavetableIndex: Int = 0

    // Oscillator 2
    var osc2Enabled: Bool = true
    var osc2Waveform: WaveformType = .square
    var osc2Volume: Float = 0.5
    var osc2Octave: Int = 0
    var osc2Detune: Float = 5.0
    var osc2PulseWidth: Float = 0.5
    var osc2WavetableMorph: Float = 0.0
    /// 0: Basic Shapes, 1: Analog, 2: Digital, 3: PWM, 4: Formant, 5: User
    var osc2WavetableIndex: Int = 0

    // Sub-Oscillator & FM / Sync
    var subOscVolume: Float = 0.0
    var subOscOctave: Int = -1
    var subOscWaveform: WaveformType = .sine
    var fmAmount: Float = 0.0
    var oscSyncEnabled: Bool = false

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
    /// 0…1. 1 = cutoff follows the played note 1:1 (octave per octave) around C4.
    var filterKeyTracking: Float = 0.0
    var filterEnvUseDedicatedADSR: Bool = false
    var filterAttack: Float = 0.01
    var filterDecay: Float = 0.3
    var filterSustain: Float = 0.0
    var filterRelease: Float = 0.3
    /// Velocity Routing (Phase V2.9): scales cutoff and envelope amount by key velocity.
    var velocityToCutoff: Float = 0.0
    var velocityToEnvAmount: Float = 0.0

    // LFO
    var lfoEnabled: Bool = false
    var lfoRate: Float = 5.0
    var lfoDepth: Float = 0.5
    var lfoWaveform: WaveformType = .sine
    var lfoTarget: LFOTarget = .pitch
    var lfoTempoSync: Bool = false
    var lfoSyncDivision: TimeDivision = .quarter

    // LFO 2
    var lfo2Enabled: Bool = false
    var lfo2Rate: Float = 2.0
    var lfo2Depth: Float = 0.5
    var lfo2Waveform: WaveformType = .triangle
    var lfo2Target: LFOTarget = .none
    var lfo2TempoSync: Bool = false
    var lfo2SyncDivision: TimeDivision = .eighth

    // Mix FX
    var reverbMix: Float = 0.2
    var reverbRoomSize: Float = 0.5
    var chorusRate: Float = 1.5
    var chorusDepth: Float = 0.5
    var chorusMix: Float = 0.0
    var delayTime: Float = 0.3
    var delayFeedback: Float = 0.4
    var delayMix: Float = 0.0
    var delayTempoSync: Bool = false
    var delaySyncDivision: TimeDivision = .eighth

    // Master
    var masterVolume: Float = 0.55
    var portamento: Float = 0.0

    // Unison & Drift
    var unisonVoices: Int = 1
    var unisonDetune: Float = 0.0
    var unisonSpread: Float = 0.0
    /// Alias for unisonSpread (Phase V2.3)
    var unisonStereoSpread: Float {
        get { unisonSpread }
        set { unisonSpread = newValue }
    }
    /// Per-voice analog pitch & cutoff drift (0.0...1.0 = ±5 cents)
    var analogDrift: Float = 0.0
    /// Chord Memory mode for unison partials (Phase V2.10)
    var chordMode: ChordMode = .off

    // Phase V2.6: Chorus Stereo & Reverb Shimmer
    var chorusStereo: Bool = true
    var reverbShimmer: Float = 0.0

    // Matrix
    var modMatrix: [ModMatrixEntry] = []

    // Arpeggiator / Sequencer
    var arpMode: ArpeggiatorMode = .off
    var arpRate: TimeDivision = .sixteenth
    var arpOctaves: Int = 1
    var arpGateLength: Float = 0.8
    var arpSwing: Float = 0.0
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
    /// Semitones at full pitch-bend throw. Older JSON leaves this at 2.
    var pitchBendRange: Float = 2
    /// Older behaviour: "LFO 1 → X" rows are multiplied by LFO Depth. New patches
    /// use the raw LFO so the row Amount is the real depth. Saved JSON without the
    /// key and the factory patches with LFO rows keep `true`, so they sound the same.
    var lfoRowsFollowDepth: Bool = false

    var distortionOversampling: Bool = false
    var delayPingPong: Bool = false

    // MARK: - Phase V2.7: Ring Mod & Noise Color
    var ringModAmount: Float = 0.0
    var noiseColor: NoiseColor = .white

    // MARK: - Performance Macros (-1.0...1.0)
    var macro1: Float = 0.0
    var macro2: Float = 0.0
    var macro3: Float = 0.0
    var macro4: Float = 0.0

    // MARK: - Voice Mode (Poly / Mono / Legato)
    var voiceMode: VoiceMode = .poly

    /// `.internal` uses the BPM slider. `.midiClock` follows Logic's MIDI clock.
    var syncSource: SyncSource = .`internal`

    /// Safe neutral starting point (clean headroom).
    static let defaultPreset = SynthPreset(name: "Init", category: .lead)

    // MARK: - Codable (new fields optional for older user JSON)

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case osc1Waveform, osc1Volume, osc1Octave, osc1Detune, osc1PulseWidth, osc1WavetableMorph, osc1WavetableIndex
        case osc2Enabled, osc2Waveform, osc2Volume, osc2Octave, osc2Detune, osc2PulseWidth, osc2WavetableMorph, osc2WavetableIndex
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
        case pitchBendRange
        case lfoRowsFollowDepth
        case filterKeyTracking
        case subOscVolume, subOscOctave, subOscWaveform, fmAmount, oscSyncEnabled
        case lfoTempoSync, lfoSyncDivision, delayTempoSync, delaySyncDivision
        case lfo2Enabled, lfo2Rate, lfo2Depth, lfo2Waveform, lfo2Target, lfo2TempoSync, lfo2SyncDivision
        case arpOctaves
        case distortionOversampling, delayPingPong
        case filterEnvUseDedicatedADSR, filterAttack, filterDecay, filterSustain, filterRelease
        case analogDrift
        case chorusStereo, reverbShimmer
        case ringModAmount, noiseColor
        case arpGateLength, arpSwing
        case velocityToCutoff, velocityToEnvAmount
        case chordMode
        case macro1, macro2, macro3, macro4
        case voiceMode
        case syncSource
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
        phaserMix: Float = 0.4,
        pitchBendRange: Float = 2,
        filterKeyTracking: Float = 0,
        osc1WavetableIndex: Int = 0,
        osc2WavetableIndex: Int = 0,
        subOscVolume: Float = 0.0,
        subOscOctave: Int = -1,
        subOscWaveform: WaveformType = .sine,
        fmAmount: Float = 0.0,
        oscSyncEnabled: Bool = false,
        lfoTempoSync: Bool = false,
        lfoSyncDivision: TimeDivision = .quarter,
        delayTempoSync: Bool = false,
        delaySyncDivision: TimeDivision = .eighth,
        lfo2Enabled: Bool = false,
        lfo2Rate: Float = 2.0,
        lfo2Depth: Float = 0.5,
        lfo2Waveform: WaveformType = .triangle,
        lfo2Target: LFOTarget = .none,
        lfo2TempoSync: Bool = false,
        lfo2SyncDivision: TimeDivision = .eighth,
        arpOctaves: Int = 1,
        distortionOversampling: Bool = false,
        delayPingPong: Bool = false,
        filterEnvUseDedicatedADSR: Bool = false,
        filterAttack: Float = 0.01,
        filterDecay: Float = 0.3,
        filterSustain: Float = 0.0,
        filterRelease: Float = 0.3,
        analogDrift: Float = 0.0,
        chorusStereo: Bool = true,
        reverbShimmer: Float = 0.0,
        ringModAmount: Float = 0.0,
        noiseColor: NoiseColor = .white,
        arpGateLength: Float = 0.8,
        arpSwing: Float = 0.0,
        velocityToCutoff: Float = 0.0,
        velocityToEnvAmount: Float = 0.0,
        chordMode: ChordMode = .off,
        macro1: Float = 0.0,
        macro2: Float = 0.0,
        macro3: Float = 0.0,
        macro4: Float = 0.0,
        voiceMode: VoiceMode = .poly,
        syncSource: SyncSource = .`internal`
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
        self.pitchBendRange = pitchBendRange
        self.filterKeyTracking = filterKeyTracking
        self.osc1WavetableIndex = osc1WavetableIndex
        self.osc2WavetableIndex = osc2WavetableIndex
        self.subOscVolume = subOscVolume
        self.subOscOctave = subOscOctave
        self.subOscWaveform = subOscWaveform
        self.fmAmount = fmAmount
        self.oscSyncEnabled = oscSyncEnabled
        self.lfoTempoSync = lfoTempoSync
        self.lfoSyncDivision = lfoSyncDivision
        self.delayTempoSync = delayTempoSync
        self.delaySyncDivision = delaySyncDivision
        self.lfo2Enabled = lfo2Enabled
        self.lfo2Rate = lfo2Rate
        self.lfo2Depth = lfo2Depth
        self.lfo2Waveform = lfo2Waveform
        self.lfo2Target = lfo2Target
        self.lfo2TempoSync = lfo2TempoSync
        self.lfo2SyncDivision = lfo2SyncDivision
        self.arpOctaves = arpOctaves
        self.distortionOversampling = distortionOversampling
        self.delayPingPong = delayPingPong
        self.filterEnvUseDedicatedADSR = filterEnvUseDedicatedADSR
        self.filterAttack = filterAttack
        self.filterDecay = filterDecay
        self.filterSustain = filterSustain
        self.filterRelease = filterRelease
        self.analogDrift = analogDrift
        self.chorusStereo = chorusStereo
        self.reverbShimmer = reverbShimmer
        self.ringModAmount = ringModAmount
        self.noiseColor = noiseColor
        self.arpGateLength = arpGateLength
        self.arpSwing = arpSwing
        self.velocityToCutoff = velocityToCutoff
        self.velocityToEnvAmount = velocityToEnvAmount
        self.chordMode = chordMode
        self.macro1 = macro1
        self.macro2 = macro2
        self.macro3 = macro3
        self.macro4 = macro4
        self.voiceMode = voiceMode
        self.syncSource = syncSource
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
        pitchBendRange = try c.decodeIfPresent(Float.self, forKey: .pitchBendRange) ?? 2
        lfoRowsFollowDepth = try c.decodeIfPresent(Bool.self, forKey: .lfoRowsFollowDepth) ?? true
        filterKeyTracking = try c.decodeIfPresent(Float.self, forKey: .filterKeyTracking) ?? 0
        osc1WavetableIndex = try c.decodeIfPresent(Int.self, forKey: .osc1WavetableIndex) ?? 0
        osc2WavetableIndex = try c.decodeIfPresent(Int.self, forKey: .osc2WavetableIndex) ?? 0
        subOscVolume = try c.decodeIfPresent(Float.self, forKey: .subOscVolume) ?? 0.0
        subOscOctave = try c.decodeIfPresent(Int.self, forKey: .subOscOctave) ?? -1
        subOscWaveform = try c.decodeIfPresent(WaveformType.self, forKey: .subOscWaveform) ?? .sine
        fmAmount = try c.decodeIfPresent(Float.self, forKey: .fmAmount) ?? 0.0
        oscSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .oscSyncEnabled) ?? false
        lfoTempoSync = try c.decodeIfPresent(Bool.self, forKey: .lfoTempoSync) ?? false
        lfoSyncDivision = try c.decodeIfPresent(TimeDivision.self, forKey: .lfoSyncDivision) ?? .quarter
        delayTempoSync = try c.decodeIfPresent(Bool.self, forKey: .delayTempoSync) ?? false
        delaySyncDivision = try c.decodeIfPresent(TimeDivision.self, forKey: .delaySyncDivision) ?? .eighth
        lfo2Enabled = try c.decodeIfPresent(Bool.self, forKey: .lfo2Enabled) ?? false
        lfo2Rate = try c.decodeIfPresent(Float.self, forKey: .lfo2Rate) ?? 2.0
        lfo2Depth = try c.decodeIfPresent(Float.self, forKey: .lfo2Depth) ?? 0.5
        lfo2Waveform = try c.decodeIfPresent(WaveformType.self, forKey: .lfo2Waveform) ?? .triangle
        lfo2Target = try c.decodeIfPresent(LFOTarget.self, forKey: .lfo2Target) ?? .none
        lfo2TempoSync = try c.decodeIfPresent(Bool.self, forKey: .lfo2TempoSync) ?? false
        lfo2SyncDivision = try c.decodeIfPresent(TimeDivision.self, forKey: .lfo2SyncDivision) ?? .eighth
        arpOctaves = try c.decodeIfPresent(Int.self, forKey: .arpOctaves) ?? 1
        distortionOversampling = try c.decodeIfPresent(Bool.self, forKey: .distortionOversampling) ?? false
        delayPingPong = try c.decodeIfPresent(Bool.self, forKey: .delayPingPong) ?? false
        filterEnvUseDedicatedADSR = try c.decodeIfPresent(Bool.self, forKey: .filterEnvUseDedicatedADSR) ?? false
        filterAttack = try c.decodeIfPresent(Float.self, forKey: .filterAttack) ?? 0.01
        filterDecay = try c.decodeIfPresent(Float.self, forKey: .filterDecay) ?? 0.3
        filterSustain = try c.decodeIfPresent(Float.self, forKey: .filterSustain) ?? 0.0
        filterRelease = try c.decodeIfPresent(Float.self, forKey: .filterRelease) ?? 0.3
        analogDrift = try c.decodeIfPresent(Float.self, forKey: .analogDrift) ?? 0.0
        chorusStereo = try c.decodeIfPresent(Bool.self, forKey: .chorusStereo) ?? true
        reverbShimmer = try c.decodeIfPresent(Float.self, forKey: .reverbShimmer) ?? 0.0
        ringModAmount = try c.decodeIfPresent(Float.self, forKey: .ringModAmount) ?? 0.0
        noiseColor = try c.decodeIfPresent(NoiseColor.self, forKey: .noiseColor) ?? .white
        arpGateLength = try c.decodeIfPresent(Float.self, forKey: .arpGateLength) ?? 0.8
        arpSwing = try c.decodeIfPresent(Float.self, forKey: .arpSwing) ?? 0.0
        velocityToCutoff = try c.decodeIfPresent(Float.self, forKey: .velocityToCutoff) ?? 0.0
        velocityToEnvAmount = try c.decodeIfPresent(Float.self, forKey: .velocityToEnvAmount) ?? 0.0
        chordMode = try c.decodeIfPresent(ChordMode.self, forKey: .chordMode) ?? .off
        macro1 = try c.decodeIfPresent(Float.self, forKey: .macro1) ?? 0.0
        macro2 = try c.decodeIfPresent(Float.self, forKey: .macro2) ?? 0.0
        macro3 = try c.decodeIfPresent(Float.self, forKey: .macro3) ?? 0.0
        macro4 = try c.decodeIfPresent(Float.self, forKey: .macro4) ?? 0.0
        voiceMode = try c.decodeIfPresent(VoiceMode.self, forKey: .voiceMode) ?? .poly
        syncSource = try c.decodeIfPresent(SyncSource.self, forKey: .syncSource) ?? .`internal`
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

enum VoiceMode: String, CaseIterable, Codable {
    case poly = "Poly"
    case mono = "Mono"
    case legato = "Legato"
}

enum NoiseColor: String, CaseIterable, Codable {
    case white = "White"
    case pink = "Pink"
    case brown = "Brown"
}

enum ChordMode: String, CaseIterable, Codable {
    case off = "Off"
    case octave = "Octave"
    case fifth = "Fifth"
    case minor = "Minor"
    case major = "Major"
    case sus4 = "Sus4"

    func semitoneOffset(for partial: Int, totalPartials: Int) -> Float {
        guard self != .off else { return 0 }
        let intervals: [Float]
        switch self {
        case .off:
            return 0
        case .octave:
            intervals = [0, 12, -12, 24, -24]
        case .fifth:
            intervals = [0, 7, 12, 19, -12]
        case .minor:
            intervals = [0, 3, 7, 10, 12]
        case .major:
            intervals = [0, 4, 7, 11, 12]
        case .sus4:
            intervals = [0, 5, 7, 12, 17]
        }
        let idx = max(0, min(intervals.count - 1, partial))
        return intervals[idx]
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
    /// The oscillator still runs for matrix rows. It does not move a direct target.
    case none = "Matrix only"
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
    case lfo2 = "LFO 2"
    case modWheel = "Mod Wheel"
    case keyTrack = "Key Track"
    case env2 = "Env 2 (Filter)"
    case aftertouch = "Aftertouch"
    case macro1 = "Macro 1"
    case macro2 = "Macro 2"
    case macro3 = "Macro 3"
    case macro4 = "Macro 4"
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
    case wtMorph1 = "WT Morph 1"
    case wtMorph2 = "WT Morph 2"
    case lfoRate = "LFO Rate"
    case lfoDepth = "LFO Depth"
    case mix = "Osc Mix"

    var menuTitle: String {
        switch self {
        case .pitch1: return "Pitch 1"
        case .pitch2: return "Pitch 2"
        case .pwm1: return "PWM 1"
        case .pwm2: return "PWM 2"
        case .wtMorph1: return "Morph 1"
        case .wtMorph2: return "Morph 2"
        case .mix: return "Mix"
        case .cutoff: return "Cutoff"
        case .resonance: return "Resonance"
        case .amp: return "Amp"
        case .pan: return "Pan"
        case .lfoRate: return "Rate"
        case .lfoDepth: return "Depth"
        }
    }

    /// Signed amount in the destination's own units.
    func formatAmount(_ amount: Float) -> String {
        switch self {
        case .pitch1, .pitch2:
            return String(format: "%+.2f oct", amount)
        case .cutoff:
            return String(format: "%+.1f oct", amount * 4)
        case .amp, .resonance, .lfoDepth, .mix, .wtMorph1, .wtMorph2:
            return String(format: "%+.0f %%", amount * 100)
        case .pwm1, .pwm2:
            // Render moves pulse width by 0.45 × amount: show the real width points.
            return String(format: "%+.0f %% PW", amount * pwmModulationSpan * 100)
        case .pan:
            let pct = abs(amount) * 100
            if amount < -0.0001 { return String(format: "L %.0f %%", pct) }
            if amount > 0.0001 { return String(format: "R %.0f %%", pct) }
            return "C 0 %"
        case .lfoRate:
            let factor = pow(2, 2 * amount)
            return String(format: "×%.1f rate", factor)
        }
    }
}

/// Pulse-width travel at Amount 1 (shared by the render and the label).
let pwmModulationSpan: Float = 0.45

// MARK: - Factory authoring helpers

enum PresetAuthoring {
    /// Every destination is applied by the render.
    static let liveDestinations: Set<ModDestination> = Set(ModDestination.allCases)

    static func mod(_ source: ModSource, _ dest: ModDestination, _ amount: Float) -> ModMatrixEntry {
        ModMatrixEntry(source: source, destination: dest, amount: amount)
    }
}
