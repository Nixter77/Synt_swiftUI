//
//  SynthPreset.swift
//  Synt_swiftUI
//
//  Preset model + categories. Factory library lives in FactoryPresets.swift.
//

import Foundation

/// Where the arp, sequencer and tempo-synced clocks take their tempo.
public enum SyncSource: String, Codable, CaseIterable, Equatable {
    case `internal`
    case midiClock
}

public enum PresetCategory: String, CaseIterable, Codable {
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

public struct SynthPreset: Codable, Identifiable, Hashable {
    public var id = UUID()
    public var name: String
    public var category: PresetCategory = .lead

    // Oscillator 1
    public var osc1Waveform: WaveformType = .sawtooth
    public var osc1Volume: Float = 0.7
    public var osc1Octave: Int = 0
    public var osc1Detune: Float = 0.0
    public var osc1PulseWidth: Float = 0.5
    /// Wavetable morph 0…1 (only meaningful when waveform == .wavetable)
    public var osc1WavetableMorph: Float = 0.0
    /// 0: Basic Shapes, 1: Analog, 2: Digital, 3: PWM, 4: Formant, 5: User
    public var osc1WavetableIndex: Int = 0

    // Oscillator 2
    public var osc2Enabled: Bool = true
    public var osc2Waveform: WaveformType = .square
    public var osc2Volume: Float = 0.5
    public var osc2Octave: Int = 0
    public var osc2Detune: Float = 5.0
    public var osc2PulseWidth: Float = 0.5
    public var osc2WavetableMorph: Float = 0.0
    /// 0: Basic Shapes, 1: Analog, 2: Digital, 3: PWM, 4: Formant, 5: User
    public var osc2WavetableIndex: Int = 0

    // Sub-Oscillator & FM / Sync
    public var subOscVolume: Float = 0.0
    public var subOscOctave: Int = -1
    public var subOscWaveform: WaveformType = .sine
    public var fmAmount: Float = 0.0
    public var oscSyncEnabled: Bool = false

    // ADSR
    public var attack: Float = 0.01
    public var decay: Float = 0.1
    public var sustain: Float = 0.7
    public var release: Float = 0.3

    // Filter
    public var filterType: FilterType = .lowPass
    public var filterCutoff: Float = 5000.0
    public var filterResonance: Float = 0.5
    public var filterEnvelopeAmount: Float = 0.0
    /// 0…1. 1 = cutoff follows the played note 1:1 (octave per octave) around C4.
    public var filterKeyTracking: Float = 0.0
    public var filterEnvUseDedicatedADSR: Bool = false
    public var filterAttack: Float = 0.01
    public var filterDecay: Float = 0.3
    public var filterSustain: Float = 0.0
    public var filterRelease: Float = 0.3
    /// Velocity Routing (Phase V2.9): scales cutoff and envelope amount by key velocity.
    public var velocityToCutoff: Float = 0.0
    public var velocityToEnvAmount: Float = 0.0

    // LFO
    public var lfoEnabled: Bool = false
    public var lfoRate: Float = 5.0
    public var lfoDepth: Float = 0.5
    public var lfoWaveform: WaveformType = .sine
    public var lfoTarget: LFOTarget = .pitch
    public var lfoTempoSync: Bool = false
    public var lfoSyncDivision: TimeDivision = .quarter

    // LFO 2
    public var lfo2Enabled: Bool = false
    public var lfo2Rate: Float = 2.0
    public var lfo2Depth: Float = 0.5
    public var lfo2Waveform: WaveformType = .triangle
    public var lfo2Target: LFOTarget = .none
    public var lfo2TempoSync: Bool = false
    public var lfo2SyncDivision: TimeDivision = .eighth

    // Mix FX
    public var reverbMix: Float = 0.2
    public var reverbRoomSize: Float = 0.5
    public var chorusRate: Float = 1.5
    public var chorusDepth: Float = 0.5
    public var chorusMix: Float = 0.0
    public var delayTime: Float = 0.3
    public var delayFeedback: Float = 0.4
    public var delayMix: Float = 0.0
    public var delayTempoSync: Bool = false
    public var delaySyncDivision: TimeDivision = .eighth

