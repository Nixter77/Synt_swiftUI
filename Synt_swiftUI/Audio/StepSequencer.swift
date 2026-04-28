//
//  StepSequencer.swift
//  Synt_swiftUI
//
//  16-step sequencer engine.
//

import Foundation

/// Step Sequencer pattern containing 16 steps
struct StepSequencerPattern: Codable, Identifiable {
    var id = UUID()
    var name: String = "Pattern 1"
    var steps: [SequencerStep]
    var length: Int = 16  // Number of active steps (1-16)
    
    init(name: String = "Pattern 1", stepCount: Int = 16) {
        self.name = name
        self.steps = (0..<stepCount).map { _ in SequencerStep() }
        self.length = stepCount
    }
}

/// Step Sequencer engine
final class StepSequencer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPlaying: Bool = false
    @Published var currentStep: Int = 0
    @Published var pattern: StepSequencerPattern = StepSequencerPattern()
    
    /// Swing amount 0.0 (straight) to 1.0 (max swing)
    @Published var swing: Float = 0.0
    
    /// Root note (MIDI number)
    @Published var rootNote: Int = 60  // C4
    
    // MARK: - Callback
    
    /// Called on each step with (midiNote, velocity, gateLength)
    var onStep: ((Int, Float, Float) -> Void)?
    
    /// Called when note should be turned off
    var onNoteOff: ((Int) -> Void)?
    
    // MARK: - Internal State
    
    private var tickCounter: Int = 0
    private var gateOffTick: Int = 0
    private var currentNotePlayning: Int? = nil
    private var samplesPerStep: Double = 0
    private let sampleRate: Double = 44100.0
    private let defaultGateLength: Float = 0.5  // 50% gate
    
    // MARK: - Public Methods
    
    func start() {
        isPlaying = true
        currentStep = 0
        tickCounter = 0
        gateOffTick = 0
        currentNotePlayning = nil
    }
    
    func stop() {
        isPlaying = false
        // Turn off current note
        if let note = currentNotePlayning {
            onNoteOff?(note)
            currentNotePlayning = nil
        }
    }
    
    func reset() {
        currentStep = 0
        tickCounter = 0
        gateOffTick = 0
        if let note = currentNotePlayning {
            onNoteOff?(note)
            currentNotePlayning = nil
        }
    }
    
    /// Call this from audio thread to advance the sequencer
    /// Returns true if a new step was triggered
    @discardableResult
    func tick(bpm: Float, sampleCount: Int = 1) -> Bool {
        guard isPlaying else { return false }
        
        // Calculate samples per 16th note (step)
        let beatsPerSecond = Double(bpm) / 60.0
        let sixteenthsPerSecond = beatsPerSecond * 4.0
        samplesPerStep = sampleRate / sixteenthsPerSecond
        
        // Apply swing to odd steps
        var effectiveSamplesPerStep = samplesPerStep
        if currentStep % 2 == 1 && swing > 0 {
            effectiveSamplesPerStep *= Double(1.0 + swing * 0.5)
        } else if currentStep % 2 == 0 && swing > 0 && currentStep > 0 {
            effectiveSamplesPerStep *= Double(1.0 - swing * 0.25)
        }
        
        tickCounter += sampleCount
        
        // Check if we need to turn off the current note (gate end)
        if currentNotePlayning != nil && tickCounter >= gateOffTick {
            if let note = currentNotePlayning {
                onNoteOff?(note)
                currentNotePlayning = nil
            }
        }
        
        // Check if it's time for next step
        if tickCounter >= Int(effectiveSamplesPerStep) {
            tickCounter = 0
            advanceStep()
            return true
        }
        
        return false
    }
    
    // MARK: - Pattern Management
    
    func setStep(_ index: Int, active: Bool) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].isActive = active
    }
    
    func setStepOffset(_ index: Int, offset: Int) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].noteOffset = offset
    }
    
    func setStepVelocity(_ index: Int, velocity: Float) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].velocity = max(0.0, min(1.0, velocity))
    }
    
    func setStepOctave(_ index: Int, octave: Int) {
        guard index >= 0 && index < pattern.steps.count else { return }
        pattern.steps[index].octave = max(-2, min(2, octave))
    }
    
    func clearPattern() {
        pattern = StepSequencerPattern()
    }
    
    func randomizePattern() {
        for i in 0..<pattern.steps.count {
            pattern.steps[i].isActive = Bool.random()
            pattern.steps[i].noteOffset = Int.random(in: -12...12)
            pattern.steps[i].velocity = Float.random(in: 0.5...1.0)
            pattern.steps[i].octave = Int.random(in: -1...1)
        }
    }
    
    // MARK: - Private Methods
    
    private func advanceStep() {
        currentStep = (currentStep + 1) % pattern.length
        
        let step = pattern.steps[currentStep]
        
        if step.isActive {
            // Calculate final MIDI note
            let note = rootNote + step.noteOffset + (step.octave * 12)
            let clampedNote = max(0, min(127, note))
            
            // Calculate gate off time (in samples)
            gateOffTick = Int(samplesPerStep * Double(defaultGateLength))
            
            // Trigger note
            onStep?(clampedNote, step.velocity, defaultGateLength)
            currentNotePlayning = clampedNote
        }
    }
}
