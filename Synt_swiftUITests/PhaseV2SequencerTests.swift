//
//  PhaseV2SequencerTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.4: Step Sequencer Ratcheting and Probability.
//

import Foundation
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2SequencerTests {

    @Test func sequencerStepDefaultsAndBackwardCompatibility() throws {
        let step = SequencerStep()
        #expect(step.ratchet == 1)
        #expect(step.probability == 1.0)

        // Decode legacy JSON missing ratchet and probability
        let legacyJSON = """
        {"isActive":true,"noteOffset":5,"velocity":0.9,"octave":1,"tie":false,"gate":0.75}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequencerStep.self, from: legacyJSON)
        #expect(decoded.ratchet == 1)
        #expect(decoded.probability == 1.0)
        #expect(decoded.noteOffset == 5)
        #expect(decoded.velocity == 0.9)
    }

    @Test func sequencerStepRoundTripWithRatchetAndProbability() throws {
        let step = SequencerStep(isActive: true, noteOffset: 3, velocity: 0.7, octave: 0, tie: false, gate: 0.5, ratchet: 3, probability: 0.5)
        let encoded = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequencerStep.self, from: encoded)
        #expect(decoded.ratchet == 3)
        #expect(abs(decoded.probability - 0.5) < 1e-4)
        #expect(decoded.noteOffset == 3)
    }

    @Test func midiFileBuilderRatchetingSubdividesNotes() {
        var steps = [SequencerStep](repeating: SequencerStep(), count: 16)
        // Step 0 has ratchet = 3
        steps[0] = SequencerStep(isActive: true, noteOffset: 0, velocity: 0.8, octave: 0, tie: false, gate: 0.5, ratchet: 3, probability: 1.0)

        let smfData = MIDIFileBuilder.buildSMF(steps: steps, rootNote: 60, bpm: 120.0, length: 1)
        #expect(!smfData.isEmpty)

        // Count Note-On status bytes (0x90) for note 60 (0x3C)
        var noteOnCount = 0
        for i in 0..<(smfData.count - 2) {
            if smfData[i] == 0x90 && smfData[i + 1] == 60 {
                noteOnCount += 1
            }
        }
        #expect(noteOnCount == 3, "Ratchet = 3 must export exactly 3 Note-On events")
    }

    @Test func sequencerZeroProbabilitySkipsStep() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120
        engine.preset = preset
        engine.applyPresetForTesting()

        var pattern = [SequencerStep](repeating: SequencerStep(), count: 16)
        pattern[0] = SequencerStep(isActive: true, noteOffset: 0, velocity: 0.8, ratchet: 1, probability: 0.0)

        engine.sequencerTransport.publish(
            playing: true,
            swing: 0,
            bpm: 120,
            rootNote: 60,
            length: 1,
            generation: 1,
            gate: 0.8,
            patternSteps: pattern
        )

        _ = engine.renderOneSample()
        #expect(engine.seqMirror.stepSkipped, "Step with 0% probability must be skipped")
        #expect(engine.seqMirror.heldNote == -1, "No note should be held when step is skipped")
    }

    @Test func sequencerFullProbabilityTriggersStep() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120
        engine.preset = preset
        engine.applyPresetForTesting()

        var pattern = [SequencerStep](repeating: SequencerStep(), count: 16)
        pattern[0] = SequencerStep(isActive: true, noteOffset: 4, velocity: 0.8, ratchet: 1, probability: 1.0)

        engine.sequencerTransport.publish(
            playing: true,
            swing: 0,
            bpm: 120,
            rootNote: 60,
            length: 1,
            generation: 1,
            gate: 0.8,
            patternSteps: pattern
        )

        _ = engine.renderOneSample()
        #expect(!engine.seqMirror.stepSkipped)
        #expect(engine.seqMirror.heldNote == 64)
    }

    @Test func sequencerRatchetingTriggersSubstepsInRender() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120
        engine.preset = preset
        engine.applyPresetForTesting()

        var pattern = [SequencerStep](repeating: SequencerStep(), count: 16)
        // Step with ratchet = 2
        pattern[0] = SequencerStep(isActive: true, noteOffset: 0, velocity: 0.8, ratchet: 2, probability: 1.0)

        engine.sequencerTransport.publish(
            playing: true,
            swing: 0,
            bpm: 120,
            rootNote: 60,
            length: 1,
            generation: 1,
            gate: 0.5,
            patternSteps: pattern
        )

        // Substep 0 starts at sample 0
        _ = engine.renderOneSample()
        #expect(engine.seqMirror.ratchetIndex == 0)
        #expect(engine.seqMirror.heldNote == 60)

        // Total 16th note at 120 bpm, 44100 sr = 5512.5 samples.
        // Substep 1 starts around 5512.5 / 2 = ~2756 samples.
        _ = engine.renderFramesForTesting(2800)
        #expect(engine.seqMirror.ratchetIndex == 1, "Substep 1 must trigger halfway through the step")
    }

    @Test func phaseV2PreservesInitGolden() {
        let golden: UInt64 = 0xd1b3635203a4799e
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == golden,
                "Init hash changed to 0x\(String(hash, radix: 16)); expected 0x\(String(golden, radix: 16))")
    }
}
