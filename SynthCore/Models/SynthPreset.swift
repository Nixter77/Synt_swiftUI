//
//  SynthPreset.swift
//  Synt_swiftUI
//
//  Preset model + categories. Factory library lives in FactoryPresets.swift.
//

import Foundation

/// Where the arp, sequencer and tempo-synced clocks take their tempo.
public enum SyncSource: String, Codable, CaseIterable, Equatable, Sendable {
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
    public var macro5: Float = 0.0
    public var macro6: Float = 0.0
    public var macro7: Float = 0.0
    public var macro8: Float = 0.0

    /// When set, random phase, S&H, and random LFO are reproducible from note to note on load.
    public var randomSeed: UInt32? = nil

    /// User wavetable data embedded in preset (preserves custom samples across environments).
    public var userWavetableName: String? = nil
    public var userWavetableData: Data? = nil

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

    /// Stereo tool. Off leaves the master bus untouched.
    public var stereoEnabled: Bool = false
    public var stereoWidth: Float = 1
    public var stereoMidSide: Float = 0
    public var stereoHaasMs: Float = 0
    public var stereoMonoBassHz: Float = 0

    /// Reset keeps `AudioMath.voiceStartPhases`. Free and Random do not.
    public var oscPhaseMode: OscPhaseMode = .reset

    /// 1...32. 32 is `AudioEngine.maxVoices` and keeps the full voice search.
    public var polyphonyLimit: Int = 32

    /// Trance gate. Off skips the amplitude multiply.
    public var tranceGateEnabled: Bool = false
    public var tranceGatePattern: UInt16 = 0xAAAA
    public var tranceGateDepth: Float = 1
    public var tranceGateSmooth: Float = 0
    public var tranceGateDivision: TimeDivision = .sixteenth

    /// Smooth-random matrix source. The generator advances only while a row uses it.
    public var perlinRate: Float = 1
    public var perlinTempoSync: Bool = false
    public var perlinSyncDivision: TimeDivision = .quarter

    /// Flanger sits on the chorus processor. Off keeps the chorus body.
    public var chorusFlanger: Bool = false
    public var chorusFeedback: Float = 0
    public var chorusFlangerSync: Bool = false
    public var chorusFlangerDivision: TimeDivision = .quarter

    /// Filter output fed back into the filter input. 0 keeps the current filter call.
    public var filterFeedback: Float = 0

    /// Plugin reverb. Off leaves Mix/Room on the Apple unit and the render hash unchanged.
    public var dspReverbEnabled: Bool = false
    public var reverbDamping: Float = 0.4

    /// OSC 2 ignores the note and plays this frequency. Off keeps note tracking.
    public var osc2FixedFrequency: Bool = false
    public var osc2FrequencyHz: Float = 440

    /// High-pass in front of the FX chain. Off leaves the mix untouched.
    public var sceneHPFEnabled: Bool = false
    public var sceneHPFFrequency: Float = 120

    /// Ensemble is the last chorus mode. Standard keeps the existing chorus or flanger.
    public var chorusMode: ChorusMode = .standard

    /// FM ratio retunes the modulator. Off keeps the current phase-mod path.
    public var fmRatioEnabled: Bool = false
    public var fmCoarse: Int = 1
    public var fmFine: Float = 0
    public var fmRoute: FMRoute = .osc2ToOsc1

    /// Second filter. Off leaves the voice filter path untouched.
    public var filter2Routing: DualFilterRouting = .off
    public var filter2Type: FilterType = .lowPass
    public var filter2Cutoff: Float = 2000
    public var filter2Resonance: Float = 0.2
    public var filter2Balance: Float = 0.5
    /// Vowel 0…4 for a formant filter. Unused unless a filter type is formant.
    public var filterVowel: Float = 0
    /// MSEG 1. Empty points leave the generator idle.
    public var mseg = MSEGPreset()
    /// MSEG 2. Empty points leave the generator idle.
    public var mseg2 = MSEGPreset()

    /// ADSR curves (curve per segment, −1…1, default 0: classic logarithmic/exponential).
    public var attackCurve: Float = 0
    public var decayCurve: Float = 0
    public var releaseCurve: Float = 0

    /// Stereo modulation (L/R phase offset in degrees 0…360, default 0: mono).
    public var lfoStereoPhase: Float = 0
    public var lfo2StereoPhase: Float = 0

    /// Envelope Follower settings (attack / release in seconds).
    public var envFollowerAttack: Float = 0.01
    public var envFollowerRelease: Float = 0.05

