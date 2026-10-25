//
//  AudioEngine.swift
//  Synt_swiftUI
//
//  Real-time audio render path rules:
//  - No NSLock / notesLock in generateSample
//  - No DispatchQueue.main from generateSample
//  - No direct preset.<field> reads on the audio path (use caches only)
//  - Note on/off via AudioCommandQueue; metering via AtomicMeteringState + UI poll
//

import AVFoundation
import AudioToolbox
import Combine
import os
import SwiftUI
import Synchronization

public final class PressedKeysModel: ObservableObject {
    @Published public var keys: Set<Int> = []
    public init() {}
}

public struct ActiveParameterRamp: Sendable {
    public var id: UInt64 = 0
    public var currentValue: Float = 0
    public var targetValue: Float = 0
    public var stepPerFrame: Float = 0
    public var remainingFrames: Int = 0
    public var startOffset: Int = 0
    public var active: Bool = false

    public init() {}
    public init(
        id: UInt64,
        currentValue: Float,
        targetValue: Float,
        stepPerFrame: Float,
        remainingFrames: Int,
        startOffset: Int,
        active: Bool
    ) {
        self.id = id
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.stepPerFrame = stepPerFrame
        self.remainingFrames = remainingFrames
        self.startOffset = startOffset
        self.active = active
    }
}

public struct MPEChannelState: Sendable {
    public var pitchBend: Float = 0.0
    public var pitchBendMultiplier: Double = 1.0
    public var pressure: Float = 0.0
    public var timbre: Float = 0.0

    public init() {}
}

public final class AudioEngine: ObservableObject, @unchecked Sendable {
    private static let log = Logger(subsystem: "Home.Synt-swiftUI", category: "AudioEngine")
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    public let reverb = ReverbEffect()
    public let delay = DelayEffect()
    public let dspChorus = DSPChorus()
    public let stereoTool = DSPStereoTool()
    /// After Apple Reverb, before the mixer. Pre-gain 0, so levels under 0 dBFS stay put.
    public let peakLimiter = AudioEngine.makePeakLimiter()
    /// Fixed 0.62 headroom in front of the limiter, so the limiter is truly last.
    public let headroomMixer = AVAudioMixerNode()
    public static let postFXHeadroom: Float = 0.62

    // Stage 4 advanced FX — disabled by default so factory sound is unchanged.
    public let distortion = Distortion()
    public let parametricEQL = ParametricEQ(sampleRate: 44100)
    public let parametricEQR = ParametricEQ(sampleRate: 44100)
    public let phaser = Phaser(sampleRate: 44100)
    public let pingPongDelay = PingPongDelay(sampleRate: 44100)
    public let shimmer = ShimmerProcessor(sampleRate: 44100)
    /// Used only while `cachedDSPReverb` is on. Allocate from `prepare` / the AU.
    public let dspReverb = DSPReverb()
    /// Parallel send buses. Idle while the send levels are 0, so the insert chain stays bit-exact.
    public let sendReverb = DSPReverb()
    public let sendDelay = PingPongDelay(sampleRate: 44100)
    /// Leslie rotor. Skipped while `cachedRotaryEnabled` is false.
    public let rotary = DSPRotary(sampleRate: 44100)
    public let transientShaper = DSPTransientShaper(sampleRate: 44100)
    public let sceneHPF = SceneHPF()

    @Published public var isPlaying = false
    /// SYNT_23 R14-10: re-entrancy guard for `applyPreset`. Main thread only (plain var by design).
    var applyPresetInProgress = false
    /// SYNT_26 R22-1: true only inside `init`. The engine is not yet published to any other
    /// thread, so the initial apply may run on whatever thread builds it (AU hosts: XPC queue).
    /// Init-only: written before `self` escapes, never touched afterwards off the init thread.
    var isConstructing = false
    /// Main thread only, like `applyPresetInProgress`.
    var applyPresetRerunPending = false
    /// SYNT_24 R20-2: max applyPreset passes per outer call (1 + 3 coalesced reruns).
    static let applyPresetMaxPasses = 4
    #if DEBUG
    // SYNT_24 R20-3: test counters exist only in DEBUG builds.
    public var applyPresetCallCountForTesting: Int = 0
    public var applyPresetCoalescedCountForTesting: Int = 0
    public var applyPresetOffMainCountForTesting: Int = 0
    /// R20-2: outer calls that stopped at the pass cap with a rerun still pending.
    public var applyPresetCapHitCountForTesting: Int = 0
    /// R20-2: tests that hit the cap on purpose turn the assertion off.
    public var applyPresetCapAssertEnabled = true
    /// R20-2: invoked at the start of every pass (test-only re-entry source).
    public var applyPresetPassHookForTesting: (() -> Void)?
    /// R20-3: hard main-thread check for applyPreset — on by default in DEBUG (SYNT_25).
    /// Skipped while the engine is still being constructed (SYNT_26 R22-1).
    nonisolated(unsafe) public static var strictMainThreadApplyPreset = true
    #endif

    @Published private var _storedPreset: SynthPreset = .defaultPreset {
        didSet { storedPresetDidChange?(_storedPreset) }
    }
    /// SYNT_27 P2-2: called (main thread) after every `preset` change, including display-only
    /// edits. The AU keeps its any-thread preset mirror current through it.
    var storedPresetDidChange: ((SynthPreset) -> Void)?
    /// SYNT_27 P2-1: serializes the whole set of render publications (preset snapshot, MSEG 1/2,
    /// mod matrix) so two writers cannot interleave and leave render with a mixed pair.
    /// Render never takes it.
    let presetPublicationLock = Mutex(())

    public var preset: SynthPreset {
        get { _storedPreset }
        set {
            _storedPreset = newValue
            applyPreset()
        }
    }

    /// Explicit path to mutate the stored display preset without triggering applyPreset().
    public func updatePresetDisplayOnly(_ mutate: (inout SynthPreset) -> Void) {
        mutate(&_storedPreset)
    }

    // UI Visualization. Levels live on `meters`, which ContentView does not observe.
    /// Lit keys live on their own model so a note does not redraw ContentView.
    public let keyDisplay = PressedKeysModel()
    /// Keys held from the UI / computer keyboard. Main thread only.
    private var uiPressedKeys: Set<Int> = []
    /// Keys held on MIDI. Written by the CoreMIDI thread, polled by main.
    public let midiKeys = AtomicKeyBits()
    private var lastMIDIKeyBits: (lo: UInt64, hi: UInt64) = (0, 0)
    private var lastMIDIKeySet: Set<Int> = []
    public let meters = AudioMeterModel()

    public var oscillator1 = Oscillator()
    public var oscillator2 = Oscillator()
    /// SYNT_22 Stage 2: render-owned frequency-multiplier caches (see OscFreqMulCache).
    var rtOsc1FreqMul = OscFreqMulCache()
    var rtOsc2FreqMul = OscFreqMulCache()
    public var envelope = ADSREnvelope()
    public var filterEnvelope = ADSREnvelope()
    public var modEnvelope = ADSREnvelope(attack: 0.01, decay: 0.2, sustain: 0.0, release: 0.1)
    public var filterL = CachedBiquadFilter()
    public var filterR = CachedBiquadFilter()
    public var lfo = LFO()
    public var lfo2 = LFO()
    /// Linear gain rider in front of the waveshapers. Not the brick-wall limiter.
    public let cleanBus = CleanBus()

    /// Owned engines for `.wavetable` waveform only (Stage 3). Classical shapes unchanged.
    public let wavetableEngine1 = WavetableOscillator()
    public let wavetableEngine2 = WavetableOscillator()
    public var loadedWTIndex1: Int = 0
    public var loadedWTIndex2: Int = 0

    /// UI → audio command path (SPSC). Only audio thread mutates the voice pool.
    public let commandQueue = AudioCommandQueue(capacity: 1024)
    /// CoreMIDI thread → audio (SPSC). Separate ring: two producers on one SPSC ring race.
    public let midiQueue = AudioCommandQueue(capacity: 1024)
    /// Main → audio: a MIDI device went away. Applied by the render *after*
    /// draining `midiQueue`, so a key-down the device sent just before it left
    /// cannot outlive the reset.
    public let midiResetRequested = Atomic<Bool>(false)
    /// Audio → UI metering path. Audio writes atomics; main polls.
    public let meteringState = AtomicMeteringState()
    public var cancellables = Set<AnyCancellable>()