    // Master
    public var masterVolume: Float = 0.55
    public var portamento: Float = 0.0

    // Unison & Drift
    public var unisonVoices: Int = 1
    public var unisonDetune: Float = 0.0
    public var unisonSpread: Float = 0.0
    /// Alias for unisonSpread (Phase V2.3)
    public var unisonStereoSpread: Float {
        get { unisonSpread }
        set { unisonSpread = newValue }
    }
    /// Per-voice analog pitch & cutoff drift (0.0...1.0 = ±5 cents)
    public var analogDrift: Float = 0.0
    /// Chord Memory mode for unison partials (Phase V2.10)
    public var chordMode: ChordMode = .off

    // Phase V2.6: Chorus Stereo & Reverb Shimmer
    public var chorusStereo: Bool = true
    public var reverbShimmer: Float = 0.0

    // Matrix
    public var modMatrix: [ModMatrixEntry] = []

    // Arpeggiator / Sequencer
    public var arpMode: ArpeggiatorMode = .off
    public var arpRate: TimeDivision = .sixteenth
    public var arpOctaves: Int = 1
    public var arpGateLength: Float = 0.8
    public var arpSwing: Float = 0.0
    public var bpm: Float = 120.0
    public var sequencerData: [SequencerStep] = Array(repeating: SequencerStep(), count: 16)

    // MARK: - Advanced FX (Stage 4) — default OFF / neutral for clean Init

    public var distortionEnabled: Bool = false
    public var distortionType: DistortionType = .softClip
    public var distortionDrive: Float = 0.35
    public var distortionTone: Float = 0.5
    public var distortionMix: Float = 0.25

    public var eqEnabled: Bool = false
    public var eqPreset: EQPreset = .flat
    public var eqLowGain: Float = 0
    public var eqLowFreq: Float = 100
    public var eqMidGain: Float = 0
    public var eqMidFreq: Float = 1000
    public var eqMidQ: Float = 1.0
    public var eqHighGain: Float = 0
    public var eqHighFreq: Float = 8000

    public var phaserEnabled: Bool = false
    public var phaserMode: PhaserMode = .phaser4
    public var phaserRate: Float = 0.4
    public var phaserDepth: Float = 0.55
    public var phaserFeedback: Float = 0.25
    public var phaserCenterFrequency: Float = 800
    public var phaserStereoSpread: Float = 0.5
    public var phaserMix: Float = 0.4
    /// Semitones at full pitch-bend throw. Older JSON leaves this at 2.
    public var pitchBendRange: Float = 2
    /// Older behaviour: "LFO 1 → X" rows are multiplied by LFO Depth. New patches
    /// use the raw LFO so the row Amount is the real depth. Saved JSON without the
    /// key and the factory patches with LFO rows keep `true`, so they sound the same.
    public var lfoRowsFollowDepth: Bool = false

    public var distortionOversampling: Bool = false
    public var delayPingPong: Bool = false

    // MARK: - Phase V2.7: Ring Mod & Noise Color
    public var ringModAmount: Float = 0.0
    public var noiseColor: NoiseColor = .white

    // MARK: - Performance Macros (-1.0...1.0)
    public var macro1: Float = 0.0
    public var macro2: Float = 0.0
    public var macro3: Float = 0.0
    public var macro4: Float = 0.0

    // MARK: - Voice Mode (Poly / Mono / Legato)
    public var voiceMode: VoiceMode = .poly

    /// `.internal` uses the BPM slider. `.midiClock` follows Logic's MIDI clock.
    public var syncSource: SyncSource = .`internal`

    /// Extra input gain into the filter. 0 leaves LP/HP/BP on the old path.
    public var filterDrive: Float = 0

    /// Master stereo pan (-1.0...1.0, 0 = center).
    public var pan: Float = 0.0

