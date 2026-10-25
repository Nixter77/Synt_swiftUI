//
//  StepSequencerTimingTests.swift
//  Sample-accurate step clock on the audio thread.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct StepSequencerTimingTests {

    @Test func straightSixteenthsLandOnStepBoundaries() {
        let ons = renderNoteOns(swing: 0, bpm: 120, steps: 16)
        let base = ons.samplesPerStep
        for index in 0..<16 {
            let midi = 60 + index
            let actual = ons.samples[midi]
            let expected = expectedStepTime(index: index, samplesPerStep: base, swing: 0)
            #expect(actual != nil, "missing noteOn for step \(index)")
            if let actual {
                let error = abs(Double(actual) - expected)
                #expect(error <= 1.0, "step \(index) at \(actual), expected \(expected), error \(error)")
            }
        }
    }

    @Test func swingDelaysEvenStepsByHalfAStepAtFullSwing() {
        let swing: Float = 1
        let ons = renderNoteOns(swing: swing, bpm: 120, steps: 16)
        let base = ons.samplesPerStep
        let shift = Double(swing) * base * 0.5
        for index in 0..<16 {
            let midi = 60 + index
            let actual = ons.samples[midi]
            let straight = Double(index) * base
            let expected = (index % 2 == 1) ? straight + shift : straight
            #expect(actual != nil, "missing swung noteOn for step \(index)")
            if let actual {
                let error = abs(Double(actual) - expected)
                #expect(error <= 1.0, "step \(index) at \(actual), expected \(expected) (shift \(shift)), error \(error)")
            }
        }
    }

    private func renderNoteOns(swing: Float, bpm: Float, steps: Int) -> (samples: [Int: Int], samplesPerStep: Double) {
        let engine = AudioEngine()
        engine.applyPresetForTesting()
        engine.processCommandsForTesting()

        var pattern: [SequencerStep] = []
        for index in 0..<steps {
            var step = SequencerStep()
            step.isActive = true
            step.noteOffset = index
            step.velocity = 0.8
            step.octave = 0
            pattern.append(step)
        }

        engine.updateSequencerSnapshot(
            playing: true,
            swing: swing,
            bpm: bpm,
            rootNote: 60,
            length: steps,
            generation: 1,
            steps: pattern
        )

        let samplesPerStep = engine.sampleRate * 60.0 / Double(bpm) / 4.0
        let frames = Int(samplesPerStep * Double(steps)) + 4
        var first: [Int: Int] = [:]
        var previous = Set<Int>()
        for sample in 0..<frames {
            _ = engine.renderOneSample()
            let held = engine.heldMIDINotesForTesting()
            for note in held where !previous.contains(note) {
                if first[note] == nil {
                    first[note] = sample
                }
            }
            previous = held
        }
        return (first, samplesPerStep)
    }

    /// Continuous time of step `index`. Odd indices (user-facing steps 2, 4, 6…)
    /// are delayed by `swing * samplesPerStep * 0.5`; the following step returns
    /// to the straight grid so the bar does not drift.
    private func expectedStepTime(index: Int, samplesPerStep: Double, swing: Double) -> Double {
        let offset = swing * samplesPerStep * 0.5
        var time = 0.0
        for step in 0..<index {
            if step % 2 == 0 {
                time += samplesPerStep + offset
            } else {
                time += max(1, samplesPerStep - offset)
            }
        }
        return time
    }
}