    /// Fixed voice pool — no Dictionary on the audio thread (was a multi-note glitch source).
    public static let maxVoices = 32
    /// Released tails kept while other notes are still held. Older tails fast-fade.
    public static let keptReleaseTails = 2
    /// At or below this, release is the pluck. Tail trimming would eat the sound.
    public static let tailTrimSkipsReleaseAtOrBelow: Float = 0.20
    /// Value-type voice pool. `Array(repeating:)` would share class state, so each
    /// slot is built on its own. Filter 2 and the formant bank are NOT fields of
    /// this struct: `renderOneSample` copies it, and a class field would retain
    /// on the audio thread.
    public var voices: [ActiveNote] = (0..<AudioEngine.maxVoices).map { _ in ActiveNote() }
    /// Filter 2. One instance per slot, allocated here, never inside the voice copy.
    public let voiceDual: [DSPDualFilter] = (0..<AudioEngine.maxVoices).map { _ in DSPDualFilter() }
    /// Filter 1 formant. Same lifetime rule as `voiceDual`.
    public let voiceFormant: [DSPFormantFilter] = (0..<AudioEngine.maxVoices).map { _ in DSPFormantFilter() }
    /// Filter 1 comb / resonator. Same lifetime rule as `voiceDual`.
    public let voiceComb: [DSPCombFilter] = (0..<AudioEngine.maxVoices).map { _ in DSPCombFilter() }
    public let voiceDualPtr: UnsafeMutablePointer<Unmanaged<DSPDualFilter>>
    public let voiceFormantPtr: UnsafeMutablePointer<Unmanaged<DSPFormantFilter>>
    public let voiceCombPtr: UnsafeMutablePointer<Unmanaged<DSPCombFilter>>
    public var activeVoiceCountRT: Int = 0
    /// Audio-thread note-off counter. Newer releases have a higher serial.
    public var releaseSerialRT: Int = 1

    /// Offline and pre-start default. `start()` replaces this with the device rate.
    private(set) var sampleRate: Double = 44100.0
    private var graphSampleRate: Double = 44100.0
    private var isApplyingSampleRate = false
    private var configObserver: NSObjectProtocol?

    // MARK: - Cached parameters (written on applyPreset / main; read on audio path)
    public var cachedOsc2Enabled: Bool = true
    public var cachedSubOscVolume: Float = 0.0
    public var cachedSubOscOctave: Int = -1
    public var cachedSubOscWaveform: WaveformType = .sine
    public var cachedFmAmount: Float = 0.0
    public var cachedOscSyncEnabled: Bool = false
    public var cachedFilterCutoff: Float = 5000.0
    public var cachedFilterDrive: Float = 0
    /// Render-owned CC override for the base resonance (-1 = none). Applied as a
    /// render-local offset; `filterL/R.resonance` keep their single writer (main).
    public var ccResonanceRT: Float = -1
    /// MIDI CC pan offset, -1...1 (render thread only; 0 = centre / no CC).
    public var ccPanRT: Float = 0
    /// Targets for the ~8 ms CC glide. The live fields are the smoothed values.
    public var ccPanTarget: Float = 0
    public var ccPwm1Target: Float = 0.5
    public var ccPwm2Target: Float = 0.5
    public var ccDetune1Target: Float = 0
    public var ccDetune2Target: Float = 0
    public var ccMixTarget: Float = 0.5
    public var ccLfoRateTarget: Float = 5
    public var ccAttackTarget: Float = 0.01
    public var ccDecayTarget: Float = 0.1
    public var ccSustainTarget: Float = 0.7
    public var ccReleaseTarget: Float = 0.3
    public var ccCutoffTarget: Float = 5000
    public var ccFilterAttackTarget: Float = 0.01
    public var ccFilterDecayTarget: Float = 0.3
    public var ccFilterSustainTarget: Float = 0.0
    public var ccFilterReleaseTarget: Float = 0.3
    public var ccWtMorph1Target: Float = 0
    public var ccWtMorph2Target: Float = 0
    public var ccLfoDepthTarget: Float = 0
    public var ccSmoothCoeff: Float = 0
    public var ccSmoothCoeffSampleRate: Double = 0
    /// Soft takeover. All bits set = every knob is live. A patch change clears them.
    public let ccCaughtLo = Atomic<UInt64>(UInt64.max)
    public let ccCaughtHi = Atomic<UInt64>(UInt64.max)
    /// Last raw CC seen while a knob was waiting to catch. 255 = none yet.
    public let ccLastRaw = UnsafeMutablePointer<Atomic<UInt8>>.allocate(capacity: 128)
    public var midiSmoothCoeff: Float = 0
    public var midiSmoothCoeffSampleRate: Double = 0
    /// `filterL.resonance` when the CC arrived; a later knob / preset change drops the override.
    public var ccResonanceBaseRT: Float = 0
    /// Per-voice filter envelope depth (-1…1, 1 = +4 octaves at full env). 0 = off.
    public var cachedFilterEnvAmount: Float = 0.0
    /// Per-voice key tracking (0…1) around C4. 0 = off.
    public var cachedFilterKeyTracking: Float = 0.0
    public var cachedFilterEnvUseDedicatedADSR: Bool = false
    public var cachedFilterAttack: Float = 0.01
    public var cachedFilterDecay: Float = 0.3
    public var cachedFilterSustain: Float = 0.0
    public var cachedFilterRelease: Float = 0.3
    public var cachedVelocityToCutoff: Float = 0.0
    public var cachedVelocityToEnvAmount: Float = 0.0
    public var cachedMasterVolume: Float = 0.5
    public var cachedPortamento: Float = 0.0
    public var cachedUnisonVoices: Int = 1
    public var cachedUnisonDetune: Float = 0.0
    public var cachedUnisonSpread: Float = 0.0
    public var cachedAnalogDrift: Float = 0.0
    public var cachedChordMode: ChordMode = .off
    public var cachedBPM: Float = 120.0
    public var cachedSyncSource: SyncSource = .`internal`
    /// Audio thread. True only after MIDI Start/Continue while sync is external.
    public var midiClockRunning = false
    /// The Audio Unit sets this. Standalone and golden renders leave it false,
    /// so the MIDI-clock gate below stays bit-identical.
    public var usesHostTransport = false
    /// Audio thread. Ignored unless `usesHostTransport` is true.
    public var hostTransportMoving = true
    public var cachedLfoTempoSync = false
    public var cachedLfo2TempoSync = false
    public var cachedLfoSyncDivision: TimeDivision = .quarter
    public var cachedLfo2SyncDivision: TimeDivision = .quarter
    public var cachedDelayTempoSync = false
    public var cachedDelaySyncDivision: TimeDivision = .quarter
    public var midiClockSample: UInt64 = 0
    public var midiClockLastSample: UInt64 = 0
    public var midiClockHaveLast = false
    public var midiClockIntervalCount = 0
    public var midiClockIntervalWrite = 0
    /// Twenty-four clock intervals. Allocated once, freed in deinit.
    public let midiClockIntervals = UnsafeMutablePointer<Float>.allocate(capacity: 24)
    /// Timed MIDI for the block currently being rendered. Audio thread only.
    public let midiSchedule = UnsafeMutablePointer<ScheduledMIDI>.allocate(capacity: 512)
    public var midiScheduleCount = 0
    public var blockMIDIParser = MIDIByteParser()
    /// Program change seen on the audio thread. −1 means none. The main poll applies it.
    public let pendingProgram = Atomic<Int32>(-1)
    public var appliedSyncSource: SyncSource = .`internal`
    /// Float bits of the external tempo. 0 means the clock has not locked yet.
    public let externalBPMBits = Atomic<UInt32>(0)
    /// Main-thread copy, published only when it moves by at least half a BPM.
    @Published public var externalTempo: Float = 0
    public var cachedArpMode: ArpeggiatorMode = .off
    public var cachedArpRate: TimeDivision = .sixteenth
    public var cachedArpOctaves: Int = 1
    public var cachedArpGateLength: Float = 0.8
    public var cachedArpSwing: Float = 0.0
    public var cachedArpLatch: Bool = false
    public var cachedHostBeatPosition: Double = 0.0
    public var cachedDelayPingPong: Bool = false
    /// Audio Unit: no device graph, so Apple Delay never runs. The DSP delay
    /// renders both modes (ping-pong off = plain stereo delay).
    public var rendersAllDelayInDSP = false
    /// SYNT_20 P2-8: Audio Unit has no Apple Reverb node either, so the DSP reverb renders
    /// every preset there. Off by default (standalone keeps Apple Reverb when the preset asks).
    public var rendersAllReverbInDSP = false
    /// Fixed table of FX slots read on the RT audio thread without allocations.
    public var cachedFXOrder: FXOrderTable = FXOrderTable()
    /// Host or user preference for MIDI Program Change events.
    @Published public var respondsToProgramChange: Bool = false
    public static let maxActiveRamps = 8
    public var activeRamps = [ActiveParameterRamp](repeating: ActiveParameterRamp(), count: maxActiveRamps)
    public var hasActiveRamps = false
    /// Knob values for Apple Delay and Reverb. The parameter provider reads these
    /// instead of copying `preset` (the preset holds arrays).
    public var parameterReverbMix: Float = 0.2
    public var parameterReverbRoom: Float = 0.5
    public var parameterDelayTime: Float = 0.3
    var glideRateCached: Double = 0
    var glideRateForPortamento: Float = -1
    var glideRateSampleRate: Double = 0
    public var parameterDelayFeedback: Float = 0.4
    public var parameterDelayMix: Float = 0
    public var cachedChorusStereo: Bool = true
    public var cachedReverbShimmer: Float = 0.0
    public var cachedRingModAmount: Float = 0.0
    public var cachedNoiseColor: NoiseColor = .white
    public var cachedVoiceMode: VoiceMode = .poly
    public var cachedVelocityCurve: VelocityCurve = .linear
    public var cachedVelocityToVolume: Float = 1.0
    public var cachedGlideMode: GlideMode = .time
    public var cachedGlideLegatoOnly: Bool = false
    public var cachedMonoPriority: MonoPriority = .last
    public var cachedStereoEnabled: Bool = false
    public var cachedStereoWidth: Float = 1
    public var cachedStereoMidSide: Float = 0
    public var cachedStereoHaasMs: Float = 0
    public var cachedStereoMonoBassHz: Float = 0
    public var cachedOscPhaseMode: OscPhaseMode = .reset
    /// 32 searches every voice. A smaller limit only narrows `findFreeVoiceSlot`.
    public var cachedPolyphonyLimit: Int = AudioEngine.maxVoices
    public var cachedTranceEnabled: Bool = false
    public var cachedTranceSteps: UInt16 = 0xAAAA
    public var cachedTranceDepth: Float = 1
    public var cachedTranceSmooth: Float = 0
    public var cachedTranceDivision: TimeDivision = .sixteenth
    var tranceStep: Int = 0
    var tranceCursor: Double = 0
    /// Set from the host musical context. Locate and loop overwrite it.
    var tranceHostBeat: Double = 0
    var tranceHostLocked: Bool = false
    var tranceGain: Float = 1
    var tranceSmoothForCoeff: Float = -1
    var tranceCoeffRate: Double = 0
    var tranceSmoothCoeff: Float = 1
    public let smoothRandom = SmoothRandom()
    /// One MSEG for the matrix. Banks are swapped from the preset, not written in place.
    public let mseg: DSPMSEG = {
        let unit = DSPMSEG(sampleRate: 44_100)
        unit.publishEmpty()
        return unit
    }()
    public let mseg2: DSPMSEG = {
        let unit = DSPMSEG(sampleRate: 44_100)
        unit.publishEmpty()
        return unit
    }()
    public var cachedPerlinHz: Float = 1
    public var cachedPerlinTempoSync: Bool = false
    public var cachedPerlinDivision: TimeDivision = .quarter
    public var cachedChorusFlanger: Bool = false
    public var cachedChorusFlangerSync: Bool = false
    public var cachedChorusFlangerDivision: TimeDivision = .quarter
    public var cachedFilterFeedback: Float = 0
    public var cachedFilter2Routing: DualFilterRouting = .off
    public var cachedFilter2Type: FilterType = .lowPass
    public var cachedFilter2Cutoff: Float = 2000
    public var cachedFilter2Resonance: Float = 0.2
    public var cachedFilter2Balance: Float = 0.5
    public var cachedFilterVowel: Float = 0
    public var cachedDSPReverb: Bool = false
    public var cachedReverbMix: Float = 0
    public var cachedReverbRoom: Float = 0.5
    public var cachedReverbDamping: Float = 0.4
    public var cachedSendA: Float = 0
    public var cachedSendB: Float = 0
    public var cachedSendDelayTime: Float = 0.3
    public var cachedSendDelayFeedback: Float = 0.4
    public var cachedSendPostInsert: Bool = false
    public var lastSendA: Float = 0
    public var lastSendB: Float = 0
    public var sendFadeA: Float = 0
    public var sendFadeB: Float = 0
    /// R9-2: Step per sample for smooth 10–20 ms tail fade (~15 ms at current sample rate).
    public var sendFadeStep: Float = Float(1.0 / (44100.0 * 0.015))
    /// R11-4: Per-AU instance user wavetable and compiled mip data (not static/shared).
    public var userWavetable: Wavetable?
    public var userCompiledWavetable: CompiledMipData?
    public var cachedRotaryEnabled: Bool = false
    public var cachedRotaryFast: Bool = false
    public var cachedRotaryHornSlow: Float = 0.7
    public var cachedRotaryHornFast: Float = 6.8
    public var cachedRotaryDrumSlow: Float = 0.55
    public var cachedRotaryDrumFast: Float = 5.2
    public var cachedRotaryDrive: Float = 0
    public var cachedRotaryMix: Float = 1
    public var cachedRotaryAccel: Float = 2
    public var cachedTransientEnabled: Bool = false
    public var cachedTransientAttack: Float = 0.0
    public var cachedTransientSustain: Float = 0.0
    public var cachedTransientOutput: Float = 1.0
    public var cachedTransientMix: Float = 1.0
    public var cachedOsc2Fixed: Bool = false
    public var cachedOsc2Hz: Float = 440
    public var cachedSceneHPF: Bool = false
    public var cachedSceneHPFHz: Float = 120
    public var cachedFMRatio: Bool = false
    public var cachedFMCoarse: Int = 1
    public var cachedFMFine: Float = 0
    public var cachedFMRoute: FMRoute = .osc2ToOsc1
    public var randomSeed: UInt32 = 0x12345678
    /// Optional microtonal tuning table (128 notes). Nil = standard 12-TET.
    public var customTuningTable: [Double]? = nil

