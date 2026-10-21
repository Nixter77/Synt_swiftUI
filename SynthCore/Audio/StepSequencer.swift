//
//  StepSequencer.swift
//  Synt_swiftUI
//
//  16-step sequencer engine.
//

import Foundation
import Synchronization

/// Fixed-size step used by the audio-thread sequencer snapshot.
public struct SequencerStepRT {
    public var isActive: Bool = false
    public var noteOffset: Int16 = 0
    public var octave: Int8 = 0
    public var velocity: Float = 0.8
    public var tie: Bool = false
    public var gate: Float = 0.8
    public var ratchet: UInt8 = 1
    public var probability: Float = 1.0
}

/// UI → audio pattern snapshot. One seqlock, no allocation on the audio thread.
/// The UI thread is the only writer. The audio thread copies into its own mirror.
public final class SequencerTransport: @unchecked Sendable {
    public static let stepCount = 16
    public static let defaultGate: Float = 0.5

    public struct Mirror {
        var playing: Bool = false
        var swing: Float = 0
        var bpm: Float = 120
        var rootNote: Int = 60
        var length: Int = 16
        var gate: Float = SequencerTransport.defaultGate
        var generation: UInt32 = 0
        var steps: [SequencerStepRT]
        var scratch: [SequencerStepRT]
        var seenRevision: UInt64 = 0
        var stepIndex: Int = 0
        var phase: Double = 0
        var heldNote: Int = -1
        var gateSamplesLeft: Int = 0
        var armed: Bool = false
        var stepSkipped: Bool = false
        var ratchetIndex: Int = 0
        var prngState: UInt32 = 0x12345678

        init() {
            steps = Array(repeating: SequencerStepRT(), count: SequencerTransport.stepCount)
            scratch = Array(repeating: SequencerStepRT(), count: SequencerTransport.stepCount)
        }
    }

    private let sequence = Atomic<UInt64>(0)
    private let revision = Atomic<UInt64>(0)
    private let displayStep = Atomic<Int>(0)
    private var writeSequence: UInt64 = 0

    private var playing = false
    private var swing: Float = 0
    private var bpm: Float = 120
    private var rootNote: Int = 60
    private var length: Int = 16
    private var gate: Float = SequencerTransport.defaultGate
    private var generation: UInt32 = 0
    private var steps: [SequencerStepRT]

    public init() {
        steps = Array(repeating: SequencerStepRT(), count: Self.stepCount)
    }

    public var currentDisplayStep: Int {
        displayStep.load(ordering: .relaxed)
    }

    public func setDisplayStep(_ step: Int) {
        displayStep.store(step, ordering: .relaxed)
    }

    /// UI thread. Copies into the preallocated slot, then publishes.
    public func publish(
        playing: Bool,
        swing: Float,
        bpm: Float,
        rootNote: Int,
        length: Int,
        generation: UInt32,
        gate: Float,
        patternSteps: [SequencerStep]
    ) {
        let odd = writeSequence &+ 1
        sequence.store(odd, ordering: .releasing)

        self.playing = playing
        self.swing = min(1, max(0, swing))
        self.bpm = max(20, bpm)
        self.rootNote = max(0, min(127, rootNote))
        self.length = max(1, min(Self.stepCount, length))
        self.gate = min(1, max(0.05, gate))
        self.generation = generation

        let n = min(Self.stepCount, patternSteps.count)
        for i in 0..<n {
            steps[i].isActive = patternSteps[i].isActive
            steps[i].noteOffset = Int16(max(-48, min(48, patternSteps[i].noteOffset)))
            steps[i].octave = Int8(max(-2, min(2, patternSteps[i].octave)))
            steps[i].velocity = min(1, max(0, patternSteps[i].velocity))
            steps[i].tie = patternSteps[i].tie
            steps[i].gate = min(1, max(0.05, patternSteps[i].gate))
            steps[i].ratchet = UInt8(max(1, min(4, patternSteps[i].ratchet)))
            steps[i].probability = min(1.0, max(0.0, patternSteps[i].probability))
        }
        for i in n..<Self.stepCount {
            steps[i] = SequencerStepRT()
        }

        let even = writeSequence &+ 2
        writeSequence = even
        sequence.store(even, ordering: .releasing)
        revision.store(even, ordering: .releasing)
    }