    /// Reorderable FX slots.
    public var fxOrder: [FXSlotID] = FXSlotID.defaultOrder

    public var lfoMode: LFOMode = .free
    public var lfoStartPhase: Float = 0.0
    public var lfo2Mode: LFOMode = .free
    public var lfo2StartPhase: Float = 0.0
    public var arpLatch: Bool = false

    // Stage 3: Velocity, Mod Envelope, Glide, Mono
    public var velocityCurve: VelocityCurve = .linear
    public var velocityToVolume: Float = 1.0
    public var modEnvAttack: Float = 0.01
    public var modEnvDecay: Float = 0.2
    public var modEnvSustain: Float = 0.0
    public var modEnvRelease: Float = 0.1
    public var glideMode: GlideMode = .time
    public var glideLegatoOnly: Bool = false
    public var monoPriority: MonoPriority = .last

    /// Safe neutral starting point (clean headroom).
    public static let defaultPreset = SynthPreset(name: "Init", category: .lead)

    // MARK: - Codable (new fields optional for older user JSON)

    public enum CodingKeys: String, CodingKey {
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
        case filterDrive
        case pan
        case fxOrder
        case lfoMode, lfoStartPhase, lfo2Mode, lfo2StartPhase, arpLatch
        case velocityCurve, velocityToVolume
        case modEnvAttack, modEnvDecay, modEnvSustain, modEnvRelease
        case glideMode, glideLegatoOnly
        case monoPriority
    }

    public init(
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
        syncSource: SyncSource = .`internal`,
        filterDrive: Float = 0,
        pan: Float = 0.0,
        fxOrder: [FXSlotID] = FXSlotID.defaultOrder,
        lfoMode: LFOMode = .free,
        lfoStartPhase: Float = 0.0,
        lfo2Mode: LFOMode = .free,
        lfo2StartPhase: Float = 0.0,
        arpLatch: Bool = false,
        velocityCurve: VelocityCurve = .linear,
        velocityToVolume: Float = 1.0,
        modEnvAttack: Float = 0.01,
        modEnvDecay: Float = 0.2,
        modEnvSustain: Float = 0.0,
        modEnvRelease: Float = 0.1,
        glideMode: GlideMode = .time,
        glideLegatoOnly: Bool = false,
        monoPriority: MonoPriority = .last
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
        self.filterDrive = filterDrive
        self.pan = pan
        self.fxOrder = fxOrder
        self.lfoMode = lfoMode
        self.lfoStartPhase = lfoStartPhase
        self.lfo2Mode = lfo2Mode
        self.lfo2StartPhase = lfo2StartPhase
        self.arpLatch = arpLatch
        self.velocityCurve = velocityCurve
        self.velocityToVolume = velocityToVolume
        self.modEnvAttack = modEnvAttack
        self.modEnvDecay = modEnvDecay
        self.modEnvSustain = modEnvSustain
        self.modEnvRelease = modEnvRelease
        self.glideMode = glideMode
        self.glideLegatoOnly = glideLegatoOnly
        self.monoPriority = monoPriority
    }