    @inline(__always)
    public func noteToFrequency(_ midiNote: Int) -> Double {
        if let table = customTuningTable, midiNote >= 0, midiNote < table.count {
            return table[midiNote]
        }
        return AudioMath.midiToFrequency(midiNote)
    }
    public var monoNoteStack = MonoNoteStack()
    /// Lock-free RT CC mapping table: 128 slots storing target ID (-1 if unmapped)
    /// CC -> target index. Written on main, read on the audio thread: per-slot atomics.
    public let rtCCMap = UnsafeMutablePointer<Atomic<Int16>>.allocate(capacity: 128)
    public var cachedMacro1: Float = 0.0
    public var cachedMacro2: Float = 0.0
    public var cachedMacro3: Float = 0.0
    public var cachedMacro4: Float = 0.0
    public var cachedMacro5: Float = 0.0
    public var cachedMacro6: Float = 0.0
    public var cachedMacro7: Float = 0.0
    public var cachedMacro8: Float = 0.0
    public var cachedRandomSeed: UInt32? = nil
    public var lastAppliedSeed: UInt32? = nil
    public var cachedAttackCurve: Float = 0.0
    public var cachedDecayCurve: Float = 0.0
    public var cachedReleaseCurve: Float = 0.0
    public var cachedLfoStereoPhase: Float = 0.0
    public var cachedLfo2StereoPhase: Float = 0.0
    public var envelopeFollowerRT: Float = 0.0
    public var envelopeFollowerValue: Float = 0.0
    public var cachedEnvFollowerAttack: Float = 0.01 {
        didSet { updateEnvFollowerCoeffs() }
    }
    public var cachedEnvFollowerRelease: Float = 0.05 {
        didSet { updateEnvFollowerCoeffs() }
    }
    public var envFollowerAttCoeff: Float = 0.002
    public var envFollowerRelCoeff: Float = 0.0005