    /// Audio thread. Returns true when `generation` changed (transport start/stop/reset).
    public func pullIfChanged(into mirror: inout Mirror) -> Bool {
        let rev = revision.load(ordering: .acquiring)
        if rev == mirror.seenRevision { return false }

        let s1 = sequence.load(ordering: .acquiring)
        if s1 != rev || (s1 & 1) != 0 { return false }

        let playing = self.playing
        let swing = self.swing
        let bpm = self.bpm
        let rootNote = self.rootNote
        let length = self.length
        let gate = self.gate
        let generation = self.generation
        for i in 0..<Self.stepCount {
            mirror.scratch[i] = steps[i]
        }

        // Keep the plain reads above from sinking below the re-check (ARM).
        atomicMemoryFence(ordering: .acquiring)
        let s2 = sequence.load(ordering: .relaxed)
        if s2 != s1 { return false }

        for i in 0..<Self.stepCount {
            mirror.steps[i] = mirror.scratch[i]
        }
        let generationChanged = generation != mirror.generation
        mirror.playing = playing
        mirror.swing = swing
        mirror.bpm = bpm
        mirror.rootNote = rootNote
        mirror.length = length
        mirror.gate = gate
        mirror.generation = generation
        mirror.seenRevision = rev
        return generationChanged
    }
}

/// Step Sequencer pattern containing 16 steps
public struct StepSequencerPattern: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String = "Pattern 1"
    public var steps: [SequencerStep]
    public var length: Int = 16  // Number of active steps (1-16)
    
    public init(name: String = "Pattern 1", stepCount: Int = 16) {
        self.name = name
        self.steps = (0..<stepCount).map { _ in SequencerStep() }
        self.length = stepCount
    }
}

/// Playhead only. Observed by StepSequencerView alone, so a step tick
/// does not invalidate ContentView and every knob.
public final class PlayheadModel: ObservableObject {
    @Published public var step: Int = 0
    public init() {}
}

/// Step Sequencer engine
public final class StepSequencer: ObservableObject {
    public init() {}

    // MARK: - Published Properties
    
    @Published public var isPlaying: Bool = false
    public let playhead = PlayheadModel()
    /// Not @Published on purpose (see PlayheadModel).
    public var currentStep: Int {
        get { playhead.step }
        set { if playhead.step != newValue { playhead.step = newValue } }
    }
    @Published public var pattern: StepSequencerPattern = StepSequencerPattern()
    
    /// Swing amount 0.0 (straight) to 1.0 (max swing)
    @Published public var swing: Float = 0.0
    
    /// Root note (MIDI number)
    @Published public var rootNote: Int = 60  // C4

    /// Bumped on start / stop / reset so the audio thread restarts the clock.
    public private(set) var transportGeneration: UInt32 = 0

    // MARK: - Public Methods

    public func start() {
        transportGeneration &+= 1
        currentStep = 0
        isPlaying = true
    }

    public func stop() {
        transportGeneration &+= 1
        isPlaying = false
    }

    public func reset() {
        transportGeneration &+= 1
        currentStep = 0
    }
    
    // MARK: - Pattern Management
    
    public func setStep(_ index: Int, active: Bool) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].isActive = active
    }
    
    public func setStepOffset(_ index: Int, offset: Int) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].noteOffset = offset
    }
    
    public func setStepVelocity(_ index: Int, velocity: Float) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].velocity = max(0.0, min(1.0, velocity))
    }
    
    public func setStepOctave(_ index: Int, octave: Int) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].octave = max(-2, min(2, octave))
    }
    
    public func clearPattern() {
        pattern = StepSequencerPattern()
    }
    
    public func randomizePattern() {
        for i in 0..<pattern.steps.count {
            pattern.steps[i].isActive = Bool.random()
            pattern.steps[i].noteOffset = Int.random(in: -12...12)
            pattern.steps[i].velocity = Float.random(in: 0.5...1.0)
            pattern.steps[i].octave = Int.random(in: -1...1)
        }
    }
    
}
