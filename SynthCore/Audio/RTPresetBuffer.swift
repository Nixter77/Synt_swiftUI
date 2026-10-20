//
//  RTPresetBuffer.swift
//  SynthCore
//
//  Lock-free double-buffered preset snapshot for real-time audio thread.
//  Main/host thread publishes a snapshot; render thread pulls at buffer boundary.
//  Zero ARC, zero allocations on the audio path.
//

import Foundation
import Synchronization

public struct RTPresetSnapshot: Sendable {
    // Oscillator 1
    public var osc1Waveform: WaveformType = .sawtooth
    public var osc1Volume: Float = 0.7
    public var osc1Octave: Int = 0
    public var osc1Detune: Float = 0.0
    public var osc1PulseWidth: Float = 0.5
    public var osc1WavetableMorph: Float = 0.0
    public var osc1WavetableIndex: Int = 0

    // Oscillator 2
    public var osc2Enabled: Bool = true
    public var osc2Waveform: WaveformType = .square
    public var osc2Volume: Float = 0.5
    public var osc2Octave: Int = 0
    public var osc2Detune: Float = 5.0
    public var osc2PulseWidth: Float = 0.5
    public var osc2WavetableMorph: Float = 0.0
    public var osc2WavetableIndex: Int = 0

    // Sub Osc & FM & Ring & Noise
    public var subOscVolume: Float = 0.0
    public var subOscOctave: Int = -1
    public var subOscWaveform: WaveformType = .sine
    public var fmAmount: Float = 0.0
    public var oscSyncEnabled: Bool = false
    public var ringModAmount: Float = 0.0
    public var noiseColor: NoiseColor = .white

    // Envelopes
    public var attack: Float = 0.01
    public var decay: Float = 0.1
    public var sustain: Float = 0.7
    public var release: Float = 0.3

    public var filterAttack: Float = 0.01
    public var filterDecay: Float = 0.3
    public var filterSustain: Float = 0.0
    public var filterRelease: Float = 0.3
    public var filterEnvUseDedicatedADSR: Bool = false
    public var modEnvAttack: Float = 0.01
    public var modEnvDecay: Float = 0.2
    public var modEnvSustain: Float = 0.0
    public var modEnvRelease: Float = 0.1

    // Filter
    public var filterType: FilterType = .lowPass
    public var filterCutoff: Float = 5000.0
    public var filterResonance: Float = 0.5
    public var filterDrive: Float = 0.0
    public var filterEnvAmount: Float = 0.0
    public var filterKeyTracking: Float = 0.0
    public var velocityToCutoff: Float = 0.0
    public var velocityToEnvAmount: Float = 0.0

    // LFO 1
    public var lfoEnabled: Bool = true
    public var lfoTempoSync: Bool = false
    public var lfoSyncDivision: TimeDivision = .quarter
    public var lfoRate: Float = 2.0
    public var lfoDepth: Float = 0.0
    public var lfoRowsFollowDepth: Bool = false
    public var lfoWaveform: WaveformType = .triangle
    public var lfoTarget: LFOTarget = .none
    public var lfoMode: LFOMode = .free
    public var lfoStartPhase: Float = 0.0

    // LFO 2
    public var lfo2Enabled: Bool = false
    public var lfo2TempoSync: Bool = false
    public var lfo2SyncDivision: TimeDivision = .eighth
    public var lfo2Rate: Float = 2.0
    public var lfo2Depth: Float = 0.5
    public var lfo2Waveform: WaveformType = .triangle
    public var lfo2Target: LFOTarget = .none
    public var lfo2Mode: LFOMode = .free
    public var lfo2StartPhase: Float = 0.0