    public func updateEnvFollowerCoeffs(rate: Double? = nil) {
        let sr = max(8000.0, rate ?? sampleRate)
        envFollowerAttCoeff = 1.0 - Float(exp(-1.0 / (sr * Double(max(0.0005, cachedEnvFollowerAttack)))))
        envFollowerRelCoeff = 1.0 - Float(exp(-1.0 / (sr * Double(max(0.0005, cachedEnvFollowerRelease)))))
    }
    public let liveModulation = LiveModulationSnapshot()
    public var lastRenderedSampleL: Float = 0.0
    public var lastRenderedSampleR: Float = 0.0
    public let frequencyShifter = DSPFrequencyShifter()
    public var cachedFrequencyShifterEnabled: Bool = false
    public var cachedFrequencyShifterShiftHz: Float = 0.0
    public var cachedFrequencyShifterMix: Float = 0.5
    public var cachedFrequencyShifterFeedback: Float = 0.0
    public var cachedCharacter: CharacterMode = .off
    public let characterToneL = DSPCharacterTone()
    public let characterToneR = DSPCharacterTone()
    /// Read per sample on the render thread; never an array there.
    public let rtModMatrix = RTModMatrix()
    /// Double-buffered preset snapshot consumed by render thread at buffer boundaries.
    public let rtPresetBuffer = RTPresetBuffer()
    public let isRenderingActive = Atomic<Bool>(false)
    /// SYNT_20 P1-2: render lifecycle, not "inside a callback". True from AU
    /// `allocateRenderResources` / standalone `start()` until deallocate / `stop()`.
    /// While true, main only publishes snapshots and render applies them; while false
    /// nothing renders, so main may apply DSP directly.
    public let renderLifecycleActive = Atomic<Bool>(false)
    public var lastAppliedPresetID: UUID?
    public var lastAppliedPresetName: String = ""

    // Portamento state (audio thread)
    public var lastPlayedFrequency: Double? = nil

    /// Audio-thread performance controls. UI only pushes commands.
    public var pitchBendTarget: Float = 0
    public var pitchBendSmoothed: Float = 0
    public var cachedPitchBendRange: Float = 2
    /// Last `exp2` of the smoothed bend. Reused while the wheel and the range stay put.
    public var cachedPitchBendMultiplier: Double = 1
    public var cachedPitchBendMultiplierSmoothed: Float = 0
    public var cachedPitchBendMultiplierRange: Float = 0
    /// 0 keeps the preset LFO depth; CC1 adds on top, up to full depth at 127.
    public var modWheel: Float = 0
    public var aftertouchTarget: Float = 0
    public var aftertouchSmoothed: Float = 0
    public var cachedLfoDepth: Float = 0.5
    public var cachedLfo2Depth: Float = 0.5
    public var sustainPedalDown = false
    public var sustainedLo: UInt64 = 0
    public var sustainedHi: UInt64 = 0

    // MPE (MIDI Polyphonic Expression)
    // SYNT_17 R13-7: the three routing mirrors are main-thread vars; the standalone CoreMIDI thread
    // reads them only through `standaloneMPERouting` (one atomic word), never the vars themselves.
    public var mpeEnabled: Bool = false { didSet { publishStandaloneMPERouting() } }
    public var cachedMpeEnabled: Bool = false
    public var mpePitchBendRange: Float = 48.0
    public var cachedMpePitchBendRange: Float = 48.0
    public var mpeZone: MPEZone = .lower { didSet { publishStandaloneMPERouting() } }
    public var cachedMpeZone: MPEZone = .lower
    public var mpeMemberChannelCount: Int = 15 { didSet { publishStandaloneMPERouting() } }
    /// SYNT_17 R13-7: bit 0 enabled, bit 1 upper zone, bits 2-6 member count. Default = off/lower/15.
    public let standaloneMPERouting = Atomic<Int>(15 << 2)
    func publishStandaloneMPERouting() {
        let v = (mpeEnabled ? 1 : 0) | (mpeZone == .upper ? 2 : 0) | (max(0, min(15, mpeMemberChannelCount)) << 2)
        standaloneMPERouting.store(v, ordering: .releasing)
    }
    /// Any thread. Lock-free snapshot of the standalone routing config.
    @inline(__always)
    public func standaloneMPESnapshot() -> (enabled: Bool, zone: MPEZone, memberCount: Int) {
        let v = standaloneMPERouting.load(ordering: .acquiring)
        return (v & 1 != 0, v & 2 != 0 ? .upper : .lower, (v >> 2) & 0x1F)
    }
    public var cachedMpeMemberChannelCount: Int = 15
    /// SYNT_16 R13-1: controller (RPN 0 / MCM) values layered over the host/preset value.
    /// Render thread only. A snapshot or parameter write that repeats the previous host
    /// value keeps the controller value; a different host value replaces it.
    public var mpeCtl = MPEControllerOverride()
    /// SYNT_17 R14-1: main-thread mirror of the controller overrides (runtime only, never saved).
    /// UI reads it to show controller values next to the user's settings.
    public var controllerMPEMain = MPEControllerOverride() {
        didSet {
            // SYNT_18 R15-8: UI line for the controller override (nil = none).
            let s = controllerMPEMain.overrideSummary
            if s != controllerMPEOverrideSummary { controllerMPEOverrideSummary = s }
        }
    }
    /// SYNT_18 R15-8: published summary of the controller MPE override (runtime only).
    @Published public var controllerMPEOverrideSummary: String? = nil
    /// SYNT_18 R15-5: render-owned LFO gate (written only by applyPresetDSP / applyAddressedParameterRT).
    public var rtOsc1IsWavetable = false
    public var rtOsc2IsWavetable = false
    /// SYNT_16 R13-9: master-channel RPN 0 range seen by main. Runtime only, never saved in a preset.
    /// SYNT_17 R14-8: published so the standalone MPE menu shows it.
    @Published public var controllerMasterPitchBendRange: Float? = nil
    /// Main thread. Called after `pollMPEConfigMailbox` mirrored a controller change
    /// (the AU writes the MPE parameters into its store from here).
    public var controllerMPEConfigDidChange: (() -> Void)? = nil
    /// R12-1: render writes packed MPE config here (RPN/MCM); main polls it. Bit 63 = new data.
    public let mpeConfigMailbox = Atomic<UInt64>(0)
    /// SYNT_21 R17-2: main only. Number of resets issued (mod 256); replaces the SYNT_20 Bool so a
    /// double Reset before render drains cannot let an entry between the two resets through.
    var mpeResetIssued: UInt8 = 0
    /// SYNT_21 R17-2: render only. Number of resets applied (mod 256), stamped into every mailbox entry.
    var rtMPEResetApplied: UInt8 = 0
    /// SYNT_16 R13-5: last resolved user wavetable blob (main thread only).
    var lastUserWTData: Data?
    var lastUserWTSampleRate: Double = 0
    var lastUserWTCompiled: CompiledMipData?
    public var userWTFastPathCountForTesting = 0
    public var mpeChannelStates: [MPEChannelState] = Array(repeating: MPEChannelState(), count: 16)

    public struct RPNChannelState {
        public var rpnMSB: UInt8? = nil
        public var rpnLSB: UInt8? = nil
        /// SYNT_16: last Data Entry MSB, so a following CC 38 (LSB) can refine it.
        public var dataMSB: UInt8? = nil
        public init() {}
    }
    public var rpnStates: [RPNChannelState] = Array(repeating: RPNChannelState(), count: 16)

    // Level metering (audio-thread accumulators → AtomicMeteringState)
    public var currentLevel: Float = 0.0
    public var currentPeak: Float = 0.0
    public var sampleCounter: Int = 0
    public let levelUpdateInterval: Int = 2048
    public let levelDecay: Float = 0.95
    public let peakDecay: Float = 0.9995

    // Parameter Smoothing
    public var smoothedFilterCutoff: Float = 5000.0
    public var smoothedMasterVolume: Float = 0.5
    /// 0.999 per sample at 44.1 kHz (~23 ms). Rescaled so the time stays put at
    /// other rates; pow(0.999, 1) is exact, so 44.1 kHz renders are unchanged.
    public var smoothingCoeff: Float = 0.999
    public static func smoothingCoefficient(sampleRate: Double) -> Float {
        Float(pow(0.999, 44_100.0 / max(8_000, sampleRate)))
    }
    /// Peak before the safety soft-clip (tests / gain staging).
    public var lastPreClipAbs: Float = 0
    /// Previous LFO sample, used only when a row modulates LFO rate or depth.
    public var lastMatrixLFO: Float = 0
    public var lastMatrixLFO2: Float = 0
    /// Legacy patches: LFO matrix rows are scaled by LFO Depth (see SynthPreset).
    public var cachedLfoRowsFollowDepth = false

    // Oscilloscope Capture (audio thread buffer → AtomicMeteringState)
    public var scopeBuffer: [Float] = Array(repeating: 0.0, count: 512)
    public var scopeIndex: Int = 0
    public var isCapturingScope: Bool = true