    /// Parallel FX sends for this preset. 0 keeps the insert chain bit-exact.
    /// Send A feeds reverb. Send B feeds delay.
    public var sendA: Float = 0
    public var sendB: Float = 0
    /// Pre/post-insert switch for sends (default false = pre-insert).
    public var sendPostInsert: Bool = false

    /// Leslie rotor beside the insert chain. Off is bit-exact. Not an FX slot.
    public var rotaryEnabled: Bool = false
    /// false is slow, true is fast. Discrete switch matching AU indexed parameter.
    public var rotaryFast: Bool = false
    public var rotaryHornSlow: Float = 0.7
    public var rotaryHornFast: Float = 6.8
    public var rotaryDrumSlow: Float = 0.55
    public var rotaryDrumFast: Float = 5.2
    public var rotaryDrive: Float = 0
    public var rotaryMix: Float = 1
    public var rotaryAccel: Float = 2

    /// Transient shaper in the insert chain. Off by default, bit-exact when off.
    public var transientEnabled: Bool = false
    public var transientAttack: Float = 0.0
    public var transientSustain: Float = 0.0
    public var transientOutput: Float = 1.0
    public var transientMix: Float = 1.0

    /// MPE (MIDI Polyphonic Expression) input mode. Off by default, bit-exact when off.
    public var mpeEnabled: Bool = false
    public var mpePitchBendRange: Float = 48.0
    public var mpeZone: MPEZone = .lower
    public var mpeMemberChannelCount: Int = 15

    /// Frequency shifter in FX (Bode single-sideband frequency shifter). Off by default.
    public var frequencyShifterEnabled: Bool = false
    public var frequencyShifterShiftHz: Float = 0.0
    public var frequencyShifterMix: Float = 0.5
    public var frequencyShifterFeedback: Float = 0.0