    public init(from decoder: Decoder) throws {
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
        filterDrive = try c.decodeIfPresent(Float.self, forKey: .filterDrive) ?? 0
        pan = try c.decodeIfPresent(Float.self, forKey: .pan) ?? 0.0
        fxOrder = try c.decodeIfPresent([FXSlotID].self, forKey: .fxOrder) ?? FXSlotID.defaultOrder
        lfoMode = try c.decodeIfPresent(LFOMode.self, forKey: .lfoMode) ?? .free
        lfoStartPhase = try c.decodeIfPresent(Float.self, forKey: .lfoStartPhase) ?? 0.0
        lfo2Mode = try c.decodeIfPresent(LFOMode.self, forKey: .lfo2Mode) ?? .free
        lfo2StartPhase = try c.decodeIfPresent(Float.self, forKey: .lfo2StartPhase) ?? 0.0
        arpLatch = try c.decodeIfPresent(Bool.self, forKey: .arpLatch) ?? false
        velocityCurve = try c.decodeIfPresent(VelocityCurve.self, forKey: .velocityCurve) ?? .linear
        velocityToVolume = try c.decodeIfPresent(Float.self, forKey: .velocityToVolume) ?? 1.0
        modEnvAttack = try c.decodeIfPresent(Float.self, forKey: .modEnvAttack) ?? 0.01
        modEnvDecay = try c.decodeIfPresent(Float.self, forKey: .modEnvDecay) ?? 0.2
        modEnvSustain = try c.decodeIfPresent(Float.self, forKey: .modEnvSustain) ?? 0.0
        modEnvRelease = try c.decodeIfPresent(Float.self, forKey: .modEnvRelease) ?? 0.1
        glideMode = try c.decodeIfPresent(GlideMode.self, forKey: .glideMode) ?? .time
        glideLegatoOnly = try c.decodeIfPresent(Bool.self, forKey: .glideLegatoOnly) ?? false
        monoPriority = try c.decodeIfPresent(MonoPriority.self, forKey: .monoPriority) ?? .last
    }

    /// Apply EQ factory curve into numeric fields (and enable EQ).
    public mutating func applyEQCurve(_ preset: EQPreset) {
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

public enum VoiceMode: String, CaseIterable, Codable {
    case poly = "Poly"
    case mono = "Mono"
    case legato = "Legato"
}

public enum NoiseColor: String, CaseIterable, Codable {
    case white = "White"
    case pink = "Pink"
    case brown = "Brown"
}

public enum ChordMode: String, CaseIterable, Codable {
    case off = "Off"
    case octave = "Octave"
    case fifth = "Fifth"
    case minor = "Minor"
    case major = "Major"
    case sus4 = "Sus4"

    public func semitoneOffset(for partial: Int, totalPartials: Int) -> Float {
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

public enum FilterType: String, CaseIterable, Codable {
    case lowPass = "Low Pass"
    case highPass = "High Pass"
    case bandPass = "Band Pass"
    case notch = "Notch"
    case ladder = "Ladder"
}

public enum LFOTarget: String, CaseIterable, Codable {
    case pitch = "Pitch"
    case filter = "Filter"
    case amplitude = "Amplitude"
    case pan = "Pan"
    /// The oscillator still runs for matrix rows. It does not move a direct target.
    case none = "Matrix only"
}

public struct ModMatrixEntry: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var source: ModSource
    public var destination: ModDestination
    public var amount: Float

    public init(id: UUID = UUID(), source: ModSource, destination: ModDestination, amount: Float) {
        self.id = id
        self.source = source
        self.destination = destination
        self.amount = amount
    }
}

public enum ModSource: String, CaseIterable, Codable {
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
    case modEnv = "Mod Env"
    case pitchBend = "Pitch Bend"
    case random = "Random"
    case sampleAndHold = "Sample & Hold"
}

public enum VelocityCurve: String, CaseIterable, Codable, Sendable {
    case linear = "Linear"
    case exponential = "Exponential"
    case logarithmic = "Logarithmic"
}

public enum GlideMode: String, CaseIterable, Codable, Sendable {
    case time = "Time"
    case rate = "Rate"
}

public enum MonoPriority: String, CaseIterable, Codable, Sendable {
    case last = "Last"
    case low = "Low"
    case high = "High"
}

public enum ModDestination: String, CaseIterable, Codable {
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

    public var menuTitle: String {
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
    public func formatAmount(_ amount: Float) -> String {
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
public let pwmModulationSpan: Float = 0.45

// MARK: - Factory authoring helpers

public enum PresetAuthoring {
    /// Every destination is applied by the render.
    public static let liveDestinations: Set<ModDestination> = Set(ModDestination.allCases)

    public static func mod(_ source: ModSource, _ dest: ModDestination, _ amount: Float) -> ModMatrixEntry {
        ModMatrixEntry(source: source, destination: dest, amount: amount)
    }
}