    // Clock & Arpeggiator (audio-thread state)
    public var clockPhase: Double = 0.0
    public var samplesPerTick: Double = 0.0
    public var arpStepIndex: Int = 0
    public var arpGateSamplesLeft: Int = 0
    public var arp = ArpeggiatorEngine()
    public var heldKeysForArp = MIDIKeySet()
    public var latchedKeysForArp = MIDIKeySet()
    public var playedKeysForArp: [Int] = {
        var a: [Int] = []
        a.reserveCapacity(32)
        return a
    }()

    /// UI publishes a pattern snapshot; the audio thread owns the clock.
    public let sequencerTransport = SequencerTransport()
    public var seqMirror = SequencerTransport.Mirror()

    // Random noise seed (also used by arp random mode)
    public var noiseSeed: UInt32 = 12345

    /// `coreOnly`: DSP core for the Audio Unit. No device graph, no audio
    /// session, no 30 Hz main poll, no shared MIDI CC store.
    /// `audioUnitHosted`: set the AU flags (host transport, delay/reverb always in DSP) before
    /// the initial apply, so the AU needs no second apply after construction.
    public init(coreOnly: Bool = false, audioUnitHosted: Bool = false) {
        for i in 0..<128 { (rtCCMap + i).initialize(to: Atomic<Int16>(-1)) }
        for i in 0..<128 { (ccLastRaw + i).initialize(to: Atomic<UInt8>(255)) }
        midiClockIntervals.initialize(repeating: 0, count: 24)
        midiSchedule.initialize(repeating: ScheduledMIDI(offset: 0, command: .clearAll), count: 512)
        voiceDualPtr = .allocate(capacity: AudioEngine.maxVoices)
        voiceFormantPtr = .allocate(capacity: AudioEngine.maxVoices)
        voiceCombPtr = .allocate(capacity: AudioEngine.maxVoices)
        for i in 0..<AudioEngine.maxVoices {
            (voiceDualPtr + i).initialize(to: Unmanaged.passUnretained(voiceDual[i]))
            (voiceFormantPtr + i).initialize(to: Unmanaged.passUnretained(voiceFormant[i]))
            (voiceCombPtr + i).initialize(to: Unmanaged.passUnretained(voiceComb[i]))
        }
        _ = MIDIControlTarget.from(rtIndex: 0) // warm the static table off the audio thread

        // Attach wavetable engines before first render (used only if waveform == .wavetable).
        oscillator1.wavetableEngine = wavetableEngine1
        oscillator1.wavetableSampleRate = sampleRate
        oscillator2.wavetableEngine = wavetableEngine2
        oscillator2.wavetableSampleRate = sampleRate
        lfo.wavetableEngine = wavetableEngine1
        lfo2.wavetableEngine = wavetableEngine2

        // Stage 4 defaults: advanced FX off (keep current factory sound).
        distortion.enabled = false
        parametricEQL.enabled = false
        parametricEQR.enabled = false
        phaser.bypass = true
        sendDelay.enabled = true
        sendDelay.mix = 1
        sendDelay.crossFeed = true

        if !coreOnly {
            setupAudioSession()
            setupAudioEngine()
        }
        if audioUnitHosted {
            usesHostTransport = true
            rendersAllDelayInDSP = true
            rendersAllReverbInDSP = true  // SYNT_20 P2-8
        }
        isConstructing = true
        applyPreset()
        isConstructing = false
        _ = rtPresetBuffer.pullNewSnapshot()
        guard !coreOnly else { return }
        startMeteringPoll()
        // Tests build an engine per case. Attaching every one of them would point
        // the shared CC store at a throwaway engine and drop a mapping mid-test.
        if !RuntimeEnvironment.isUnitTestHost {
            MIDICCLearnStore.shared.attachEngine(self)
        }
    }

    public func updateRTMappings(_ mappings: [UInt8: MIDIControlTarget]) {
        for i in 0..<128 {
            let idx: Int16 = mappings[UInt8(i)]?.rtIndex ?? -1
            (rtCCMap + i).pointee.store(idx, ordering: .releasing)
        }
    }


    private func setupAudioSession() {
        #if os(iOS)
        do {
             let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            Self.log.error("Failed to set up audio session: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    public func renderBlock(intoL: UnsafeMutablePointer<Float>, intoR: UnsafeMutablePointer<Float>?, frameCount: Int) {
        wavetableEngine1.pullNewWavetableRT()
        wavetableEngine2.pullNewWavetableRT()
        // SYNT_16 R13-4: wavetable LFOs follow their oscillator's table (per-block snapshot).
        // SYNT_17 R14-5: only while that oscillator is in wavetable mode; otherwise the default shape
        // (the last-loaded table is invisible to the user then).
        lfo.adoptShape(bits: rtOsc1IsWavetable ? wavetableEngine1.lfoShapeBits.load(ordering: .acquiring) : 0)
        lfo2.adoptShape(bits: rtOsc2IsWavetable ? wavetableEngine2.lfoShapeBits.load(ordering: .acquiring) : 0)
        if let intoR = intoR {
            for frame in 0..<frameCount {
                advanceParameterRampsRT()
                let (sampleL, sampleR) = renderOneSample()
                intoL[frame] = sampleL
                intoR[frame] = sampleR
            }
        } else {
            for frame in 0..<frameCount {
                advanceParameterRampsRT()
                let (sampleL, sampleR) = renderOneSample()
                intoL[frame] = (sampleL + sampleR) * 0.5
            }
        }
    }

    public func enqueueParameterRamp(
        id: UInt64,
        startValue: Float,
        endValue: Float,
        durationFrames: Int,
        sampleOffset: Int
    ) {
        guard durationFrames > 1 else {
            enqueueParameter(id: id, value: endValue, sampleOffset: sampleOffset)
            return
        }
        let dur = max(1, durationFrames)
        let step = (endValue - startValue) / Float(dur)
        var targetIndex = -1
        for i in 0..<Self.maxActiveRamps {
            if activeRamps[i].active && activeRamps[i].id == id {
                targetIndex = i
                break
            }
        }
        if targetIndex == -1 {
            for i in 0..<Self.maxActiveRamps {
                if !activeRamps[i].active {
                    targetIndex = i
                    break
                }
            }
        }
        if targetIndex == -1 {
            targetIndex = 0
        }
        activeRamps[targetIndex] = ActiveParameterRamp(
            id: id,
            currentValue: startValue,
            targetValue: endValue,
            stepPerFrame: step,
            remainingFrames: dur,
            startOffset: max(0, sampleOffset),
            active: true
        )
        hasActiveRamps = true
    }

    @inline(__always)
    public func advanceParameterRampsRT() {
        guard hasActiveRamps else { return }
        var stillActive = false
        for i in 0..<Self.maxActiveRamps {
            if activeRamps[i].active {
                if activeRamps[i].startOffset > 0 {
                    activeRamps[i].startOffset -= 1
                    stillActive = true
                    continue
                }
                activeRamps[i].currentValue += activeRamps[i].stepPerFrame
                activeRamps[i].remainingFrames -= 1
                if activeRamps[i].remainingFrames <= 0 {
                    activeRamps[i].currentValue = activeRamps[i].targetValue
                    activeRamps[i].active = false
                } else {
                    stillActive = true
                }
                applyAddressedParameterRT(id: activeRamps[i].id, value: activeRamps[i].currentValue)
            }
        }
        hasActiveRamps = stillActive
    }

    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        let engineRef = Unmanaged.passUnretained(self)
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let engine = engineRef.takeUnretainedValue()
            let frames = Int(frameCount)
            guard frames > 0 else { return noErr }

            engine.render(frames: frames, into: audioBufferList)
            return noErr
        }

        guard let sourceNode = sourceNode else { return }

        engine.attach(sourceNode)
        engine.attach(delay.delay)
        engine.attach(reverb.reverb)
        engine.attach(peakLimiter)
        engine.attach(headroomMixer)

        // Source → Delay → Reverb → Headroom (×0.62) → Peak Limiter → Mixer (×1).
        // Below the ceiling this is the old gain exactly; the limiter is now last,
        // so it holds ~0 dBFS instead of an unreachable −4 dBFS.
        connectPostFX(format: format)
        configurePeakLimiter()
        headroomMixer.outputVolume = Self.postFXHeadroom
        engine.mainMixerNode.outputVolume = 1

        engine.prepare()
        graphSampleRate = sampleRate
    }