    /// Output character contour (Off / Warm / Bright). Off by default.
    public var character: CharacterMode = .off

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
        case stereoEnabled, stereoWidth, stereoMidSide, stereoHaasMs, stereoMonoBassHz
        case oscPhaseMode
        case polyphonyLimit
        case tranceGateEnabled, tranceGatePattern, tranceGateDepth, tranceGateSmooth, tranceGateDivision
        case perlinRate, perlinTempoSync, perlinSyncDivision
        case chorusFlanger, chorusFeedback, chorusFlangerSync, chorusFlangerDivision
        case filterFeedback
        case dspReverbEnabled, reverbDamping
        case osc2FixedFrequency, osc2FrequencyHz
        case sceneHPFEnabled, sceneHPFFrequency
        case chorusMode
        case fmRatioEnabled, fmCoarse, fmFine, fmRoute
        case filter2Routing, filter2Type, filter2Cutoff, filter2Resonance, filter2Balance
        case filterVowel
        case mseg
        case mseg2
        case attackCurve, decayCurve, releaseCurve
        case lfoStereoPhase, lfo2StereoPhase
        case frequencyShifterEnabled, frequencyShifterShiftHz, frequencyShifterMix, frequencyShifterFeedback
        case character
        case envFollowerAttack, envFollowerRelease
        case sendA, sendB, sendPostInsert
        case rotaryEnabled, rotaryFast, rotaryHornSlow, rotaryHornFast
        case rotaryDrumSlow, rotaryDrumFast, rotaryDrive, rotaryMix, rotaryAccel
        case macro5, macro6, macro7, macro8
        case randomSeed
        case transientEnabled, transientAttack, transientSustain, transientOutput, transientMix
        case userWavetableName, userWavetableData
        case mpeEnabled, mpePitchBendRange, mpeZone, mpeMemberChannelCount
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
        macro5: Float = 0.0,
        macro6: Float = 0.0,
        macro7: Float = 0.0,
        macro8: Float = 0.0,
        randomSeed: UInt32? = nil,
        userWavetableName: String? = nil,
        userWavetableData: Data? = nil,
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
        monoPriority: MonoPriority = .last,
        mpeEnabled: Bool = false,
        mpePitchBendRange: Float = 48.0,
        mpeZone: MPEZone = .lower,
        mpeMemberChannelCount: Int = 15
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
        self.macro5 = macro5
        self.macro6 = macro6
        self.macro7 = macro7
        self.macro8 = macro8
        self.randomSeed = randomSeed
        self.userWavetableName = userWavetableName
        self.userWavetableData = userWavetableData
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
        self.mpeEnabled = mpeEnabled
        self.mpePitchBendRange = mpePitchBendRange
        self.mpeZone = mpeZone
        self.mpeMemberChannelCount = mpeMemberChannelCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        category = c.tolerant(PresetCategory.self, forKey: .category) ?? .lead
        osc1Waveform = c.tolerant(WaveformType.self, forKey: .osc1Waveform) ?? .sawtooth
        osc1Volume = try c.decodeIfPresent(Float.self, forKey: .osc1Volume) ?? 0.7
        osc1Octave = try c.decodeIfPresent(Int.self, forKey: .osc1Octave) ?? 0
        osc1Detune = try c.decodeIfPresent(Float.self, forKey: .osc1Detune) ?? 0
        osc1PulseWidth = try c.decodeIfPresent(Float.self, forKey: .osc1PulseWidth) ?? 0.5
        osc1WavetableMorph = try c.decodeIfPresent(Float.self, forKey: .osc1WavetableMorph) ?? 0
        osc2Enabled = try c.decodeIfPresent(Bool.self, forKey: .osc2Enabled) ?? true
        osc2Waveform = c.tolerant(WaveformType.self, forKey: .osc2Waveform) ?? .square
        osc2Volume = try c.decodeIfPresent(Float.self, forKey: .osc2Volume) ?? 0.5
        osc2Octave = try c.decodeIfPresent(Int.self, forKey: .osc2Octave) ?? 0
        osc2Detune = try c.decodeIfPresent(Float.self, forKey: .osc2Detune) ?? 5
        osc2PulseWidth = try c.decodeIfPresent(Float.self, forKey: .osc2PulseWidth) ?? 0.5
        osc2WavetableMorph = try c.decodeIfPresent(Float.self, forKey: .osc2WavetableMorph) ?? 0
        attack = try c.decodeIfPresent(Float.self, forKey: .attack) ?? 0.01
        decay = try c.decodeIfPresent(Float.self, forKey: .decay) ?? 0.1
        sustain = try c.decodeIfPresent(Float.self, forKey: .sustain) ?? 0.7
        release = try c.decodeIfPresent(Float.self, forKey: .release) ?? 0.3
        filterType = c.tolerant(FilterType.self, forKey: .filterType) ?? .lowPass
        filterCutoff = try c.decodeIfPresent(Float.self, forKey: .filterCutoff) ?? 5000
        filterResonance = try c.decodeIfPresent(Float.self, forKey: .filterResonance) ?? 0.5
        filterEnvelopeAmount = try c.decodeIfPresent(Float.self, forKey: .filterEnvelopeAmount) ?? 0
        lfoEnabled = try c.decodeIfPresent(Bool.self, forKey: .lfoEnabled) ?? false
        lfoRate = try c.decodeIfPresent(Float.self, forKey: .lfoRate) ?? 5
        lfoDepth = try c.decodeIfPresent(Float.self, forKey: .lfoDepth) ?? 0.5
        lfoWaveform = c.tolerant(WaveformType.self, forKey: .lfoWaveform) ?? .sine
        lfoTarget = c.tolerant(LFOTarget.self, forKey: .lfoTarget) ?? .pitch
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
        // SYNT_21 R17-5: an entry with an unknown source/destination is dropped, not the preset.
        modMatrix = (c.tolerant([LossyDecodable<ModMatrixEntry>].self, forKey: .modMatrix) ?? []).compactMap(\.value)
        arpMode = c.tolerant(ArpeggiatorMode.self, forKey: .arpMode) ?? .off
        arpRate = c.tolerant(TimeDivision.self, forKey: .arpRate) ?? .sixteenth
        bpm = try c.decodeIfPresent(Float.self, forKey: .bpm) ?? 120
        sequencerData = try c.decodeIfPresent([SequencerStep].self, forKey: .sequencerData)
            ?? Array(repeating: SequencerStep(), count: 16)
        distortionEnabled = try c.decodeIfPresent(Bool.self, forKey: .distortionEnabled) ?? false
        distortionType = c.tolerant(DistortionType.self, forKey: .distortionType) ?? .softClip
        distortionDrive = try c.decodeIfPresent(Float.self, forKey: .distortionDrive) ?? 0.35
        distortionTone = try c.decodeIfPresent(Float.self, forKey: .distortionTone) ?? 0.5
        distortionMix = try c.decodeIfPresent(Float.self, forKey: .distortionMix) ?? 0.25
        eqEnabled = try c.decodeIfPresent(Bool.self, forKey: .eqEnabled) ?? false
        eqPreset = c.tolerant(EQPreset.self, forKey: .eqPreset) ?? .flat
        eqLowGain = try c.decodeIfPresent(Float.self, forKey: .eqLowGain) ?? 0
        eqLowFreq = try c.decodeIfPresent(Float.self, forKey: .eqLowFreq) ?? 100
        eqMidGain = try c.decodeIfPresent(Float.self, forKey: .eqMidGain) ?? 0
        eqMidFreq = try c.decodeIfPresent(Float.self, forKey: .eqMidFreq) ?? 1000
        eqMidQ = try c.decodeIfPresent(Float.self, forKey: .eqMidQ) ?? 1
        eqHighGain = try c.decodeIfPresent(Float.self, forKey: .eqHighGain) ?? 0
        eqHighFreq = try c.decodeIfPresent(Float.self, forKey: .eqHighFreq) ?? 8000
        phaserEnabled = try c.decodeIfPresent(Bool.self, forKey: .phaserEnabled) ?? false
        phaserMode = c.tolerant(PhaserMode.self, forKey: .phaserMode) ?? .phaser4
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
        subOscWaveform = c.tolerant(WaveformType.self, forKey: .subOscWaveform) ?? .sine
        fmAmount = try c.decodeIfPresent(Float.self, forKey: .fmAmount) ?? 0.0
        oscSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .oscSyncEnabled) ?? false
        lfoTempoSync = try c.decodeIfPresent(Bool.self, forKey: .lfoTempoSync) ?? false
        lfoSyncDivision = c.tolerant(TimeDivision.self, forKey: .lfoSyncDivision) ?? .quarter
        delayTempoSync = try c.decodeIfPresent(Bool.self, forKey: .delayTempoSync) ?? false
        delaySyncDivision = c.tolerant(TimeDivision.self, forKey: .delaySyncDivision) ?? .eighth
        lfo2Enabled = try c.decodeIfPresent(Bool.self, forKey: .lfo2Enabled) ?? false
        lfo2Rate = try c.decodeIfPresent(Float.self, forKey: .lfo2Rate) ?? 2.0
        lfo2Depth = try c.decodeIfPresent(Float.self, forKey: .lfo2Depth) ?? 0.5
        lfo2Waveform = c.tolerant(WaveformType.self, forKey: .lfo2Waveform) ?? .triangle
        lfo2Target = c.tolerant(LFOTarget.self, forKey: .lfo2Target) ?? .none
        lfo2TempoSync = try c.decodeIfPresent(Bool.self, forKey: .lfo2TempoSync) ?? false
        lfo2SyncDivision = c.tolerant(TimeDivision.self, forKey: .lfo2SyncDivision) ?? .eighth
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
        noiseColor = c.tolerant(NoiseColor.self, forKey: .noiseColor) ?? .white
        arpGateLength = try c.decodeIfPresent(Float.self, forKey: .arpGateLength) ?? 0.8
        arpSwing = try c.decodeIfPresent(Float.self, forKey: .arpSwing) ?? 0.0
        velocityToCutoff = try c.decodeIfPresent(Float.self, forKey: .velocityToCutoff) ?? 0.0
        velocityToEnvAmount = try c.decodeIfPresent(Float.self, forKey: .velocityToEnvAmount) ?? 0.0
        chordMode = c.tolerant(ChordMode.self, forKey: .chordMode) ?? .off
        macro1 = try c.decodeIfPresent(Float.self, forKey: .macro1) ?? 0.0
        macro2 = try c.decodeIfPresent(Float.self, forKey: .macro2) ?? 0.0
        macro3 = try c.decodeIfPresent(Float.self, forKey: .macro3) ?? 0.0
        macro4 = try c.decodeIfPresent(Float.self, forKey: .macro4) ?? 0.0
        macro5 = try c.decodeIfPresent(Float.self, forKey: .macro5) ?? 0.0
        macro6 = try c.decodeIfPresent(Float.self, forKey: .macro6) ?? 0.0
        macro7 = try c.decodeIfPresent(Float.self, forKey: .macro7) ?? 0.0
        macro8 = try c.decodeIfPresent(Float.self, forKey: .macro8) ?? 0.0
        randomSeed = try c.decodeIfPresent(UInt32.self, forKey: .randomSeed)
        userWavetableName = try c.decodeIfPresent(String.self, forKey: .userWavetableName)
        userWavetableData = try c.decodeIfPresent(Data.self, forKey: .userWavetableData)
        voiceMode = c.tolerant(VoiceMode.self, forKey: .voiceMode) ?? .poly
        syncSource = c.tolerant(SyncSource.self, forKey: .syncSource) ?? .`internal`
        filterDrive = try c.decodeIfPresent(Float.self, forKey: .filterDrive) ?? 0
        pan = try c.decodeIfPresent(Float.self, forKey: .pan) ?? 0.0
        // SYNT_22 R18-3: lossy — unknown slot IDs are dropped and missing default slots appended,
        // instead of one bad ID resetting the user's whole order.
        if let lossy = c.tolerant([LossyDecodable<FXSlotID>].self, forKey: .fxOrder) {
            fxOrder = Self.sanitizeFXOrder(lossy.compactMap(\.value))
        } else {
            fxOrder = FXSlotID.defaultOrder
        }
        lfoMode = c.tolerant(LFOMode.self, forKey: .lfoMode) ?? .free
        lfoStartPhase = try c.decodeIfPresent(Float.self, forKey: .lfoStartPhase) ?? 0.0
        lfo2Mode = c.tolerant(LFOMode.self, forKey: .lfo2Mode) ?? .free
        lfo2StartPhase = try c.decodeIfPresent(Float.self, forKey: .lfo2StartPhase) ?? 0.0
        arpLatch = try c.decodeIfPresent(Bool.self, forKey: .arpLatch) ?? false
        velocityCurve = c.tolerant(VelocityCurve.self, forKey: .velocityCurve) ?? .linear
        velocityToVolume = try c.decodeIfPresent(Float.self, forKey: .velocityToVolume) ?? 1.0
        modEnvAttack = try c.decodeIfPresent(Float.self, forKey: .modEnvAttack) ?? 0.01
        modEnvDecay = try c.decodeIfPresent(Float.self, forKey: .modEnvDecay) ?? 0.2
        modEnvSustain = try c.decodeIfPresent(Float.self, forKey: .modEnvSustain) ?? 0.0
        modEnvRelease = try c.decodeIfPresent(Float.self, forKey: .modEnvRelease) ?? 0.1
        glideMode = c.tolerant(GlideMode.self, forKey: .glideMode) ?? .time
        glideLegatoOnly = try c.decodeIfPresent(Bool.self, forKey: .glideLegatoOnly) ?? false
        monoPriority = c.tolerant(MonoPriority.self, forKey: .monoPriority) ?? .last
        stereoEnabled = try c.decodeIfPresent(Bool.self, forKey: .stereoEnabled) ?? false
        stereoWidth = try c.decodeIfPresent(Float.self, forKey: .stereoWidth) ?? 1
        stereoMidSide = try c.decodeIfPresent(Float.self, forKey: .stereoMidSide) ?? 0
        stereoHaasMs = try c.decodeIfPresent(Float.self, forKey: .stereoHaasMs) ?? 0
        stereoMonoBassHz = try c.decodeIfPresent(Float.self, forKey: .stereoMonoBassHz) ?? 0
        oscPhaseMode = c.tolerant(OscPhaseMode.self, forKey: .oscPhaseMode) ?? .reset
        polyphonyLimit = try c.decodeIfPresent(Int.self, forKey: .polyphonyLimit) ?? 32
        tranceGateEnabled = try c.decodeIfPresent(Bool.self, forKey: .tranceGateEnabled) ?? false
        tranceGatePattern = try c.decodeIfPresent(UInt16.self, forKey: .tranceGatePattern) ?? 0xAAAA
        tranceGateDepth = try c.decodeIfPresent(Float.self, forKey: .tranceGateDepth) ?? 1
        tranceGateSmooth = try c.decodeIfPresent(Float.self, forKey: .tranceGateSmooth) ?? 0
        tranceGateDivision = c.tolerant(TimeDivision.self, forKey: .tranceGateDivision) ?? .sixteenth
        perlinRate = try c.decodeIfPresent(Float.self, forKey: .perlinRate) ?? 1
        perlinTempoSync = try c.decodeIfPresent(Bool.self, forKey: .perlinTempoSync) ?? false
        perlinSyncDivision = c.tolerant(TimeDivision.self, forKey: .perlinSyncDivision) ?? .quarter
        chorusFlanger = try c.decodeIfPresent(Bool.self, forKey: .chorusFlanger) ?? false
        chorusFeedback = try c.decodeIfPresent(Float.self, forKey: .chorusFeedback) ?? 0
        chorusFlangerSync = try c.decodeIfPresent(Bool.self, forKey: .chorusFlangerSync) ?? false
        chorusFlangerDivision = c.tolerant(TimeDivision.self, forKey: .chorusFlangerDivision) ?? .quarter
        filterFeedback = try c.decodeIfPresent(Float.self, forKey: .filterFeedback) ?? 0
        dspReverbEnabled = try c.decodeIfPresent(Bool.self, forKey: .dspReverbEnabled) ?? false
        reverbDamping = try c.decodeIfPresent(Float.self, forKey: .reverbDamping) ?? 0.4
        osc2FixedFrequency = try c.decodeIfPresent(Bool.self, forKey: .osc2FixedFrequency) ?? false
        osc2FrequencyHz = try c.decodeIfPresent(Float.self, forKey: .osc2FrequencyHz) ?? 440
        sceneHPFEnabled = try c.decodeIfPresent(Bool.self, forKey: .sceneHPFEnabled) ?? false
        sceneHPFFrequency = try c.decodeIfPresent(Float.self, forKey: .sceneHPFFrequency) ?? 120
        chorusMode = c.tolerant(ChorusMode.self, forKey: .chorusMode) ?? .standard
        fmRatioEnabled = try c.decodeIfPresent(Bool.self, forKey: .fmRatioEnabled) ?? false
        fmCoarse = try c.decodeIfPresent(Int.self, forKey: .fmCoarse) ?? 1
        fmFine = try c.decodeIfPresent(Float.self, forKey: .fmFine) ?? 0
        fmRoute = c.tolerant(FMRoute.self, forKey: .fmRoute) ?? .osc2ToOsc1
        filter2Routing = c.tolerant(DualFilterRouting.self, forKey: .filter2Routing) ?? .off
        filter2Type = c.tolerant(FilterType.self, forKey: .filter2Type) ?? .lowPass
        filter2Cutoff = try c.decodeIfPresent(Float.self, forKey: .filter2Cutoff) ?? 2000
        filter2Resonance = try c.decodeIfPresent(Float.self, forKey: .filter2Resonance) ?? 0.2
        filter2Balance = try c.decodeIfPresent(Float.self, forKey: .filter2Balance) ?? 0.5
        filterVowel = try c.decodeIfPresent(Float.self, forKey: .filterVowel) ?? 0
        mseg = c.tolerant(MSEGPreset.self, forKey: .mseg) ?? MSEGPreset()
        mseg2 = c.tolerant(MSEGPreset.self, forKey: .mseg2) ?? MSEGPreset()
        attackCurve = try c.decodeIfPresent(Float.self, forKey: .attackCurve) ?? 0
        decayCurve = try c.decodeIfPresent(Float.self, forKey: .decayCurve) ?? 0
        releaseCurve = try c.decodeIfPresent(Float.self, forKey: .releaseCurve) ?? 0
        lfoStereoPhase = try c.decodeIfPresent(Float.self, forKey: .lfoStereoPhase) ?? 0
        lfo2StereoPhase = try c.decodeIfPresent(Float.self, forKey: .lfo2StereoPhase) ?? 0
        frequencyShifterEnabled = try c.decodeIfPresent(Bool.self, forKey: .frequencyShifterEnabled) ?? false
        frequencyShifterShiftHz = try c.decodeIfPresent(Float.self, forKey: .frequencyShifterShiftHz) ?? 0.0
        frequencyShifterMix = try c.decodeIfPresent(Float.self, forKey: .frequencyShifterMix) ?? 0.5
        frequencyShifterFeedback = try c.decodeIfPresent(Float.self, forKey: .frequencyShifterFeedback) ?? 0.0
        character = c.tolerant(CharacterMode.self, forKey: .character) ?? .off
        envFollowerAttack = try c.decodeIfPresent(Float.self, forKey: .envFollowerAttack) ?? 0.01
        envFollowerRelease = try c.decodeIfPresent(Float.self, forKey: .envFollowerRelease) ?? 0.05
        sendA = try c.decodeIfPresent(Float.self, forKey: .sendA) ?? 0
        sendB = try c.decodeIfPresent(Float.self, forKey: .sendB) ?? 0
        sendPostInsert = try c.decodeIfPresent(Bool.self, forKey: .sendPostInsert) ?? false
        rotaryEnabled = try c.decodeIfPresent(Bool.self, forKey: .rotaryEnabled) ?? false
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .rotaryFast) {
            rotaryFast = b
        } else if let f = try? c.decodeIfPresent(Float.self, forKey: .rotaryFast) {
            rotaryFast = f >= 0.5
        } else {
            rotaryFast = false
        }
        rotaryHornSlow = try c.decodeIfPresent(Float.self, forKey: .rotaryHornSlow) ?? 0.7
        rotaryHornFast = try c.decodeIfPresent(Float.self, forKey: .rotaryHornFast) ?? 6.8
        rotaryDrumSlow = try c.decodeIfPresent(Float.self, forKey: .rotaryDrumSlow) ?? 0.55
        rotaryDrumFast = try c.decodeIfPresent(Float.self, forKey: .rotaryDrumFast) ?? 5.2
        rotaryDrive = try c.decodeIfPresent(Float.self, forKey: .rotaryDrive) ?? 0
        rotaryMix = try c.decodeIfPresent(Float.self, forKey: .rotaryMix) ?? 1
        rotaryAccel = try c.decodeIfPresent(Float.self, forKey: .rotaryAccel) ?? 2
        transientEnabled = try c.decodeIfPresent(Bool.self, forKey: .transientEnabled) ?? false
        transientAttack = try c.decodeIfPresent(Float.self, forKey: .transientAttack) ?? 0.0
        transientSustain = try c.decodeIfPresent(Float.self, forKey: .transientSustain) ?? 0.0
        transientOutput = try c.decodeIfPresent(Float.self, forKey: .transientOutput) ?? 1.0
        transientMix = try c.decodeIfPresent(Float.self, forKey: .transientMix) ?? 1.0
        mpeEnabled = try c.decodeIfPresent(Bool.self, forKey: .mpeEnabled) ?? false
        mpePitchBendRange = try c.decodeIfPresent(Float.self, forKey: .mpePitchBendRange) ?? 48.0
        // SYNT_20 audit P3-9: an unknown zone (newer/foreign preset) falls back to .lower instead of
        // failing the whole preset.
        mpeZone = c.tolerant(MPEZone.self, forKey: .mpeZone) ?? .lower
        mpeMemberChannelCount = try c.decodeIfPresent(Int.self, forKey: .mpeMemberChannelCount) ?? 15
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