    // Performance
    public var pitchBendRange: Float = 2.0
    public var masterVolume: Float = 0.8
    public var bpm: Float = 120.0
    public var pan: Float = 0.0
    public var portamento: Float = 0.0
    public var unisonVoices: Int = 1
    public var unisonDetune: Float = 0.0
    public var unisonSpread: Float = 0.0
    public var analogDrift: Float = 0.0
    public var chordMode: ChordMode = .off
    public var voiceMode: VoiceMode = .poly
    public var syncSource: SyncSource = .`internal`
    public var arpMode: ArpeggiatorMode = .off
    public var arpRate: TimeDivision = .sixteenth
    public var arpOctaves: Int = 1
    public var arpGateLength: Float = 0.8
    public var arpSwing: Float = 0.0
    public var arpLatch: Bool = false
    public var velocityCurve: VelocityCurve = .linear
    public var velocityToVolume: Float = 1.0
    public var glideMode: GlideMode = .time
    public var glideLegatoOnly: Bool = false
    public var monoPriority: MonoPriority = .last
    public var stereoEnabled: Bool = false
    public var stereoWidth: Float = 1
    public var stereoMidSide: Float = 0
    public var stereoHaasMs: Float = 0
    public var stereoMonoBassHz: Float = 0
    public var oscPhaseMode: OscPhaseMode = .reset
    public var polyphonyLimit: Int = 32
    public var macro1: Float = 0.0
    public var macro2: Float = 0.0
    public var macro3: Float = 0.0
    public var macro4: Float = 0.0

    // Effects
    public var reverbMix: Float = 0.0
    public var reverbRoomSize: Float = 0.5
    public var reverbShimmer: Float = 0.0
    public var chorusRate: Float = 0.8
    public var chorusDepth: Float = 0.2
    public var chorusMix: Float = 0.0
    public var chorusStereo: Bool = true

    public var delayTime: Float = 0.3
    public var delayFeedback: Float = 0.3
    public var delayMix: Float = 0.0
    public var delayPingPong: Bool = false
    public var rendersAllDelayInDSP: Bool = false
    public var delayTempoSync: Bool = false
    public var delaySyncDivision: TimeDivision = .eighth
    public var delayEffectiveTime: Float = 0.3

    public var distortionEnabled: Bool = false
    public var distortionType: DistortionType = .softClip
    public var distortionDrive: Float = 0.35
    public var distortionTone: Float = 0.5
    public var distortionMix: Float = 0.25
    public var distortionOversampling: Bool = false

    public var eqEnabled: Bool = false
    public var eqLowGain: Float = 0.0
    public var eqMidGain: Float = 0.0
    public var eqHighGain: Float = 0.0
    public var eqLowFreq: Float = 100.0
    public var eqMidFreq: Float = 1000.0
    public var eqHighFreq: Float = 8000.0
    public var eqMidQ: Float = 1.0

    public var phaserEnabled: Bool = false
    public var phaserMode: PhaserMode = .phaser4
    public var phaserRate: Float = 0.4
    public var phaserDepth: Float = 0.55
    public var phaserFeedback: Float = 0.25
    public var phaserCenterFrequency: Float = 800.0
    public var phaserStereoSpread: Float = 0.5
    public var phaserMix: Float = 0.4
    public var fxOrder: FXOrderTable = FXOrderTable()

    public init() {}