    deinit {
        // Observer first, so a late config-change callback can't reach a dying engine.
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        stop()
        // Detach the render node before freeing memory its block reads (rtCCMap).
        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        rtCCMap.deinitialize(count: 128)
        rtCCMap.deallocate()
        ccLastRaw.deinitialize(count: 128)
        ccLastRaw.deallocate()
        midiClockIntervals.deinitialize(count: 24)
        midiClockIntervals.deallocate()
        midiSchedule.deinitialize(count: 512)
        midiSchedule.deallocate()
        voiceDualPtr.deinitialize(count: AudioEngine.maxVoices)
        voiceDualPtr.deallocate()
        voiceFormantPtr.deinitialize(count: AudioEngine.maxVoices)
        voiceFormantPtr.deallocate()
        voiceCombPtr.deinitialize(count: AudioEngine.maxVoices)
        voiceCombPtr.deallocate()
    }

    private static func makePeakLimiter() -> AVAudioUnitEffect {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: description)
    }

    /// Main thread only, and only while the render callback is stopped.
    func applySampleRate(_ rate: Double, rebuildGraph: Bool) {
        guard !isApplyingSampleRate else { return }
        let rate = min(192_000, max(8_000, rate))
        let needsRateChange = abs(rate - sampleRate) > 0.5
        let needsGraph = rebuildGraph && abs(rate - graphSampleRate) > 0.5
        guard needsRateChange || needsGraph else { return }

        isApplyingSampleRate = true
        defer { isApplyingSampleRate = false }

        // Stop the render callback BEFORE touching DSP state it reads.
        let wasRunning = engine.isRunning
        if wasRunning { engine.stop() }

        if needsRateChange {
            sampleRate = rate
            pushSampleRateToDSP(rate)
        }
        if needsGraph {
            reconnectGraph(sampleRate: rate)
        }
        if wasRunning {
            try? engine.start()
        }
    }

    /// Coefficients and mip maps. Must not run from the render callback.
    private func pushSampleRateToDSP(_ rate: Double) {
        let rateF = Float(rate)
        smoothingCoeff = Self.smoothingCoefficient(sampleRate: rate)
        sendFadeStep = Float(1.0 / max(1.0, rate * 0.015))
        parametricEQL.setSampleRate(rateF)
        parametricEQR.setSampleRate(rateF)
        phaser.setSampleRate(rateF)
        dspChorus.setSampleRate(rate)
        pingPongDelay.setSampleRate(rate)
        sendDelay.setSampleRate(rate)
        sendDelay.enabled = true
        sendDelay.mix = 1
        rotary.setSampleRate(rate)
        transientShaper.setSampleRate(rateF)
        shimmer.setSampleRate(rate)
        dspReverb.allocate(sampleRate: rate)
        sendReverb.allocate(sampleRate: rate)
        prepareVoiceFilters(sampleRate: rate, maxFrames: 512)
        mseg.prepare(sampleRate: rate)
        mseg2.prepare(sampleRate: rate)
        wavetableEngine1.setSampleRate(rate)
        wavetableEngine2.setSampleRate(rate)
        oscillator1.wavetableSampleRate = rate
        oscillator2.wavetableSampleRate = rate
        cleanBus.setSampleRate(rateF)
        filterL.setSampleRate(rateF)
        filterR.setSampleRate(rateF)
        updateEnvFollowerCoeffs(rate: rate)
    }

    private func reconnectGraph(sampleRate: Double) {
        if isRecording {
            _ = stopRecording()
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let sourceNode else { return }
        engine.disconnectNodeOutput(sourceNode)
        engine.disconnectNodeOutput(delay.delay)
        engine.disconnectNodeOutput(reverb.reverb)
        engine.disconnectNodeOutput(peakLimiter)
        engine.disconnectNodeOutput(headroomMixer)
        connectPostFX(format: format)
        configurePeakLimiter()
        graphSampleRate = sampleRate
        engine.prepare()
    }

    private func installConfigurationObserver() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleEngineConfigurationChange()
        }
    }

    private func handleEngineConfigurationChange() {
        guard !isApplyingSampleRate else { return }
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard rate >= 8_000 else { return }
        let shouldRun = isPlaying
        applySampleRate(rate, rebuildGraph: true)
        guard shouldRun, !engine.isRunning else { return }
        do {
            try engine.start()
            renderLifecycleActive.store(true, ordering: .sequentiallyConsistent)
            isPlaying = true
        } catch {
            Self.log.error("Failed to restart audio engine after a device change: \(error.localizedDescription, privacy: .public)")
            isPlaying = false
        }
    }

    private func connectPostFX(format: AVAudioFormat) {
        guard let sourceNode else { return }
        engine.connect(sourceNode, to: delay.delay, format: format)
        engine.connect(delay.delay, to: reverb.reverb, format: format)
        engine.connect(reverb.reverb, to: headroomMixer, format: format)
        engine.connect(headroomMixer, to: peakLimiter, format: format)
        engine.connect(peakLimiter, to: engine.mainMixerNode, format: format)
    }

    /// Attack 1 ms, release 50 ms, pre-gain 0 dB. Ceiling is the AU's 0 dBFS.
    private func configurePeakLimiter() {
        let au = peakLimiter.audioUnit
        let params: [(AudioUnitParameterID, AudioUnitParameterValue)] = [
            (kLimiterParam_AttackTime, 0.001),
            (kLimiterParam_DecayTime, 0.050),
            (kLimiterParam_PreGain, 0),
        ]
        for (id, value) in params {
            let status = AudioUnitSetParameter(au, id, kAudioUnitScope_Global, 0, value, 0)
            if status != noErr {
                Self.log.error("Peak limiter param \(id) failed: \(status)")
            }
        }
    }


    // MARK: - Public API (non-audio / UI thread)

    public func start() {
        // Belt and braces: a unit-test run never opens the audio output.
        guard !RuntimeEnvironment.isUnitTestHost else { return }
        guard !engine.isRunning else { return }
        installConfigurationObserver()
        let deviceRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if deviceRate >= 8_000 {
            applySampleRate(deviceRate, rebuildGraph: true)
        }

        do {
            try engine.start()
            renderLifecycleActive.store(true, ordering: .sequentiallyConsistent)
            isPlaying = true
        } catch {
            Self.log.error("Failed to start audio engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func stop() {
        if isRecording {
            _ = stopRecording()
        }
        engine.stop()
        renderLifecycleActive.store(false, ordering: .sequentiallyConsistent)
        isPlaying = false
        clearAllNotes()
        meters.resetDisplay()
        currentLevel = 0.0
        currentPeak = 0.0
        meteringState.setOutputLevel(0)
        meteringState.setPeakLevel(0)
    }

    public func pitchBend(_ normalized: Float) {
        let bend = min(1, max(-1, normalized))
        _ = commandQueue.push(.setPitchBend(bend))
    }

    public func modWheel(_ amount: Float) {
        let wheel = min(1, max(0, amount))
        _ = commandQueue.push(.setModWheel(wheel))
    }

    public func sustainPedal(down: Bool) {
        _ = commandQueue.push(.setSustain(down))
    }

    public func aftertouch(_ amount: Float) {
        let val = min(1, max(0, amount))
        _ = commandQueue.push(.setAftertouch(val))
    }

    public func polyAftertouch(midiNote: Int, pressure: Float) {
        let val = min(1, max(0, pressure))
        _ = commandQueue.push(.setPolyAftertouch(midiNote: midiNote, pressure: val))
    }

    public func noteOn(midiNote: Int, velocity: Float = 1.0) {
        // Read preset only on non-audio path; push RT-safe command
        if preset.arpMode != .off {
            _ = commandQueue.push(.arpKeyDown(midiNote: midiNote))
        } else {
            _ = commandQueue.push(.noteOn(midiNote: midiNote, velocity: velocity))
        }
        updatePressedKeys { $0.insert(midiNote) }
    }

    public func noteOff(midiNote: Int) {
        if preset.arpMode != .off {
            _ = commandQueue.push(.arpKeyUp(midiNote: midiNote))
        } else {
            _ = commandQueue.push(.noteOff(midiNote: midiNote))
        }
        updatePressedKeys { $0.remove(midiNote) }
    }

    // MARK: - MIDI input (CoreMIDI thread only; producer of `midiQueue`)

    /// Does not read `preset`: the audio thread picks arp vs voice.
    public func midiNoteOn(midiNote: Int, velocity: Float, channel: UInt8 = 0) {
        if isStandaloneMPEMember(channel) {
            _ = midiQueue.push(.mpeKeyDown(midiNote: midiNote, velocity: velocity, channel: channel))
        } else {
            _ = midiQueue.push(.keyDown(midiNote: midiNote, velocity: velocity))
        }
        midiKeys.insert(midiNote)
    }

    public func midiNoteOff(midiNote: Int, channel: UInt8 = 0) {
        if isStandaloneMPEMember(channel) {
            _ = midiQueue.push(.mpeKeyUp(midiNote: midiNote, channel: channel))
        } else {
            _ = midiQueue.push(.keyUp(midiNote: midiNote))
        }
        midiKeys.remove(midiNote)
    }

    public func midiPitchBend(_ normalized: Float, channel: UInt8 = 0) {
        let bend = min(1, max(-1, normalized))
        if isStandaloneMPEMember(channel) {
            _ = midiQueue.push(.mpePitchBend(channel: channel, value: bend))
        } else {
            _ = midiQueue.push(.setPitchBend(bend))
        }
    }

    public func midiModWheel(_ amount: Float) {
        _ = midiQueue.push(.setModWheel(min(1, max(0, amount))))
    }

    public func midiAftertouch(_ amount: Float, channel: UInt8 = 0) {
        let val = min(1, max(0, amount))
        if isStandaloneMPEMember(channel) {
            _ = midiQueue.push(.mpePressure(channel: channel, value: val))
        } else {
            _ = midiQueue.push(.setAftertouch(val))
        }
    }

    /// MIDI thread. Zone-aware member test for the standalone path (main-mirrored config).
    @inline(__always)
    public func isStandaloneMPEMember(_ channel: UInt8) -> Bool {
        let r = standaloneMPESnapshot()
        return r.enabled && AudioEngine.isMPEMemberChannel(channel, zone: r.zone, memberCount: r.memberCount)
    }

    /// MIDI thread (standalone). R12-5: routes CC through the same router as the AU path.
    /// Returns true when the CC was consumed by MPE (CC74 timbre on a member, RPN/MCM CCs);
    /// false means the caller handles it as an ordinary CC.
    @discardableResult
    public func midiMPEControlChange(controller: UInt8, value: UInt8, channel: UInt8) -> Bool {
        let r = standaloneMPESnapshot()
        guard r.enabled else { return false }
        let msg = MIDIMessage.controlChange(controller: controller, value: value, channel: channel)
        guard let cmd = AudioEngine.command(for: msg, mpeEnabled: true, zone: r.zone, memberCount: r.memberCount) else { return false }
        switch cmd {
        case .mpeTimbre, .mpeControlChange:
            _ = midiQueue.push(cmd)
            return true
        default:
            return false
        }
    }

    public func midiTimbre(_ amount: Float, channel: UInt8 = 0) {
        let val = min(1, max(0, amount))
        _ = midiQueue.push(.mpeTimbre(channel: channel, value: val))
    }

    public func midiPolyAftertouch(midiNote: Int, pressure: Float) {
        _ = midiQueue.push(.setPolyAftertouch(midiNote: midiNote, pressure: min(1, max(0, pressure))))
    }

    public func midiSustainPedal(down: Bool) {
        _ = midiQueue.push(.setSustain(down))
    }

    /// Main thread: a MIDI source was disconnected or deselected. Release every
    /// key, centre the bend and lift the pedal on the audio thread, after the
    /// MIDI ring (see `processCommandQueue`).
    public func requestMIDIReset() {
        midiResetRequested.store(true, ordering: .releasing)
        midiKeys.removeAll()
        updatePressedKeys { $0.removeAll() }
    }

    /// CC123: release all keys, tails ring out.
    public func midiAllNotesOff() {
        _ = midiQueue.push(.allNotesOff)
        midiKeys.removeAll()
    }

    /// CC120: hard silence (same as a panic / preset change).
    public func midiAllSoundOff() {
        _ = midiQueue.push(.clearAll)
        midiKeys.removeAll()
    }

    public func clearAllNotes() {
        _ = commandQueue.push(.clearAll)
        midiKeys.removeAll()
        updatePressedKeys { $0.removeAll() }
    }

    /// UI thread. Copies swing, BPM, root and the 16 steps into the lock-free snapshot.
    public func updateSequencerSnapshot(
        playing: Bool,
        swing: Float,
        bpm: Float,
        rootNote: Int,
        length: Int,
        generation: UInt32,
        steps: [SequencerStep],
        gate: Float = SequencerTransport.defaultGate
    ) {
        sequencerTransport.publish(
            playing: playing,
            swing: swing,
            bpm: bpm,
            rootNote: rootNote,
            length: length,
            generation: generation,
            gate: gate,
            patternSteps: steps
        )
    }

    /// Audio → UI playhead. The view polls this at 30 Hz.
    public var sequencerDisplayStep: Int { sequencerTransport.currentDisplayStep }

    /// UI producers only (MIDI uses `midiKeys`). Off-main UI callers still hop.
    private func updatePressedKeys(_ body: @escaping (inout Set<Int>) -> Void) {
        if Thread.isMainThread {
            body(&uiPressedKeys)
            refreshKeyDisplay()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                body(&self.uiPressedKeys)
                self.refreshKeyDisplay()
            }
        }
    }

    /// Main thread. Merges UI keys with the polled MIDI bits; publishes on change only.
    public func refreshKeyDisplay() {
        let bits = midiKeys.bits
        if bits != lastMIDIKeyBits {
            lastMIDIKeyBits = bits
            lastMIDIKeySet = AtomicKeyBits.notes(lo: bits.lo, hi: bits.hi)
        }
        let shown = lastMIDIKeySet.isEmpty ? uiPressedKeys : uiPressedKeys.union(lastMIDIKeySet)
        if keyDisplay.keys != shown { keyDisplay.keys = shown }
    }


    // MARK: - Test / diagnostic hooks (drive shipped types without AVAudioEngine)

    /// Offline tests pin the render rate without touching the device graph.
    public func setSampleRateForTesting(_ rate: Double) {
        applySampleRate(rate, rebuildGraph: false)
    }

    /// Rebuilds the AU graph at `rate`. Not used by the offline golden path.
    public func applySampleRateForTesting(_ rate: Double, rebuildGraph: Bool) {
        applySampleRate(rate, rebuildGraph: rebuildGraph)
    }

    public var graphSampleRateForTesting: Double { graphSampleRate }
    public var mainMixerVolumeForTesting: Float { engine.mainMixerNode.outputVolume }

    public var sourceNodeSampleRateForTesting: Double {
        sourceNode?.outputFormat(forBus: 0).sampleRate ?? 0
    }

    /// Live graph: reverb's output is the peak limiter, which feeds the mixer.
    public func postFXChainForTesting() -> (
        limiterFollowsReverb: Bool,
        limiterFeedsMixer: Bool,
        limiterIsAttached: Bool,
        attack: Float,
        decay: Float,
        preGain: Float
    ) {
        let reverbToHeadroom = engine.outputConnectionPoints(for: reverb.reverb, outputBus: 0)
            .contains { $0.node === headroomMixer }
        let headroomToLimiter = engine.outputConnectionPoints(for: headroomMixer, outputBus: 0)
            .contains { $0.node === peakLimiter }
        let afterReverb = reverbToHeadroom && headroomToLimiter
        let intoMixer = engine.outputConnectionPoints(for: peakLimiter, outputBus: 0)
            .contains { $0.node === engine.mainMixerNode }
        let attached = engine.attachedNodes.contains { $0 === peakLimiter }
        var attack: AudioUnitParameterValue = -999
        var decay: AudioUnitParameterValue = -999
        var preGain: AudioUnitParameterValue = -999
        AudioUnitGetParameter(peakLimiter.audioUnit, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, &attack)
        AudioUnitGetParameter(peakLimiter.audioUnit, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, &decay)
        AudioUnitGetParameter(peakLimiter.audioUnit, kLimiterParam_PreGain, kAudioUnitScope_Global, 0, &preGain)
        return (afterReverb, intoMixer, attached, attack, decay, preGain)
    }

    /// Applies current preset caches (same path as didSet). Exposed for unit tests.
    public func applyPresetForTesting() {
        applyPreset()
    }

    /// Snapshot values currently held for the audio path.
    public func cachedAudioParamsForTesting() -> (
        bpm: Float,
        arpMode: ArpeggiatorMode,
        osc2Enabled: Bool,
        unisonVoices: Int,
        portamento: Float,
        filterCutoff: Float,
        masterVolume: Float,
        modMatrixCount: Int
    ) {
        (
            cachedBPM,
            cachedArpMode,
            cachedOsc2Enabled,
            cachedUnisonVoices,
            cachedPortamento,
            cachedFilterCutoff,
            cachedMasterVolume,
            rtModMatrix.publishedCount
        )
    }

    public var reverbFactoryLoadCountForTesting: Int { reverb.factoryPresetLoadCount }

    /// Wrapper 0…1 (not AU percent). Crystal Lead must stay ~0.28, never 28.
    public var delayFeedbackForTesting: Float { delay.feedback }
    public var delayWetPercentForTesting: Float { delay.wetDryMix }

    /// Advanced FX + morph state after `applyPreset` (for factory library tests).
    public func appliedAdvancedFXForTesting() -> (
        distortionEnabled: Bool,
        distortionDrive: Float,
        eqEnabled: Bool,
        eqLowGain: Float,
        phaserEnabled: Bool,
        phaserMix: Float,
        osc1Morph: Float,
        osc2Morph: Float,
        osc1Waveform: WaveformType
    ) {
        (
            distortion.enabled,
            distortion.drive,
            parametricEQL.enabled,
            parametricEQL.lowGain,
            !phaser.bypass,
            phaser.mix,
            oscillator1.wavetableMorph,
            oscillator2.wavetableMorph,
            oscillator1.waveform
        )
    }

    /// Process pending commands as the audio thread would (for unit tests).
    public func processCommandsForTesting() {
        processCommandQueue()
    }

    /// Offline render of the current voice pool (no AVAudioEngine device).
    public func renderFramesForTesting(_ frameCount: Int) -> (peak: Float, nanCount: Int, nearClipCount: Int) {
        let d = renderFramesDetailedForTesting(frameCount)
        return (d.peak, d.nanCount, d.nearClipCount)
    }

    public func renderFramesDetailedForTesting(_ frameCount: Int) -> (
        peak: Float, nanCount: Int, nearClipCount: Int, preClipPeak: Float
    ) {
        var peak: Float = 0
        var preClipPeak: Float = 0
        var nanCount = 0
        var nearClipCount = 0
        let frames = max(0, frameCount)
        guard frames > 0 else { return (0, 0, 0, 0) }
        var left: Float = 0
        var right: Float = 0
        withUnsafeMutablePointer(to: &left) { pL in
            withUnsafeMutablePointer(to: &right) { pR in
                for _ in 0..<frames {
                    renderBlock(intoL: pL, intoR: pR, frameCount: 1)
                    if lastPreClipAbs > preClipPeak { preClipPeak = lastPreClipAbs }
                    let l = pL.pointee
                    let r = pR.pointee
                    if !l.isFinite || !r.isFinite {
                        nanCount += 1
                        continue
                    }
                    let absSample = max(abs(l), abs(r))
                    if absSample > peak { peak = absSample }
                    if absSample > 0.98 { nearClipCount += 1 }
                }
            }
        }
        return (peak, nanCount, nearClipCount, preClipPeak)
    }

    public func unisonScaleForTesting(_ midiNote: Int) -> Float {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                return voices[i].unisonScale
            }
        }
        return 0
    }

    public func voiceReleaseFlagsForTesting() -> [(
        midiNote: Int,
        isReleasing: Bool,
        fastRelease: Bool,
        releaseSerial: Int,
        envelopeValue: Float
    )] {
        var out: [(midiNote: Int, isReleasing: Bool, fastRelease: Bool, releaseSerial: Int, envelopeValue: Float)] = []
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            out.append((
                voices[i].midiNote,
                voices[i].isReleasing,
                voices[i].fastRelease,
                voices[i].releaseSerial,
                voices[i].envelopeValue
            ))
        }
        return out
    }

    public func voiceFilterEnergyForTesting(_ midiNote: Int) -> Float {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                return voices[i].filter.energy
            }
        }
        return 0
    }

    /// Active oscillator partials (unison voices), including those in release.
    public var activePartialCountForTesting: Int {
        var count = 0
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive { count += 1 }
        }
        return count
    }

    /// Partials that are still held (not in release). Chord path should stay at 1 per note.
    public var heldPartialCountForTesting: Int {
        var count = 0
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && !voices[i].isReleasing { count += 1 }
        }
        return count
    }

    /// Active unique MIDI note count after command processing (audio-thread state).
    public var activeNoteCountForTesting: Int {
        var seen = Set<Int>()
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive { seen.insert(voices[i].midiNote) }
        }
        return seen.count
    }

    /// MIDI notes that are still held (not in release). Test helper, not the render path.
    public func heldMIDINotesForTesting() -> Set<Int> {
        var notes = Set<Int>()
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && !voices[i].isReleasing {
                notes.insert(voices[i].midiNote)
            }
        }
        return notes
    }

    /// Whether a note has any active voice in the fixed pool.
    public func isNoteActiveForTesting(_ midiNote: Int) -> Bool {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote { return true }
        }
        return false
    }

    /// Whether every active partial for a note is releasing.
    public func isNoteReleasingForTesting(_ midiNote: Int) -> Bool {
        var found = false
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                found = true
                if !voices[i].isReleasing { return false }
            }
        }
        return found
    }

    /// Expose metering state for tests (write as audio would, read as UI would).
    public var meteringStateForTesting: AtomicMeteringState { meteringState }

    /// Expose command queue for full-queue / FIFO tests that need the engine instance.
    public var commandQueueForTesting: AudioCommandQueue { commandQueue }

    /// Offline render metrics for golden harness (peak + RMS; no device I/O).
    /// Does not alter DSP — only aggregates samples from `renderOneSample()`.
    public func renderFramesMetricsForTesting(_ frameCount: Int) -> (
        peak: Float, rms: Float, nanCount: Int, nearClipCount: Int, preClipPeak: Float
     ) {
        var peak: Float = 0
        var preClipPeak: Float = 0
        var nanCount = 0
        var nearClipCount = 0
        var sumSq: Double = 0
        var finiteFrames = 0
        let frames = max(0, frameCount)
        guard frames > 0 else { return (0, 0, 0, 0, 0) }
        var left: Float = 0
        var right: Float = 0
        withUnsafeMutablePointer(to: &left) { pL in
            withUnsafeMutablePointer(to: &right) { pR in
                for _ in 0..<frames {
                    renderBlock(intoL: pL, intoR: pR, frameCount: 1)
                    if lastPreClipAbs > preClipPeak { preClipPeak = lastPreClipAbs }
                    let l = pL.pointee
                    let r = pR.pointee
                    if !l.isFinite || !r.isFinite {
                        nanCount += 1
                        continue
                    }
                    let absSample = max(abs(l), abs(r))
                    if absSample > peak { peak = absSample }
                    if absSample > 0.98 { nearClipCount += 1 }
                    let mono = Double(l + r) * 0.5
                    sumSq += mono * mono
                    finiteFrames += 1
                }
            }
        }
        let rms: Float
        if finiteFrames > 0 {
            rms = Float(sqrt(sumSq / Double(finiteFrames)))
        } else {
            rms = 0
        }
        return (peak, rms, nanCount, nearClipCount, preClipPeak)
    }

    /// Snapshot active voice oscillators / filter z-energy for continuity goldens.
    public func voiceProbesForTesting(midiNote: Int? = nil) -> [(
        midiNote: Int,
        phase: Double,
        phase2: Double,
        targetFrequency: Double,
        currentFrequency: Double,
        filterEnergy: Float,
        isReleasing: Bool,
        unisonScale: Float
    )] {
        var out: [(
            midiNote: Int,
            phase: Double,
            phase2: Double,
            targetFrequency: Double,
            currentFrequency: Double,
            filterEnergy: Float,
            isReleasing: Bool,
            unisonScale: Float
        )] = []
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            if let midiNote, voices[i].midiNote != midiNote { continue }
            out.append((
                voices[i].midiNote,
                voices[i].phase,
                voices[i].phase2,
                voices[i].targetFrequency,
                voices[i].currentFrequency,
                voices[i].filter.energy,
                voices[i].isReleasing,
                voices[i].unisonScale
            ))
        }
        return out
    }

    // MARK: - Audio Output Recorder
    @Published public var isRecording: Bool = false
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?

    @discardableResult
    public func startRecording(to fileURL: URL? = nil) -> Bool {
        guard !isRecording else { return false }
        let targetURL = fileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("Synth_\(Int(Date().timeIntervalSince1970)).wav")
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else { return false }

        do {
            recordingFile = try AVAudioFile(forWriting: targetURL, settings: format.settings)
            recordingURL = targetURL
            mixer.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let self = self, let file = self.recordingFile else { return }
                try? file.write(from: buffer)
            }
            isRecording = true
            return true
        } catch {
            Self.log.error("Failed to start audio recording: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func stopRecording() -> URL? {
        guard isRecording else { return nil }
        engine.mainMixerNode.removeTap(onBus: 0)
        recordingFile = nil
        isRecording = false
        return recordingURL
    }
}