public enum VoiceMode: String, CaseIterable, Codable, Sendable {
    case poly = "Poly"
    case mono = "Mono"
    case legato = "Legato"
}

/// Oscillator start phase. `.reset` is the historical `voiceStartPhases` path.
public enum OscPhaseMode: String, CaseIterable, Codable, Sendable {
    case reset = "Reset"
    case free = "Free"
    case random = "Random"
    /// New seed on every trigger. Appended so stored "Random" stays the note hash.
    case randomPerNote = "Random Per Note"
}

public enum NoiseColor: String, CaseIterable, Codable, Sendable {
    case white = "White"
    case pink = "Pink"
    case brown = "Brown"
}

public enum ChordMode: String, CaseIterable, Codable, Sendable {
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

public enum FilterType: String, CaseIterable, Codable, Sendable {
    case lowPass = "Low Pass"
    case highPass = "High Pass"
    case bandPass = "Band Pass"
    case notch = "Notch"
    case ladder = "Ladder"
    /// Vowel bank. Appended so the earlier filter indices stay put.
    case formant = "Formant"
    /// Comb filter / resonator. Appended at end so existing filter indices stay put.
    case comb = "Comb"
}

public enum LFOTarget: String, CaseIterable, Codable, Sendable {
    case pitch = "Pitch"
    case filter = "Filter"
    case amplitude = "Amplitude"
    case pan = "Pan"
    /// The oscillator still runs for matrix rows. It does not move a direct target.
    case none = "Matrix only"
}

public enum ModCurve: String, Codable, CaseIterable, Sendable {
    case linear
    case exponential
    case logarithmic
    case sCurve
    case steps