    public init(from preset: SynthPreset, rendersAllDelayInDSP: Bool) {
        osc1Waveform = preset.osc1Waveform
        osc1Volume = preset.osc1Volume
        osc1Octave = preset.osc1Octave
        osc1Detune = preset.osc1Detune
        osc1PulseWidth = preset.osc1PulseWidth
        osc1WavetableMorph = max(0, min(1, preset.osc1WavetableMorph))
        osc1WavetableIndex = preset.osc1WavetableIndex

        osc2Enabled = preset.osc2Enabled
        osc2Waveform = preset.osc2Waveform
        osc2Volume = preset.osc2Volume
        osc2Octave = preset.osc2Octave
        osc2Detune = preset.osc2Detune
        osc2PulseWidth = preset.osc2PulseWidth
        osc2WavetableMorph = max(0, min(1, preset.osc2WavetableMorph))
        osc2WavetableIndex = preset.osc2WavetableIndex

        subOscVolume = max(0, min(1, preset.subOscVolume))
        subOscOctave = preset.subOscOctave == -2 ? -2 : -1
        subOscWaveform = preset.subOscWaveform
        fmAmount = max(0, min(1, preset.fmAmount))
        oscSyncEnabled = preset.oscSyncEnabled
        ringModAmount = max(0, min(1, preset.ringModAmount))
        noiseColor = preset.noiseColor

        attack = preset.attack
        decay = preset.decay
        sustain = preset.sustain
        release = preset.release

        filterAttack = preset.filterAttack
        filterDecay = preset.filterDecay
        filterSustain = preset.filterSustain
        filterRelease = preset.filterRelease
        filterEnvUseDedicatedADSR = preset.filterEnvUseDedicatedADSR
        modEnvAttack = preset.modEnvAttack
        modEnvDecay = preset.modEnvDecay
        modEnvSustain = preset.modEnvSustain
        modEnvRelease = preset.modEnvRelease

        filterType = preset.filterType
        filterCutoff = preset.filterCutoff
        filterResonance = preset.filterResonance
        filterDrive = min(1, max(0, preset.filterDrive))
        filterEnvAmount = max(-1, min(1, preset.filterEnvelopeAmount))
        filterKeyTracking = max(0, min(1, preset.filterKeyTracking))
        velocityToCutoff = max(0, min(1, preset.velocityToCutoff))
        velocityToEnvAmount = max(-1, min(1, preset.velocityToEnvAmount))

        lfoEnabled = preset.lfoEnabled
        lfoTempoSync = preset.lfoTempoSync
        lfoSyncDivision = preset.lfoSyncDivision
        lfoRate = preset.lfoTempoSync ? preset.lfoSyncDivision.frequency(bpm: preset.bpm) : preset.lfoRate
        lfoDepth = preset.lfoDepth
        lfoRowsFollowDepth = preset.lfoRowsFollowDepth
        lfoWaveform = preset.lfoWaveform
        lfoTarget = preset.lfoTarget

        lfo2Enabled = preset.lfo2Enabled
        lfo2TempoSync = preset.lfo2TempoSync
        lfo2SyncDivision = preset.lfo2SyncDivision
        lfo2Rate = preset.lfo2TempoSync ? preset.lfo2SyncDivision.frequency(bpm: preset.bpm) : preset.lfo2Rate
        lfo2Depth = preset.lfo2Depth
        lfo2Waveform = preset.lfo2Waveform
        lfo2Target = preset.lfo2Target

        pitchBendRange = max(0, preset.pitchBendRange)
        masterVolume = preset.masterVolume
        bpm = preset.bpm
        pan = preset.pan
        portamento = preset.portamento
        unisonVoices = preset.unisonVoices
        unisonDetune = preset.unisonDetune
        unisonSpread = preset.unisonSpread
        analogDrift = max(0, min(1, preset.analogDrift))
        chordMode = preset.chordMode
        voiceMode = preset.voiceMode
        syncSource = preset.syncSource
        arpMode = preset.arpMode
        arpRate = preset.arpRate
        arpOctaves = max(1, min(3, preset.arpOctaves))
        arpGateLength = max(0.1, min(1.0, preset.arpGateLength))
        arpSwing = max(0.0, min(0.75, preset.arpSwing))
        arpLatch = preset.arpLatch
        velocityCurve = preset.velocityCurve
        velocityToVolume = preset.velocityToVolume
        glideMode = preset.glideMode
        glideLegatoOnly = preset.glideLegatoOnly
        monoPriority = preset.monoPriority
        stereoEnabled = preset.stereoEnabled
        stereoWidth = max(0, min(2, preset.stereoWidth))
        stereoMidSide = max(-1, min(1, preset.stereoMidSide))
        stereoHaasMs = max(0, min(30, preset.stereoHaasMs))
        stereoMonoBassHz = max(0, min(400, preset.stereoMonoBassHz))
        oscPhaseMode = preset.oscPhaseMode
        let limit = preset.polyphonyLimit
        polyphonyLimit = limit < 1 ? 32 : min(32, limit)
        lfoMode = preset.lfoMode
        lfoStartPhase = preset.lfoStartPhase
        lfo2Mode = preset.lfo2Mode
        lfo2StartPhase = preset.lfo2StartPhase
        macro1 = preset.macro1
        macro2 = preset.macro2
        macro3 = preset.macro3
        macro4 = preset.macro4

        reverbMix = preset.reverbMix
        reverbRoomSize = preset.reverbRoomSize
        reverbShimmer = preset.reverbShimmer
        chorusRate = preset.chorusRate
        chorusDepth = preset.chorusDepth
        chorusMix = preset.chorusMix
        chorusStereo = preset.chorusStereo

        let effDelay: Float
        if preset.delayTempoSync {
            let dur = preset.delaySyncDivision.duration(bpm: preset.bpm)
            effDelay = max(0.001, min(2.0, dur))
        } else {
            effDelay = preset.delayTime
        }
        delayEffectiveTime = effDelay
        delayTime = preset.delayTime
        delayFeedback = preset.delayFeedback
        delayMix = preset.delayMix
        delayPingPong = preset.delayPingPong
        self.rendersAllDelayInDSP = rendersAllDelayInDSP
        delayTempoSync = preset.delayTempoSync
        delaySyncDivision = preset.delaySyncDivision

        distortionEnabled = preset.distortionEnabled
        distortionType = preset.distortionType
        distortionDrive = preset.distortionDrive
        distortionTone = preset.distortionTone
        distortionMix = preset.distortionMix
        distortionOversampling = preset.distortionOversampling

        eqEnabled = preset.eqEnabled
        eqLowGain = preset.eqLowGain
        eqMidGain = preset.eqMidGain
        eqHighGain = preset.eqHighGain
        eqLowFreq = preset.eqLowFreq
        eqMidFreq = preset.eqMidFreq
        eqHighFreq = preset.eqHighFreq
        eqMidQ = preset.eqMidQ

        phaserEnabled = preset.phaserEnabled
        phaserMode = preset.phaserMode
        phaserRate = preset.phaserRate
        phaserDepth = preset.phaserDepth
        phaserFeedback = preset.phaserFeedback
        phaserCenterFrequency = preset.phaserCenterFrequency
        phaserStereoSpread = preset.phaserStereoSpread
        phaserMix = preset.phaserMix
        fxOrder = FXOrderTable(order: preset.fxOrder)
    }
}

public final class RTPresetBuffer: @unchecked Sendable {
    private let buffers: UnsafeMutablePointer<RTPresetSnapshot>
    private let active = Atomic<Int>(0)
    private let pending = Atomic<Bool>(false)

    public init() {
        buffers = .allocate(capacity: 2)
        buffers.initialize(to: RTPresetSnapshot())
        (buffers + 1).initialize(to: RTPresetSnapshot())
    }

    deinit {
        buffers.deinitialize(count: 2)
        buffers.deallocate()
    }

    /// Thread-safe. Called from main or host thread.
    public func publish(_ snapshot: RTPresetSnapshot) {
        let target = 1 - active.load(ordering: .acquiring)
        buffers[target] = snapshot
        active.store(target, ordering: .releasing)
        pending.store(true, ordering: .releasing)
    }

    /// Audio thread only. Pulls the latest snapshot at buffer boundary if pending.
    @inline(__always)
    public func pullNewSnapshot() -> RTPresetSnapshot? {
        guard pending.exchange(false, ordering: .acquiringAndReleasing) else { return nil }
        let idx = active.load(ordering: .acquiring)
        return buffers[idx]
    }
}