    public var menuTitle: String {
        switch self {
        case .linear: return "Lin"
        case .exponential: return "Exp"
        case .logarithmic: return "Log"
        case .sCurve: return "S"
        case .steps: return "Steps"
        }
    }

    /// Maps a source in −1...1. Linear is not tabulated.
    public func remap(_ x: Float) -> Float {
        if self == .linear { return x }
        let clamped = max(-1, min(1, x))
        let mag = abs(clamped)
        let sign: Float = clamped < 0 ? -1 : 1
        switch self {
        case .linear:
            return clamped
        case .exponential:
            return sign * mag * mag
        case .logarithmic:
            return sign * sqrt(mag)
        case .sCurve:
            return sign * (mag * mag * (3 - 2 * mag))
        case .steps:
            return sign * min(floor(mag * 8) / 8, 1)
        }
    }
}

public struct ModMatrixEntry: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var source: ModSource
    public var destination: ModDestination
    public var amount: Float
    public var curve: ModCurve = .linear

    public init(
        id: UUID = UUID(),
        source: ModSource,
        destination: ModDestination,
        amount: Float,
        curve: ModCurve = .linear
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.amount = amount
        self.curve = curve
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, destination, amount, curve
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        source = try c.decode(ModSource.self, forKey: .source)
        destination = try c.decode(ModDestination.self, forKey: .destination)
        amount = try c.decodeIfPresent(Float.self, forKey: .amount) ?? 0
        curve = try c.decodeIfPresent(ModCurve.self, forKey: .curve) ?? .linear
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(source, forKey: .source)
        try c.encode(destination, forKey: .destination)
        try c.encode(amount, forKey: .amount)
        try c.encode(curve, forKey: .curve)
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
    case smoothRandom = "Smooth Random"
    /// Multi-stage envelope. Appended so earlier sources keep their order.
    case mseg = "MSEG 1"
    /// Envelope Follower (tracks audio signal amplitude). Appended so earlier sources keep order.
    case envelopeFollower = "Env Follower"
    /// MSEG 2 (second multi-stage envelope).
    case mseg2 = "MSEG 2"
    case macro5 = "Macro 5"
    case macro6 = "Macro 6"
    case macro7 = "Macro 7"
    case macro8 = "Macro 8"
    /// Per-voice MPE modulation sources
    case mpePitchBend = "MPE Pitch Bend"
    case mpePressure = "MPE Pressure"
    case mpeTimbre = "MPE Timbre"
}

public enum MPEZone: String, CaseIterable, Codable, Sendable {
    case lower = "Lower"
    case upper = "Upper"
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

public enum FMRoute: String, Codable, CaseIterable, Sendable {
    case osc2ToOsc1 = "OSC2 to OSC1"
    case osc1ToOsc2 = "OSC1 to OSC2"
}

public enum ChorusMode: String, Codable, CaseIterable, Sendable {
    case standard = "Chorus"
    case flanger = "Flanger"
    case ensemble = "Ensemble"
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
    case finePitch = "Fine Pitch"
    case fm = "FM"
    case chorusMix = "Chorus Mix"
    case delayMix = "Delay Mix"
    case reverbMix = "Reverb Mix"
    /// Formant vowel, 0…4. Appended so earlier destinations keep their order.
    case vowel = "Vowel"

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
        case .finePitch: return "Fine"
        case .fm: return "FM"
        case .chorusMix: return "Chorus"
        case .delayMix: return "Delay"
        case .reverbMix: return "Reverb"
        case .vowel: return "Vowel"
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
        case .finePitch:
            return String(format: "%+.0f ct", amount * 100)
        case .fm, .chorusMix, .delayMix, .reverbMix:
            return String(format: "%+.0f %%", amount * 100)
        case .vowel:
            return String(format: "%+.2f", amount * 4)
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

// MARK: - SYNT_21 R17-5: tolerant decoding
// An unknown enum case (preset from a newer build or another tool) falls back to the field's
// default instead of failing the whole preset. `try?` also maps a type mismatch for that key to
// the default. The encoded format is unchanged, so `stateVersion` stays 1.
extension KeyedDecodingContainer {
    func tolerant<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            // SYNT_22 R18-4: the fallback to default is no longer silent (DEBUG only).
            TolerantDecodeLog.record(key: key.stringValue, error: error)
            return nil
        }
    }
}

struct LossyDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}


/// SYNT_22 R18-4: DEBUG-only diagnostics when a tolerant preset decode falls back to a default.
/// Release builds do nothing (no logging, no counting).
enum TolerantDecodeLog {
    #if DEBUG
    private static let lock = NSLock()
    nonisolated(unsafe) private static var keys: [String] = []
    static let maxKeys = 256
    static func record(key: String, error: Error) {
        // SYNT_24 R19-5: bounded — keep the newest `maxKeys` entries.
        lock.lock()
        if keys.count >= maxKeys { keys.removeFirst(keys.count - maxKeys + 1) }
        keys.append(key)
        lock.unlock()
        print("[SynthPreset] tolerant decode fell back to default for '\(key)': \(error)")
    }
    static func fallbackKeysForTesting() -> [String] { lock.lock(); defer { lock.unlock() }; return keys }
    static func resetForTesting() { lock.lock(); keys.removeAll(); lock.unlock() }
    #else
    @inline(__always) static func record(key: String, error: Error) {}
    #endif
}
